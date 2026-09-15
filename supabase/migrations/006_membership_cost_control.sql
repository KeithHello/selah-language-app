-- Selah Membership, Entitlements, Cost Control and Admin Audit Schema.
-- Local migration draft for review before applying to remote environments.

-- 1. Membership Periods and User Subscriptions
CREATE TABLE IF NOT EXISTS public.user_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan TEXT NOT NULL CHECK (plan IN ('free', 'trial', 'monthly')),
    status TEXT NOT NULL CHECK (status IN ('trial', 'active', 'expired')),
    source TEXT NOT NULL CHECK (source IN ('paid', 'grant', 'compensation', 'system_trial')),
    started_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    period_index INTEGER NOT NULL DEFAULT 1 CHECK (period_index >= 1),
    total_periods INTEGER NOT NULL DEFAULT 1 CHECK (total_periods >= 1),
    grant_reason TEXT,
    granted_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_memberships_user_status
    ON public.user_memberships(user_id, status, expires_at DESC);

-- 2. Membership Orders
CREATE TABLE IF NOT EXISTS public.membership_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    client_request_id UUID NOT NULL UNIQUE,
    sku TEXT NOT NULL DEFAULT 'selah_membership_monthly',
    amount_fen_cny INTEGER NOT NULL DEFAULT 3990 CHECK (amount_fen_cny > 0),
    currency TEXT NOT NULL DEFAULT 'CNY' CHECK (currency = 'CNY'),
    status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    channel TEXT NOT NULL,
    channel_order_id VARCHAR(200),
    channel_transaction_id VARCHAR(200),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_membership_orders_user
    ON public.membership_orders(user_id, created_at DESC);

-- 3. Entitlement and Cost Reservations
CREATE TABLE IF NOT EXISTS public.membership_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    membership_id UUID REFERENCES public.user_memberships(id),
    client_request_id UUID NOT NULL,
    feature TEXT NOT NULL CHECK (
        feature IN ('transcription', 'sentence', 'preparation', 'batch', 'tts')
    ),
    units_reserved INTEGER NOT NULL CHECK (units_reserved > 0),
    nano_usd_reserved BIGINT NOT NULL CHECK (nano_usd_reserved >= 0),
    nano_usd_actual BIGINT CHECK (nano_usd_actual >= 0),
    status TEXT NOT NULL DEFAULT 'reserved' CHECK (
        status IN ('reserved', 'dispatch_claimed', 'settled', 'released_unsent', 'unknown')
    ),
    payload_hash TEXT NOT NULL,
    budget_period_key TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settled_at TIMESTAMPTZ,
    UNIQUE (user_id, client_request_id, feature)
);

CREATE INDEX IF NOT EXISTS idx_membership_reservations_status
    ON public.membership_reservations(user_id, status, feature);

-- 4. Platform and Pool Budget Ledgers
CREATE TABLE IF NOT EXISTS public.platform_budget_ledgers (
    period_key TEXT PRIMARY KEY,
    budget_nano_usd BIGINT NOT NULL CHECK (budget_nano_usd >= 0),
    committed_nano_usd BIGINT NOT NULL DEFAULT 0 CHECK (committed_nano_usd >= 0),
    reserved_nano_usd BIGINT NOT NULL DEFAULT 0 CHECK (reserved_nano_usd >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Admin Audit Logs
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operator_id UUID NOT NULL REFERENCES auth.users(id),
    target_user_id UUID NOT NULL REFERENCES auth.users(id),
    action TEXT NOT NULL,
    reason TEXT NOT NULL,
    old_state JSONB,
    new_state JSONB,
    client_request_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target
    ON public.admin_audit_logs(target_user_id, created_at DESC);

-- 6. Row Level Security
ALTER TABLE public.user_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_budget_ledgers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.user_memberships FROM anon, authenticated;
REVOKE ALL ON TABLE public.membership_orders FROM anon, authenticated;
REVOKE ALL ON TABLE public.membership_reservations FROM anon, authenticated;
REVOKE ALL ON TABLE public.platform_budget_ledgers FROM anon, authenticated;
REVOKE ALL ON TABLE public.admin_audit_logs FROM anon, authenticated;

GRANT SELECT ON TABLE public.user_memberships TO authenticated;
GRANT SELECT ON TABLE public.membership_orders TO authenticated;
GRANT ALL ON TABLE public.user_memberships TO service_role;
GRANT ALL ON TABLE public.membership_orders TO service_role;
GRANT ALL ON TABLE public.membership_reservations TO service_role;
GRANT ALL ON TABLE public.platform_budget_ledgers TO service_role;
GRANT ALL ON TABLE public.admin_audit_logs TO service_role;

CREATE POLICY user_memberships_select_own ON public.user_memberships
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY membership_orders_select_own ON public.membership_orders
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- 7. Stored Procedure: Get User Membership Summary
CREATE OR REPLACE FUNCTION public.get_user_membership_summary(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_current RECORD;
    v_has_current BOOLEAN := false;
    v_next_started_at TIMESTAMPTZ;
    v_next_source TEXT;
    v_has_trial_ever BOOLEAN := false;
BEGIN
    IF auth.uid() IS NOT NULL
       AND auth.role() <> 'service_role'
       AND auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'membership access denied' USING ERRCODE = '42501';
    END IF;

    -- Check if user ever had a trial
    SELECT EXISTS (
        SELECT 1 FROM public.user_memberships
        WHERE user_id = p_user_id AND plan = 'trial'
    ) INTO v_has_trial_ever;

    -- Find current active period (trial or monthly)
    SELECT * INTO v_current
      FROM public.user_memberships
     WHERE user_id = p_user_id
       AND status IN ('trial', 'active')
       AND started_at <= v_now AND expires_at > v_now
     ORDER BY expires_at DESC
     LIMIT 1;
    v_has_current := FOUND;

    -- Find next queued period if any
    IF v_has_current THEN
        SELECT started_at, source
          INTO v_next_started_at, v_next_source
          FROM public.user_memberships
         WHERE user_id = p_user_id
           AND started_at >= v_current.expires_at
           AND status IN ('trial', 'active')
         ORDER BY started_at ASC
         LIMIT 1;
    ELSE
        SELECT started_at, source
          INTO v_next_started_at, v_next_source
          FROM public.user_memberships
         WHERE user_id = p_user_id
           AND status IN ('trial', 'active')
           AND started_at > v_now
           AND expires_at > started_at
         ORDER BY started_at ASC
         LIMIT 1;
    END IF;

    IF NOT v_has_current THEN
        IF v_has_trial_ever THEN
            RETURN jsonb_build_object(
                'plan', 'free',
                'status', 'expired',
                'periodStartsAt', null,
                'periodEndsAt', null,
                'membershipSource', null,
                'nextPeriodStartsAt', v_next_started_at,
                'nextPeriodSource', v_next_source,
                'renewalMode', 'manual'
            );
        ELSE
            RETURN jsonb_build_object(
                'plan', 'free',
                'status', 'none',
                'periodStartsAt', null,
                'periodEndsAt', null,
                'membershipSource', null,
                'nextPeriodStartsAt', v_next_started_at,
                'nextPeriodSource', v_next_source,
                'renewalMode', 'manual'
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'plan', v_current.plan,
        'status', v_current.status,
        'periodStartsAt', v_current.started_at,
        'periodEndsAt', v_current.expires_at,
        'membershipSource', v_current.source,
        'nextPeriodStartsAt', v_next_started_at,
        'nextPeriodSource', v_next_source,
        'renewalMode', 'manual'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_membership_summary(UUID) TO authenticated, service_role;

-- 8. Stored Procedure: Reserve Generation Allowance
-- Atomically checks active membership/trial, quota limits, platform budget, and reserves units.
CREATE OR REPLACE FUNCTION public.reserve_generation_allowance(
    p_user_id UUID,
    p_client_request_id UUID,
    p_feature TEXT,
    p_units INTEGER,
    p_nano_usd BIGINT,
    p_payload_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_membership public.user_memberships%ROWTYPE;
    v_existing public.membership_reservations%ROWTYPE;
    v_limit INTEGER := 0;
    v_used INTEGER := 0;
    v_reservation_id UUID;
    v_minute_count INTEGER := 0;
    v_budget_period_key TEXT;
    v_budget public.platform_budget_ledgers%ROWTYPE;
BEGIN
    IF auth.uid() IS NOT NULL
       AND auth.role() <> 'service_role'
       AND auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'membership access denied' USING ERRCODE = '42501';
    END IF;
    IF p_feature NOT IN ('transcription', 'sentence', 'preparation', 'batch', 'tts')
       OR p_units IS NULL OR p_units <= 0
       OR p_nano_usd IS NULL OR p_nano_usd < 0
       OR p_payload_hash IS NULL OR char_length(p_payload_hash) = 0 THEN
        RAISE EXCEPTION 'invalid_reservation_request' USING ERRCODE = '22023';
    END IF;

    -- Serialize all reservations for one user before checking the period sum.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_user_id::TEXT || ':membership-reservation', 0)
    );

    -- 1. Check idempotency: already reserved or settled?
    SELECT * INTO v_existing
      FROM public.membership_reservations
     WHERE user_id = p_user_id
       AND client_request_id = p_client_request_id
       AND feature = p_feature;

    IF v_existing.id IS NOT NULL THEN
        IF v_existing.payload_hash IS DISTINCT FROM p_payload_hash THEN
            RAISE EXCEPTION 'request_conflict' USING ERRCODE = 'P0006';
        END IF;
        RETURN jsonb_build_object(
            'reservationId', v_existing.id,
            'status', v_existing.status
        );
    END IF;

    -- 2. Minute rate check (anti-spam protection: max 15 calls per minute)
    SELECT COUNT(*)
      INTO v_minute_count
      FROM public.membership_reservations
     WHERE user_id = p_user_id
       AND created_at >= v_now - INTERVAL '1 minute';

    IF v_minute_count >= 15 THEN
        RAISE EXCEPTION 'rate_limited' USING ERRCODE = 'P0001';
    END IF;

    -- 3. Find active membership or trial
    SELECT * INTO v_membership
      FROM public.user_memberships
     WHERE user_id = p_user_id
       AND status IN ('trial', 'active')
       AND started_at <= v_now AND expires_at > v_now
     ORDER BY expires_at DESC
     LIMIT 1;

    IF v_membership.id IS NULL THEN
        -- Check if user had a trial previously
        IF EXISTS (SELECT 1 FROM public.user_memberships WHERE user_id = p_user_id AND plan = 'trial') THEN
            RAISE EXCEPTION 'trial_expired' USING ERRCODE = 'P0002';
        ELSE
            RAISE EXCEPTION 'membership_required' USING ERRCODE = 'P0003';
        END IF;
    END IF;

    -- 4. Determine feature limits based on plan
    IF v_membership.plan = 'monthly' THEN
        IF p_feature IN ('sentence', 'batch') THEN v_limit := 300;
        ELSIF p_feature = 'tts' THEN v_limit := 30000;
        ELSIF p_feature = 'transcription' THEN v_limit := 3600000;
        ELSIF p_feature = 'preparation' THEN v_limit := 30;
        END IF;
    ELSIF v_membership.plan = 'trial' THEN
        IF p_feature IN ('sentence', 'batch') THEN v_limit := 30;
        ELSIF p_feature = 'tts' THEN v_limit := 3000;
        ELSIF p_feature = 'transcription' THEN v_limit := 300000;
        ELSIF p_feature = 'preparation' THEN v_limit := 3;
        END IF;
    END IF;

    -- 5. Calculate currently used + in-flight reserved units in this membership period
    SELECT COALESCE(SUM(units_reserved), 0)
      INTO v_used
      FROM public.membership_reservations
     WHERE user_id = p_user_id
       AND membership_id = v_membership.id
       AND feature = p_feature
       AND status IN ('reserved', 'dispatch_claimed', 'settled', 'unknown');

    IF (v_used + p_units) > v_limit THEN
        RAISE EXCEPTION 'feature_limit_reached' USING ERRCODE = 'P0004';
    END IF;

    -- The platform daily ledger is deliberately configuration-driven.  A
    -- missing or exhausted row fails closed before the provider is called.
    v_budget_period_key := 'platform:day:' ||
        to_char(v_now AT TIME ZONE 'UTC', 'YYYY-MM-DD');
    SELECT * INTO v_budget
      FROM public.platform_budget_ledgers
     WHERE period_key = v_budget_period_key
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'service_budget_protected' USING ERRCODE = 'P0009';
    END IF;
    IF v_budget.committed_nano_usd + v_budget.reserved_nano_usd + p_nano_usd
        > v_budget.budget_nano_usd THEN
        RAISE EXCEPTION 'service_budget_protected' USING ERRCODE = 'P0009';
    END IF;
    UPDATE public.platform_budget_ledgers
       SET reserved_nano_usd = reserved_nano_usd + p_nano_usd,
           updated_at = v_now
     WHERE period_key = v_budget_period_key;

    -- 6. Insert atomic reservation
    INSERT INTO public.membership_reservations (
        user_id,
        membership_id,
        client_request_id,
        feature,
        units_reserved,
        nano_usd_reserved,
        status,
        payload_hash,
        created_at,
        budget_period_key
    ) VALUES (
        p_user_id,
        v_membership.id,
        p_client_request_id,
        p_feature,
        p_units,
        p_nano_usd,
        'reserved',
        p_payload_hash,
        v_now,
        v_budget_period_key
    )
    RETURNING id INTO v_reservation_id;

    RETURN jsonb_build_object(
        'reservationId', v_reservation_id,
        'status', 'reserved'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reserve_generation_allowance(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT) TO authenticated, service_role;

-- 9. Stored Procedure: Settle Generation Allowance
CREATE OR REPLACE FUNCTION public.settle_generation_allowance(
    p_reservation_id UUID,
    p_status TEXT,
    p_actual_nano_usd BIGINT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reservation public.membership_reservations%ROWTYPE;
    v_budget public.platform_budget_ledgers%ROWTYPE;
    v_committed BIGINT;
BEGIN
    SELECT * INTO v_reservation
      FROM public.membership_reservations
     WHERE id = p_reservation_id
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'reservation_not_found' USING ERRCODE = 'P0005';
    END IF;
    IF auth.uid() IS NOT NULL
       AND auth.role() <> 'service_role'
       AND auth.uid() IS DISTINCT FROM v_reservation.user_id THEN
        RAISE EXCEPTION 'membership access denied' USING ERRCODE = '42501';
    END IF;
    IF p_status NOT IN ('settled', 'released_unsent', 'unknown') THEN
        RAISE EXCEPTION 'invalid_reservation_status' USING ERRCODE = '22023';
    END IF;
    IF p_actual_nano_usd IS NOT NULL AND p_actual_nano_usd < 0 THEN
        RAISE EXCEPTION 'invalid_actual_cost' USING ERRCODE = '22023';
    END IF;

    -- Final states are idempotent.  Unknown usage is intentionally retained
    -- for later evidence and can never be silently released as unsent.
    IF v_reservation.status IN ('settled', 'released_unsent') THEN
        IF v_reservation.status = p_status THEN
            RETURN;
        END IF;
        RAISE EXCEPTION 'reservation_already_final' USING ERRCODE = 'P0006';
    END IF;
    IF v_reservation.status = 'unknown' THEN
        IF p_status = 'unknown' THEN
            RETURN;
        END IF;
        RAISE EXCEPTION 'reservation_unknown_requires_reconciliation' USING ERRCODE = 'P0006';
    END IF;
    IF v_reservation.status NOT IN ('reserved', 'dispatch_claimed') THEN
        RAISE EXCEPTION 'invalid_reservation_transition' USING ERRCODE = 'P0006';
    END IF;
    IF v_reservation.budget_period_key IS NULL THEN
        RAISE EXCEPTION 'service_budget_protected' USING ERRCODE = 'P0009';
    END IF;
    SELECT * INTO v_budget
      FROM public.platform_budget_ledgers
     WHERE period_key = v_reservation.budget_period_key
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'service_budget_protected' USING ERRCODE = 'P0009';
    END IF;

    IF p_status = 'released_unsent' THEN
        UPDATE public.platform_budget_ledgers
           SET reserved_nano_usd = GREATEST(
                   0,
                   reserved_nano_usd - v_reservation.nano_usd_reserved
               ),
               updated_at = now()
         WHERE period_key = v_reservation.budget_period_key;
    ELSE
        v_committed := COALESCE(p_actual_nano_usd, v_reservation.nano_usd_reserved);
        UPDATE public.platform_budget_ledgers
           SET reserved_nano_usd = GREATEST(
                   0,
                   reserved_nano_usd - v_reservation.nano_usd_reserved
               ),
               committed_nano_usd = committed_nano_usd + v_committed,
               updated_at = now()
         WHERE period_key = v_reservation.budget_period_key;
    END IF;
    UPDATE public.membership_reservations
       SET status = p_status,
           nano_usd_actual = p_actual_nano_usd,
           settled_at = now()
     WHERE id = p_reservation_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.settle_generation_allowance(UUID, TEXT, BIGINT) TO authenticated, service_role;

-- 10. Stored Procedure: Apply Verified Payment
-- Idempotently applies payment verification, activates or extends membership period.
CREATE OR REPLACE FUNCTION public.apply_verified_payment(
    p_order_id UUID,
    p_channel_transaction_id TEXT,
    p_verified_at TIMESTAMPTZ DEFAULT now()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order public.membership_orders%ROWTYPE;
    v_latest_period public.user_memberships%ROWTYPE;
    v_start TIMESTAMPTZ;
    v_end TIMESTAMPTZ;
    v_membership_id UUID;
BEGIN
    IF p_order_id IS NULL
       OR p_channel_transaction_id IS NULL
       OR char_length(btrim(p_channel_transaction_id)) = 0
       OR p_verified_at IS NULL THEN
        RAISE EXCEPTION 'invalid_payment_verification' USING ERRCODE = '22023';
    END IF;
    IF p_verified_at > now() + INTERVAL '5 minutes' THEN
        RAISE EXCEPTION 'payment_verified_at_in_future' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_order
      FROM public.membership_orders
     WHERE id = p_order_id
       FOR UPDATE;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'order_not_found' USING ERRCODE = 'P0005';
    END IF;

    IF v_order.status = 'refunded' THEN
        RAISE EXCEPTION 'order_refunded' USING ERRCODE = '22023';
    END IF;
    IF v_order.sku <> 'selah_membership_monthly'
       OR v_order.amount_fen_cny <> 3990
       OR v_order.currency <> 'CNY' THEN
        RAISE EXCEPTION 'order_amount_mismatch' USING ERRCODE = '22023';
    END IF;

    -- Already paid?  A different transaction cannot replay the order.
    IF v_order.status = 'paid' THEN
        IF v_order.channel_transaction_id IS DISTINCT FROM btrim(p_channel_transaction_id) THEN
            RAISE EXCEPTION 'payment_request_conflict' USING ERRCODE = 'P0006';
        END IF;
        RETURN jsonb_build_object('status', 'already_paid', 'orderId', v_order.id);
    END IF;

    -- Update order status
    UPDATE public.membership_orders
       SET status = 'paid',
           channel_transaction_id = btrim(p_channel_transaction_id),
           verified_at = p_verified_at
     WHERE id = p_order_id;

    -- Payments for different orders of the same account share one timeline.
    -- Serialize them before reading the latest period to prevent overlaps.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(v_order.user_id::TEXT || ':membership', 0)
    );

    -- Determine start time: if user has active/queued period, chain onto its end
    SELECT * INTO v_latest_period
      FROM public.user_memberships
     WHERE user_id = v_order.user_id
       AND status IN ('trial', 'active')
       AND expires_at > p_verified_at
     ORDER BY expires_at DESC
     LIMIT 1
     FOR UPDATE;

    IF v_latest_period.id IS NOT NULL THEN
        v_start := v_latest_period.expires_at;
    ELSE
        v_start := p_verified_at;
    END IF;

    v_end := public.add_calendar_months_utc(v_start, 1);

    -- Insert new monthly membership period
    INSERT INTO public.user_memberships (
        user_id,
        plan,
        status,
        source,
        started_at,
        expires_at,
        created_at
    ) VALUES (
        v_order.user_id,
        'monthly',
        'active',
        'paid',
        v_start,
        v_end,
        now()
    )
    RETURNING id INTO v_membership_id;

    RETURN jsonb_build_object(
        'status', 'paid',
        'orderId', v_order.id,
        'membershipId', v_membership_id,
        'startedAt', v_start,
        'expiresAt', v_end
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, TIMESTAMPTZ) TO authenticated, service_role;

-- 11. Service controls and explicit operator allowlist
--
-- The service-control row is deliberately seeded in the safe state.  A
-- database that has the migration but has not been configured still keeps
-- membership sales and trial signups closed until an operator changes them.
CREATE TABLE IF NOT EXISTS public.platform_settings (
    id TEXT PRIMARY KEY DEFAULT 'global' CHECK (id = 'global'),
    version TEXT NOT NULL DEFAULT '2026-09-12-v1',
    revision BIGINT NOT NULL DEFAULT 1 CHECK (revision >= 1),
    membership_enforcement_enabled BOOLEAN NOT NULL DEFAULT false,
    trial_signups_enabled BOOLEAN NOT NULL DEFAULT false,
    membership_sales_enabled BOOLEAN NOT NULL DEFAULT false,
    generation_enabled BOOLEAN NOT NULL DEFAULT true,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_client_request_id TEXT
);

INSERT INTO public.platform_settings (id)
VALUES ('global')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.admin_operators (
    user_id UUID PRIMARY KEY REFERENCES public.admin_members(user_id) ON DELETE CASCADE,
    granted_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.platform_service_control_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_request_id TEXT UNIQUE,
    operator_id UUID NOT NULL REFERENCES auth.users(id),
    payload JSONB NOT NULL,
    result JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_service_control_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.platform_settings FROM anon, authenticated;
REVOKE ALL ON TABLE public.admin_operators FROM anon, authenticated;
REVOKE ALL ON TABLE public.platform_service_control_events FROM anon, authenticated;
GRANT ALL ON TABLE public.platform_settings TO service_role;
GRANT ALL ON TABLE public.admin_operators TO service_role;
GRANT ALL ON TABLE public.platform_service_control_events TO service_role;

CREATE OR REPLACE FUNCTION public.is_admin_operator(
    p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p_user_id IS NOT NULL
       AND public.is_admin_member(p_user_id)
       AND EXISTS (
           SELECT 1
           FROM public.admin_operators
           WHERE user_id = p_user_id
       );
$$;

REVOKE ALL ON FUNCTION public.is_admin_operator(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_operator(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_platform_service_controls()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_settings public.platform_settings%ROWTYPE;
BEGIN
    SELECT * INTO v_settings
      FROM public.platform_settings
     WHERE id = 'global';

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'version', '2026-09-12-v1',
            'configured', false,
            'membership_enforcement_enabled', false,
            'trial_signups_enabled', false,
            'membership_sales_enabled', false,
            'generation_enabled', true,
            'updated_at', NULL,
            'updated_by', NULL
        );
    END IF;

    RETURN jsonb_build_object(
        'version', v_settings.version,
        'configured', true,
        'membership_enforcement_enabled', v_settings.membership_enforcement_enabled,
        'trial_signups_enabled', v_settings.trial_signups_enabled,
        'membership_sales_enabled', v_settings.membership_sales_enabled,
        'generation_enabled', v_settings.generation_enabled,
        'updated_at', v_settings.updated_at,
        'updated_by', v_settings.updated_by,
        'revision', v_settings.revision
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_platform_service_controls() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_service_controls() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.set_platform_service_controls(
    p_admin_user_id UUID,
    p_expected_version TEXT,
    p_version TEXT,
    p_membership_enforcement_enabled BOOLEAN,
    p_trial_signups_enabled BOOLEAN,
    p_membership_sales_enabled BOOLEAN,
    p_generation_enabled BOOLEAN,
    p_reason TEXT,
    p_client_request_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_settings public.platform_settings%ROWTYPE;
    v_existing public.platform_service_control_events%ROWTYPE;
    v_payload JSONB;
    v_result JSONB;
    v_next_version TEXT;
    v_next_revision BIGINT;
BEGIN
    IF NOT public.is_admin_operator(p_admin_user_id) THEN
        RAISE EXCEPTION 'admin_write_forbidden' USING ERRCODE = '42501';
    END IF;
    IF p_version IS NULL OR p_version <> '2026-09-12-v1' THEN
        RAISE EXCEPTION 'unsupported_settings_version' USING ERRCODE = '22023';
    END IF;
    IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN
        RAISE EXCEPTION 'invalid_reason' USING ERRCODE = '22023';
    END IF;
    IF p_client_request_id IS NOT NULL
       AND char_length(btrim(p_client_request_id)) > 200 THEN
        RAISE EXCEPTION 'invalid_client_request_id' USING ERRCODE = '22023';
    END IF;

    v_payload := jsonb_build_object(
        'version', p_version,
        'membershipEnforcementEnabled', p_membership_enforcement_enabled,
        'trialSignupsEnabled', p_trial_signups_enabled,
        'membershipSalesEnabled', p_membership_sales_enabled,
        'generationEnabled', p_generation_enabled,
        'reason', btrim(p_reason)
    );

    IF p_client_request_id IS NOT NULL THEN
        SELECT * INTO v_existing
          FROM public.platform_service_control_events
         WHERE client_request_id = btrim(p_client_request_id)
         FOR UPDATE;
        IF FOUND THEN
            IF v_existing.payload IS DISTINCT FROM v_payload THEN
                RAISE EXCEPTION 'request_conflict' USING ERRCODE = 'P0006';
            END IF;
            RETURN v_existing.result;
        END IF;
    END IF;

    SELECT * INTO v_settings
      FROM public.platform_settings
     WHERE id = 'global'
     FOR UPDATE;
    IF NOT FOUND THEN
        INSERT INTO public.platform_settings (id)
        VALUES ('global')
        RETURNING * INTO v_settings;
    END IF;
    IF p_expected_version IS NOT NULL
       AND p_expected_version <> v_settings.version THEN
        RAISE EXCEPTION 'controls_version_conflict' USING ERRCODE = 'P0006';
    END IF;

    v_next_revision := v_settings.revision + 1;
    v_next_version := CASE
        WHEN v_next_revision = 1 THEN p_version
        ELSE p_version || '-r' || v_next_revision::TEXT
    END;

    UPDATE public.platform_settings
       SET version = v_next_version,
           revision = v_next_revision,
           membership_enforcement_enabled = p_membership_enforcement_enabled,
           trial_signups_enabled = p_trial_signups_enabled,
           membership_sales_enabled = p_membership_sales_enabled,
           generation_enabled = p_generation_enabled,
           updated_by = p_admin_user_id,
           updated_at = now(),
           last_client_request_id = p_client_request_id
     WHERE id = 'global';

    v_result := jsonb_build_object(
        'version', v_next_version,
        'configured', true,
        'membership_enforcement_enabled', p_membership_enforcement_enabled,
        'trial_signups_enabled', p_trial_signups_enabled,
        'membership_sales_enabled', p_membership_sales_enabled,
        'generation_enabled', p_generation_enabled,
        'updated_at', now(),
        'updated_by', p_admin_user_id,
        'revision', v_next_revision
    );

    INSERT INTO public.platform_service_control_events (
        client_request_id,
        operator_id,
        payload,
        result
    ) VALUES (
        NULLIF(btrim(p_client_request_id), ''),
        p_admin_user_id,
        v_payload,
        v_result
    );
    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.set_platform_service_controls(
    UUID, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_platform_service_controls(
    UUID, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT, TEXT
) TO service_role;

-- 12. Trial activation and calendar-period helpers
CREATE OR REPLACE FUNCTION public.add_calendar_months_utc(
    p_start TIMESTAMPTZ,
    p_months INTEGER
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
    v_local TIMESTAMP := p_start AT TIME ZONE 'UTC';
    v_month_start TIMESTAMP;
    v_last_day INTEGER;
    v_anchor_day INTEGER;
    v_time_of_day INTERVAL;
BEGIN
    IF p_start IS NULL OR p_months < 0 THEN
        RAISE EXCEPTION 'invalid calendar month arguments' USING ERRCODE = '22023';
    END IF;
    v_anchor_day := EXTRACT(DAY FROM v_local)::INTEGER;
    v_time_of_day := v_local - date_trunc('day', v_local);
    v_month_start := date_trunc('month', v_local) + make_interval(months => p_months);
    v_last_day := EXTRACT(
        DAY FROM (v_month_start + INTERVAL '1 month - 1 day')
    )::INTEGER;
    RETURN (
        date_trunc('day', v_month_start)
        + make_interval(days => LEAST(v_anchor_day, v_last_day) - 1)
        + v_time_of_day
    ) AT TIME ZONE 'UTC';
END;
$$;

REVOKE ALL ON FUNCTION public.add_calendar_months_utc(TIMESTAMPTZ, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_calendar_months_utc(TIMESTAMPTZ, INTEGER)
    TO service_role;

CREATE OR REPLACE FUNCTION public.activate_trial_with_result(
    p_user_id UUID,
    p_client_request_id UUID,
    p_started_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_start TIMESTAMPTZ := COALESCE(p_started_at, v_now);
    v_existing public.user_memberships%ROWTYPE;
    v_membership_id UUID;
    v_request_status TEXT;
    v_membership_open BOOLEAN := false;
    v_trial_open BOOLEAN := false;
BEGIN
    IF p_user_id IS NULL OR p_client_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_trial_activation_request' USING ERRCODE = '22023';
    END IF;
    IF v_start > v_now + INTERVAL '5 minutes' THEN
        RAISE EXCEPTION 'trial_start_in_future' USING ERRCODE = '22023';
    END IF;

    SELECT status INTO v_request_status
      FROM public.generation_requests
     WHERE user_id = p_user_id
       AND operation_type = 'sentence_generation'
       AND client_request_id = p_client_request_id
     FOR UPDATE;
    IF NOT FOUND OR v_request_status <> 'succeeded' THEN
        RAISE EXCEPTION 'trial_result_not_persisted' USING ERRCODE = 'P0007';
    END IF;

    SELECT membership_enforcement_enabled, trial_signups_enabled
      INTO v_membership_open, v_trial_open
      FROM public.platform_settings
     WHERE id = 'global';
    IF COALESCE(v_membership_open, false) IS NOT TRUE THEN
        RETURN jsonb_build_object('status', 'membership_mode_disabled');
    END IF;
    IF COALESCE(v_trial_open, false) IS NOT TRUE THEN
        RETURN jsonb_build_object('status', 'trial_signups_disabled');
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_user_id::TEXT || ':trial', 0)
    );

    SELECT * INTO v_existing
      FROM public.user_memberships
     WHERE user_id = p_user_id
       AND plan = 'trial'
     ORDER BY created_at ASC
     LIMIT 1
     FOR UPDATE;
    IF FOUND THEN
        RETURN jsonb_build_object(
            'status', 'already_activated',
            'membershipId', v_existing.id,
            'startedAt', v_existing.started_at,
            'expiresAt', v_existing.expires_at
        );
    END IF;

    -- A paid/granted period takes precedence over a trial that has not begun.
    IF EXISTS (
        SELECT 1
        FROM public.user_memberships
        WHERE user_id = p_user_id
          AND source IN ('paid', 'grant', 'compensation')
          AND expires_at > v_start
    ) THEN
        RETURN jsonb_build_object('status', 'membership_already_active');
    END IF;

    INSERT INTO public.user_memberships (
        user_id,
        plan,
        status,
        source,
        started_at,
        expires_at,
        period_index,
        total_periods
    ) VALUES (
        p_user_id,
        'trial',
        'trial',
        'system_trial',
        v_start,
        v_start + INTERVAL '168 hours',
        1,
        1
    )
    RETURNING id INTO v_membership_id;

    RETURN jsonb_build_object(
        'status', 'activated',
        'membershipId', v_membership_id,
        'startedAt', v_start,
        'expiresAt', v_start + INTERVAL '168 hours'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.activate_trial_with_result(UUID, UUID, TIMESTAMPTZ)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.activate_trial_with_result(UUID, UUID, TIMESTAMPTZ)
    TO service_role;

-- 13. Admin action idempotency and atomic membership operations
CREATE TABLE IF NOT EXISTS public.admin_membership_action_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_request_id UUID NOT NULL UNIQUE,
    operator_id UUID NOT NULL REFERENCES auth.users(id),
    target_user_id UUID NOT NULL REFERENCES auth.users(id),
    action TEXT NOT NULL CHECK (
        action IN (
            'grant_membership',
            'compensate_membership',
            'revoke_grant',
            'replay_order',
            'record_manual_payment'
        )
    ),
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'applied')),
    result JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

ALTER TABLE public.admin_membership_action_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.admin_membership_action_requests FROM anon, authenticated;
GRANT ALL ON TABLE public.admin_membership_action_requests TO service_role;

ALTER TABLE public.user_memberships
    ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS revoke_reason TEXT;

ALTER TABLE public.membership_reservations
    ADD COLUMN IF NOT EXISTS nano_usd_actual BIGINT,
    ADD COLUMN IF NOT EXISTS budget_period_key TEXT;

ALTER TABLE public.membership_orders
    ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS manual_verified_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS manual_verification_reason TEXT,
    ADD COLUMN IF NOT EXISTS manual_receipt_ref TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_membership_orders_channel_transaction
    ON public.membership_orders(channel, channel_transaction_id)
    WHERE channel_transaction_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.admin_apply_membership_action(
    p_admin_user_id UUID,
    p_target_user_id UUID,
    p_action TEXT,
    p_months INTEGER DEFAULT 1,
    p_reason TEXT DEFAULT NULL,
    p_client_request_id UUID DEFAULT NULL,
    p_order_id UUID DEFAULT NULL,
    p_membership_id UUID DEFAULT NULL,
    p_channel TEXT DEFAULT NULL,
    p_transaction_id TEXT DEFAULT NULL,
    p_amount_fen_cny INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_payload JSONB;
    v_result JSONB;
    v_existing_payload JSONB;
    v_existing_result JSONB;
    v_existing_status TEXT;
    v_action_id UUID;
    v_latest_end TIMESTAMPTZ;
    v_base_start TIMESTAMPTZ;
    v_start TIMESTAMPTZ;
    v_end TIMESTAMPTZ;
    v_membership_id UUID;
    v_period_ids JSONB := '[]'::JSONB;
    v_membership public.user_memberships%ROWTYPE;
    v_order public.membership_orders%ROWTYPE;
    v_replay_result JSONB;
    v_source TEXT;
    v_i INTEGER;
BEGIN
    IF NOT public.is_admin_operator(p_admin_user_id) THEN
        RAISE EXCEPTION 'admin_write_forbidden' USING ERRCODE = '42501';
    END IF;
    IF p_target_user_id IS NULL OR p_client_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_action_request' USING ERRCODE = '22023';
    END IF;
    IF p_action IS NULL OR p_action NOT IN (
        'grant_membership',
        'compensate_membership',
        'revoke_grant',
        'replay_order',
        'record_manual_payment'
    ) THEN
        RAISE EXCEPTION 'unsupported_action' USING ERRCODE = '22023';
    END IF;
    IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN
        RAISE EXCEPTION 'invalid_reason' USING ERRCODE = '22023';
    END IF;
    IF p_months IS NULL OR p_months < 1 OR p_months > 12 THEN
        RAISE EXCEPTION 'invalid_months' USING ERRCODE = '22023';
    END IF;
    IF p_action = 'replay_order' AND p_order_id IS NULL THEN
        RAISE EXCEPTION 'missing_order_id' USING ERRCODE = '22023';
    END IF;
    IF p_action = 'revoke_grant' AND p_membership_id IS NULL THEN
        RAISE EXCEPTION 'missing_membership_id' USING ERRCODE = '22023';
    END IF;
    IF p_action = 'record_manual_payment' AND (
        p_channel IS NULL OR char_length(btrim(p_channel)) = 0
        OR p_transaction_id IS NULL OR char_length(btrim(p_transaction_id)) = 0
        OR p_amount_fen_cny IS DISTINCT FROM 3990
        OR p_months <> 1
    ) THEN
        RAISE EXCEPTION 'invalid_manual_payment' USING ERRCODE = '22023';
    END IF;

    v_payload := jsonb_build_object(
        'targetUserId', p_target_user_id,
        'action', p_action,
        'months', p_months,
        'reason', btrim(p_reason),
        'orderId', p_order_id,
        'membershipId', p_membership_id,
        'channel', p_channel,
        'transactionId', p_transaction_id,
        'amountFenCny', p_amount_fen_cny
    );

    INSERT INTO public.admin_membership_action_requests (
        client_request_id,
        operator_id,
        target_user_id,
        action,
        payload
    ) VALUES (
        p_client_request_id,
        p_admin_user_id,
        p_target_user_id,
        p_action,
        v_payload
    )
    ON CONFLICT (client_request_id) DO NOTHING
    RETURNING id INTO v_action_id;

    IF v_action_id IS NULL THEN
        SELECT payload, result, status
          INTO v_existing_payload, v_existing_result, v_existing_status
          FROM public.admin_membership_action_requests
         WHERE client_request_id = p_client_request_id
         FOR UPDATE;
        IF v_existing_payload IS DISTINCT FROM v_payload THEN
            RAISE EXCEPTION 'request_conflict' USING ERRCODE = 'P0006';
        END IF;
        IF v_existing_status = 'applied' AND v_existing_result IS NOT NULL THEN
            RETURN v_existing_result;
        END IF;
    END IF;

    -- One account timeline is serialized for every administrative operation.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_target_user_id::TEXT || ':membership', 0)
    );

    IF p_action IN ('grant_membership', 'compensate_membership') THEN
        v_source := CASE
            WHEN p_action = 'compensate_membership' THEN 'compensation'
            ELSE 'grant'
        END;
        SELECT max(expires_at) INTO v_latest_end
          FROM public.user_memberships
         WHERE user_id = p_target_user_id
           AND status IN ('trial', 'active')
           AND expires_at > v_now;
        v_start := COALESCE(v_latest_end, v_now);
        v_base_start := v_start;
        FOR v_i IN 1..p_months LOOP
            -- Calculate every boundary from the original anchor so Jan 31
            -- grants become Feb 28, Mar 31, Apr 30 rather than drifting.
            v_end := public.add_calendar_months_utc(v_base_start, v_i);
            INSERT INTO public.user_memberships (
                user_id,
                plan,
                status,
                source,
                started_at,
                expires_at,
                period_index,
                total_periods,
                grant_reason,
                granted_by
            ) VALUES (
                p_target_user_id,
                'monthly',
                'active',
                v_source,
                v_start,
                v_end,
                v_i,
                p_months,
                btrim(p_reason),
                p_admin_user_id
            )
            RETURNING id INTO v_membership_id;
            v_period_ids := v_period_ids || jsonb_build_array(v_membership_id);
            v_start := v_end;
        END LOOP;
        v_result := jsonb_build_object(
            'status', 'applied',
            'action', p_action,
            'grantedMonths', p_months,
            'membershipIds', v_period_ids,
            'startedAt', COALESCE(v_latest_end, v_now),
            'expiresAt', v_start
        );

    ELSIF p_action = 'revoke_grant' THEN
        SELECT * INTO v_membership
          FROM public.user_memberships
         WHERE id = p_membership_id
           AND user_id = p_target_user_id
         FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'membership_not_found' USING ERRCODE = 'P0005';
        END IF;
        IF v_membership.source <> 'grant' OR v_membership.status <> 'active' THEN
            RAISE EXCEPTION 'grant_not_reversible' USING ERRCODE = '22023';
        END IF;
        IF EXISTS (
            SELECT 1
            FROM public.membership_reservations
            WHERE membership_id = p_membership_id
              AND status IN ('reserved', 'dispatch_claimed', 'settled', 'unknown')
        ) THEN
            RAISE EXCEPTION 'grant_has_usage' USING ERRCODE = 'P0008';
        END IF;
        UPDATE public.user_memberships
           SET status = 'expired',
               revoked_at = v_now,
               revoked_by = p_admin_user_id,
               revoke_reason = btrim(p_reason),
               updated_at = v_now
         WHERE id = p_membership_id;
        v_result := jsonb_build_object(
            'status', 'applied',
            'action', p_action,
            'membershipId', p_membership_id,
            'revokedAt', v_now
        );

    ELSIF p_action = 'replay_order' THEN
        SELECT * INTO v_order
          FROM public.membership_orders
         WHERE id = p_order_id
         FOR UPDATE;
        IF NOT FOUND OR v_order.user_id <> p_target_user_id THEN
            RAISE EXCEPTION 'order_not_found' USING ERRCODE = 'P0005';
        END IF;
        IF NULLIF(btrim(COALESCE(p_transaction_id, v_order.channel_transaction_id)), '') IS NULL THEN
            RAISE EXCEPTION 'missing_transaction_id' USING ERRCODE = '22023';
        END IF;
        v_replay_result := public.apply_verified_payment(
            p_order_id,
            btrim(COALESCE(p_transaction_id, v_order.channel_transaction_id)),
            v_now
        );
        v_result := jsonb_build_object(
            'status', 'applied',
            'action', p_action,
            'orderId', p_order_id,
            'payment', v_replay_result
        );

    ELSE
        SELECT * INTO v_order
          FROM public.membership_orders
         WHERE (p_order_id IS NOT NULL AND id = p_order_id)
            OR (p_order_id IS NULL
                AND channel = btrim(p_channel)
                AND channel_transaction_id = btrim(p_transaction_id))
         FOR UPDATE;
        IF FOUND THEN
            IF v_order.user_id <> p_target_user_id
               OR v_order.amount_fen_cny <> 3990
               OR v_order.currency <> 'CNY' THEN
                RAISE EXCEPTION 'manual_payment_mismatch' USING ERRCODE = '22023';
            END IF;
            IF v_order.status = 'refunded' THEN
                RAISE EXCEPTION 'order_refunded' USING ERRCODE = '22023';
            END IF;
            v_replay_result := public.apply_verified_payment(
                v_order.id,
                btrim(p_transaction_id),
                v_now
            );
        ELSE
            INSERT INTO public.membership_orders (
                user_id,
                client_request_id,
                sku,
                amount_fen_cny,
                currency,
                status,
                channel,
                channel_transaction_id,
                manual_verified_by,
                manual_verification_reason
            ) VALUES (
                p_target_user_id,
                p_client_request_id,
                'selah_membership_monthly',
                3990,
                'CNY',
                'pending',
                btrim(p_channel),
                btrim(p_transaction_id),
                p_admin_user_id,
                btrim(p_reason)
            )
            RETURNING * INTO v_order;
            v_replay_result := public.apply_verified_payment(
                v_order.id,
                btrim(p_transaction_id),
                v_now
            );
        END IF;
        v_result := jsonb_build_object(
            'status', 'applied',
            'action', p_action,
            'orderId', v_order.id,
            'payment', v_replay_result,
            'manualVerified', true
        );
    END IF;

    INSERT INTO public.admin_audit_logs (
        operator_id,
        target_user_id,
        action,
        reason,
        old_state,
        new_state,
        client_request_id
    ) VALUES (
        p_admin_user_id,
        p_target_user_id,
        p_action,
        btrim(p_reason),
        NULL,
        v_result,
        p_client_request_id
    );

    UPDATE public.admin_membership_action_requests
       SET status = 'applied',
           result = v_result,
           completed_at = v_now
     WHERE id = v_action_id OR client_request_id = p_client_request_id;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_apply_membership_action(
    UUID, UUID, TEXT, INTEGER, TEXT, UUID, UUID, UUID, TEXT, TEXT, INTEGER
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_apply_membership_action(
    UUID, UUID, TEXT, INTEGER, TEXT, UUID, UUID, UUID, TEXT, TEXT, INTEGER
) TO service_role;

-- The service-key Edge Functions are the only callers of these mutation RPCs.
REVOKE ALL ON FUNCTION public.get_user_membership_summary(UUID)
    FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.reserve_generation_allowance(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)
    FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.settle_generation_allowance(UUID, TEXT, BIGINT)
    FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_verified_payment(UUID, TEXT, TIMESTAMPTZ)
    FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_membership_summary(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.reserve_generation_allowance(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.settle_generation_allowance(UUID, TEXT, BIGINT)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_verified_payment(UUID, TEXT, TIMESTAMPTZ)
    TO service_role;

-- Browser clients use the Edge Functions for membership data; they never get
-- direct table reads or mutation RPC access to the underlying ledgers.
REVOKE SELECT ON TABLE public.user_memberships FROM authenticated;
REVOKE SELECT ON TABLE public.membership_orders FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.is_admin_operator(UUID) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_platform_service_controls() FROM authenticated;

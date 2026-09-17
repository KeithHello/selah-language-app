-- Temporary anonymous testing with platform-only budget protection.
-- Anonymous identities receive no personal trial or paid quota; every billable
-- request must first reserve against the shared platform ledger.
-- This is a local migration draft; applying it to a remote database requires
-- separate confirmation.

ALTER TABLE public.platform_settings
    ADD COLUMN IF NOT EXISTS anonymous_test_mode_enabled BOOLEAN;

UPDATE public.platform_settings
   SET anonymous_test_mode_enabled = false
 WHERE anonymous_test_mode_enabled IS NULL;

ALTER TABLE public.platform_settings
    ALTER COLUMN anonymous_test_mode_enabled SET DEFAULT false;

ALTER TABLE public.platform_settings
    ALTER COLUMN anonymous_test_mode_enabled SET NOT NULL;

CREATE TABLE IF NOT EXISTS public.platform_generation_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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
    budget_period_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settled_at TIMESTAMPTZ,
    UNIQUE (user_id, client_request_id, feature)
);

CREATE INDEX IF NOT EXISTS idx_platform_reservations_user_status
    ON public.platform_generation_reservations(user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_platform_reservations_budget
    ON public.platform_generation_reservations(budget_period_key, status);

ALTER TABLE public.platform_generation_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.platform_generation_reservations FROM anon, authenticated;
GRANT ALL ON TABLE public.platform_generation_reservations TO service_role;

-- The two functions below intentionally replace the 006 service-control RPCs.
-- Anonymous testing is closed by default and can only be opened by an admin.

CREATE OR REPLACE FUNCTION public.get_platform_service_controls()
RETURNS JSONB
LANGUAGE plpgsql
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
            'version', '2026-09-17-v1',
            'configured', false,
            'membership_enforcement_enabled', false,
            'trial_signups_enabled', false,
            'membership_sales_enabled', false,
            'generation_enabled', true,
            'anonymous_test_mode_enabled', false,
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
        'anonymous_test_mode_enabled', v_settings.anonymous_test_mode_enabled,
        'updated_at', v_settings.updated_at,
        'updated_by', v_settings.updated_by,
        'revision', v_settings.revision
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_platform_service_controls() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_service_controls()
    TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.set_platform_service_controls(
    p_admin_user_id UUID,
    p_expected_version TEXT,
    p_version TEXT,
    p_membership_enforcement_enabled BOOLEAN,
    p_trial_signups_enabled BOOLEAN,
    p_membership_sales_enabled BOOLEAN,
    p_generation_enabled BOOLEAN,
    p_anonymous_test_mode_enabled BOOLEAN,
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
    IF p_version IS NULL OR p_version <> '2026-09-17-v1' THEN
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
        'anonymousTestModeEnabled', p_anonymous_test_mode_enabled,
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
           anonymous_test_mode_enabled = p_anonymous_test_mode_enabled,
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
        'anonymous_test_mode_enabled', p_anonymous_test_mode_enabled,
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
    UUID, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_platform_service_controls(
    UUID, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT, TEXT
) TO service_role;

CREATE OR REPLACE FUNCTION public.reserve_platform_generation_allowance(
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
    v_existing public.platform_generation_reservations%ROWTYPE;
    v_minute_count INTEGER := 0;
    v_budget_period_key TEXT;
    v_budget public.platform_budget_ledgers%ROWTYPE;
    v_reservation_id UUID;
BEGIN
    IF auth.uid() IS NOT NULL
       AND auth.role() <> 'service_role'
       AND auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'platform reservation access denied' USING ERRCODE = '42501';
    END IF;
    IF p_feature NOT IN ('transcription', 'sentence', 'preparation', 'batch', 'tts')
       OR p_units IS NULL OR p_units <= 0
       OR p_nano_usd IS NULL OR p_nano_usd < 0
       OR p_payload_hash IS NULL OR char_length(p_payload_hash) = 0 THEN
        RAISE EXCEPTION 'invalid_reservation_request' USING ERRCODE = '22023';
    END IF;
    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_user_id::TEXT || ':platform-generation-reservation', 0)
    );
    SELECT * INTO v_existing
      FROM public.platform_generation_reservations
     WHERE user_id = p_user_id
       AND client_request_id = p_client_request_id
       AND feature = p_feature
     FOR UPDATE;
    IF FOUND THEN
        RETURN jsonb_build_object('reservationId', v_existing.id, 'status', v_existing.status);
    END IF;
    SELECT COUNT(*) INTO v_minute_count
      FROM public.platform_generation_reservations
     WHERE user_id = p_user_id
       AND created_at >= v_now - INTERVAL '1 minute';
    IF v_minute_count >= 15 THEN
        RAISE EXCEPTION 'rate_limited' USING ERRCODE = 'P0001';
    END IF;
    v_budget_period_key := 'platform:day:' || to_char(v_now AT TIME ZONE 'UTC', 'YYYY-MM-DD');
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
    INSERT INTO public.platform_generation_reservations (
        user_id, client_request_id, feature, units_reserved,
        nano_usd_reserved, status, payload_hash, created_at, budget_period_key
    ) VALUES (
        p_user_id, p_client_request_id, p_feature, p_units,
        p_nano_usd, 'reserved', p_payload_hash, v_now, v_budget_period_key
    ) RETURNING id INTO v_reservation_id;
    RETURN jsonb_build_object('reservationId', v_reservation_id, 'status', 'reserved');
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_platform_generation_allowance(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_platform_generation_allowance(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)
    TO service_role;

CREATE OR REPLACE FUNCTION public.settle_platform_generation_allowance(
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
    v_reservation public.platform_generation_reservations%ROWTYPE;
    v_budget public.platform_budget_ledgers%ROWTYPE;
    v_committed BIGINT;
BEGIN
    SELECT * INTO v_reservation
      FROM public.platform_generation_reservations
     WHERE id = p_reservation_id
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'reservation_not_found' USING ERRCODE = 'P0005';
    END IF;
    IF p_status NOT IN ('settled', 'released_unsent', 'unknown') THEN
        RAISE EXCEPTION 'invalid_reservation_status' USING ERRCODE = '22023';
    END IF;
    IF p_actual_nano_usd IS NOT NULL AND p_actual_nano_usd < 0 THEN
        RAISE EXCEPTION 'invalid_actual_cost' USING ERRCODE = '22023';
    END IF;
    IF v_reservation.status IN ('settled', 'released_unsent') THEN
        IF v_reservation.status = p_status THEN RETURN; END IF;
        RAISE EXCEPTION 'reservation_already_final' USING ERRCODE = 'P0006';
    END IF;
    IF v_reservation.status = 'unknown' THEN
        IF p_status = 'unknown' THEN RETURN; END IF;
        RAISE EXCEPTION 'reservation_unknown_requires_reconciliation' USING ERRCODE = 'P0006';
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
           SET reserved_nano_usd = GREATEST(0, reserved_nano_usd - v_reservation.nano_usd_reserved),
               updated_at = now()
         WHERE period_key = v_reservation.budget_period_key;
    ELSE
        v_committed := COALESCE(p_actual_nano_usd, v_reservation.nano_usd_reserved);
        UPDATE public.platform_budget_ledgers
           SET reserved_nano_usd = GREATEST(0, reserved_nano_usd - v_reservation.nano_usd_reserved),
               committed_nano_usd = committed_nano_usd + v_committed,
               updated_at = now()
         WHERE period_key = v_reservation.budget_period_key;
    END IF;
    UPDATE public.platform_generation_reservations
       SET status = p_status,
           nano_usd_actual = p_actual_nano_usd,
           settled_at = now()
     WHERE id = p_reservation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.settle_platform_generation_allowance(UUID, TEXT, BIGINT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.settle_platform_generation_allowance(UUID, TEXT, BIGINT)
    TO service_role;

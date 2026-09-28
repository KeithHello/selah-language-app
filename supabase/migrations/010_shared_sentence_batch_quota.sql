-- Sentence and batch generation share the same per-membership quota pool.
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

    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_user_id::TEXT || ':membership-reservation', 0)
    );

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

    SELECT COUNT(*) INTO v_minute_count
      FROM public.membership_reservations
     WHERE user_id = p_user_id
       AND created_at >= v_now - INTERVAL '1 minute';
    IF v_minute_count >= 15 THEN
        RAISE EXCEPTION 'rate_limited' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_membership
      FROM public.user_memberships
     WHERE user_id = p_user_id
       AND status IN ('trial', 'active')
       AND started_at <= v_now AND expires_at > v_now
     ORDER BY expires_at DESC
     LIMIT 1;
    IF v_membership.id IS NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.user_memberships
             WHERE user_id = p_user_id AND plan = 'trial'
        ) THEN
            RAISE EXCEPTION 'trial_expired' USING ERRCODE = 'P0002';
        ELSE
            RAISE EXCEPTION 'membership_required' USING ERRCODE = 'P0003';
        END IF;
    END IF;

    IF v_membership.plan = 'pro' THEN
        IF p_feature IN ('sentence', 'batch') THEN v_limit := 900;
        ELSIF p_feature = 'tts' THEN v_limit := 90000;
        ELSIF p_feature = 'transcription' THEN v_limit := 10800000;
        ELSIF p_feature = 'preparation' THEN v_limit := 90;
        END IF;
    ELSIF v_membership.plan = 'monthly' THEN
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

    SELECT COALESCE(SUM(units_reserved), 0)
      INTO v_used
     FROM public.membership_reservations
     WHERE user_id = p_user_id
       AND membership_id = v_membership.id
       AND (
           (p_feature IN ('sentence', 'batch') AND feature IN ('sentence', 'batch'))
           OR (p_feature NOT IN ('sentence', 'batch') AND feature = p_feature)
       )
       AND status IN ('reserved', 'dispatch_claimed', 'settled', 'unknown');
    IF (v_used + p_units) > v_limit THEN
        RAISE EXCEPTION 'feature_limit_reached' USING ERRCODE = 'P0004';
    END IF;

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

    INSERT INTO public.membership_reservations (
        user_id, membership_id, client_request_id, feature, units_reserved,
        nano_usd_reserved, status, payload_hash, created_at, budget_period_key
    ) VALUES (
        p_user_id, v_membership.id, p_client_request_id, p_feature, p_units,
        p_nano_usd, 'reserved', p_payload_hash, v_now, v_budget_period_key
    ) RETURNING id INTO v_reservation_id;

    RETURN jsonb_build_object(
        'reservationId', v_reservation_id,
        'status', 'reserved'
    );
END;
$$;

-- Keep member entitlements independent from the platform-wide daily safeguard.
-- The public-mode usage RPC now reserves the same daily ledger as member mode.
DO $$
DECLARE
    v_change RECORD;
    v_definition TEXT;
BEGIN
    FOR v_change IN
        SELECT * FROM (VALUES
            (
                'public.ensure_platform_daily_budget(TEXT)'::REGPROCEDURE,
                'service_budget_protected',
                'platform_daily_budget_unavailable'
            ),
            (
                'public.reserve_generation_allowance(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)'::REGPROCEDURE,
                'service_budget_protected',
                'platform_daily_budget_exhausted'
            ),
            (
                'public.reserve_platform_generation_allowance(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)'::REGPROCEDURE,
                'service_budget_protected',
                'platform_daily_budget_exhausted'
            )
        ) AS replacements(function_signature, old_message, new_message)
    LOOP
        v_definition := pg_get_functiondef(v_change.function_signature);
        IF position(quote_literal(v_change.old_message) IN v_definition) = 0 THEN
            RAISE EXCEPTION 'Expected platform budget error in %',
                v_change.function_signature;
        END IF;
        v_definition := replace(
            v_definition,
            quote_literal(v_change.old_message),
            quote_literal(v_change.new_message)
        );
        EXECUTE v_definition;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_generation_usage(
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
    v_existing public.membership_reservations%ROWTYPE;
    v_reservation_id UUID;
    v_minute_count INTEGER := 0;
    v_budget_period_key TEXT;
    v_budget public.platform_budget_ledgers%ROWTYPE;
    v_nano_usd BIGINT;
BEGIN
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
       AND feature = p_feature
     FOR UPDATE;

    IF FOUND THEN
        IF v_existing.payload_hash IS DISTINCT FROM p_payload_hash THEN
            RAISE EXCEPTION 'request_conflict' USING ERRCODE = 'P0006';
        END IF;
        -- Older audit-only reservations did not reserve against the platform
        -- ledger. If one is still in flight, reserve it before retrying.
        IF v_existing.budget_period_key IS NULL
           AND v_existing.status IN ('reserved', 'dispatch_claimed') THEN
            v_budget_period_key := 'platform:day:' ||
                to_char(v_now AT TIME ZONE 'UTC', 'YYYY-MM-DD');
            v_budget := public.ensure_platform_daily_budget(v_budget_period_key);
            IF v_budget.committed_nano_usd + v_budget.reserved_nano_usd
                + v_existing.nano_usd_reserved > v_budget.budget_nano_usd THEN
                RAISE EXCEPTION 'platform_daily_budget_exhausted' USING ERRCODE = 'P0009';
            END IF;
            UPDATE public.platform_budget_ledgers
               SET reserved_nano_usd = reserved_nano_usd + v_existing.nano_usd_reserved,
                   updated_at = v_now
             WHERE period_key = v_budget_period_key;
            UPDATE public.membership_reservations
               SET budget_period_key = v_budget_period_key
             WHERE id = v_existing.id;
        END IF;
        RETURN jsonb_build_object(
            'reservationId', v_existing.id,
            'status', v_existing.status,
            'enforced', false
        );
    END IF;

    SELECT COUNT(*) INTO v_minute_count
      FROM public.membership_reservations
     WHERE user_id = p_user_id
       AND created_at >= v_now - INTERVAL '1 minute';
    IF v_minute_count >= 15 THEN
        RAISE EXCEPTION 'rate_limited' USING ERRCODE = 'P0001';
    END IF;

    v_budget_period_key := 'platform:day:' ||
        to_char(v_now AT TIME ZONE 'UTC', 'YYYY-MM-DD');
    v_budget := public.ensure_platform_daily_budget(v_budget_period_key);
    v_nano_usd := p_nano_usd;
    IF v_budget.committed_nano_usd + v_budget.reserved_nano_usd + v_nano_usd
        > v_budget.budget_nano_usd THEN
        RAISE EXCEPTION 'platform_daily_budget_exhausted' USING ERRCODE = 'P0009';
    END IF;

    UPDATE public.platform_budget_ledgers
       SET reserved_nano_usd = reserved_nano_usd + v_nano_usd,
           updated_at = v_now
     WHERE period_key = v_budget_period_key;
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
        NULL,
        p_client_request_id,
        p_feature,
        p_units,
        v_nano_usd,
        'reserved',
        p_payload_hash,
        v_now,
        v_budget_period_key
    ) RETURNING id INTO v_reservation_id;

    RETURN jsonb_build_object(
        'reservationId', v_reservation_id,
        'status', 'reserved',
        'enforced', false
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_platform_budget_summary(
    p_admin_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_period_key TEXT;
    v_default_budget BIGINT;
    v_configured BOOLEAN := false;
    v_ledger public.platform_budget_ledgers%ROWTYPE;
    v_ledger_exists BOOLEAN := false;
    v_budget BIGINT := 0;
    v_reserved BIGINT := 0;
    v_committed BIGINT := 0;
BEGIN
    IF NOT COALESCE(public.is_admin_member(p_admin_user_id), false) THEN
        RAISE EXCEPTION 'admin_forbidden' USING ERRCODE = '42501';
    END IF;

    SELECT default_daily_budget_nano_usd
      INTO v_default_budget
      FROM public.platform_settings
     WHERE id = 'global';
    v_configured := FOUND;

    v_period_key := 'platform:day:' ||
        to_char(v_now AT TIME ZONE 'UTC', 'YYYY-MM-DD');
    SELECT * INTO v_ledger
      FROM public.platform_budget_ledgers
     WHERE period_key = v_period_key;
    v_ledger_exists := FOUND;

    v_budget := COALESCE(v_ledger.budget_nano_usd, v_default_budget, 0);
    v_reserved := COALESCE(v_ledger.reserved_nano_usd, 0);
    v_committed := COALESCE(v_ledger.committed_nano_usd, 0);

    RETURN jsonb_build_object(
        'periodKey', v_period_key,
        'asOf', v_now,
        'configured', v_configured,
        'ledgerExists', v_ledger_exists,
        'budgetNanoUsd', v_budget,
        'reservedNanoUsd', v_reserved,
        'committedNanoUsd', v_committed,
        'remainingNanoUsd', GREATEST(0, v_budget - v_reserved - v_committed),
        'overrunNanoUsd', GREATEST(0, v_reserved + v_committed - v_budget)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_platform_budget_summary(UUID)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_platform_budget_summary(UUID)
    TO service_role;

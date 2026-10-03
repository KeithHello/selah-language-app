-- Always-on generation metering. These rows are the user-visible usage
-- ledger even while quota enforcement remains off. Rows without a platform
-- budget period are audit-only and are settled without changing the budget.

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
    v_existing public.membership_reservations%ROWTYPE;
    v_reservation_id UUID;
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
       AND feature = p_feature;

    IF v_existing.id IS NOT NULL THEN
        IF v_existing.payload_hash IS DISTINCT FROM p_payload_hash THEN
            RAISE EXCEPTION 'request_conflict' USING ERRCODE = 'P0006';
        END IF;
        RETURN jsonb_build_object(
            'reservationId', v_existing.id,
            'status', v_existing.status,
            'enforced', v_existing.budget_period_key IS NOT NULL
        );
    END IF;

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
        p_nano_usd,
        'reserved',
        p_payload_hash,
        now(),
        NULL
    )
    RETURNING id INTO v_reservation_id;

    RETURN jsonb_build_object(
        'reservationId', v_reservation_id,
        'status', 'reserved',
        'enforced', false
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_generation_usage(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_generation_usage(UUID, UUID, TEXT, INTEGER, BIGINT, TEXT)
    TO service_role;

CREATE INDEX IF NOT EXISTS idx_generation_usage_attempts_user_started
    ON public.generation_usage_attempts(user_id, started_at DESC);

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
        RAISE EXCEPTION 'invalid_reservation_status' USING ERRCODE = 'P0005';
    END IF;
    IF p_actual_nano_usd IS NOT NULL AND p_actual_nano_usd < 0 THEN
        RAISE EXCEPTION 'invalid_actual_cost' USING ERRCODE = 'P0005';
    END IF;

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
        UPDATE public.membership_reservations
           SET status = p_status,
               nano_usd_actual = p_actual_nano_usd,
               settled_at = now()
         WHERE id = p_reservation_id;
        RETURN;
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

REVOKE ALL ON FUNCTION public.settle_generation_allowance(UUID, TEXT, BIGINT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.settle_generation_allowance(UUID, TEXT, BIGINT)
    TO service_role;

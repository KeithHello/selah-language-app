-- Atomic per-user generation limits and idempotency ledger.
-- This migration is local/CI only until an explicit remote deployment approval.

CREATE TABLE public.generation_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    operation_type TEXT NOT NULL,
    client_request_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'in_progress',
    response_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT generation_requests_operation_check CHECK (
        operation_type IN (
            'sentence_generation',
            'audio_generation',
            'capture_preparation'
        )
    ),
    CONSTRAINT generation_requests_status_check CHECK (
        status IN ('in_progress', 'succeeded', 'failed')
    ),
    CONSTRAINT generation_requests_user_operation_request_unique
        UNIQUE (user_id, operation_type, client_request_id)
);

CREATE INDEX idx_generation_requests_user_created
    ON public.generation_requests(user_id, operation_type, created_at DESC);

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.generation_requests
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.generation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.generation_requests FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.generation_requests TO service_role;

CREATE OR REPLACE FUNCTION public.claim_generation_request(
    p_user_id UUID,
    p_operation_type TEXT,
    p_client_request_id UUID,
    p_minute_limit INTEGER,
    p_daily_limit INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_existing public.generation_requests%ROWTYPE;
    v_request_exists BOOLEAN := false;
    v_minute_count INTEGER;
    v_daily_count INTEGER;
    v_retry_after INTEGER;
BEGIN
    IF p_operation_type NOT IN (
        'sentence_generation',
        'audio_generation',
        'capture_preparation'
    ) THEN
        RAISE EXCEPTION 'Unsupported generation operation' USING ERRCODE = '22023';
    END IF;
    IF p_minute_limit < 1 OR p_daily_limit < 1 THEN
        RAISE EXCEPTION 'Generation limits must be positive' USING ERRCODE = '22023';
    END IF;

    -- Serialize claims for one user and operation so the count and insert are atomic.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_user_id::TEXT || ':' || p_operation_type, 0)
    );

    SELECT *
    INTO v_existing
    FROM public.generation_requests
    WHERE user_id = p_user_id
      AND operation_type = p_operation_type
      AND client_request_id = p_client_request_id
    FOR UPDATE;

    v_request_exists := FOUND;

    IF v_request_exists AND v_existing.status = 'succeeded' THEN
        RETURN jsonb_build_object(
            'decision', 'replay',
            'retryAfterSeconds', 0,
            'responsePayload', v_existing.response_payload
        );
    END IF;

    IF v_request_exists
       AND v_existing.status = 'in_progress'
       AND v_existing.updated_at > now() - interval '5 minutes' THEN
        v_retry_after := GREATEST(
            1,
            CEIL(EXTRACT(EPOCH FROM (
                v_existing.updated_at + interval '5 minutes' - now()
            )))::INTEGER
        );
        RETURN jsonb_build_object(
            'decision', 'in_progress',
            'retryAfterSeconds', v_retry_after,
            'responsePayload', NULL
        );
    END IF;

    SELECT count(*)::INTEGER
    INTO v_minute_count
    FROM public.usage_records
    WHERE user_id = p_user_id
      AND operation_type = p_operation_type
      AND created_at > now() - interval '1 minute';

    IF v_minute_count >= p_minute_limit THEN
        SELECT GREATEST(
            1,
            CEIL(EXTRACT(EPOCH FROM (min(created_at) + interval '1 minute' - now())))::INTEGER
        )
        INTO v_retry_after
        FROM public.usage_records
        WHERE user_id = p_user_id
          AND operation_type = p_operation_type
          AND created_at > now() - interval '1 minute';

        RETURN jsonb_build_object(
            'decision', 'rate_limited',
            'retryAfterSeconds', v_retry_after,
            'responsePayload', NULL
        );
    END IF;

    SELECT count(*)::INTEGER
    INTO v_daily_count
    FROM public.usage_records
    WHERE user_id = p_user_id
      AND operation_type = p_operation_type
      AND created_at > now() - interval '24 hours';

    IF v_daily_count >= p_daily_limit THEN
        SELECT GREATEST(
            1,
            CEIL(EXTRACT(EPOCH FROM (min(created_at) + interval '24 hours' - now())))::INTEGER
        )
        INTO v_retry_after
        FROM public.usage_records
        WHERE user_id = p_user_id
          AND operation_type = p_operation_type
          AND created_at > now() - interval '24 hours';

        RETURN jsonb_build_object(
            'decision', 'quota_exceeded',
            'retryAfterSeconds', v_retry_after,
            'responsePayload', NULL
        );
    END IF;

    IF v_request_exists THEN
        UPDATE public.generation_requests
        SET status = 'in_progress', response_payload = NULL
        WHERE id = v_existing.id;
    ELSE
        INSERT INTO public.generation_requests (
            user_id,
            operation_type,
            client_request_id
        ) VALUES (
            p_user_id,
            p_operation_type,
            p_client_request_id
        );
    END IF;

    INSERT INTO public.usage_records (
        user_id,
        operation_type,
        estimated_units,
        client_request_id
    ) VALUES (
        p_user_id,
        p_operation_type,
        1,
        p_client_request_id
    );

    RETURN jsonb_build_object(
        'decision', 'claimed',
        'retryAfterSeconds', 0,
        'responsePayload', NULL
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_generation_request(
    p_user_id UUID,
    p_operation_type TEXT,
    p_client_request_id UUID,
    p_response_payload JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.generation_requests
    SET status = 'succeeded', response_payload = p_response_payload
    WHERE user_id = p_user_id
      AND operation_type = p_operation_type
      AND client_request_id = p_client_request_id
      AND status = 'in_progress';
    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fail_generation_request(
    p_user_id UUID,
    p_operation_type TEXT,
    p_client_request_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.generation_requests
    SET status = 'failed', response_payload = NULL
    WHERE user_id = p_user_id
      AND operation_type = p_operation_type
      AND client_request_id = p_client_request_id
      AND status = 'in_progress';
    RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_generation_request(UUID, TEXT, UUID, INTEGER, INTEGER)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_generation_request(UUID, TEXT, UUID, JSONB)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fail_generation_request(UUID, TEXT, UUID)
    FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.claim_generation_request(UUID, TEXT, UUID, INTEGER, INTEGER)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_generation_request(UUID, TEXT, UUID, JSONB)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_generation_request(UUID, TEXT, UUID)
    TO service_role;

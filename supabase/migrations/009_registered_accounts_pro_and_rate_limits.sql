-- Registered-account access, Pro entitlements, and request-level operation limits.
-- Draft only: apply to remote projects only after a separate approval.

CREATE OR REPLACE FUNCTION public.request_has_registered_identity()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SET search_path = ''
AS $$
    SELECT auth.uid() IS NOT NULL
       AND COALESCE(auth.jwt() ->> 'is_anonymous', 'false') <> 'true';
$$;

REVOKE ALL ON FUNCTION public.request_has_registered_identity() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_has_registered_identity()
    TO anon, authenticated, service_role;

-- Existing authenticated sessions created by anonymous sign-in stop seeing or
-- mutating user-owned rows. Policies granted to PUBLIC are covered as well.
DO $$
DECLARE
    v_policy RECORD;
    v_statement TEXT;
BEGIN
    FOR v_policy IN
        SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
          FROM pg_policies
         WHERE schemaname = 'public'
           AND (
                roles @> ARRAY['public'::name]
                OR roles @> ARRAY['authenticated'::name]
           )
    LOOP
        v_statement := format(
            'ALTER POLICY %I ON %I.%I',
            v_policy.policyname,
            v_policy.schemaname,
            v_policy.tablename
        );
        IF v_policy.cmd IN ('SELECT', 'UPDATE', 'DELETE', 'ALL') THEN
            v_statement := v_statement || format(
                ' USING ((%s) AND public.request_has_registered_identity())',
                COALESCE(v_policy.qual, 'true')
            );
        END IF;
        IF v_policy.cmd IN ('INSERT', 'UPDATE', 'ALL') THEN
            v_statement := v_statement || format(
                ' WITH CHECK ((%s) AND public.request_has_registered_identity())',
                COALESCE(v_policy.with_check, 'true')
            );
        END IF;
        EXECUTE v_statement;
    END LOOP;
END;
$$;

UPDATE public.platform_settings
   SET anonymous_test_mode_enabled = false,
       updated_at = now()
 WHERE id = 'global';

ALTER TABLE public.user_memberships
    DROP CONSTRAINT IF EXISTS user_memberships_plan_check;
ALTER TABLE public.user_memberships
    ADD CONSTRAINT user_memberships_plan_check
    CHECK (plan IN ('free', 'trial', 'monthly', 'pro'));

ALTER TABLE public.generation_requests
    DROP CONSTRAINT IF EXISTS generation_requests_operation_check;
ALTER TABLE public.generation_requests
    ADD CONSTRAINT generation_requests_operation_check
    CHECK (operation_type IN (
        'sentence_generation',
        'audio_generation',
        'capture_preparation',
        'batch_generation',
        'text_preparation',
        'speech_transcription'
    ));

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
        'capture_preparation',
        'batch_generation',
        'text_preparation',
        'speech_transcription'
    ) THEN
        RAISE EXCEPTION 'Unsupported generation operation' USING ERRCODE = '22023';
    END IF;
    IF p_minute_limit < 1 OR p_daily_limit < 1 THEN
        RAISE EXCEPTION 'Generation limits must be positive' USING ERRCODE = '22023';
    END IF;

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
            CEIL(EXTRACT(EPOCH FROM (
                min(created_at) + interval '1 minute' - now()
            )))::INTEGER
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
            CEIL(EXTRACT(EPOCH FROM (
                min(created_at) + interval '24 hours' - now()
            )))::INTEGER
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
            user_id, operation_type, client_request_id
        ) VALUES (
            p_user_id, p_operation_type, p_client_request_id
        );
    END IF;

    INSERT INTO public.usage_records (
        user_id, operation_type, estimated_units, client_request_id
    ) VALUES (
        p_user_id, p_operation_type, 1, p_client_request_id
    );

    RETURN jsonb_build_object(
        'decision', 'claimed',
        'retryAfterSeconds', 0,
        'responsePayload', NULL
    );
END;
$$;

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
       AND feature = p_feature
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

CREATE OR REPLACE FUNCTION public.admin_grant_membership_plan(
    p_admin_user_id UUID,
    p_target_user_id UUID,
    p_plan TEXT,
    p_months INTEGER,
    p_reason TEXT,
    p_client_request_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_payload JSONB;
    v_existing_payload JSONB;
    v_result JSONB;
    v_existing_status TEXT;
    v_request_id UUID;
    v_latest_end TIMESTAMPTZ;
    v_base_start TIMESTAMPTZ;
    v_start TIMESTAMPTZ;
    v_end TIMESTAMPTZ;
    v_membership_ids JSONB := '[]'::JSONB;
    v_membership_id UUID;
    v_i INTEGER;
BEGIN
    IF NOT public.is_admin_operator(p_admin_user_id) THEN
        RAISE EXCEPTION 'admin_write_forbidden' USING ERRCODE = '42501';
    END IF;
    IF p_target_user_id IS NULL OR p_client_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_action_request' USING ERRCODE = '22023';
    END IF;
    IF p_plan IS NULL OR p_plan NOT IN ('monthly', 'pro') THEN
        RAISE EXCEPTION 'invalid_plan' USING ERRCODE = '22023';
    END IF;
    IF p_months IS NULL OR p_months < 1 OR p_months > 12 THEN
        RAISE EXCEPTION 'invalid_months' USING ERRCODE = '22023';
    END IF;
    IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN
        RAISE EXCEPTION 'invalid_reason' USING ERRCODE = '22023';
    END IF;

    v_payload := jsonb_build_object(
        'targetUserId', p_target_user_id,
        'action', 'grant_membership',
        'plan', p_plan,
        'months', p_months,
        'reason', btrim(p_reason)
    );
    INSERT INTO public.admin_membership_action_requests (
        client_request_id, operator_id, target_user_id, action, payload
    ) VALUES (
        p_client_request_id, p_admin_user_id, p_target_user_id,
        'grant_membership', v_payload
    )
    ON CONFLICT (client_request_id) DO NOTHING
    RETURNING id INTO v_request_id;

    IF v_request_id IS NULL THEN
        SELECT id, payload, result, status
          INTO v_request_id, v_existing_payload, v_result, v_existing_status
          FROM public.admin_membership_action_requests
         WHERE client_request_id = p_client_request_id
         FOR UPDATE;
        IF v_existing_payload IS DISTINCT FROM v_payload THEN
            RAISE EXCEPTION 'request_conflict' USING ERRCODE = 'P0006';
        END IF;
        IF v_existing_status = 'applied' AND v_result IS NOT NULL THEN
            RETURN v_result;
        END IF;
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_target_user_id::TEXT || ':membership', 0)
    );
    SELECT max(expires_at) INTO v_latest_end
      FROM public.user_memberships
     WHERE user_id = p_target_user_id
       AND status IN ('trial', 'active')
       AND expires_at > v_now;
    v_start := COALESCE(v_latest_end, v_now);
    v_base_start := v_start;
    FOR v_i IN 1..p_months LOOP
        v_end := public.add_calendar_months_utc(v_base_start, v_i);
        INSERT INTO public.user_memberships (
            user_id, plan, status, source, started_at, expires_at,
            period_index, total_periods, grant_reason, granted_by
        ) VALUES (
            p_target_user_id, p_plan, 'active', 'grant', v_start, v_end,
            v_i, p_months, btrim(p_reason), p_admin_user_id
        ) RETURNING id INTO v_membership_id;
        v_membership_ids := v_membership_ids || jsonb_build_array(v_membership_id);
        v_start := v_end;
    END LOOP;

    v_result := jsonb_build_object(
        'status', 'applied',
        'action', 'grant_membership',
        'plan', p_plan,
        'grantedMonths', p_months,
        'membershipIds', v_membership_ids,
        'startedAt', COALESCE(v_latest_end, v_now),
        'expiresAt', v_start
    );
    INSERT INTO public.admin_audit_logs (
        operator_id, target_user_id, action, reason, new_state, client_request_id
    ) VALUES (
        p_admin_user_id, p_target_user_id, 'grant_membership', btrim(p_reason),
        v_result, p_client_request_id
    );
    UPDATE public.admin_membership_action_requests
       SET status = 'applied', result = v_result, completed_at = v_now
     WHERE id = v_request_id;
    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_grant_membership_plan(
    UUID, UUID, TEXT, INTEGER, TEXT, UUID
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_membership_plan(
    UUID, UUID, TEXT, INTEGER, TEXT, UUID
) TO service_role;

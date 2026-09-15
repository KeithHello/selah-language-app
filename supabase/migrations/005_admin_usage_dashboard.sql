-- Admin usage dashboard and billable provider accounting.
-- Local/CI migration only until the owner explicitly approves remote execution.

CREATE TABLE IF NOT EXISTS public.admin_members (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.generation_business_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    feature TEXT NOT NULL CHECK (
        feature IN ('transcription', 'sentence', 'preparation', 'batch', 'tts')
    ),
    client_request_id UUID NOT NULL,
    environment TEXT NOT NULL DEFAULT 'production' CHECK (
        environment IN ('production', 'test')
    ),
    outcome TEXT NOT NULL CHECK (
        outcome IN ('completed', 'reused', 'in_progress', 'rate_limited', 'failed')
    ),
    item_count INTEGER NOT NULL DEFAULT 1 CHECK (item_count BETWEEN 1 AND 20),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, feature, client_request_id, outcome)
);

CREATE INDEX IF NOT EXISTS idx_generation_business_events_range
    ON public.generation_business_events(environment, occurred_at DESC, feature);

CREATE TABLE IF NOT EXISTS public.generation_usage_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    client_request_id UUID NOT NULL,
    feature TEXT NOT NULL CHECK (
        feature IN ('transcription', 'sentence', 'preparation', 'batch', 'tts')
    ),
    environment TEXT NOT NULL DEFAULT 'production' CHECK (
        environment IN ('production', 'test')
    ),
    model TEXT NOT NULL CHECK (char_length(model) BETWEEN 1 AND 200),
    provider_request_id VARCHAR(200),
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    provider_status TEXT NOT NULL DEFAULT 'started' CHECK (
        provider_status IN ('started', 'succeeded', 'failed', 'unknown')
    ),
    delivery_status TEXT NOT NULL DEFAULT 'pending' CHECK (
        delivery_status IN ('pending', 'succeeded', 'failed')
    ),
    http_status INTEGER CHECK (http_status BETWEEN 100 AND 599),
    error_code VARCHAR(100),
    item_count INTEGER NOT NULL DEFAULT 1 CHECK (item_count BETWEEN 1 AND 20),
    input_tokens BIGINT CHECK (input_tokens >= 0),
    cached_input_tokens BIGINT CHECK (cached_input_tokens >= 0),
    output_tokens BIGINT CHECK (output_tokens >= 0),
    audio_input_tokens BIGINT CHECK (audio_input_tokens >= 0),
    text_input_tokens BIGINT CHECK (text_input_tokens >= 0),
    input_characters INTEGER CHECK (input_characters >= 0),
    duration_ms INTEGER CHECK (duration_ms >= 0),
    usage_source TEXT NOT NULL DEFAULT 'unknown' CHECK (
        usage_source IN ('provider', 'request_estimate', 'unknown')
    ),
    estimate_basis TEXT NOT NULL DEFAULT 'unknown' CHECK (
        estimate_basis IN (
            'text_tokens', 'tts_characters', 'transcription_duration', 'unknown'
        )
    ),
    price_version VARCHAR(100),
    estimated_cost_usd NUMERIC(16, 10) CHECK (estimated_cost_usd >= 0),
    CONSTRAINT cached_tokens_within_input_tokens CHECK (
        cached_input_tokens IS NULL OR input_tokens IS NULL
        OR cached_input_tokens <= input_tokens
    )
);

CREATE INDEX IF NOT EXISTS idx_generation_usage_attempts_range
    ON public.generation_usage_attempts(environment, started_at DESC, feature);
CREATE INDEX IF NOT EXISTS idx_generation_usage_attempts_client_request
    ON public.generation_usage_attempts(client_request_id);

CREATE TABLE IF NOT EXISTS public.provider_cost_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL DEFAULT 'openai' CHECK (provider = 'openai'),
    project_external_id VARCHAR(200),
    environment TEXT NOT NULL DEFAULT 'production' CHECK (
        environment IN ('production', 'test')
    ),
    line_item VARCHAR(200) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    amount NUMERIC(16, 10) NOT NULL CHECK (amount >= 0),
    usage_date DATE NOT NULL,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider, project_external_id, environment, line_item, usage_date)
);

CREATE INDEX IF NOT EXISTS idx_provider_cost_snapshots_range
    ON public.provider_cost_snapshots(environment, usage_date);

ALTER TABLE public.admin_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_business_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_usage_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_cost_snapshots ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.admin_members FROM anon, authenticated;
REVOKE ALL ON TABLE public.generation_business_events FROM anon, authenticated;
REVOKE ALL ON TABLE public.generation_usage_attempts FROM anon, authenticated;
REVOKE ALL ON TABLE public.provider_cost_snapshots FROM anon, authenticated;
GRANT SELECT ON TABLE public.admin_members TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.generation_business_events TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.generation_usage_attempts TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.provider_cost_snapshots TO service_role;

CREATE OR REPLACE FUNCTION public.is_admin_member(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.admin_members WHERE user_id = p_user_id
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin_member(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_member(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_dashboard_summary(
    p_start TIMESTAMPTZ,
    p_end TIMESTAMPTZ,
    p_environment TEXT DEFAULT 'production',
    p_admin_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin UUID := COALESCE(p_admin_user_id, auth.uid());
    v_active BIGINT := 0;
    v_sessions BIGINT := 0;
    v_minutes NUMERIC := 0;
    v_feature_usage JSONB := '[]'::jsonb;
    v_daily_activity JSONB := '[]'::jsonb;
    v_api JSONB := '{}'::jsonb;
BEGIN
    IF p_start IS NULL OR p_end IS NULL OR p_start >= p_end THEN
        RAISE EXCEPTION 'invalid period' USING ERRCODE = '22023';
    END IF;
    IF p_environment NOT IN ('production', 'test') THEN
        RAISE EXCEPTION 'invalid environment' USING ERRCODE = '22023';
    END IF;
    IF v_admin IS NULL OR NOT public.is_admin_member(v_admin) THEN
        RAISE EXCEPTION 'admin access required' USING ERRCODE = '42501';
    END IF;

    SELECT COUNT(DISTINCT user_id)
      INTO v_active
      FROM public.learning_events
     WHERE happened_at >= p_start AND happened_at < p_end
       AND event_type IN (
           'sentence_created', 'listen_completed',
           'practice_rated', 'preview_completed'
       );

    WITH slots AS (
        SELECT DISTINCT user_id,
               (metadata ->> 'slot_start')::numeric AS slot_start
        FROM public.learning_events
        WHERE happened_at >= p_start AND happened_at < p_end
          AND event_type = 'activity_heartbeat'
          AND metadata ->> 'slot_start' ~ '^\d+$'
    ), starts AS (
        SELECT CASE
                   WHEN slot_start - LAG(slot_start) OVER (
                       PARTITION BY user_id ORDER BY slot_start
                   ) > 1800 THEN 1
                   WHEN ROW_NUMBER() OVER (
                       PARTITION BY user_id ORDER BY slot_start
                   ) = 1 THEN 1
                   ELSE 0
               END AS is_start
        FROM slots
    )
    SELECT COUNT(*) FILTER (WHERE is_start = 1), COUNT(*) * 0.5
      INTO v_sessions, v_minutes
      FROM starts;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'feature', event_type, 'count', count
           ) ORDER BY event_type), '[]'::jsonb)
      INTO v_feature_usage
      FROM (
          SELECT event_type, COUNT(*) AS count
          FROM public.learning_events
          WHERE happened_at >= p_start AND happened_at < p_end
            AND event_type IN (
                'sentence_created', 'listen_completed',
                'practice_rated', 'preview_completed'
            )
          GROUP BY event_type
      ) features;

    WITH learning_days AS (
        SELECT DISTINCT user_id,
               date_trunc('day', happened_at AT TIME ZONE 'UTC') AS day
        FROM public.learning_events
        WHERE happened_at >= p_start AND happened_at < p_end
          AND event_type IN (
              'sentence_created', 'listen_completed',
              'practice_rated', 'preview_completed'
          )
    ), slots AS (
        SELECT DISTINCT user_id,
               date_trunc('day', happened_at AT TIME ZONE 'UTC') AS day,
               (metadata ->> 'slot_start')::numeric AS slot_start
        FROM public.learning_events
        WHERE happened_at >= p_start AND happened_at < p_end
          AND event_type = 'activity_heartbeat'
          AND metadata ->> 'slot_start' ~ '^\d+$'
    ), joined AS (
        SELECT COALESCE(l.day, s.day) AS day,
               COALESCE(l.user_id, s.user_id) AS user_id,
               s.slot_start
        FROM learning_days l
        FULL JOIN slots s ON l.user_id = s.user_id AND l.day = s.day
    ), active AS (
        SELECT day, COUNT(DISTINCT user_id) AS active_learners
        FROM learning_days
        GROUP BY day
    ), minutes AS (
        SELECT date_trunc('day', happened_at AT TIME ZONE 'UTC') AS day,
               COUNT(DISTINCT (user_id, (metadata ->> 'slot_start')::numeric)) * 0.5 AS effective_minutes
        FROM public.learning_events
        WHERE happened_at >= p_start AND happened_at < p_end
          AND event_type = 'activity_heartbeat'
          AND metadata ->> 'slot_start' ~ '^\d+$'
        GROUP BY day
    )
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'date', day,
               'activeLearners', COALESCE(active_learners, 0),
               'effectiveLearningMinutes', effective_minutes
           ) ORDER BY day), '[]'::jsonb)
      INTO v_daily_activity
      FROM (
          SELECT COALESCE(a.day, m.day) AS day,
                 a.active_learners,
                 COALESCE(m.effective_minutes, 0) AS effective_minutes
          FROM active a
          FULL JOIN minutes m ON a.day = m.day
      ) days;

    SELECT jsonb_build_object(
        'businessRequests', COALESCE(b.count, 0),
        'reusedRequests', COALESCE(b.reused, 0),
        'providerAttempts', COALESCE(a.count, 0),
        'knownEstimatedCostUsd', COALESCE(a.estimated_cost, 0),
        'unknownUsageAttempts', COALESCE(a.unknown_count, 0),
        'providerRecordedCostUsd', COALESCE(c.amount, 0),
        'byFeature', COALESCE(a.by_feature, '[]'::jsonb),
        'dailyCosts', COALESCE(c.daily_costs, '[]'::jsonb)
    )
      INTO v_api
      FROM (
          SELECT COUNT(*) AS count,
                 COUNT(*) FILTER (WHERE outcome = 'reused') AS reused
          FROM public.generation_business_events
          WHERE environment = p_environment
            AND occurred_at >= p_start AND occurred_at < p_end
      ) b,
      LATERAL (
          SELECT COUNT(*) AS count,
                 COUNT(*) FILTER (
                     WHERE usage_source = 'unknown' OR provider_status = 'unknown'
                 ) AS unknown_count,
                 COALESCE(SUM(estimated_cost_usd), 0) AS estimated_cost,
                 (
                     SELECT COALESCE(jsonb_agg(jsonb_build_object(
                         'feature', feature,
                         'attempts', attempts,
                         'estimatedCostUsd', cost,
                         'unknownAttempts', unknown_count
                     ) ORDER BY feature), '[]'::jsonb)
                     FROM (
                         SELECT feature,
                                COUNT(*) AS attempts,
                                COALESCE(SUM(estimated_cost_usd), 0) AS cost,
                                COUNT(*) FILTER (
                                    WHERE usage_source = 'unknown'
                                       OR provider_status = 'unknown'
                                ) AS unknown_count
                         FROM public.generation_usage_attempts
                         WHERE environment = p_environment
                           AND started_at >= p_start AND started_at < p_end
                         GROUP BY feature
                     ) feature_rows
                 ) AS by_feature
          FROM public.generation_usage_attempts
          WHERE environment = p_environment
            AND started_at >= p_start AND started_at < p_end
      ) a,
      LATERAL (
          SELECT COALESCE(SUM(amount), 0) AS amount,
                 (
                     SELECT COALESCE(jsonb_agg(
                         jsonb_build_object('date', usage_date, 'amountUsd', amount)
                         ORDER BY usage_date
                     ), '[]'::jsonb)
                     FROM (
                         SELECT usage_date, SUM(amount) AS amount
                         FROM public.provider_cost_snapshots
                         WHERE environment = p_environment
                           AND currency = 'USD'
                           AND usage_date >= (p_start AT TIME ZONE 'UTC')::date
                           AND usage_date < (p_end AT TIME ZONE 'UTC')::date
                         GROUP BY usage_date
                     ) cost_days
                 ) AS daily_costs
          FROM public.provider_cost_snapshots
          WHERE environment = p_environment
            AND currency = 'USD'
            AND usage_date >= (p_start AT TIME ZONE 'UTC')::date
            AND usage_date < (p_end AT TIME ZONE 'UTC')::date
      ) c;

    RETURN jsonb_build_object(
        'period', jsonb_build_object(
            'start', p_start, 'end', p_end, 'timezone', 'UTC'
        ),
        'environment', p_environment,
        'activeLearners', v_active,
        'learningSessions', v_sessions,
        'effectiveLearningMinutes', v_minutes,
        'featureUsage', v_feature_usage,
        'dailyActivity', v_daily_activity,
        'api', v_api
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_summary(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_summary(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID)
    TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_generation_attempts(
    p_start TIMESTAMPTZ DEFAULT NULL,
    p_end TIMESTAMPTZ DEFAULT NULL,
    p_environment TEXT DEFAULT 'production',
    p_feature TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0,
    p_admin_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    client_request_id UUID,
    feature TEXT,
    model TEXT,
    provider_request_id VARCHAR(200),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    provider_status TEXT,
    delivery_status TEXT,
    http_status INTEGER,
    error_code VARCHAR(100),
    item_count INTEGER,
    usage_source TEXT,
    estimate_basis TEXT,
    estimated_cost_usd NUMERIC(16, 10)
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF COALESCE(p_admin_user_id, auth.uid()) IS NULL
       OR NOT public.is_admin_member(COALESCE(p_admin_user_id, auth.uid())) THEN
        RAISE EXCEPTION 'admin access required' USING ERRCODE = '42501';
    END IF;
    IF p_environment NOT IN ('production', 'test') THEN
        RAISE EXCEPTION 'invalid environment' USING ERRCODE = '22023';
    END IF;
    IF p_feature IS NOT NULL AND p_feature NOT IN (
        'transcription', 'sentence', 'preparation', 'batch', 'tts'
    ) THEN
        RAISE EXCEPTION 'invalid feature' USING ERRCODE = '22023';
    END IF;
    IF p_status IS NOT NULL AND p_status NOT IN (
        'started', 'succeeded', 'failed', 'unknown'
    ) THEN
        RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT a.id,
           a.user_id,
           a.client_request_id,
           a.feature,
           a.model,
           a.provider_request_id,
           a.started_at,
           a.finished_at,
           a.provider_status,
           a.delivery_status,
           a.http_status,
           a.error_code,
           a.item_count,
           a.usage_source,
           a.estimate_basis,
           a.estimated_cost_usd
    FROM public.generation_usage_attempts a
    WHERE a.environment = p_environment
      AND (p_start IS NULL OR a.started_at >= p_start)
      AND (p_end IS NULL OR a.started_at < p_end)
      AND (p_feature IS NULL OR a.feature = p_feature)
      AND (p_status IS NULL OR a.provider_status = p_status)
    ORDER BY a.started_at DESC
    LIMIT GREATEST(LEAST(p_limit, 500), 1)
    OFFSET GREATEST(p_offset, 0);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_generation_attempts(
    TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, INTEGER, INTEGER, UUID
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_generation_attempts(
    TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, INTEGER, INTEGER, UUID
) TO authenticated, service_role;

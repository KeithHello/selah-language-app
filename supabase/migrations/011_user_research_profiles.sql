-- Optional user research profiles: answers, consent, prompt state, revisions.
-- Draft only: apply to remote projects only after a separate approval.
-- Contract: supabase/functions/_shared/research_profile_contract.ts

CREATE TABLE IF NOT EXISTS public.user_research_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    learning_goal TEXT,
    english_level TEXT,
    age_group TEXT,
    life_stage TEXT,
    gender TEXT,
    gender_description TEXT,
    research_consent BOOLEAN NOT NULL DEFAULT false,
    notice_version TEXT,
    prompt_state TEXT NOT NULL DEFAULT 'unseen',
    revision INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT user_research_profiles_learning_goal_check CHECK (
        learning_goal IS NULL
        OR learning_goal IN ('work', 'daily', 'travel', 'exam', 'other', 'prefer_not_say')
    ),
    CONSTRAINT user_research_profiles_english_level_check CHECK (
        english_level IS NULL
        OR english_level IN ('starter', 'reading_stronger', 'conversational', 'not_sure', 'prefer_not_say')
    ),
    CONSTRAINT user_research_profiles_age_group_check CHECK (
        age_group IS NULL
        OR age_group IN ('under_14', 'age_14_17', 'age_18_24', 'age_25_34', 'age_35_44', 'age_45_plus', 'prefer_not_say')
    ),
    CONSTRAINT user_research_profiles_life_stage_check CHECK (
        life_stage IS NULL
        OR life_stage IN ('student', 'employee', 'self_employed', 'other', 'prefer_not_say')
    ),
    CONSTRAINT user_research_profiles_gender_check CHECK (
        gender IS NULL
        OR gender IN ('male', 'female', 'self_described', 'prefer_not_say')
    ),
    CONSTRAINT user_research_profiles_prompt_state_check CHECK (
        prompt_state IN ('unseen', 'offered', 'skipped', 'answered', 'withdrawn')
    ),
    -- 40 Unicode code points mirrors the edge-function contract.
    CONSTRAINT user_research_profiles_gender_description_check CHECK (
        gender_description IS NULL OR char_length(gender_description) <= 40
    )
);

-- Row access is server-only: the Edge Function uses the service role and the
-- RPCs below validate ownership. Direct anon/authenticated access stays
-- revoked while RLS is enabled as defense in depth.
ALTER TABLE public.user_research_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_research_profiles FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.user_research_profile_snapshot(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_row public.user_research_profiles%ROWTYPE;
BEGIN
    SELECT * INTO v_row
      FROM public.user_research_profiles
     WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'profile', jsonb_build_object(
                'learningGoal', NULL,
                'englishLevel', NULL,
                'ageGroup', NULL,
                'lifeStage', NULL,
                'gender', NULL,
                'genderDescription', NULL
            ),
            'promptState', 'unseen',
            'consentState', 'none',
            'noticeVersion', '2026-09-12-v1',
            'revision', 0,
            'canInvite', true
        );
    END IF;
    RETURN jsonb_build_object(
        'profile', jsonb_build_object(
            'learningGoal', v_row.learning_goal,
            'englishLevel', v_row.english_level,
            'ageGroup', v_row.age_group,
            'lifeStage', v_row.life_stage,
            'gender', v_row.gender,
            'genderDescription', v_row.gender_description
        ),
        'promptState', v_row.prompt_state,
        'consentState',
            CASE
                WHEN v_row.prompt_state = 'withdrawn' THEN 'withdrawn'
                WHEN v_row.research_consent THEN 'granted'
                ELSE 'none'
            END,
        'noticeVersion', COALESCE(v_row.notice_version, '2026-09-12-v1'),
        'revision', v_row.revision,
        'canInvite', v_row.prompt_state = 'unseen'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_research_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'profile_invalid_input: missing user id';
    END IF;
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'profile_invalid_input: cross-user access is not allowed';
    END IF;
    RETURN public.user_research_profile_snapshot(p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_user_research_profile(
    p_user_id UUID,
    p_operation TEXT,
    p_profile JSONB DEFAULT NULL,
    p_notice_version TEXT DEFAULT NULL,
    p_research_consent BOOLEAN DEFAULT false,
    p_expected_revision INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_row public.user_research_profiles%ROWTYPE;
    v_learning_goal TEXT;
    v_english_level TEXT;
    v_age_group TEXT;
    v_life_stage TEXT;
    v_gender TEXT;
    v_gender_description TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'profile_invalid_input: missing user id';
    END IF;
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'profile_invalid_input: cross-user access is not allowed';
    END IF;
    IF p_operation NOT IN ('offer', 'save', 'skip', 'withdraw') THEN
        RAISE EXCEPTION 'profile_invalid_input: unknown operation';
    END IF;

    INSERT INTO public.user_research_profiles (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT * INTO v_row
      FROM public.user_research_profiles
     WHERE user_id = p_user_id
     FOR UPDATE;

    IF p_expected_revision IS NOT NULL
       AND p_expected_revision <> v_row.revision THEN
        RAISE EXCEPTION 'profile_conflict: revision moved, reload before retrying';
    END IF;

    IF p_operation = 'offer' THEN
        -- Claiming the invite is atomic and idempotent: later offers keep
        -- whatever state the profile already reached.
        IF v_row.prompt_state = 'unseen' THEN
            UPDATE public.user_research_profiles
               SET prompt_state = 'offered',
                   updated_at = now()
             WHERE user_id = p_user_id;
        END IF;
    ELSIF p_operation = 'save' THEN
        IF p_research_consent IS NOT TRUE THEN
            RAISE EXCEPTION 'profile_consent_required: research consent is required';
        END IF;
        IF p_profile IS NULL THEN
            RAISE EXCEPTION 'profile_invalid_input: profile payload is required';
        END IF;
        v_learning_goal := NULLIF(p_profile ->> 'learningGoal', '');
        v_english_level := NULLIF(p_profile ->> 'englishLevel', '');
        v_age_group := NULLIF(p_profile ->> 'ageGroup', '');
        v_life_stage := NULLIF(p_profile ->> 'lifeStage', '');
        v_gender := NULLIF(p_profile ->> 'gender', '');
        v_gender_description := NULLIF(trim(p_profile ->> 'genderDescription'), '');

        IF v_learning_goal IS NOT NULL AND v_learning_goal NOT IN
            ('work', 'daily', 'travel', 'exam', 'other', 'prefer_not_say') THEN
            RAISE EXCEPTION 'profile_invalid_input: invalid learningGoal';
        END IF;
        IF v_english_level IS NOT NULL AND v_english_level NOT IN
            ('starter', 'reading_stronger', 'conversational', 'not_sure', 'prefer_not_say') THEN
            RAISE EXCEPTION 'profile_invalid_input: invalid englishLevel';
        END IF;
        IF v_age_group IS NOT NULL AND v_age_group NOT IN
            ('under_14', 'age_14_17', 'age_18_24', 'age_25_34', 'age_35_44', 'age_45_plus', 'prefer_not_say') THEN
            RAISE EXCEPTION 'profile_invalid_input: invalid ageGroup';
        END IF;
        IF v_life_stage IS NOT NULL AND v_life_stage NOT IN
            ('student', 'employee', 'self_employed', 'other', 'prefer_not_say') THEN
            RAISE EXCEPTION 'profile_invalid_input: invalid lifeStage';
        END IF;
        IF v_gender IS NOT NULL AND v_gender NOT IN
            ('male', 'female', 'self_described', 'prefer_not_say') THEN
            RAISE EXCEPTION 'profile_invalid_input: invalid gender';
        END IF;
        IF v_gender_description IS NOT NULL
           AND char_length(v_gender_description) > 40 THEN
            RAISE EXCEPTION 'profile_invalid_input: genderDescription is too long';
        END IF;
        IF v_gender_description IS NOT NULL AND v_gender <> 'self_described' THEN
            RAISE EXCEPTION 'profile_invalid_input: genderDescription requires self_described gender';
        END IF;

        UPDATE public.user_research_profiles
           SET learning_goal = v_learning_goal,
               english_level = v_english_level,
               age_group = v_age_group,
               life_stage = v_life_stage,
               gender = v_gender,
               gender_description = v_gender_description,
               research_consent = true,
               notice_version = COALESCE(p_notice_version, notice_version),
               prompt_state = 'answered',
               revision = revision + 1,
               updated_at = now()
         WHERE user_id = p_user_id;
    ELSIF p_operation = 'skip' THEN
        IF v_row.prompt_state IN ('unseen', 'offered') THEN
            UPDATE public.user_research_profiles
               SET prompt_state = 'skipped',
                   revision = revision + 1,
                   updated_at = now()
             WHERE user_id = p_user_id;
        END IF;
    ELSE
        -- Withdraw clears every research answer and keeps the minimal
        -- withdrawal marker so the invite is never re-armed.
        UPDATE public.user_research_profiles
           SET learning_goal = NULL,
               english_level = NULL,
               age_group = NULL,
               life_stage = NULL,
               gender = NULL,
               gender_description = NULL,
               research_consent = false,
               prompt_state = 'withdrawn',
               revision = revision + 1,
               updated_at = now()
         WHERE user_id = p_user_id;
    END IF;

    RETURN public.user_research_profile_snapshot(p_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.user_research_profile_snapshot(UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_user_research_profile(UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_user_research_profile(UUID, TEXT, JSONB, TEXT, BOOLEAN, INTEGER)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_research_profile_snapshot(UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.get_user_research_profile(UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user_research_profile(UUID, TEXT, JSONB, TEXT, BOOLEAN, INTEGER)
    TO service_role;

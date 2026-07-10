-- Selah v8 Initial Schema Migration
-- Date: 2026-07-10
-- Based on: archive/selah-v8-ios-architecture.md §5 Core Data Model
--
-- This migration creates all tables for the Selah backend.
-- The iOS app is local-first; Supabase serves as backup + AI/TTS proxy.
-- Raw user sentences are NOT permanently stored here (privacy-first).
-- Only metadata and sync state are persisted.

-- ============================================================
-- 1. user_profiles
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    source_language TEXT NOT NULL DEFAULT 'zh-Hant',
    target_language TEXT NOT NULL DEFAULT 'en',
    voice_profile TEXT NOT NULL DEFAULT 'gentle-natural',
    playback_speed REAL NOT NULL DEFAULT 0.85,
    active_companion_id UUID,
    notification_enabled BOOLEAN NOT NULL DEFAULT true,
    notification_time TEXT DEFAULT '20:00',
    onboarding_completed BOOLEAN NOT NULL DEFAULT false,
    daily_recordings_used INTEGER NOT NULL DEFAULT 0,
    daily_recording_limit INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. companions (sprite companion)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.companions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    companion_key TEXT NOT NULL DEFAULT 'seed_sprite',
    display_name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    mood TEXT NOT NULL DEFAULT 'neutral',
    decoration_stage TEXT NOT NULL DEFAULT 'none',
    last_interaction_at TIMESTAMPTZ,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_companions_user_id ON public.companions(user_id);
CREATE INDEX idx_companions_active ON public.companions(user_id, active);

-- ============================================================
-- 3. sprite_memories (learning milestones)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.sprite_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    companion_id UUID NOT NULL REFERENCES public.companions(id) ON DELETE CASCADE,
    memory_key TEXT NOT NULL,
    title TEXT NOT NULL,
    description_text TEXT NOT NULL,
    icon TEXT NOT NULL DEFAULT '🌱',
    category TEXT NOT NULL DEFAULT 'started',
    unlocked BOOLEAN NOT NULL DEFAULT false,
    unlocked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(companion_id, memory_key)
);

CREATE INDEX idx_sprite_memories_companion_id ON public.sprite_memories(companion_id);

-- ============================================================
-- 4. sentences (user's learning sentences - metadata only)
-- ============================================================
-- Note: raw Chinese text is processed transiently by Edge Functions.
-- This table stores sentence metadata for sync, NOT the raw audio.
-- The target_text (English) is stored because it's the learning material.

CREATE TABLE IF NOT EXISTS public.sentences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    source_text TEXT NOT NULL,
    target_text TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'daily_life',
    origin TEXT NOT NULL DEFAULT 'user_recording',
    deconstruction JSONB NOT NULL DEFAULT '[]'::jsonb,
    vocab_candidates JSONB NOT NULL DEFAULT '[]'::jsonb,
    archived BOOLEAN NOT NULL DEFAULT false,
    previewed_at TIMESTAMPTZ,
    listen_completed_at TIMESTAMPTZ,
    review_state TEXT NOT NULL DEFAULT 'new',
    next_review_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    interval_days INTEGER NOT NULL DEFAULT 1,
    last_recall_signal TEXT,
    lapse_count INTEGER NOT NULL DEFAULT 0,
    synced_to_cloud BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sentences_user_id ON public.sentences(user_id);
CREATE INDEX idx_sentences_user_review ON public.sentences(user_id, next_review_at);
CREATE INDEX idx_sentences_user_category ON public.sentences(user_id, category);

-- ============================================================
-- 5. vocab_items (vocabulary tied to sentences)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.vocab_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sentence_id UUID NOT NULL REFERENCES public.sentences(id) ON DELETE CASCADE,
    surface_text TEXT NOT NULL,
    meaning_in_context TEXT NOT NULL,
    help_state TEXT NOT NULL DEFAULT 'new',
    manually_added BOOLEAN NOT NULL DEFAULT false,
    success_count INTEGER NOT NULL DEFAULT 0,
    failure_count INTEGER NOT NULL DEFAULT 0,
    active_help_visible BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vocab_items_user_id ON public.vocab_items(user_id);
CREATE INDEX idx_vocab_items_sentence_id ON public.vocab_items(sentence_id);
CREATE INDEX idx_vocab_items_help_state ON public.vocab_items(user_id, help_state);

-- ============================================================
-- 6. audio_assets (metadata for cached TTS audio)
-- ============================================================
-- Audio files are NOT stored in the database.
-- This table tracks: which sentence has audio, which voice, generation status.
-- Actual audio lives on device (local-first) or optional object storage.

CREATE TABLE IF NOT EXISTS public.audio_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sentence_id UUID NOT NULL REFERENCES public.sentences(id) ON DELETE CASCADE,
    voice_profile TEXT NOT NULL DEFAULT 'gentle-natural',
    local_file_path TEXT,
    remote_asset_id TEXT,
    generation_status TEXT NOT NULL DEFAULT 'queued',
    generation_reason TEXT NOT NULL DEFAULT 'initial_generation',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    downloaded_at TIMESTAMPTZ
);

CREATE INDEX idx_audio_assets_sentence_id ON public.audio_assets(sentence_id);
CREATE INDEX idx_audio_assets_status ON public.audio_assets(user_id, generation_status);

-- ============================================================
-- 7. generation_jobs (retry queue for AI/TTS)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sentence_id UUID NOT NULL REFERENCES public.sentences(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 5,
    last_error_code TEXT,
    next_retry_at TIMESTAMPTZ,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_generation_jobs_status ON public.generation_jobs(status, next_retry_at);
CREATE INDEX idx_generation_jobs_sentence_id ON public.generation_jobs(sentence_id);

-- ============================================================
-- 8. learning_events (append-only analytics, privacy-minimal)
-- ============================================================
-- Never stores raw sentence text. Only event type + metadata.

CREATE TABLE IF NOT EXISTS public.learning_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sentence_id UUID,
    event_type TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    happened_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_learning_events_user_id ON public.learning_events(user_id, happened_at DESC);
CREATE INDEX idx_learning_events_type ON public.learning_events(user_id, event_type);

-- ============================================================
-- 9. sync_queue (offline change queue)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.sync_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    operation TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT
);

CREATE INDEX idx_sync_queue_user_id ON public.sync_queue(user_id, created_at);

-- ============================================================
-- 10. seed_sentences (system-provided cold-start content)
-- ============================================================
-- Read-only for all authenticated users.
-- Contains pre-generated English + deconstruction + vocab.
-- Audio URLs point to pre-generated CDN files.

CREATE TABLE IF NOT EXISTS public.seed_sentences (
    id TEXT PRIMARY KEY,
    zh_text TEXT NOT NULL,
    en_translation TEXT NOT NULL,
    category TEXT NOT NULL,
    difficulty TEXT NOT NULL DEFAULT 'basic',
    deconstruction JSONB NOT NULL DEFAULT '[]'::jsonb,
    vocab_candidates JSONB NOT NULL DEFAULT '[]'::jsonb,
    seed_tags TEXT[] NOT NULL DEFAULT '{}',
    audio_urls JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_seed_sentences_category ON public.seed_sentences(category);
CREATE INDEX idx_seed_sentences_difficulty ON public.seed_sentences(difficulty);

-- ============================================================
-- 11. usage_records (credit-ready metering, dormant in MVP)
-- ============================================================
-- Tracks billable AI/TTS operations for future billing.
-- Not shown to users in MVP.

CREATE TABLE IF NOT EXISTS public.usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    operation_type TEXT NOT NULL,
    estimated_units INTEGER NOT NULL DEFAULT 1,
    client_request_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_usage_records_user_id ON public.usage_records(user_id, created_at DESC);

-- ============================================================
-- Updated_at trigger (applies to all tables with updated_at)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'user_profiles',
        'companions',
        'sentences',
        'vocab_items',
        'generation_jobs'
    ])
    LOOP
        EXECUTE format('
            CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
        ', t);
    END LOOP;
END $$;

-- ============================================================
-- Auto-create user_profile + companion on signup
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_companion_id UUID;
BEGIN
    -- Create user profile
    INSERT INTO public.user_profiles (id)
    VALUES (NEW.id);

    -- Create default companion
    INSERT INTO public.companions (user_id, display_name)
    VALUES (NEW.id, '小豆')
    RETURNING id INTO new_companion_id;

    -- Link companion to profile
    UPDATE public.user_profiles
    SET active_companion_id = new_companion_id
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
-- Selah RLS Policies
-- Date: 2026-07-10
-- Based on: v8 architecture §4 Backend Storage Policy
--
-- Rules:
-- - Users can only CRUD their own data (auth.uid() = user_id)
-- - seed_sentences is read-only for all authenticated users
-- - usage_records is insert-only (no user-facing read in MVP)

-- ============================================================
-- Enable RLS on all tables
-- ============================================================

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sprite_memories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sentences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocab_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audio_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seed_sentences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_records ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- user_profiles: user can only access own profile
-- ============================================================

CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ============================================================
-- companions: user can only access own companions
-- ============================================================

CREATE POLICY "Users can view own companions"
    ON public.companions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own companions"
    ON public.companions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own companions"
    ON public.companions FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own companions"
    ON public.companions FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- sprite_memories: user can access memories of own companions
-- ============================================================

CREATE POLICY "Users can view own sprite memories"
    ON public.sprite_memories FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.companions c
            WHERE c.id = sprite_memories.companion_id
            AND c.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own sprite memories"
    ON public.sprite_memories FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.companions c
            WHERE c.id = sprite_memories.companion_id
            AND c.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own sprite memories"
    ON public.sprite_memories FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.companions c
            WHERE c.id = sprite_memories.companion_id
            AND c.user_id = auth.uid()
        )
    );

-- ============================================================
-- sentences: user can only access own sentences
-- ============================================================

CREATE POLICY "Users can view own sentences"
    ON public.sentences FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sentences"
    ON public.sentences FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sentences"
    ON public.sentences FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sentences"
    ON public.sentences FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- vocab_items: user can only access own vocab
-- ============================================================

CREATE POLICY "Users can view own vocab items"
    ON public.vocab_items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own vocab items"
    ON public.vocab_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own vocab items"
    ON public.vocab_items FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own vocab items"
    ON public.vocab_items FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- audio_assets: user can only access own audio metadata
-- ============================================================

CREATE POLICY "Users can view own audio assets"
    ON public.audio_assets FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own audio assets"
    ON public.audio_assets FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own audio assets"
    ON public.audio_assets FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own audio assets"
    ON public.audio_assets FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- generation_jobs: user can only access own jobs
-- ============================================================

CREATE POLICY "Users can view own generation jobs"
    ON public.generation_jobs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own generation jobs"
    ON public.generation_jobs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own generation jobs"
    ON public.generation_jobs FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own generation jobs"
    ON public.generation_jobs FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- learning_events: user can only access own events (insert-only + read)
-- ============================================================

CREATE POLICY "Users can view own learning events"
    ON public.learning_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own learning events"
    ON public.learning_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- No UPDATE or DELETE policy: events are append-only

-- ============================================================
-- sync_queue: user can only access own queue
-- ============================================================

CREATE POLICY "Users can view own sync queue"
    ON public.sync_queue FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sync queue items"
    ON public.sync_queue FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sync queue items"
    ON public.sync_queue FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sync queue items"
    ON public.sync_queue FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- seed_sentences: all authenticated users can read (public read)
-- ============================================================

CREATE POLICY "Authenticated users can read seed sentences"
    ON public.seed_sentences FOR SELECT
    USING (auth.role() = 'authenticated');

-- No INSERT/UPDATE/DELETE policy: seed data is managed server-side only

-- ============================================================
-- usage_records: user can insert, cannot read (server-side only)
-- ============================================================

CREATE POLICY "Users can insert own usage records"
    ON public.usage_records FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- No SELECT/UPDATE/DELETE policy: usage is server-managed

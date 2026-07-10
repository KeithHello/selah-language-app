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

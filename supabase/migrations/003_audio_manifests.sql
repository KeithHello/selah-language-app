-- Selah M2 Audio Delivery Migration
-- Private Supabase Storage + audio manifest deduplication.
-- Audio is always served through short-lived signed URLs from Edge Functions.

-- ============================================================
-- 1. Audio manifests
-- ============================================================

CREATE TABLE IF NOT EXISTS public.audio_manifests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    -- sentence_id is a local SwiftData UUID during MVP, so it intentionally
    -- has no foreign key to the cloud sentences table.
    sentence_id UUID,
    seed_sentence_id TEXT REFERENCES public.seed_sentences(id) ON DELETE CASCADE,
    scope_key TEXT NOT NULL,
    voice_profile TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    storage_path TEXT,
    tts_model TEXT NOT NULL DEFAULT 'tts-1',
    speed REAL NOT NULL DEFAULT 0.85,
    audio_format TEXT NOT NULL DEFAULT 'mp3',
    byte_size BIGINT NOT NULL DEFAULT 0,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    sha256 TEXT,
    generation_status TEXT NOT NULL DEFAULT 'queued',
    error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_accessed_at TIMESTAMPTZ,
    CONSTRAINT audio_manifests_scope_hash_unique UNIQUE (scope_key, content_hash),
    CONSTRAINT audio_manifests_scope_check CHECK (
        (owner_user_id IS NOT NULL AND sentence_id IS NOT NULL AND seed_sentence_id IS NULL)
        OR
        (owner_user_id IS NULL AND sentence_id IS NULL AND seed_sentence_id IS NOT NULL)
    ),
    CONSTRAINT audio_manifests_status_check CHECK (
        generation_status IN ('queued', 'generating', 'ready', 'failed')
    )
);

CREATE INDEX IF NOT EXISTS idx_audio_manifests_owner_status
    ON public.audio_manifests(owner_user_id, generation_status);
CREATE INDEX IF NOT EXISTS idx_audio_manifests_seed_status
    ON public.audio_manifests(seed_sentence_id, generation_status);
CREATE INDEX IF NOT EXISTS idx_audio_manifests_last_accessed
    ON public.audio_manifests(last_accessed_at);

DROP TRIGGER IF EXISTS set_updated_at ON public.audio_manifests;
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.audio_manifests
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- 2. Private Storage bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'audio-assets',
    'audio-assets',
    false,
    10485760,
    ARRAY['audio/mpeg']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- No direct client Storage object access. Edge Functions use service-role access
-- and return signed URLs after validating JWT ownership/scope.
DROP POLICY IF EXISTS "No direct audio object reads" ON storage.objects;
CREATE POLICY "No direct audio object reads"
    ON storage.objects FOR SELECT
    USING (bucket_id <> 'audio-assets');

DROP POLICY IF EXISTS "No direct audio object writes" ON storage.objects;
CREATE POLICY "No direct audio object writes"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id <> 'audio-assets');

DROP POLICY IF EXISTS "No direct audio object updates" ON storage.objects;
CREATE POLICY "No direct audio object updates"
    ON storage.objects FOR UPDATE
    USING (bucket_id <> 'audio-assets')
    WITH CHECK (bucket_id <> 'audio-assets');

DROP POLICY IF EXISTS "No direct audio object deletes" ON storage.objects;
CREATE POLICY "No direct audio object deletes"
    ON storage.objects FOR DELETE
    USING (bucket_id <> 'audio-assets');

-- ============================================================
-- 3. Manifest RLS
-- ============================================================

ALTER TABLE public.audio_manifests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read permitted audio manifests" ON public.audio_manifests;
CREATE POLICY "Users can read permitted audio manifests"
    ON public.audio_manifests FOR SELECT
    USING (
        owner_user_id = auth.uid()
        OR seed_sentence_id IS NOT NULL
    );

-- Client writes are intentionally denied. Audio manifests are created and
-- updated exclusively by trusted Edge Functions using the service role.

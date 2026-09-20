-- Preserve the language and generation provenance of personal sentences.
--
-- Existing rows intentionally remain NULL.  Their source language cannot be
-- inferred safely from the stored text, and this migration must not rewrite
-- user content.  New clients write these fields when they create or update a
-- sentence; older clients remain compatible because every column is nullable.

ALTER TABLE public.sentences
    ADD COLUMN IF NOT EXISTS source_language TEXT,
    ADD COLUMN IF NOT EXISTS target_language TEXT,
    ADD COLUMN IF NOT EXISTS generation_model TEXT,
    ADD COLUMN IF NOT EXISTS prompt_version TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'public.sentences'::regclass
           AND conname = 'sentences_source_language_check'
    ) THEN
        ALTER TABLE public.sentences
            ADD CONSTRAINT sentences_source_language_check
            CHECK (
                source_language IS NULL
                OR source_language IN ('zh-Hant', 'zh-Hans', 'ja')
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'public.sentences'::regclass
           AND conname = 'sentences_target_language_check'
    ) THEN
        ALTER TABLE public.sentences
            ADD CONSTRAINT sentences_target_language_check
            CHECK (target_language IS NULL OR target_language = 'en');
    END IF;
END $$;

COMMENT ON COLUMN public.sentences.source_language IS
    'Language of the user-provided sentence; NULL means legacy provenance is unknown.';
COMMENT ON COLUMN public.sentences.target_language IS
    'Language generated for study; NULL means legacy provenance is unknown.';
COMMENT ON COLUMN public.sentences.generation_model IS
    'Model/provider identifier returned by the sentence-generation function.';
COMMENT ON COLUMN public.sentences.prompt_version IS
    'Prompt contract version used to generate the sentence.';

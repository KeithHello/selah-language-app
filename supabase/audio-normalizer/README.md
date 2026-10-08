# Selah audio normalizer

This directory is the standalone, dependency-free HTTP worker used by the Supabase audio-generate Edge Function. server.py validates a private MP3 upload, runs FFmpeg EBU R128 loudness normalization, and returns the normalized MP3 with measured metadata headers. The Docker image provides FFmpeg and runs as an unprivileged user.

The worker listens on port 8080. GET /healthz is an unauthenticated readiness probe. POST /v1/normalize requires an Authorization Bearer token, Content-Type audio/mpeg, the lufs-v1 revision header, and the SHA-256 of the exact request body. It does not fetch URLs or log request contents.

Required runtime configuration is AUDIO_NORMALIZER_TOKEN, a random value of at least 32 characters. Optional bounds are AUDIO_NORMALIZER_MAX_BODY_BYTES (512 bytes–10 MiB), AUDIO_NORMALIZER_PROCESS_TIMEOUT_SECONDS (1–120), and AUDIO_NORMALIZER_MAX_CONCURRENT_JOBS (1–8). Do not commit a real token or place one in the image.

Run local tests with Python:

    python -m unittest discover -s supabase/audio-normalizer/tests -v

Build the container from the repository root:

    docker build -f supabase/audio-normalizer/Dockerfile -t selah-audio-normalizer .

The image build and local tests do not deploy or configure an Azure resource. Before any cloud deployment, set a secret token in both the worker and the Edge Function configuration, restrict ingress to HTTPS, configure scale-to-zero HTTP scaling, and validate actual processing latency and per-request infrastructure cost.

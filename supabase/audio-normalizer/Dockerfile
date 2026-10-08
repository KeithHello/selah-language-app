FROM python:3.12-slim-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server.py /app/server.py

ENV AUDIO_NORMALIZER_BIND=0.0.0.0 \
    AUDIO_NORMALIZER_PORT=8080
EXPOSE 8080
USER 65532:65532

CMD ["python", "-u", "/app/server.py"]

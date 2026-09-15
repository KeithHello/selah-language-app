# Bundled seed audio

Run `python SelahFlutter/tool/package_seed_audio.py` from the repository root to package existing server-side seed MP3s. The tool validates each file's SHA-256 and size, creates the asset index, and never invokes AI generation. Private user audio is not included.

For offline loop listening, native seed files use `seed-xxx-source-zh-Hant.mp3` and `seed-xxx-source-ja.mp3`; the manifest keys are `seed-xxx:source:zh-Hant` and `seed-xxx:source:ja`.

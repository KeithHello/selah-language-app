# 本地种子音频响度工具

`server.py` 保留 FFmpeg EBU R128 双遍 loudnorm 函数，供本地种子音频脚本校准 MP3。线上 `audio-generate` 使用 Azure SSML 声线音量表，不调用本目录的 HTTP 服务。

种子资产统一为 24 kHz、单声道、160 kbit/s MP3，目标成品实测约 `-20.9 LUFS`，真峰值不高于 `-1 dBTP`。处理后须重新测量，并把 revision 与校验和写入 seed manifest。

需要本机安装 FFmpeg；无需 Docker、HTTP 服务、认证 token 或云端容器。测试运行方式：

    python -m unittest discover -s supabase/audio-normalizer/tests -v

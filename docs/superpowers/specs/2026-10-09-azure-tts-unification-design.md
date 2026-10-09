# Azure 三语 TTS 与响度统一设计

## 目标

将循环听、单句播放、个人音频补齐和随包种子音轨统一到 Azure Speech 标准神经语音；同一音轨生成、恢复、缓存和播放遵守一致的响度标准。保持用户已熟悉的四个英语 profile 与四个母语 profile，不改变会员文字额度。

## 语音路由

| 内容 | Azure locale／voice | profile 处理 |
| --- | --- | --- |
| 台湾普通话母语 | `zh-TW-HsiaoChenNeural` | `native-gentle` 0%；`native-clear` −5%；`native-bright` +5%／+1st；`native-calm` −8%／−1st |
| 日语母语 | `ja-JP-NanamiNeural` | 沿用相同四档母语 rate／pitch |
| 美式英语 | `en-US-JennyNeural` | gentle 0%；clear −10%；daily-bright 使用 `en-US-GuyNeural` +5%／+1st |
| 英式英语 | `en-GB-SoniaNeural` | 保留 `elegant-british` 身份和英式 locale |

profile 到 voice 的映射仅用于这一版 Azure 标准神经 voice；真实付费试听后，声音自然度、发音与 profile 差异仍要人工验收。SSML 根语言、voice locale 必须匹配，避免跨语言 voice locale 不一致。

## 响度处理

- 线上 Azure 音轨使用校准过的 SSML `volume` 按声线调整，目标声线平均响度约为 `-20.4 LUFS`。校准验收使用每种设置 5 句：平均值与目标相差不超过 `0.5 LU`，每句真峰值 `≤ -1 dBTP`。这是一种基于声线的固定增益，不承诺每一句都逐条达到同一 LUFS；极短句允许更大偏差。
- 响度表 v2：Jenny `+6%`（约 +0.51 dB）；Guy `-8%`；Sonia `-15%`；HsiaoChen `-14%`；Nanami `-31%`。同一 voice 的所有 profile 共用该值。任何声线数值、SSML 生成规则或 Azure 模型变化都须升级 `azure-vol-v2` 并复测。
- SSML 仅写非默认的 `rate`、`pitch` 和 `volume`；全为默认值时省略 `prosody`。计费字符由同一个 canonical SSML builder 计算，因此省略默认标签会同步减少平台成本预留，会员文本额度口径不变。
- 线上成品输出使用 Azure REST 格式 `audio-24khz-160kbitrate-mono-mp3`。生成流程为合成、校验 MP3、计算 SHA-256 与时长、上传成品并标记 `ready`；固定 160 kbit/s 下时长按字节数除以 20 计算毫秒。Edge Function 不运行 FFmpeg，也不调用独立标准化服务，不存放源音频中间对象。
- 随包 60 条种子音轨由 Azure 使用相同 SSML 音量表合成，Azure 返回的 MP3 原样保存；FFmpeg 只测量 LUFS 与真峰值，不修改音频。目标平均值为 `-20.4 LUFS ±0.5 LU`，真峰值 `≤ -1 dBTP`，revision 为 `azure-vol-v2`。

## 计费、额度和缓存

- 会员 `tts` 额度维持当前 `[...text].length` Unicode 码点口径，避免会员套餐无声改变。
- Azure 平台成本独立计算 `billableCharacters`：SSML voice 内文本和会计费的 prosody markup 按 Unicode code point 计数；Han 字符（覆盖汉字与日文 Kanji）每个按 2 个单位预留。计数函数与 SSML builder 共用同一 canonical SSML，防止文本路由与价格单位漂移。
- Azure 每百万计费字符价格、Azure 订阅优惠／免费额度取决于真实资源和结算配置；费率和 price version 由显式服务端配置提供，校验失败则阻止新付费 TTS。usage 记录中的 Azure 实际供应商成本保持 unknown／null，除非供应商响应或账单导入能提供可核对的实耗。预算预留采用配置费率，不把预留当成账单实耗。线上 SSML 音量不产生独立处理器运行成本。
- 请求缓存身份包括语言、provider、voice、profile、speed、文本 hash 和 `azure-vol-v2`。Flutter 浏览器本地音轨的 `audio:v3` 前缀保持不变，并将新生成缓存的响度 revision 更新为 `azure-vol-v2`；旧缓存不再命中。随包种子也使用 `azure-vol-v2` revision，并校验 manifest 与成品 checksum。
- 生成服务 API 保持现有 membership、idempotency、signed URL 和 `audio/mpeg` 响应契约。迁移后不为 Azure 失败调用 OpenAI TTS；失败音轨不可标记 ready。缓存的 OpenAI 成品不会被归为新 Azure 音频。

## 实施边界

本地实现包含 provider route、SSML 与声线音量表、计费单位、Edge Function 直传成品链路、客户端 cache revision、离线 seed 工具、测试和文档。不要创建或应用数据库 migration，不修改 `.env`／密钥，不写远端配置或部署云服务。

本方案实施授权记录在 `CLAUDE.md`。Azure 付费声线校准与种子重建仅使用 `.env` 中的 `AZURE_SPEECH_KEY` 和 `AZURE_SPEECH_REGION`；任何远端 secrets、Edge Function 部署、生产发布和 Cloudflare 操作仍遵循项目及全局授权规则。

## 官方依据

- [Azure Speech 语音与语言支持](https://learn.microsoft.com/azure/ai-services/speech-service/language-support)列出本方案使用的 locale 和标准神经 voice。
- [Azure TTS REST API 与支持的输出格式](https://learn.microsoft.com/azure/cognitive-services/speech-service/rest-text-to-speech)列出 `audio-24khz-160kbitrate-mono-mp3`。
- [Azure TTS 计费字符规则](https://learn.microsoft.com/en-us/azure/ai-services/Speech-Service/text-to-speech)说明空格／标点／Unicode code point 计费且中文及日文 Kanji 按双字符计。
- [Azure SSML 文档](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup)说明 rate、pitch、volume 等控制 markup 可能计费。
- [FFmpeg loudnorm 文档](https://ffmpeg.org/ffmpeg-filters.html#loudnorm)说明 EBU R128 双遍标准化及线性／动态模式。
- [Azure Container Apps 计费](https://learn.microsoft.com/en-us/azure/container-apps/billing)说明 scale-to-zero 时不产生 replica 资源消耗费，但请求费与运行时资源费用仍须按实际配置核算。

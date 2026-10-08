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

- 全部语言和 profile 的交付音轨目标为 `-22 LUFS ±1 LU`，真峰值 `≤ -1 dBTP`；不能依靠浏览器播放器 `volume` 或 SSML `volume` 替代文件响度校准。
- FFmpeg `loudnorm` 使用 EBU R128 两遍测量和应用，目标 `I=-22`、`TP=-1.5`、`LRA=11`；在峰值／动态范围允许时使用线性增益，否则接受 FFmpeg 动态回退。编码后重新测量，若综合响度超差、真峰值越界、时长／声道／采样率不符或结果异常则拒绝交付。
- 规范化处理器 revision 是 `lufs-v1`。成品统一为 24 kHz、单声道、160 kbit/s MP3。供应商输出格式使用 Azure REST 支持的 `audio-24khz-160kbitrate-mono-mp3`，处理器仍负责转码和响度标准化。
- Supabase Edge Function 通过 HTTPS 调用独立处理器；请求含原始音频 SHA-256 和服务端 bearer token。处理器限制输入大小、验证哈希、只在临时目录处理、限制并发和处理超时，不记录原始音频或认证头。响应给出成品 MP3、SHA-256、实测 Integrated LUFS、true peak、duration、normalizer revision 和实际线性／动态模式。
- 原始 TTS 音频在私有 Storage 用确定性临时对象名保存，以便处理器失败后恢复处理而不重新计费调用 Azure；清单只有在规范化结果上传且哈希、实测指标通过后才置为 `ready`。成功后删除临时源对象。Storage bucket 与数据库 schema 不变。

## 计费、额度和缓存

- 会员 `tts` 额度维持当前 `[...text].length` Unicode 码点口径，避免会员套餐无声改变。
- Azure 平台成本独立计算 `billableCharacters`：SSML voice 内文本和会计费的 prosody markup 按 Unicode code point 计数；Han 字符（覆盖汉字与日文 Kanji）每个按 2 个单位预留。计数函数与 SSML builder 共用同一 canonical SSML，防止文本路由与价格单位漂移。
- Azure 每百万计费字符价格、Azure 订阅优惠／免费额度，以及 normalizer 的云上实际资源费用均取决于真实资源和结算配置。官方公开页面当前未给出此订阅的可用数值；费率和 price version 由显式服务端配置提供，校验失败则阻止新付费 TTS。usage 记录中的 Azure 实际供应商成本保持 unknown／null，除非供应商响应或账单导入能提供可核对的实耗。预算预留采用配置费率，不把预留当成账单实耗。
- 请求缓存身份包括语言、provider、voice、profile、speed、文本 hash 和 `lufs-v1`。Flutter 浏览器本地音轨从 `audio:v2` 升到 `audio:v3`，旧数据保留但不再命中。预制种子 manifest 同样纳入模型／voice／speed／revision/hash 并校验成品 checksum。
- 生成服务 API 保持现有 membership、idempotency、signed URL 和 `audio/mpeg` 响应契约。迁移后不为 Azure 失败调用 OpenAI TTS；失败音轨不可标记 ready。缓存的 OpenAI 成品不会被归为新 Azure 音频。

## 实施边界

本地实现包含 provider route、SSML、计费单位、normalizer container、Edge Function 的生成／恢复链路、客户端 cache revision、seed 工具、测试和文档。不要创建或应用数据库 migration，不读取或修改 `.env`／密钥，不配置或部署任何云资源，不调用 Azure 真实 TTS，不覆盖现有随包音频，不修改 CI/CD 或公开发布。

服务端启动真实 Azure 请求还需主人后续确认并提供：Azure Speech key／region、实际 SKU 费率和 price version、normalizer endpoint／认证 token、normalizer 每请求成本预留以及云端容器配置。完成本地验收后，生产 rollout 需先部署并验证处理器，再配置服务端值、部署 Edge Function，最后小样试听并分批重制随包资产。

## 官方依据

- [Azure Speech 语音与语言支持](https://learn.microsoft.com/azure/ai-services/speech-service/language-support)列出本方案使用的 locale 和标准神经 voice。
- [Azure TTS REST API 与支持的输出格式](https://learn.microsoft.com/azure/cognitive-services/speech-service/rest-text-to-speech)列出 `audio-24khz-160kbitrate-mono-mp3`。
- [Azure TTS 计费字符规则](https://learn.microsoft.com/en-us/azure/ai-services/Speech-Service/text-to-speech)说明空格／标点／Unicode code point 计费且中文及日文 Kanji 按双字符计。
- [Azure SSML 文档](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup)说明 rate、pitch、volume 等控制 markup 可能计费。
- [FFmpeg loudnorm 文档](https://ffmpeg.org/ffmpeg-filters.html#loudnorm)说明 EBU R128 双遍标准化及线性／动态模式。
- [Azure Container Apps 计费](https://learn.microsoft.com/en-us/azure/container-apps/billing)说明 scale-to-zero 时不产生 replica 资源消耗费，但请求费与运行时资源费用仍须按实际配置核算。

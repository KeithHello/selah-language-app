# Selah Web AI 与语音费用调研档案

> 调研及价格核验日期：2026-09-07。
> 归档整理完成日期：2026-09-08；价格是上述核验日的快照。
>
> 状态：调研归档；供应商替换未实施。本文保存本次会话已打开并核对的官方来源，不代表账户账单或替代服务效果已经实测。
>
> 主人最新决定：维持原有语音与文本服务方案。本文中的低价服务仅作为后续选型资料，不进入当前开发任务。

## 1．当前决策与适用范围

仅针对 Flutter Web 正式入口及其 Supabase 服务。当前继续使用：

| 环节 | 保留的实现 | 计费发生点 |
| --- | --- | --- |
| 录音转文字 | 浏览器 MediaRecorder → speech-transcribe → gpt-4o-mini-transcribe | 停止录音后上传文件，调用文件转写 API |
| 中文生成英文学习材料 | sentences-generate／sentences-prepare／sentences-batch-generate → gpt-4o-mini | 生成英文、词汇、分类与句子拆解；长文本整理另有一次模型调用 |
| 英文生成声音 | audio-generate → OpenAI tts-1 → MP3 → Supabase Storage | 请求的文本、声线与参数没有可复用音频时合成 |
| 重复聆听 | 浏览器缓存、内置 MP3、已有 Storage 音频及签名下载链接 | 通常不再调用 TTS；存储、下载和函数开销仍需单独统计 |

服务端配置来源：[audio.ts](../supabase/functions/_shared/audio.ts) 、[sentence_contract.ts](../supabase/functions/_shared/sentence_contract.ts) 、[speech_contract.ts](../supabase/functions/_shared/speech_contract.ts) 。

TTS 保持 tts-1、MP3、生成速度 0.85 和现有四个 voiceProfile。用户调整播放速度由浏览器播放器处理。当前没有因本次调研替换模型、接入新的 API、重生成种子音频或改变声音来源。

后续开发入口：[逐项改善设计](superpowers/specs/2026-09-07-selah-web-improvement-design.md) 、[整体开发计划](superpowers/plans/2026-09-07-selah-web-improvement-plan.md) 。

## 2．官方价格与替代方案

价格按来源原币种记录。美元与人民币未做汇率转换；标价、持续月度免费额度、新客试用和受限免费模型分别对待。

### 2.1 英文语音合成

| 服务 | 官方价格快照 | 免费与接入条件 | 本次判断 |
| --- | --- | --- | --- |
| OpenAI tts-1 | 15 美元／百万字符 | 当前已使用，输出 MP3 | 保留，作为现有音质基准 |
| Google Cloud WaveNet | 4 美元／百万字符 | 每月前 400 万字符免费；必须启用计费，超额收费 | 低用量时值得后续评测 |
| Google Cloud Standard | 4 美元／百万字符 | 与 WaveNet 显示同一 SKU；不能把两行免费额度直接相加为 800 万 | 备选，需试听 |
| DeepInfra Kokoro-82M | 0.62 美元／百万字符 | 托管 API，可输出 MP3；不将 Flex 折扣当普通标价 | 按字符标价显著更低，效果未实测 |
| AWS Polly Standard | 4 美元／百万字符 | 新客促销取决于账户条件，不作为永久免费额度 | 备选 |
| Google Neural2／AWS Polly Neural | 16 美元／百万字符 | 免费条件分别按厂商政策 | 超出免费额度后并不比当前 tts-1 便宜 |
| OpenAI gpt-4o-mini-tts | 输入 0.60 美元／百万文本 token；输出 12 美元／百万音频 token | 与按字符计费的模型口径不同 | 不因名称包含 mini 就认定更便宜 |

依据：[OpenAI tts-1](https://developers.openai.com/api/docs/models/tts-1) 、[Google Cloud TTS](https://cloud.google.com/text-to-speech/pricing) 、[DeepInfra Kokoro](https://deepinfra.com/hexgrad/Kokoro-82M) 、[AWS Polly](https://aws.amazon.com/polly/pricing/) 、[OpenAI mini-TTS](https://developers.openai.com/api/docs/models/gpt-4o-mini-tts) 。

Google 的 MP3 可通过返回的 audioContent 解码保存；DeepInfra 也支持可保存的音频输出。未来若更换供应商，可以保留 Storage、音频清单和签名下载链路，但需要适配声线、响应格式及生成版本，不能直接保证旧声线效果一致。[Google 输出示例](https://docs.cloud.google.com/text-to-speech/docs/create-audio-text-command-line) 、[DeepInfra TTS API](https://docs.deepinfra.com/apis/text-to-speech) 。

本次引用复核修正：当前打开的 OpenAI 定价及模型页不足以支持把 mini-TTS 的“约 0.015 美元／分钟”当作现行单价，故正式测算未使用该数值。

### 2.2 录音转写

| 服务 | 价格快照 | 适用条件与限制 |
| --- | --- | --- |
| OpenAI gpt-4o-mini-transcribe | 官方估算约 0.003 美元／分钟 | 基于模型计费的分钟估算，不是本项目实测账单 |
| Groq whisper-large-v3-turbo | 0.04 美元／小时，约 0.000667 美元／分钟 | 多语言，支持直接上传 WebM 等文件；每次最低按 10 秒计费；不提供该模型内置的翻译功能 |
| Groq whisper-large-v3 | 0.111 美元／小时，约 0.00185 美元／分钟 | 多语言，最低计费同样为 10 秒；支持转写和翻译 |
| 阿里百炼 Paraformer 录音文件版，北京 | 0.00008 元／秒，即 0.0048 元／分钟 | 每月发放 36000 秒免费额度，有效期一个月 |
| 阿里百炼 Fun-ASR 录音文件版，北京 | 0.00022 元／秒，即 0.0132 元／分钟 | 36000 秒试用额度按开通／发布等条件计有效期 90 天，不能作为持续月免 |
| 硅基流动 SenseVoiceSmall | 官方标注免费 | 仍有账户认证、固定速率等条件；不能宣称无限免费 |

依据：[OpenAI 定价](https://developers.openai.com/api/docs/pricing) 、[Groq STT](https://console.groq.com/docs/speech-to-text) 、[阿里百炼价格](https://help.aliyun.com/zh/model-studio/model-pricing) 、[硅基流动价格](https://siliconflow.cn/pricing) 、[硅基流动限流规则](https://docs.siliconflow.cn/docs/userguide/rate-limits/rate-limit-and-upgradation) 。

Groq 的文件上传方式与现有 multipart 请求接近。Paraformer／非实时 Fun-ASR 使用可由厂商读取的音频文件 URL，需要额外处理文件可达性和生命周期，不能只替换模型名。阿里托管 SenseVoice 文档提示即将下线，本次未将其列为新接入推荐；该提示不等于其他厂商的 SenseVoice 托管也要下线。[阿里语音识别输入说明](https://help.aliyun.com/zh/model-studio/asr-model) 、[阿里 SenseVoice 说明](https://help.aliyun.com/zh/model-studio/sensevoice-speech-recognition/) 。

当前录音最大 180 秒、10 MiB，原始录音不写入云端 Storage 或学习事件；更换输入方式时需要重新评估这一边界。当前阶段按主人决定保持不变。

### 2.3 英文与结构化学习内容

普通文本调用价格，单位为美元／百万 token，未使用缓存或异步批处理优惠。

| 模型 | 输入 | 输出 | 口径及判断 |
| --- | ---: | ---: | --- |
| gpt-4o-mini | 0.15 | 0.60 | 当前方案，继续使用 |
| gpt-4.1-nano | 0.10 | 0.40 | 同厂商低价候选，结构化输出及教学质量仍需回归 |
| Qwen3.7-Flash | 0.028 | 0.110 | Global、输入不超过 32K 的档位；地区及上下文长度会影响价格 |
| Gemini 2.5 Flash-Lite | 0.10 | 0.40 | 付费标准文本价格；有受限免费层 |
| DeepSeek V4 Flash | 非缓存输入低峰 0.22／高峰 0.44 | 低峰 0.66／高峰 1.32 | 本次查询价格下，不是无条件更便宜的替代 |

依据：[GPT-4o mini](https://developers.openai.com/api/docs/models/gpt-4o-mini) 、[GPT-4.1 nano](https://developers.openai.com/api/docs/models/gpt-4.1-nano) 、[Qwen 价格](https://www.alibabacloud.com/help/en/model-studio/model-pricing) 、[Gemini 价格](https://ai.google.dev/gemini-api/docs/pricing) 、[DeepSeek 价格](https://api-docs.deepseek.com/quick_start/pricing/) 。

相同文本在不同模型中不一定产生相同 token 数；思考模型还可能产生额外计费输出。不能仅比较输入单价。[OpenAI token 说明](https://help.openai.com/en/articles/4936856-w) 。

本项目输出还包含分类、词汇候选和句子拆解。纯翻译 API 的价格不能代表替换整个生成接口后的总成本。Gemini 免费层内容可用于产品改进，付费层的数据使用条件不同；涉及真实私人表达时需先核对条款。[Gemini 服务条款](https://ai.google.dev/gemini-api/terms) 。

## 3．统一费用测算

假设每条新增内容包含 10 秒中文录音、1000 个输入 token、300 个输出 token、75 个英文字符和一种声线，全部首次生成。

说明：仓库 30 条种子英文合计 2227 个字符，平均约 74.2 个字符，故使用 75 字符作为短句量级。1000／300 token 及 10 秒录音均为预算假设，不是实际 usage。不同模型暂按相同 token 数对比；未计长文本整理、失败重试、税费、Storage、流量、函数与数据库费用；未计免费额度。

~~~text
当前方案：
转写 = 1000 × 10 ÷ 60 × 0.003 = 0.500000 美元
文本 = (1000 × 1000 × 0.15 + 1000 × 300 × 0.60) ÷ 1000000 = 0.330000 美元
音频 = 1000 × 75 × 15 ÷ 1000000 = 1.125000 美元
合计 = 1.955000 美元／千条

Groq + gpt-4o-mini + Google WaveNet：
0.111111 + 0.330000 + 0.300000 = 0.741111 美元／千条

Groq + Qwen3.7-Flash + Kokoro：
0.111111 + 0.061000 + 0.046500 = 0.218611 美元／千条
~~~

| 月新增内容 | 当前方案 | 保留文本模型的低价组合 | 三项低价组合 |
| --- | ---: | ---: | ---: |
| 300 条 | 0.5865 美元 | 0.2223 美元 | 0.0656 美元 |
| 1000 条 | 1.9550 美元 | 0.7411 美元 | 0.2186 美元 |
| 30000 条 | 58.6500 美元 | 22.2333 美元 | 6.5583 美元 |

后两种组合按标价分别低约 62.1% 和 88.8%。若 Google 月免费额度可用且未被其他调用消耗，费用还能降低；这是有条件的额度优惠，不能和固定单价混算。极短录音必须逐请求考虑 Groq 的最低 10 秒收费。

在该假设下，当前 TTS 占模型费约 57.5%，因此原调研建议优先评估配音降价。但个人少量使用的绝对费用很小，新增供应商的接入和维护成本也应计算。主人已决定先维持原方案。

## 4．不更换模型也能改善的部分

已存在且应保留的机制：

- 音频首次播放时按需生成；已有 ready 清单可直接签名下载。
- 浏览器音频缓存、SHA-256 校验及内置种子音频。
- 请求 ID 幂等、进行中请求复用、按用户的频率与日额度限制。
- 播放变速在浏览器进行，不为每种播放速度重做 TTS。
- 原始录音仅留当前页面会话，不为转写额外长期存储录音。

仍需改善的机制：

- usage_records 当前按请求记录 estimated_units = 1，未记录完整的供应商实际用量与费用估算。
- 已完成句子的相同中文再次提交时，尚无完整的成果复用策略。
- 整理请求每次创建新 ID；分段数量、重试与本机保存需要统一。
- 上游生成已成功而上传／写清单／回包失败时，仍存在恢复和重复调用问题。
- 控制实际输出长度，并把供应商失败、交付失败和用量未知分别记录。
- 当前批量生成是普通 Chat Completions 请求，不享受 OpenAI Batch API 的自动五折优惠。真正的 Batch 有 24 小时完成窗口，适合可等待的预制内容。[官方 Batch](https://developers.openai.com/api/reference/resources/batches) 。

Prompt caching 还受共同前缀和至少 1024 token 等条件限制；不应为了命中缓存强行加长短句提示词，也不能仅凭重复提示词就认定已享受折扣。[官方缓存说明](https://openai.com/index/api-prompt-caching/) 。

上述改善的行为、优先级和验收条件以独立设计和计划为准，本文不作为实施授权。

## 5．免费与自托管路径的边界

- 系统输入法听写后提交文字，可绕过我方转写调用；例如 Windows 听写使用其在线语音服务，不等于音频完全留在本机。[Windows 说明](https://support.microsoft.com/en-us/accessibility/windows/use-voice-typing-to-talk-instead-of-type-on-your-pc) 。
- 浏览器 SpeechRecognition 的兼容性有限，本地识别还需要能力检测和语言包；不能统一视为跨浏览器离线识别。[MDN 说明](https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition) 。
- speechSynthesis 直接朗读可免我方 TTS API 费，但不会直接返回可保存的 MP3，声音取决于设备可用 voice，不完整等价于现有音频文件体验。[接口说明](https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis/speak) 。
- Whisper／Kokoro 可以作为自托管方向，但计算资源、维护和并发能力仍有成本；源码与模型权重许可证应分别核对。[Whisper](https://github.com/openai/whisper) 、[Kokoro](https://github.com/hexgrad/kokoro) 。
- edge-tts 是第三方对 Edge 在线朗读服务的封装；本次不把它作为具备正式产品服务承诺的默认后端。[项目说明](https://github.com/rany2/edge-tts) 。

## 6．核验记录与后续调用方式

已完成：读取现有代码；打开厂商官方价格与接口文档；交叉核对高影响价格；重新计算费用；区分免费条件与计费单位。

本次会话只读 OPTIONS 检查 speech-transcribe 返回 HTTP 404，响应为 NOT_FOUND／Requested function was not found。此结果证明当时目标函数不可用，不代表 OpenAI 转写模型故障，也不能由更换模型解决。

尚未完成：替代服务付费样本评测、当前账户实际账单核算、全部声线真实生成对比、实际中文准确率／延迟／并发和免费资格验证。已有历史种子音频不代表当前所有付费服务均已端到端验收。

再次使用本文时，应先读取第 1 节用户决策，再核对拟使用服务的最新价格、账户条件及接口。只有主人改变现有方案的决定后，才进入供应商替换评估；现阶段按 Web 改善计划推进原服务的可靠性与验收。

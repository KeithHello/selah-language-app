# Web 语音转写服务

`speech-transcribe` 为浏览器录音提供一条受认证的短语音转文字接口。它只接收一次录音，转写完成后返回文字；原始音频不会写入 Supabase Storage、学习事件或日志。

实现依据 OpenAI 的[文件转写文档](https://developers.openai.com/api/docs/guides/speech-to-text)和[Audio API 参考](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create)：服务端向 `POST https://api.openai.com/v1/audio/transcriptions` 发送 `multipart/form-data`，模型固定为 `gpt-4o-mini-transcribe`。API key 只存在 Edge Function secret，浏览器只能携带 Supabase 用户 access token。

## 请求合约

请求地址为：

```text
POST /functions/v1/speech-transcribe
Authorization: Bearer <supabase-access-token>
Content-Type: multipart/form-data; boundary=...
```

表单字段如下：

| 字段 | 类型 | 要求 |
| --- | --- | --- |
| `file` | `File` | 必填，非空；`audio/webm`、`audio/mp4`、`audio/ogg`、`audio/wav` 或 `audio/x-wav`；最大 10 MiB。校验使用 `File.type`，不会信任文件名后缀。 |
| `clientRequestId` | `string` | 必填 UUID。网络重试必须复用同一个值。 |
| `language` | `string` | 可选，默认 `zh`；使用 ISO 639／常见 BCP 47 语言码，例如 `zh`、`zh-TW`。 |
| `durationMs` | `integer` | 必填，1–180000（最多 180 秒）。 |

服务端会依据已校验的 MIME 类型向 OpenAI 生成 `capture.webm`、`capture.mp4`、`capture.ogg` 或 `capture.wav` 文件名，避免客户端文件名误导 provider。

成功响应（首次调用和幂等重放一致）：

```json
{
  "text": "I am tired today.",
  "language": "zh",
  "durationMs": 2500
}
```

## 幂等、额度与失败处理

请求在调用 OpenAI 之前通过已有的 `claim_generation_request` RPC 申请容量，完成后写入 `complete_generation_request`；provider、解析或完成失败则调用 `fail_generation_request`。同一用户、同一操作和同一 `clientRequestId` 的成功请求直接返回保存的响应，不会再次调用 OpenAI；进行中的请求返回 `429 request_in_progress`。

当前数据库 migration 只允许 `sentence_generation`、`audio_generation` 和 `capture_preparation` 三种操作。为保持本次 Web 接线零 schema 变更，语音转写暂时复用 `capture_preparation` 操作和现有 `CAPTURE_PREPARATION_MINUTE_LIMIT`／`CAPTURE_PREPARATION_DAILY_LIMIT`（默认每分钟 2 次、每日 10 次）。这意味着转写和长文本整理共享额度；后续若要分开计费或配额，需要主人确认新的 migration 和配置。

客户端可按错误码处理：

| HTTP | `error` | 含义 |
| --- | --- | --- |
| 400 | `invalid_multipart`、`missing_audio_file`、`unsupported_audio_type`、`audio_file_too_large`、`invalid_duration` 等 | 请求未通过合约校验，不应重试原请求。 |
| 401 | `unauthorized` | 会话缺失或无效，先恢复登录。 |
| 429 | `request_in_progress`、`rate_limited`、`quota_exceeded` | 等待后重试；重试必须复用 `clientRequestId`。 |
| 502 | `transcription_failed`、`transcription_invalid_response`、`transcription_empty` | provider 或返回格式失败；可用同一请求 ID 重试。 |
| 503 | `transcription_service_unavailable`、`transcription_capacity_unavailable`、`transcription_completion_unavailable` | 服务配置或容量暂时不可用，保留本地录音状态并稍后重试。 |

服务端日志只记录状态码和固定错误标签，不记录原始音频、文件名、转写文字或 provider 响应体。

## 浏览器调用顺序

1. 用户点击录音后申请麦克风权限，`MediaRecorder` 选择浏览器支持的 MIME。
2. 停止录音或达到 180 秒上限时释放轨道，构造 `FormData` 并生成一个 UUID。
3. 携带 Supabase access token 调用本端点；收到文字后让用户确认，再调用 `sentences-prepare`。
4. 断网时将录音保留在当前页面会话内；恢复网络后手动使用同一个 `clientRequestId` 重试。刷新或切换账户会清除未转写录音，原始录音不进入学习事件或持久化备份。

## 部署前清单

2026-09-09 更新：本地 `supabase/config.toml` 已注册 `[functions.speech-transcribe] verify_jwt = true`，`deploy-full.sh` 与部署合约测试的函数清单统一为 8 个；远端单函数已部署，部署后无凭证检查为 `OPTIONS 200`、`POST 401 UNAUTHORIZED_NO_AUTH_HEADER`。未改 migration、`.env` 或 secret，也未执行真实 STT。付费端到端前仍需逐项完成：

1. 单函数部署已完成；完整发布前继续确保只变更 `speech-transcribe`，不运行包含数据库、secret、多函数和种子导入的完整部署脚本。
2. 真实 STT 沿用已有 `OPENAI_API_KEY`、`SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY` secrets；不要把 service-role 或 OpenAI key 放入 Web 构建参数。
3. 用专门测试账户进行一次真实音频验收。真实调用会产生 OpenAI 费用，必须显式获得 billable 验收授权并记录 HTTP 状态、响应字段和 quota ledger 结果，不保存音频或文字样本。

最小部署脚本为 `powershell -NoProfile -File supabase/scripts/deploy-speech-transcribe.ps1`。默认 dry-run 仅检查本地函数和目标 JWT 配置，不调用 CLI 或联网。加 `-Execute` 后才验证现有 CLI 登录或进程 token，通过 `--workdir` 指定项目根目录，仅部署 `speech-transcribe`，并检查 `OPTIONS 200` 和无凭证 `POST 401`；不运行 migration、不设置 secret、不导入种子、不部署其他函数、不 prune。若进程中旧 token 覆盖有效登录，会在部署前明确失败；脚本不修改凭据。

## 本地验证

```bash
deno fmt --check supabase/functions/_shared/speech_contract.ts supabase/functions/speech-transcribe/index.ts supabase/tests/speech_transcribe_test.ts
deno lint supabase/functions/_shared/speech_contract.ts supabase/functions/speech-transcribe/index.ts supabase/tests/speech_transcribe_test.ts
deno check supabase/functions/speech-transcribe/index.ts
deno test --allow-read supabase/tests/speech_transcribe_test.ts
```

测试通过依赖注入替换认证、Supabase RPC 和 `fetch`，不会连接 Supabase、OpenAI 或产生计费请求。

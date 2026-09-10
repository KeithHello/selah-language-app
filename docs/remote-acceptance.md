# 真实远端验收说明（T09）

更新日期：2026-09-09。目标项目：`ijonabyyppmgvoufgamt`（`language-study`）。

## 目的

`supabase/scripts/remote_acceptance.ts` 用一个**普通测试账号**验证 Selah 的真实闭环，不能用 owner CLI 登录或 service role 代替：

`普通 JWT 登录／恢复会话 → config-bootstrap 读库 → 第二账号与已有 RLS 样本预检 → 录音转写及幂等重放 → 单句生成及重放 → 长文本整理及重放 → ≤5 句批量及重放 → TTS 及缓存重放 → 签名 URL 下载 → 新音频的 RLS 隔离`

五个函数（`speech-transcribe`、`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate`）已部署并通过无凭证 `OPTIONS 200`／`POST 401` 检查；这些网关检查**不代表**真实业务成功，真实付费闭环仍待本脚本 `--execute`。

## 第一步：零费用预演

脚本默认 dry-run，不访问网络、不读录音、不产生费用。Windows PowerShell 使用仓库内的本地 Deno：

```powershell
output\playwright\deno-2.9.3\deno.exe run --cached-only supabase/scripts/remote_acceptance.ts
```

## 第二步：准备测试账户与录音（当前阻塞项）

以下两项尚未提供，因此本轮无法执行 `--execute`：

1. **专用普通测试账号**：在 Supabase 项目中用普通注册方式创建，不要使用个人账号或 owner 账号。仅需要 email 与密码，普通账号即可登录并触发函数。
2. **一段真实中文录音**：由实体或系统麦克风实际录制，内容为 1–2 句、约 2–4 秒的中文，例如「今天有点累，想早点休息。」
   - 格式必须是浏览器 `MediaRecorder` 实际产生的 `audio/webm`、`audio/mp4`、`audio/ogg` 或 `audio/wav`。
   - 不超过 10 MiB，时长 1–180,000 ms；脚本**不会**用 TTS 合成转写样本。
   - 录音文件放在仓库外的安全位置，路径通过环境变量或 `--audio-file` 传入，不要提交到仓库。

在 Windows 上可用系统录音机或已有录音工具保存样本。脚本也接受 `.m4a`，会以 `audio/mp4` 提交；实际内容必须是对应音频格式，不能只修改扩展名。Selah 当前页面没有录音文件导出入口。时长应填写样本的实际时长；未填写时脚本沿用 2,500 ms 默认值，该默认值不是测量结果。

## 第三步：在本机设置环境变量

密码只在当前 PowerShell 进程设置，**不要写入 `.env`，不要发到聊天或提交**。`SUPABASE_URL` 与 `SUPABASE_PUBLISHABLE_KEY` 已存在于仓库 `.env`，可在同进程加载，但仍要显式提供测试账户三项：

```powershell
$env:SUPABASE_URL = "https://ijonabyyppmgvoufgamt.supabase.co"
$env:SUPABASE_PUBLISHABLE_KEY = "<publishable/anon key>"
$env:SUPABASE_TEST_EMAIL = "dedicated-test@example.com"
$env:SUPABASE_TEST_PASSWORD = "<dedicated test password>"
$env:REMOTE_ACCEPTANCE_ALLOW_BILLABLE = "true"
$env:REMOTE_ACCEPTANCE_AUDIO_FILE = "C:\path\to\capture.webm"
$env:REMOTE_ACCEPTANCE_AUDIO_DURATION_MS = "2500"
```

在设置变量的**同一个 PowerShell 窗口**运行下面的执行命令；已经启动的 Codex 或其他终端不会自动继承这个窗口的新变量。可在本机执行后分享脱敏结果，不要分享密码。脚本只使用 publishable key 与普通测试账号，不需要 service role key，也不会打印 access token、密码或原始转写文本。

完整账户隔离验收还需第二个普通账号，以及第一账号已保存的私人句子与学习事件 ID：`SUPABASE_TEST_EMAIL_2`、`SUPABASE_TEST_PASSWORD_2`、`SUPABASE_RLS_SENTENCE_ID`、`SUPABASE_RLS_EVENT_ID`。后两个 ID 必须为 UUID，来自专用测试数据。脚本在首次付费接口请求之前检查第二账号登录、第一账号可读样本、第二账号不可读样本；预检失败立即停止。省略样本只会返回 `not_configured`，不能据此宣称完整 RLS 验收通过。新生成音频的隔离检查仍在 TTS 完成后进行。

## 第四步：执行（计费，按已确认预算）

```powershell
output\playwright\deno-2.9.3\deno.exe run --allow-net --allow-env --allow-read supabase/scripts/remote_acceptance.ts --execute
```

若中途失败，使用脚本返回的 run ID 以相同 request ID 续跑，避免重复计费：

```powershell
output\playwright\deno-2.9.3\deno.exe run --allow-net --allow-env --allow-read supabase/scripts/remote_acceptance.ts --execute --resume <run-id> --audio-file C:\path\to\capture.webm
```

## 调用预算与费用核对

一次新 run 的已确认供应商调用预算为：转写 1 次、单句生成 1 次、长文本整理 1 次、批量生成 1 次（≤5 句）、TTS 1 次。脚本对五类业务接口各发送一次提交和一次相同 ID 重放；重放、缓存命中、签名 URL 刷新与音频下载预期不新增供应商调用。录音转写文本超过 500 字会在单句步骤前安全停止，不强行拆成多次付费。

`requestCounts` 统计本脚本的接口请求数，`providerCallBudget` 是计划预算，**都不是供应商实际调用数或账单**。响应相同和缓存命中不能独立证明全部上游调用数；实际费用仍需结合服务端调用记录与供应商账单核对，结果中会保留此项 `unverified`。中途失败先检查错误并保留 run ID；`--resume` 复用请求身份，但供应商已经处理、结果却未保存的失败仍可能在重试时再次计费。

## 数据与权限边界

- `--execute` 会在测试账号下写 generation ledger、`audio_manifests` 和一个 Storage MP3 对象；不会执行 migration、部署、seed 导入、删除数据或修改密钥。
- 提供第二个账号（`SUPABASE_TEST_EMAIL_2`／`SUPABASE_TEST_PASSWORD_2`）时额外验证 RLS 互不可见；两个变量必须同时提供。
- 网络重试和断网恢复逻辑由本地替身测试覆盖；本脚本验证真实端点链路，不模拟断网。
- 真机麦克风、iPhone Safari／主屏幕 PWA、Android、弱网与跨设备 UI 属于 T10，不在本脚本范围。

## 验收证据

执行后记录（不含密钥）：执行时间、Git commit 与未提交变更状态、Web Build ID、Supabase project ref、各端点结果、segment 数量、音频字节数、缓存是否命中、RLS 结果、接口请求次数与失败错误码；供应商实际调用数另列已核实值或「未核实」。当前状态：脚本与五个部署函数已对齐，22 项脚本测试通过，尚未执行 `--execute`。

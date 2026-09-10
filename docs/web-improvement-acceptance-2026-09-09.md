# Selah Web 改善实现与本地发布候选验收

> 日期：2026-09-09。范围：Flutter Web／PWA、Supabase Edge Functions 本地合约、四声线种子音频与本地 Release 候选。`speech-transcribe` 与四个生成／音频改善函数已部署；未执行 Web 公开发布、数据库 migration、密钥修改或付费供应商调用。

> 性能续作更新：当前候选为 `1c0036e1c11f90a9`。首装缓存已由 73.52 MB 降至 56.85 MB，新的两个 Edge 上下文分别完成 Chromium／通用 CanvasKit 离线启动和 120 段音频哈希验证，详见 [首装性能验收](web-performance-2026-09-09.md) 。下文 `7e0a4516b041c795` 的截图、草稿恢复与完整解码记录是前序候选证据。

## 结论

本轮已完成本地可审阅的 Web 改善候选：正式页面输入草稿与异步保护、最多 20 段整理结果和每批 5 段生成、相同句子零调用复用、生成输出合约、转写函数远端单函数部署、音频恢复合约、30 句 × 4 声线共 120 段种子音频离线包，以及可恢复的远端验收脚本。

`speech-transcribe` 与四个生成／音频改善函数已部署，并通过无凭证路由检查和远端源码哈希核对。当前仍不能宣称线上可发布，因为普通测试账户、真实 AI／TTS／转写、RLS、跨设备、iPhone Safari、Android 和已安装 PWA 尚未验收；使用量统计需要独立数据库 schema 确认。

## 自动化验证

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 0 issue |
| `flutter test --no-pub` | 140 项全部通过 |
| `node --test test/browser_bridge.test.mjs test/browser_unload_protection.test.mjs test/service_worker_poses.test.mjs test/plush_assets.test.mjs` | 性能续作后 22 项全部通过 |
| `python -m unittest test.seed_audio_packager_test` | 5 项全部通过，使用已安装的工作区 Python runtime |
| `deno test --cached-only --allow-env --allow-read supabase/tests` | 续作收尾后 200 项全部通过，其中验收脚本 22 项；使用本地替身，不访问 Supabase／OpenAI |
| `deno lint supabase/functions supabase/tests supabase/scripts/remote_acceptance.ts supabase/scripts/seed_audio_inventory.ts` | 30 个文件检查通过 |
| `deno check`（8 个 Edge Function 入口、远端验收与音频盘点脚本） | 10 个入口全部通过 |
| `powershell -NoProfile -File supabase/tests/deploy_speech_transcribe_test.ps1` | 6 项通过，CLI 和 HTTP 全部使用本地替身，未实际部署 |
| `deno run --cached-only supabase/scripts/remote_acceptance.ts` | dry-run 通过；计划上限为 1 次转写、1 次单句、1 次整理、1 批≤5 句、1 次 TTS，未实际执行 |
| `powershell -NoProfile -File SelahFlutter/tool/web.ps1 -Action build` | 最新 Release 构建通过，Build ID `1c0036e1c11f90a9` |
| `git diff --check` | 通过 |

新增回归覆盖：正式 Today 输入框接线、刷新草稿恢复、A／B 异步编辑不被旧结果清空、20 段分 4 批、中途失败只重试剩余段、分段编辑重置待生成身份、相同句子供应商调用为 0、主动重新生成使用新请求 ID、空分句在请求前阻止、输出截断／非法分类／词汇超限、转写 multipart 与幂等重放、音频 Storage 恢复和并发认领。

2026-09-09 续作收尾另修正验收脚本的检查顺序：第二普通账户登录及已有句子／事件的只读 RLS 检查前移至首次付费接口之前。6 类失败场景先在旧实现中复现已发送 10 次业务请求（含重放），修正后均在 0 次付费接口请求时停止；成功流程仍检查新生成音频的隔离，第二账号只登录一次，结果不包含 JWT。22 项脚本测试、200 项 Deno 全量、受影响两文件 lint 和无权限 dry-run 通过。真实账号、供应商实际调用数及跨设备仍未验证。

## 真实浏览器与离线验证

以下保留本机 Chrome 对前序 Release 候选 `7e0a4516b041c795` 的音频、缓存、Today 草稿恢复和响应式布局验证：

- 页面加载后 Service Worker 为 `selah_service_worker.js?v=7e0a4516b041c795`，缓存名为 `selah-shell-7e0a4516b041c795` 与 `selah-static-7e0a4516b041c795`。
- 最终候选通过 CDP 主世界写入最小合法本机快照后刷新，Today 正式页面从 IndexedDB 恢复输入框值「今天想早点休息，但还想完成一句英文练习。」，可访问性树同步显示 `20 / 4,000`，页面 meta 与 Service Worker 均为 `7e0a4516b041c795`。
- 最终桌面 1280×720 截图为 `output/playwright/final-web-acceptance/final-build-7e0-today-draft-desktop.png`；最终手机 CSS 视口 390×844（3 倍像素下 1170×2532）截图为 `output/playwright/final-web-acceptance/final-build-7e0-today-draft-mobile.png`。手机语义树确认 Today 卡片、查看全部 30 句入口与底部五项导航可见。
- 最终候选引导页另核对 30 句均显示「可离线试听」。截图和草稿恢复完成后，仅删除 `127.0.0.1:5193` 的临时 IndexedDB、`selah-shell-7e0a4516b041c795` 与 `selah-static-7e0a4516b041c795` 缓存，并注销本地 Service Worker；不影响项目文件或远端数据。
- 远端 `audio_manifests` 只读盘点为 120 条 ready：四种声线各 30 条，无缺失、无畸形记录。
- 打包器从现有 authenticated Storage 取回 120 段 MP3，本地 `SelahFlutter/assets/audio/` 为 120 个文件、12,529,440 字节；清单键为 120 个，逐条 SHA-256 与字节数匹配。
- 本轮收尾对全部 120 段运行 FFmpeg 完整解码，并逐条核对源文件与最终 Release 副本，全部通过；四种声线各 30 段，缺失／哈希／副本／解码失败均为 0。逐文件结果保存于 `output/playwright/final-web-acceptance/seed-audio-verification.json`。候选产物为 231 个文件、99,790,053 字节。
- 续作收尾再次核对当前 30 句 × 4 声线共 120 段：源文件哈希／字节数、Release 副本和发布包预缓存清单全部一致，合计仍为 12,529,440 字节、失败为 0。新增证据为 `output/playwright/final-web-acceptance/seed-audio-current-integrity.json`；本次未重新解码或重跑浏览器，沿用上面的既有证据。
- 明确设置浏览器离线后，120 段种子音频全部通过正常 `fetch` 路径读取：`entries=120`、`fetched=120`、`hashValid=120`、`failures=[]`。
- 同一轮离线验证中，四种声线均通过 Chrome `AudioContext.decodeAudioData` 抽样解码：`clear-slow`、`daily-bright`、`elegant-british`、`gentle-natural` 全部成功。
- 原最终 Chrome 离线验收控制台错误为 0。120 段最终离线截图为 `output/playwright/final-web-acceptance/final-build-120-offline.png`。

手机视口与桌面 Chrome 证据不等同于真机验收；实体麦克风、iPhone Safari 主屏幕 PWA、Android 浏览器、移动网络性能和后台恢复仍待 T10。

## 远端与费用边界

- 部署前零费用 `OPTIONS` 矩阵：`config-bootstrap`、`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate`、`audio-download-url`、`events` 均返回 200；`speech-transcribe` 返回 404。
- 单函数部署：使用 Supabase CLI 2.117.0 从项目根目录部署 `speech-transcribe --project-ref ijonabyyppmgvoufgamt --use-api`，上传 `index.ts`、`_shared/speech_contract.ts`、`_shared/cors.ts`；未运行 migration、未设置 secret、未导入种子、未部署其他函数。
- 部署后零费用健康检查：`OPTIONS` 返回 `200 OK`，无凭证空 `POST` 返回 `401 Unauthorized`，错误码为 `UNAUTHORIZED_NO_AUTH_HEADER`。该检查不携带 JWT 或录音，不触发函数业务逻辑或 OpenAI。
- 2026-09-09 11:44—11:48（Asia/Tokyo），经主人批准后逐一部署 `sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate`；四者部署后均为 `OPTIONS 200`、无凭证 `POST 401`。该检查不携带 JWT、业务输入或音频，不触发 OpenAI。
- 部署后通过 CLI 只读取回远端源码，核对 4 个入口及随包共享模块，共 16 个 TypeScript 文件与本地 SHA-256 全部一致；记录在 `output/remote-function-postdeploy-20260909-114811/postdeploy-shared-verification.json`。
- 文档收口前再次对五个本轮函数执行零费用矩阵：`speech-transcribe`、`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate` 均为 `OPTIONS 200`、无凭证 `POST 401`。验收进程和仓库 `.env` 均未配置普通测试账户、billable 开关或录音路径；未尝试绕过普通账户验收。
- 2026-09-09 的 Management API 曾因仓库 `.env` 自动注入旧 token 返回 401；从无 `.env` 的临时目录使用 CLI 登录态后可列出项目，目标项目为 `language-study`、`ACTIVE_HEALTHY`。这证明最终部署使用的是有效 owner CLI 凭据，而不是旧 `.env` token。
- 本地 `supabase/config.toml` 与 `deploy-full.sh` 已包含 `speech-transcribe`，部署合约测试要求 8 个函数一致；本轮已部署 `speech-transcribe` 和四个生成／音频改善函数，仍未运行会覆盖数据库、secret、种子与其他函数的完整部署脚本。
- 本轮没有调用 OpenAI、没有生成新音频、没有修改 `.env` 或 secret、没有执行数据库 migration。
- 120 段种子音频全部来自现有 ready 音频文件的只读取回与本地打包；新增 TTS 调用为 0，没有调用 `seed_audio_prebuild.ts --execute`。
- 使用量统计设计已归档于 `docs/2026-09-08-generation-usage-design.md`，但 `generation_usage_attempts` migration 与服务端写入尚未实施。

## 发布前剩余阻塞

1. 提供普通测试账户和中文录音样本，按已批准预算完成真实 STT；当前验收进程和 `.env` 均未配置测试账户或录音路径。CLI 登录只用于部署，不能替代此项。

   T09 的账户、录音格式、同一 PowerShell 窗口执行、`--resume` 续跑、已确认调用预算、RLS 预检和证据字段见 [真实远端验收说明](remote-acceptance.md) 。接口请求数与供应商账单分开记录；脚本默认 dry-run，未执行 `--execute`。
2. 批准并实施使用量统计 schema，或在 T09 中以明确调用上限临时控制费用。
3. 使用普通测试账户验收已部署的最新生成／音频改善，再完成聆听、练习、笔记、RLS 与跨设备恢复；不能用无凭证检查、service-role 结果或本地替身测试替代。
4. 完成 iPhone Safari／主屏幕 PWA、Android、桌面 Chrome 的真机矩阵、120 段音频首次安装下载、低速网络性能和安装更新验收。
5. 上述证据通过后，再单独请求公开部署确认。

## 已执行的转写单函数部署

目标项目为 `ijonabyyppmgvoufgamt`；单函数部署已于 2026-09-09 执行。没有运行 `deploy-full.sh`，因为该脚本覆盖数据库、secret、多个函数和种子导入，超出恢复转写路由所需范围。

| 项目 | 内容 |
| --- | --- |
| 最小远端变更 | 已仅部署 `speech-transcribe` Edge Function；本地与网关均启用 JWT 验证 |
| 复用配置 | 复用现有 `OPENAI_API_KEY`、`SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY`；不修改 `.env`，不把 secret 传入 Web 构建 |
| 数据影响 | 不新增表、不执行 migration、不修改现有句子、音频或 Storage 对象；只使用现有 generation ledger 与额度逻辑 |
| 部署后零费用检查 | 已完成：`OPTIONS 200`，无凭证空 `POST 401 UNAUTHORIZED_NO_AUTH_HEADER`；该检查不调用 OpenAI |
| 付费验收 | 尚未执行；普通测试账户提交一段中文录音，预算上限为 1 次 STT；相同 `clientRequestId` 重放必须复用结果且不再调用 OpenAI |
| 失败边界 | 若密钥、CORS、JWT、multipart 或额度 RPC 失败，保留本地候选，不继续批量部署其他函数 |
| 回退方案 | 该函数不涉及 schema 或数据迁移；回退时重新部署上一版函数包或按主人确认移除该路由。不得用删除数据作为回退手段 |

已执行的部署命令等价于：`npx --yes supabase@2.117.0 --workdir <repo-root> functions deploy speech-transcribe --project-ref ijonabyyppmgvoufgamt --use-api`。后续真实 STT 与完整 T09 沿用已确认的预算，当前缺测试账户和录音样本；schema 与公开托管保留独立确认边界。

### 2026-09-09 部署凭据处理

- 已获得主人对「临时使用 Supabase CLI、仅部署 `speech-transcribe`」的确认；使用 `npx --yes supabase@2.117.0 ...`，未做全局安装。
- 工作区 `.env` 中的旧 `SUPABASE_ACCESS_TOKEN` 对官方 Management API 的 `GET /v1/organizations` 与 `GET /v1/projects` 均返回 HTTP 401；在仓库目录运行 CLI 时会被旧环境变量覆盖。
- 主人完成新的 CLI 登录后，在无 `.env` 自动注入的临时目录运行 `projects list` 成功；目标 `language-study` 项目状态为 `ACTIVE_HEALTHY`。
- 最终从临时目录以 `--workdir <repo-root>` 指定项目路径完成单函数部署，避免使用旧 `.env` token。凭据未写入仓库、提交或日志；现有 `.env` 未修改。
- 最小部署脚本 `supabase/scripts/deploy-speech-transcribe.ps1` 已修正：默认 dry-run 仅检查本地文件与目标函数 JWT 配置，不启动 npx 或联网；`-Execute` 接受现有 CLI 登录或进程 token，通过 `--workdir` 固定项目路径，仅部署 `speech-transcribe --use-api`，并要求 `OPTIONS 200`、无凭证 `POST 401`。不运行 migration、不设置 secret、不导入种子、不 prune 其他函数。6 项本地替身测试覆盖预演、部署范围、工作目录、凭据失败、健康检查失败及目标 JWT 校验；本轮修正后未重新部署。

## 已执行的四个生成／音频函数部署

目标为 `ijonabyyppmgvoufgamt`。以下函数已逐一部署到远端；无凭证 HTTP 检查只能证明路由和 JWT 网关生效，真实行为仍需普通账户样本验收。

| 函数 | 本地改善 | 部署影响 |
| --- | --- | --- |
| `sentences-generate` | 输出预算、响应合约与生成来源信息 | 后续单句请求使用新合约；异常输出会明确失败 |
| `sentences-prepare` | 最多 20 段、分段完整性与输出预算 | 后续长文本整理使用新合约 |
| `sentences-batch-generate` | 每批最多 5 段、响应完整性与来源信息 | 后续批量生成使用新合约 |
| `audio-generate` | 过期任务恢复、并发认领、Storage 恢复与上传重试 | 后续音频请求使用新的恢复逻辑 |

实际执行的最小命令为 `npx --yes supabase@2.117.0 --workdir <repo-root> functions deploy <function-name> --project-ref ijonabyyppmgvoufgamt --use-api`，逐一替换上表四个函数名。沿用已有模型、声线、secret、schema 和配额；未运行 `deploy-full.sh`，未生成种子音频，未携带数据库或 Web 托管发布。

四个现有远端函数已通过 CLI `functions download --use-api` 只读取回，各自保存独立的函数与共享模块副本，避免共享模块相互覆盖。回退基线位于 `output/remote-function-baseline-20260909-111153/`，含 24 个文件与 `baseline.json`；4 个函数入口均存在，24 个文件的字节数与 SHA-256 复核全部通过。该步骤没有部署函数或改动数据库。

关键风险是新处理器尚未完成普通账户真实样本验收。若 T09 发现函数级故障，可按确认范围从对应函数的独立基线目录恢复上一版本处理器，不删除业务数据。

 # 管理员用量与费用统计实施记录

 日期：2026-09-15。范围：正式 Web 端与 Supabase Edge Functions；不包含远端迁移、远端部署、secret 配置或公开发布。

 ## 已完成内容

 - 新增本地 migration `supabase/migrations/005_admin_usage_dashboard.sql`：
   - `admin_members`：管理员 allowlist。
   - `generation_business_events`：业务请求与重放结果。
   - `generation_usage_attempts`：每次实际外部供应商调用。
   - `provider_cost_snapshots`：按日保存供应商账单金额。
   - `is_admin_member`、`admin_dashboard_summary`、`admin_generation_attempts`：服务端鉴权后的受控查询。
 - 新增 `generation_usage_contract.ts`：
   - 文本按 2026-09-07 价格快照计算，输入 0.15 USD／百万 token、输出 0.60 USD／百万 token。
   - TTS 按 Unicode 字符数、15 USD／百万字符计算。
   - 转写按时长、0.003 USD／分钟估算。
   - cached token 只保存，不按未经确认的折扣计价；未知用量明确为 `unknown`，不会按 0 美元处理。
 - 五类供应商链路均已接入 attempt：`transcription`、`sentence`、`preparation`、`batch`、`tts`。
   - 幂等重放、进行中、限额拒绝不创建供应商 attempt。
   - 一批最多五句只创建一次供应商 attempt，`item_count` 保存句数。
   - Storage 上传重试不重复计算 TTS；供应商成功但交付失败会分开记录 `provider_status` 与 `delivery_status`。
 - 新增 Edge Functions：
   - `admin-summary`：管理员读取聚合与最近调用明细。
   - `admin-cost-sync`：管理员手动同步 OpenAI 组织／项目每日费用；使用服务端 `OPENAI_ADMIN_API_KEY` 与 `OPENAI_PROJECT_ID`，浏览器不接触管理密钥。
 - Web 端新增：
   - 30 秒隐私安全活动心跳，仅保存会话 ID、对齐时间槽、30 秒时长、可见性与是否正在播放音频。
   - 30 分钟无活动视为新会话；同一用户、同一时间槽在服务端去重。
   - 设置页新增「打开管理台」；普通账号收到 403 后只显示无权限。
   - 管理台显示活跃人数、学习会话、有效学习时长、业务请求、供应商调用、估算费用、供应商账单金额、未知用量与按功能分布。

## 本地验证

- Deno 全量 `supabase/tests`：293 项通过。
- `deno check supabase/functions/admin-cost-sync/index.ts supabase/functions/admin-summary/index.ts`：通过。
- `deno fmt --check supabase/functions/admin-cost-sync/index.ts supabase/tests/admin_cost_sync_test.ts`：通过。
- Flutter Web：全量 `flutter test` 220 项通过。
- 浏览器桥接、Service Worker 与 Web 资源 Node 测试：33 项通过。
- 管理台相关 Dart 文件 `dart analyze`：0 issues，并已按当前 Dart 格式化规则格式化。
- 标准 `tool/web.ps1 -Action build` 成功；产物确认编入公开 Supabase 配置，输出 `Selah Web: bundled public Supabase cloud config.`。

## 2026-09-15 上线前修复与远端预检

- 修复 `admin-cost-sync` 的费用快照写入字段：移除 `005` 表不存在的 `raw_line_item_key`，避免 OpenAI Costs API 成功后写库失败。
- 新增回归断言：费用同步 upsert payload 只包含 `005_admin_usage_dashboard.sql` 定义的列。
- 零费用远端路由预检：`admin-summary` 与 `admin-cost-sync` 当前均为 `OPTIONS 404`；五个既有收费函数 `speech-transcribe`、`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate` 均为 `OPTIONS 200`。
- OpenAI 本地 `.env` 已验证：普通模型接口 `/v1/models` 返回 `200`，组织费用接口 `/v1/organization/costs` 返回 `200`。
- 远端发布仍被 Supabase 凭据阻塞：当前 `.env` 中的 `SUPABASE_ACCESS_TOKEN` 调用 Management API 返回 `401 Unauthorized`，`SUPABASE_SERVICE_ROLE_KEY` 调用 Auth Admin API 也返回 `401 Unauthorized`；浏览器 Supabase Dashboard 同样跳转登录页。

## 2026-09-15 远端管理员 Dashboard 上线结果

- Migration：只手动应用并登记 `005_admin_usage_dashboard.sql`；四张统计表和三个 RPC 已存在，四张表均启用 RLS；`006_membership_cost_control.sql` 确认未应用，避免会员、试用和支付 schema 随统计功能误上线。
- 管理员授权：创建专用后台账号 `98f391e3-3543-4757-8cf7-8279a89e597e`（邮箱 `selah-admin-20260915124741@selah.local`），仅加入 `admin_members`；随机密码保存在本机临时文件 `C:\Users\lhjjj\AppData\Local\Temp\selah-admin-20260915124750.txt`，未进入仓库、`.env` 或聊天记录。
- Edge Secrets：已配置 `OPENAI_API_KEY`、`OPENAI_ADMIN_API_KEY`、`OPENAI_PROJECT_ID`；Supabase 平台继续提供内置 `SUPABASE_URL` 与 `SUPABASE_SERVICE_ROLE_KEY`，不手动覆盖。
- Edge Functions：已部署 `admin-summary`、`admin-cost-sync`，并重新部署 `speech-transcribe`、`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate`；未使用 prune，未部署会员支付函数。
- 网关验收：七个函数均为 `OPTIONS 200`，未登录 `POST` 均为 `401 UNAUTHORIZED_NO_AUTH_HEADER`。
- 管理员验收：专用管理员调用 `admin-summary` 返回 `200`，返回顶层 `summary`、`attempts`、`view`、`generatedAt`；空期间业务请求读数为 0 时仍返回空数组。
- 费用同步：发现并修复 OpenAI Costs 参数名，官方接口要求 `start_time`／`end_time`，不是 `start_ts`／`end_ts`；新增回归测试后重新部署。首次部署后冷启动曾出现一次 `500`，随后连续两次管理员调用均返回 `200 {"upserted":0}`；最近 7 天 OpenAI 项目费用为 0 条金额记录，因此没有快照行。
- 最新本地回归：Deno 全套 296 项通过，费用同步定向测试 5 项通过；本次修复未调用文本、转写或 TTS 生成接口。

## 尚未执行／需要授权

1. 使用普通账号执行真实收费端到端验收：转写、单句生成、长文整理、批量生成、TTS、缓存重放、MP3 下载和供应商 attempt 记录。
2. 使用第二个普通账号验证账户隔离和跨设备恢复。
3. 在真实学习链路产生数据后，重新打开管理员 Dashboard，核对功能使用、业务请求、供应商调用、估算费用和 OpenAI 实际费用。
4. `006` 会员、试用、画像、支付和服务开关仍未应用，不与本次统计上线混发。

上述真实收费验收会按既定预算触发 OpenAI 调用，仍需在准备普通测试账号和录音样本后单独执行。

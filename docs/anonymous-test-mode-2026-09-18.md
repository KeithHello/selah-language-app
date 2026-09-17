# 匿名测试模式发布说明（2026-09-18）

## 目标

匿名测试用户不需要注册即可测试云端学习闭环，但匿名身份不获得试用、免费会员或个人额度。所有匿名收费请求只受接口频率和项目每日平台预算保护；测试结束后可以由管理员立即关闭。

## 服务端行为

- 无 JWT：收费函数返回 `401 unauthorized`。
- 匿名 JWT 且 `anonymous_test_mode_enabled=false`：收费函数返回 `403 anonymous_test_ended`。
- 匿名 JWT 且开关开启：不检查会员额度，先写入 `platform_generation_reservations`，并占用 `platform_budget_ledgers` 当日预算。
- 正式用户：继续走现有会员准入与 `membership_reservations` 流程。
- 缓存命中、进行中的音频清单和种子播放不调用 OpenAI，也不需要新增收费预留。

## 管理员开关

管理台「服务与会员开关」新增「开放匿名测试」：

- 默认关闭。
- 服务控制版本：`2026-09-17-v1`。
- 只有管理员写权限可以更新。
- 关闭开关会立即阻止新的匿名收费请求，已有 Token 在过期或刷新前也无法绕过。

## 远端上线顺序

1. 应用 `supabase/migrations/007_anonymous_platform_budget.sql`。
2. 确认 `platform_settings.anonymous_test_mode_enabled=false`。
3. 为测试日期创建 `platform_budget_ledgers` 行；预算单位为纳美元。
4. 部署更新后的 Edge Functions。
5. 部署 Cloudflare Pages 最新 Web 包。
6. 在 Supabase Auth 中开启 Anonymous Sign-ins。
7. 用匿名账号执行少量真实链路测试。
8. 测试结束后先关闭管理员开关，再按需关闭 Anonymous Sign-ins。

## 回滚

- 立即停止新增匿名收费：关闭管理员「开放匿名测试」开关。
- 停止新建匿名账号：关闭 Supabase Anonymous Sign-ins。
- 前端回滚：重新部署上一版 Cloudflare Pages。
- Edge 回滚：重新部署上一版函数。
- 数据库新列和新表可保留；开关默认关闭，不影响正式用户。

## 本地验证

- Deno 全量：307 passed。
- Flutter Web 全量：242 passed。
- `dart analyze lib/web ...`：0 issues。
- Flutter Web Release 构建成功。
- `git diff --check` 通过。

## 2026-09-18 部署记录

- GitHub 分支：`codex/web-ux-reliability`。
- 初始提交：`b4d6947 feat: gate anonymous cloud testing with platform budget`。
- 热修提交：`5290405 fix: require platform budget for anonymous free mode`。
- Supabase 项目：`ijonabyyppmgvoufgamt`。
- 远端 migration：`001`—`007` 均已应用；其中本次应用了 `006_membership_cost_control.sql` 与 `007_anonymous_platform_budget.sql`。
- Edge Functions 已部署：`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`speech-transcribe`、`audio-generate`、`admin-service-controls`。
- 无凭证检查：六个函数的 `OPTIONS` 均为 200；无授权业务请求均为 401。
- Supabase Auth：`external_anonymous_users_enabled=true`；邮箱确认、SMTP 和其他外部登录保持原状。
- Cloudflare Pages：Build ID `7ac17a830f60d168` 已部署到 <https://codex-web-ux-reliability.selah-language-app-preview.pages.dev>。
- 只读页面验证：首页 200、预缓存清单 200、10 句种子、60 条音频清单、中文母语 MP3 为 `audio/mpeg`。
- UTC 当日预算：`platform:day:2026-09-17`，预算 5 USD，当前 committed 为 0.0003 USD，reserved 为 0。
- 部署验证时发现旧版本在会员限制关闭时会让匿名请求绕过平台预算；已用热修提交修复并重新部署。
- 热修后验证：匿名开关关闭时返回 `403 anonymous_test_ended` 且无预留；预算为 0 时返回 `403 service_budget_protected`，不会调用 OpenAI。
- 热修前的一次短 TTS 探测已成功，估算费用 0.0003 USD，已补记到平台预算账本；临时匿名账号已删除。

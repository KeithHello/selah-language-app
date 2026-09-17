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

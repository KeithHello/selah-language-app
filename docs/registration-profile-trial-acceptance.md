# Selah 注册画像与试用权限当前验收记录

更新时间：2026-09-13。本文记录当前分支已经完成的应用层与离线验证，不代表数据库 migration 已应用、支付渠道已接通或产品已经上线。

## 已完成

| 范围 | 当前结果 | 证据 |
|---|---|---|
| 研究资料合约 | 字段白名单、稳定枚举、Unicode 长度限制、研究告知版本、明确同意、跳过、撤回、修订冲突和未满 14 岁策略门槛已实现 | `supabase/functions/_shared/research_profile_contract.ts`、`supabase/functions/user-research-profile/index.ts` |
| 试用状态展示 | 客户端能区分 `not_started`、`preparing`、`active`、`expired`、`unavailable`；不显示剩余数量、百分比或倒计时 | `SelahFlutter/lib/web/domain/membership.dart`、`SelahFlutter/lib/web/ui/membership_widgets.dart` |
| 生成完成入口 | 单句／批量调用共同的 `complete_personal_generation` 封装；服务端明确免费模式且新 RPC 缺失时，才逐项回退到既有 `complete_generation_request` | `supabase/functions/_shared/personal_generation_completion.ts`、`supabase/functions/sentences-generate/index.ts`、`supabase/functions/sentences-batch-generate/index.ts` |
| 后台画像摘要 | 管理员只能按一个画像维度读取聚合结果，样本不足时隐藏细分指标，不返回个人问卷明细 | `supabase/functions/admin-summary/index.ts`、`SelahFlutter/lib/web/ui/admin_dashboard_page.dart` |
| 登录与费用边界 | 所有新增 AI 处理入口继续要求已验证登录；服务端先做开关、请求边界、权益和预算准入，再调用供应商 | `supabase/functions/_shared/generation_admission.ts` 及各生成函数 |

## 离线验证

- Deno 全套服务端合约测试：286 项通过，0 失败。
- 研究资料、试用状态、生成完成与后台摘要定向测试：39 项通过，0 失败。
- Flutter 全量回归：此前 194 项通过；研究资料、会员、后台及主学习页相关回归已覆盖。
- `dart analyze lib/web`：无问题。
- `flutter build web --release`：成功。
- `git diff --check`：通过；现有提示仅为工作区的 LF／CRLF 行尾提示。

## 尚不能确认

1. `006_membership_cost_control.sql` 仍是本地草稿，尚未在隔离数据库应用；当前试用准备与原子完成所需的 `007_trial_activation_closure.sql`、研究资料表与 RLS 所需的 `008_research_profiles.sql` 尚未创建。
2. 没有 Docker／可用 Supabase CLI 时，无法完成本地 SQL lint、迁移解析、事务和并发回归；源码测试不能替代这些验证。
3. 真实支付渠道的签名、查单、退款核销、账单对账、服务端密钥与日预算种子尚未配置；公开回调在缺少签名密钥时会安全返回不可用。
4. 地区、年龄与儿童路径、研究告知正文、保存期限及备份处置仍需产品政策确认；在确认前不向真实用户开放画像收集。
5. 未执行远端部署、真实账户、真实收费请求、真机浏览器或公开发布。

## 获准后的执行顺序

1. 在隔离 Supabase 数据库中先验证已有 migration，再创建并应用 `007` 试用闭环；通过 8 路并发、重复请求、批量完成、失败恢复和到期边界测试。
2. 政策确认后再创建并应用 `008` 研究资料表、RLS、撤回清除和后台聚合 RPC；用合成成年账户完成验收。
3. 配置管理员操作员、每日平台预算和正式支付适配器，在沙盒中验证付款、退款、重放和供应商调用次数。
4. 依次打开生成服务、会员限制、试用入口、会员销售开关；每一步都保留可回退的控制版本和审计记录。

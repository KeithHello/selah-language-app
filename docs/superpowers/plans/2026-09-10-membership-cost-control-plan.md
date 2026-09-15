# Selah 会员与费用保护 Implementation Plan

> 2026-09-11 状态更新：本逐项任务稿已完整并入 [会员、费用保护与 Dashboard 最终开发方案](2026-09-11-membership-dashboard-final-plan.md) 。后续按最终方案的接口、依赖、任务及验收执行并更新进度；本文保留为历史参考，不再单独追踪完成状态。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Follow the session's delegation rules; this plan does not itself authorize parallel agents.

**Goal:** 交付免费示例、7 天限额试用、39.9 元月会员及可证明不越过应用侧模型预算的服务端保护；购买前权益透明，日常不展示用量余额。

**Architecture:** 复用 Flutter Web、LearningGateway、Supabase Edge Functions 与现有管理员用量账；Postgres 原子预占权益及费用，所有供应商调用经过统一准入、一次性发送认领和保守结算。

**Tech Stack:** Flutter／Dart、Deno／TypeScript、Postgres／Supabase、现有 OpenAI 路由。支付渠道与必要的计量依赖待确认，不在本文指定未经确认的 SDK。

**设计依据：** [完整设计与 A01—A12 验收矩阵](../specs/2026-09-10-membership-cost-control-design.md) 、[独立交互展示稿](../specs/2026-09-10-membership-cost-control-ui.html) 、[交付总结与八张界面图片](../specs/2026-09-11-membership-delivery.md) 。

**2026-09-11 补充：** [Dashboard 会员运营设计与 D01—D12 验收](../specs/2026-09-11-membership-dashboard-design.md) 已并入 T08。T02／T05 共用权益来源和顺延规则，T09／T10 包含新增后台验收；所有产品任务仍未实施。

## Global Constraints

- 本轮只交付计划与展示，下面所有产品开发任务均未实施。执行前读取根与模块 `CLAUDE.md`、最新 `ROADMAP.md` 和相关现有变更；不覆盖循环听、设置、本地化或管理后台并行工作。
- 数据库 schema／migration、密钥、依赖、真实支付、上游付费样本、CI/CD、供应商配置、Cloudflare 操作及部署按项目规则分别确认。计划列出文件不等于授权执行这些操作。
- 先完成可审阅的代码和本地验证，再申请对应高风险外部操作。不得因需要部署审批而跳过可以离线完成的开发。
- 不变更当前三个模型，不加年费、额度包、自动扣款或余额面板。先保证完整权益可履约，再开售；2 元／20 元目标若不能通过证明，不以隐藏费用限制缩水权益。
- UI 文案接现有本地化计划，默认繁体，支持简体与日语。文案集中维护，不在页面中散落字符串；不擅加语言库、字体或第二套网络层。
- 每项完成后只记录实际验证到的层级；不把 mock、源码存在或局部单测写成真实支付／生产验证。下列测试路径为计划新增，命令在执行前按仓库实际工具核对。

## 交付阶段与依赖

| 阶段 | 任务 | 阶段出口 |
|---|---|---|
| 一：确认可售边界 | T01 | 每条上游路径有可信费用上界，权益和预算可同时满足；支付／资源缺项列清 |
| 二：实现服务端保护 | T02—T06 | 数据账、原子准入、所有生成入口、支付与资源控制通过本地故障／并发实验 |
| 三：接入产品界面 | T07—T08 | 会员状态与静态权益接真实接口，触顶／异常／支付反馈和管理员核查完整 |
| 四：封闭验收与发布准备 | T09—T10 | A01—A12 与 G01—G05 有证据，通过后再申请外部验证与发布 |

主链为 T01 → T02 → T03 → T04；T05、T06 基于 T02／T03；T07 基于稳定的接口，T08 基于账务；T09 汇总验证，T10 处理发布门槛。可以先制作本地 UI 状态，但不能在保护机制缺失时接真实收费调用。

## T01．固定权益、价格与单次费用证明

涉及现有文件：`supabase/functions/_shared/sentence_contract.ts`、`capture_contract.ts`、`speech_contract.ts`、`audio_contract.ts`、`generation_usage_contract.ts`。

计划新增：`supabase/functions/_shared/membership_contract.ts`、`cost_policy.ts`、`cost_policy_test.ts`。

- [ ] 定义试用／会员不可变权益版本：30／300 条、3000／30000 配音字符、300000／3600000 毫秒转写、3／30 次整理；付费 SKU 价格固定 3990 分 CNY。
- [ ] 输出每个入口的完整上游 body 与计量映射，覆盖 system prompt、schema、用户文本、音轨、编码与错误计费。不得输出私密样本或密钥。
- [ ] 证明文本 token 上界与 TTS 计费字符口径；改批量输出为 `min(n * 2048, 8192)`。STT 查明收费上界，不能用 `duration * 0.003` 估算冒充上界。
- [ ] 将费用换算实现为整数 nano USD；每次请求保存价格／汇率保护版本。过期价格、未知模型、缺少最大成本、汇率越界返回关闭该入口的明确策略结果。
- [ ] 对整个权益包的最长合法内容、录音分片、批量与一次额外重试做极端测算。通过 G01／G02 后才能启用 2 元／20 元预算；失败则形成需主人确认的权益或预算修订，不默默截断。
- [ ] 明确支付商户和渠道、平台模型日／月预算、试用池、存储／流量预算、付费容量预留、基础设施固定成本与汇率保护值。未知项保持“待确认”，配置缺失默认不开真实收费能力。

合约核心如下，类型细节可适配现有风格，含义必须保留：

```ts
type Feature = 'sentence' | 'preparation' | 'transcription' | 'tts';
type CostQuote = {
  currency: 'USD';
  maxNanoUsd: string; // 向上取整，禁止客户端提供
  priceVersion: string;
  fxGuardVersion: string;
  validUntil: string;
  evidenceVersion: string;
};
type AdmissionInput = {
  userId: string; // 取自已验证 JWT
  requestId: string;
  operation: Feature;
  payloadHash: string;
  entitlementUnits: number;
  quote: CostQuote;
};
```

验证：`deno test supabase/functions/_shared/cost_policy_test.ts`。期望所有边界均能返回可信向上取整的上界；不可信输入返回拒绝，不产生供应商调用。对应 A08、A10、G01、G02。

## T02．设计并实现可审计的会员与预算账

计划新增：`supabase/migrations/006_membership_cost_control.sql`（实施前检查编号；只有另行获批才创建／应用 schema）、`supabase/tests/membership_cost_control.sql`。

复用：`005_admin_usage_dashboard.sql` 中的 `generation_usage_attempts`、业务事件、管理员授权与汇总；现有 migration 不回写、不假设已经线上应用。

- [ ] 在获批的 migration 中增加订单／事件、权益账期、四维度额度、预算窗口、请求预占结构；attempt 引用现有用量账，补足状态字段，避免第二套重复计费明细。
- [ ] 对业务请求建立全账户生命周期幂等键与负载哈希；账期只作为原结算归属，不作为跨期重放失效条件。
- [ ] 实现受控 RPC：`reserve_generation`、`claim_generation_dispatch`、`settle_generation`、`activate_trial_with_result`、`apply_verified_payment`。参数中的用户、费用、价格与权益只能来自服务端受控路径。
- [ ] 统一锁顺序与唯一约束，原子维护用户权益、用户费用、平台日／月费用和试用池费用。强制 committed＋reserved 不超过对应上限；边界等于上限允许，超过最小单位拒绝。
- [ ] 预备试用记录唯一，失败不新发预算；首次持久化表达激活 168 小时。付费账期采用 UTC 和月末锚点；续购排期，退款事件保持历史与终态。
- [ ] 预占状态区分 `reserved`、`dispatch_claimed`、`settled`、`released_unsent`、`unknown`；未知已发送尝试不能被 TTL 清理。保留原因和结算证据。
- [ ] RLS 拒绝普通客户端直接写权益／费用／支付事件；管理员只读必要明细，普通用户只通过会员摘要接口读取状态。

验证：在获准的本地 Supabase／Postgres 环境运行 `supabase test db`，事务结束回滚测试数据。并发 50 次争最后一份额度时只有一次准入；多用户争平台尾额也不超支。对应 A01、A02、A05、A06、A11、G03。

## T03．统一供应商调用的准入、发送与结算

计划新增：`supabase/functions/_shared/generation_admission.ts`、`generation_admission_test.ts`。

计划修改：`supabase/functions/_shared/generation_usage_contract.ts`。

- [ ] 在共享入口执行鉴权、输入校验、缓存查找、报价、事务预占和一次性发送认领。拒绝分支的供应商调用计数必须为零。
- [ ] 一份供应商调用对应一条 attempt。第一次调用和最多一次额外重试分别预占费用；设置显式最大尝试数，自动结构修复也计数。
- [ ] 不自动重发未知已发送尝试；新 attempt 必须有剩余尝试资格和新费用预占。租约恢复不得让旧工作进程二次发送。
- [ ] 结果可恢复地服务端保存后再结算权益；存储重试复用供应商输出，客户端断网不触发重新生成。
- [ ] 保存实际 usage 和保守费用上界，未知不是零。结算幂等、重复事件不重复扣除；挂账必须保留到有证据的对账。
- [ ] 建立结构化错误与返回合约，不只给 message；日志不包含原文、录音、密钥或完整供应商响应。

```ts
type MembershipError = {
  code: 'trial_expired' | 'membership_required'
    | 'feature_limit_reached' | 'request_exceeds_feature_limit'
    | 'rate_limited' | 'generation_in_progress'
    | 'service_budget_protected' | 'request_conflict';
  feature?: Feature;
  resetsAt?: string; // 只有已购买的下一有效期才给自动恢复时间
  currentPeriodEndsAt?: string;
  renewalRequired?: boolean;
  retryAfterSeconds?: number;
  requestId: string;
};
```

验证：`deno test supabase/functions/_shared/generation_admission_test.ts`。故障注入涵盖预占前后、发送认领后、供应商返回后、存储后与响应前；确认不变量、可恢复结果、未知费用和最多两次供应商尝试。对应 A04—A07、A10、G03。

## T04．接入全部生成、整理、语音路径

计划修改：`supabase/functions/sentences-generate/index.ts`、`sentences-batch-generate/index.ts`、`sentences-prepare/index.ts`、`speech-transcribe/index.ts`、`audio-generate/index.ts`、`_shared/capture_contract.ts`、`_shared/speech_contract.ts`、`_shared/audio_generation_policy.ts`、`_shared/audio.ts`。

计划新增：`supabase/functions/_shared/generation_routes_test.ts`；扩充上述现有 contract 测试。

- [ ] 单句／批量／整理全部走 T03；批量一次预占计划条数，成功项逐项交付，整批 token 费用不重复按条记录。
- [ ] 真实验证音频时长与格式，忽略客户端自报成本和时长；保留 180 秒／10 MiB 单次上限。新增解析依赖前检查现有能力并按规则确认。
- [ ] 配音从用户拥有的服务端内容生成；缓存命中免费复用，新增语言／声线／重生成按完整字符记账。存储上传失败不反复调用 TTS。
- [ ] 处理旧频率限制：拆分整理与转写，去掉低于账期权益的隐藏业务日限制，保留受控并发和分钟级防刷，并返回可理解的稍候提示。
- [ ] 检查所有直接 OpenAI 调用点，逐个证明经过共享准入；未注册路径、备用路由与自动修复不得绕过。

验证：运行相关 Deno 合约与路由测试，断言被拒请求的供应商调用数为零；同一合法请求只有一个业务结算；通过 A02、A06—A08。真实收费音频样本需在另行批准的金额范围内执行。

## T05．会员摘要、订单和支付核验

计划新增：`supabase/functions/membership-status/index.ts`、`membership-checkout/index.ts`、`membership-order-status/index.ts`、`membership-payment-webhook/index.ts`、`_shared/payment_contract.ts`、`_shared/payment_contract_test.ts`。

- [ ] `membership-status` 返回方案、当前有效期、下一已购账期、静态权益版本、功能状态和真实模型来源说明；不返回 remaining／used／percent 等消费数字。
- [ ] 服务端创建 3990 分 CNY 受控 SKU 订单；一个未决订单可查询和恢复，避免每次点击创建重复收款。
- [ ] 确认渠道后接其官方协议，逐字段验证签名、商户、订单、金额、币种、账户、终态；不能把通用伪 SDK 当作完成。前端返回页不发权益。
- [ ] 支付通知与服务端查单共用幂等入账函数；重复、乱序、退款与晚到成功不造成重复发放或错误复活。
- [ ] 续购排下一账期，展示开始时间；会员即将到期不自动扣款，试用转付费不叠加剩余额度。
- [ ] 退款、补偿与暂停新增销售有独立审计；销售准入检查可履约预算容量。

摘要示例仅为接口合约，不是实际订单：

```json
{
  "plan": "monthly",
  "status": "active",
  "periodEndsAt": "2026-10-10T00:00:00Z",
  "nextPaidPeriodStartsAt": null,
  "renewalMode": "manual",
  "entitlementVersion": "monthly-v1",
  "modelDisclosure": "openai-gpt-text-v1"
}
```

验证：`deno test supabase/functions/_shared/payment_contract_test.ts`；T02 的支付 RPC 事务测试。渠道沙箱用例涵盖伪造、金额错误、重复通知、乱序退款、未决订单与月末续购；真实交易验证后方可声称支付接通。对应 A01、A09、G04。

## T06．限制存储、下载和全平台资源

计划新增：`supabase/functions/audio-download/index.ts`、`_shared/resource_budget.ts`、`resource_budget_test.ts`。

计划修改：`supabase/functions/audio-download-url/index.ts`、`_shared/audio.ts`，以及现有音频获取路径的最小必要接线。

- [ ] 盘点所有源站签名 URL 的获取与使用处。新增授权下载网关，预占对象／单 Range 字节，拒绝多 Range，不对客户端泄露可绕过网关的源站链接。
- [ ] 缓存命中保持本地复用；下载中断、重复 Range、并发获取和旧链接有效窗口计入流量预算。网关自己的函数／出站成本纳入测算。
- [ ] 新音频上传前预占存储字节，验证最长合法 MP3 后确定拟定 5 MiB 单文件上限；未知上传结果先挂账，后续对账不重复上传。
- [ ] 配置模型日／月预算、试用池、存储、下载和可控制请求量；配置缺失关闭新付费操作。预留已售权益容量，余量不足停止新试用／销售。
- [ ] 编写供应商 Spend Cap 覆盖与非覆盖清单，包含固定计算、附加项、税费、支付费等。应用请求限制不能拦住供应商计费的所有外部流量，不声称绝对总账单保证。
- [ ] 将任何控制台／Cloudflare 调整作为独立待批准步骤；先提交具体配置、影响和验证方式，本文不直接执行。

验证：`deno test supabase/functions/_shared/resource_budget_test.ts`；私有对象、失效鉴权、跨用户、重复／多 Range、未知中断、预算尾额均不绕过；本机已有音频无需生成额度。对应 A10、G05。

## T07．Flutter 会员 UI 与真实状态接线

计划新增：`SelahFlutter/lib/web/domain/membership.dart`、`membership_controller.dart`、`ui/membership_widgets.dart`、`ui/membership_copy.dart`。

计划修改：`SelahFlutter/lib/web/ui/web_learning_app.dart`、`learning_controller.dart`、`data/learning_gateway.dart`、`data/supabase_learning_gateway.dart`、`domain/web_status.dart`；不另建通用网络层。

计划新增测试：`SelahFlutter/test/membership_controller_test.dart`、`membership_widgets_test.dart`。

- [ ] 与设置／界面语言计划合并接口：建立集中繁／简／日文案，沿用现有颜色、组件和一个精灵视觉焦点。保持语言偏好与学习内容元数据分离。
- [ ] 方案页列四项静态权益、7 天起算、39.9 元和主动续购说明；账户仅显示身份、期限、续购和方案说明，无剩余／已用数字。
- [ ] 生成入口和方案页加入与服务端路由一致的 GPT 提示；音频区域单列「语音由 AI 合成」。模型来源不由页面硬写并永久假定。
- [ ] 扩展 `LearningFailure` 以承载 feature、恢复条件、retryAfter 和 requestId；按结构化错误显示到期、真正用完、本次请求超额、操作频繁、系统保护等不同状态。
- [ ] 点击生成后防连点，结果和支付都能按原请求／订单恢复；支付 pending 只允许查单，确定失败后再创建新订单。
- [ ] 草稿与已有内容不因会员到期／保护而消失；账号切换清除身份状态，重新查询服务端；离线只保存草稿与学习缓存，不在本机增加会员权益。
- [ ] 实现键盘焦点、读屏反馈、44 像素操作区域、Reduce Motion；检查 320／390／768／1440 像素和 200％ 文字放大，无横向溢出或被底导航遮挡。

验证：在 `SelahFlutter` 执行 `flutter test test/membership_controller_test.dart test/membership_widgets_test.dart` 与项目要求的 `flutter analyze`。测试业务状态与服务端错误映射，避免只测试常量重复实现。A03、A04、A09、A12 必须通过，浏览器验证再记录具体平台。

## T08．管理员会员运营、费用核查与人工处置

依赖：T02／T03 的订单、权益与原子预算账，T05 的支付核验和账期逻辑，T06 的平台准入与容量控制；可以先制作离线 UI，但写操作不能先于服务端保护接真实账户。

计划修改：`supabase/functions/admin-summary/index.ts`、`SelahFlutter/lib/web/domain/admin_dashboard.dart`、`SelahFlutter/lib/web/admin/admin_controller.dart`、`SelahFlutter/lib/web/ui/admin_dashboard_page.dart`、`SelahFlutter/lib/web/ui/web_learning_app.dart`、`SelahFlutter/lib/web/l10n/selah_strings.dart`。

计划新增：`supabase/functions/admin-users/index.ts`、`supabase/functions/admin-membership-actions/index.ts`、`supabase/functions/_shared/admin_membership_contract.ts`、`SelahFlutter/lib/web/domain/admin_membership.dart`、`SelahFlutter/lib/web/ui/admin_user_detail.dart`。权益来源、赠送承诺、权限和操作日志的增量 SQL 并入 T02 获批的新 migration，不改写 005，也不另建重复会员账。

计划新增测试：`supabase/tests/admin_membership_actions_test.ts`、`supabase/tests/admin_membership_transactions_test.ts`、`SelahFlutter/test/admin_membership_controller_test.dart`、`SelahFlutter/test/admin_membership_widgets_test.dart`；保留现有后台测试。

### T08a．用户查询与权限

- [ ] 基于补充设计 D01／D11，先定义普通用户、只读管理员和可管理后台账户的访问用例；服务端验证已验签身份与写权限，付费会员不能获得后台身份，未配置写权限时默认只读。
- [ ] 在现有 Dashboard 增加总览、用户与会员、订单与补发、用量与成本、异常与服务控制、操作日志六个区域；用户搜索支持用户 ID／邮箱，返回脱敏摘要，详情通过唯一 ID 查询。
- [ ] 查询按身份、来源、到期、用户、功能、状态及账期使用适用筛选，页大小不超过 100，采用服务端游标；不能一次下载全站用户，也不能把接口已有参数当 UI 已完成。

### T08b．开通、补发与整月赠送

- [ ] 与 T02／T05 合并权益来源、时间线与交易唯一约束：付费、赠送、补偿分别标记，所有有效月会员购买顺延，试用转立即生效的月会员不重赠试用。
- [ ] 实现受控动作「补发已购会员」「登记已核实收款」「赠送会员」「客服补偿」「撤销误赠」「暂停／恢复新增生成」，不接受客户端直接写会员布尔值、任意有效期或无限额度。
- [ ] 赠送支持 1／3／6 个月快捷项和 1—12 整月输入；按月生成权益期间，已有权益默认顺延，当前用量不变。预览返回用户、起止日期、权益版本、费用与容量影响；提交重新检查版本和权限。
- [ ] 一次预留所有赠送月份的未来预算承诺及赠送池容量；每期权益与每次模型调用仍经过原子保护。承诺与实际费用不重复相加，池缺失或不足时整个事务拒绝。
- [ ] 补发只能恢复已核验订单的缺失权益，不改成从补发当天重新赠送；人工收款保存经批准渠道、唯一交易编号、原价金额、月数、时间、凭证引用和原因，来源标为人工核实。
- [ ] 将管理员提交与支付回调置于同一幂等及账户时间线规则下；相同操作 ID 返回原结果，负载变化拒绝；后到支付回调可补充核验来源但不重复记收入或发会员。历史期间冲突进入核对，不覆盖期间。

### T08c．撤销、暂停与审计

- [ ] 撤销只针对选定赠送未使用部分，保留实际费用、在途请求与历史；其他已确认期间不被悄悄移动。暂停／恢复新增生成不改变账期、已用额度、费用预算或已有内容。
- [ ] 每次写操作在同一事务中追加操作者、目标用户、前后状态、原因、关联记录、预算变化、时间与请求 ID；失败不留下部分权益，审计写入失败则整个变更失败。
- [ ] 提交前展示实际影响；撤销、暂停和预算调整二次确认，权限被撤销或页面预览过期时重新核对。预算版本不能低于已结算、在途及已承诺责任，不能绕过 G01—G05。

### T08d．费用与经营核查

- [ ] 复用现有 providerAttempts、knownEstimatedCostUsd、providerRecordedCostUsd、unknownUsageAttempts 字段，增加预算、在途预占、守护拒绝原因和账期筛选。
- [ ] 区分业务请求、供应商 attempt、已交付权益、真实费用、估算与未知；各合计不能重复相加。
- [ ] 形成挂账对账流程，未知不默认为零；人工补偿／修正必须有证据、原因和审计，不直接修改历史记录。
- [ ] 平台接近预算仅通知管理员；停止准入在服务端原子判断完成，不能依赖邮件或通知是否送达。
- [ ] 区分付费／赠送／补偿会员、渠道核验／人工核实收款、退款与未来赠送承诺，赠送不计入收入或付费转化；按事件口径分析试用平均成本、转化、成本分布及限额反馈，均值不能替代最高费用验收。
- [ ] 将现有滚动一天筛选准确标为「过去 24 小时」；显示数据更新时间、时区、零费用／无账单／估算的区别；未接入账单采集时不宣称自动对账。

### T08e．界面与验收

- [ ] 用户详情采用权益时间线、订单与会员操作面板，管理员专用区可查看详细用量和费用；用户端只同步来源、状态及有效期，不泄露内部预算和余额。
- [ ] 集中补齐繁体／简体／日语及控制器错误文案，复用现有 `nativeLanguage` 派生界面语言；验证窄屏、键盘、提交中禁重复、失败保留表单和准确成功反馈。
- [ ] 使用现有 Flutter／浏览器能力提供同源 `/#/admin` 及受控子路径，支持登录后返回、刷新、后退与会话失效；路由不替代服务端鉴权，不增加独立站点或新路由依赖。
- [ ] 按 D01—D12 执行权限、赠送／补发竞争、月底分期、预算尾额、撤销在途、审计和界面验证；真实事务测试使用隔离数据库，环境未获准或不可用时明确记为未执行。

验证：在仓库根目录执行 `deno test --allow-env --allow-read supabase/tests/admin_summary_test.ts supabase/tests/admin_membership_actions_test.ts`；在经批准的隔离数据库连接配置下另运行事务测试，不用进程内锁代替并发证据。在 `SelahFlutter` 执行 `flutter test --no-pub test/web_admin_models_test.dart test/admin_membership_controller_test.dart test/admin_membership_widgets_test.dart`，并按项目要求分析和构建。接口名称、测试路径与命令在实施时再次核对实际依赖；本轮未新增或执行这些产品测试。覆盖 A11 与 D01—D12。

## T09．端到端边界与故障验收

计划新增：`supabase/tests/membership_scenarios.md`，记录可重复步骤、预期、实际证据与环境；只使用脱敏标识。

- [ ] 执行设计 A01—A12 及 Dashboard D01—D12，逐项填写真实证据；未执行留待验证，不以本地模拟冒充真实供应商或支付验证。
- [ ] 并发 50 请求争一份额度；多账户争平台尾额；正好等于预算和超最小计费单位；检查 ledger 与真实 dispatch 一致。
- [ ] 覆盖所有崩溃窗口、格式失败、未知计费、存储失败、过期租约、重复 webhook、退款乱序与跨账期重放。
- [ ] 验证所有合法权益用满与所有允许重试，仍符合 G01／G02；录音分片、长中／日文、母语＋英语双轨必须纳入。
- [ ] UI 检查正常学习无消费数字、每类限制文案、未续购不承诺自动恢复、系统保护不说用户用完、支付等待不重复扣款。
- [ ] 检查下载网关、旧签名链接窗口、固定费用和供应商覆盖边界；未控制成本单列，不能混入模型预算保证。

验证命令采用 T01—T08 的相关测试集；仅在新失败或修改后重复必要检查。并发与故障测试需真实数据库事务环境，不能用进程内 mock 锁代替。

## T10．封闭启用、运营验收与发布申请

- [ ] G01—G05 及后台 D01—D12 全部通过后，整理变更文件、migration、环境配置、渠道设置、试用／会员／赠送准入预算、回退停用开关与验证证据。
- [ ] 获批后先在隔离环境启用小范围账户与有限预算，验证真实用量记录、账单对账、支付查单、退款与恢复；收费样本有明确金额授权。
- [ ] 发现报价与真实计费偏差即关闭相关新增调用，保留学习与草稿；校正费用与权益可履约性后再申请恢复。不能清零未知费用换取继续运行。
- [ ] 发布前再次核对官方价格、汇率保护和资源计划；明确哪些费用被硬限制，哪些只是预算与监控。
- [ ] 更新 `ROADMAP.md` 的真实开发、测试、接线和环境验证状态；准备公开发布申请。本任务文档不预先授权生产部署、真实收款或 Cloudflare 变更。

## 计划覆盖自检

| 设计机制 | 任务 |
|---|---|
| M01 试用与账期 | T01、T02、T05、T07 |
| M02 权益展示 | T01、T07、T09 |
| M03 GPT 说明 | T01、T04、T07 |
| M04 服务端准入 | T02—T04、T06 |
| M05 并发与幂等 | T02—T05、T09 |
| M06 失败／重试／对账 | T03、T04、T08、T09 |
| M07 批量与输入边界 | T01、T04、T09 |
| M08 支付 | T02、T05、T07、T09 |
| M09 平台与资源 | T01、T06、T09、T10 |
| M10 会员运营与费用核查 | T02、T05、T08—T10；补充 D01—D12 |

本轮交付的是上述可执行计划及独立 UI 展示。所有产品任务保持未勾选；实施授权、数据库变更、外部配置、真实收费验证和发布按各自边界推进。

# Selah 注册画像与试用权限 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task after explicit implementation authorization. Follow the session's delegation rules. 本计划不授权立即实施、创建 migration、操作真实账户或启用并行代理。

**Goal:** 修复新账户首次试用的准入与激活，保持简短注册，加入可跳过、可撤回的基础画像，并在现有后台提供可靠的使用／付费群体统计。

**Architecture:** 复用现有 Flutter Web、LearningGateway、Supabase 鉴权、生成请求账、会员预占及管理台。试用预备状态与成功结果在数据库事务中闭合；研究资料采用独立账户扩展表与受控接口，和学习同步、权益判定分离。

**Tech Stack:** Flutter／Dart、Deno／TypeScript、Postgres／Supabase、现有 Node 与数据库测试工具；不增加应用或全局依赖。

**状态：** 2026-09-13，应用层与离线合约测试已完成：研究资料合约、`user-research-profile` 接口、试用状态展示、单句／批量共同完成入口、后台画像聚合入口及对应 Flutter／Deno 测试已经加入。R01—R04 的数据库闭环、R05—R08 的资料表／RLS／聚合 RPC 与真实政策仍待授权和隔离环境验收；R09—R10 尚未完成。本轮没有创建或应用数据库 migration，也没有连接真实支付、真实账户或公开部署。

**文档关系：** [会员与 Dashboard 总计划](2026-09-11-membership-dashboard-final-plan.md) 继续作为总入口。本计划分为可以分别验收的 A「试用与权限」和 B「研究资料与统计」两条工作流，具体行为以 [补充设计](../specs/2026-09-12-registration-profile-trial-design.md) 为依据；当前实现证据见[验收记录](../registration-profile-trial-acceptance.md)；原 T01—T10、A01—A12、D01—D12、G01—G05 继续有效。

## Global Constraints

- 当前开发授权覆盖应用层与离线测试；数据库 migration 创建／修改／应用、真实账户与收费样本、密钥、CI/CD、远端配置和公开发布仍按原规则逐项确认。
- 保留现有邮箱／密码注册、模型、声线、39.9 元月费及额度；界面沿用现有三语、组件和布局。原生 Swift／Flutter 旧客户端、动画、笔记和循环听不做无关改造。
- 试用首次新个人结果在服务器成功持久化后连续 168 小时。注册、登录、画像、只转写／整理、失败、缓存重放不能起算或重置。
- 预备期与激活后的试用共用同一身份、权益与费用预算；单句／批量共用表达上限，不能直接绕过准入以修复首次生成。
- 用户端不显示剩余额度、用量百分比或倒计数。后台可以显示必要经营统计，但画像字段不能决定会员、管理员或模型路由。
- 画像开发可用成年合成样本；地区、年龄政策、用途正文、保存期限及备份删除方案未确认前，不向真实用户开放收集。
- 所有拒绝场景检查「供应商调用为零」；源码字符串测试不等于数据库事务、并发、RLS 或真实平台验收。
- 匹配现有文件职责，不抽象新的通用网络层，不引入第三方统计 SDK，不为本轮创建独立后台。

## 1．执行顺序与退出条件

| 工作流 | 任务 | 前置 | 完成时可以确认的结果 |
|---|---|---|---|
| 基线 | R00 | 明确后续开发授权 | 知道当前部署、migration、产品政策及本次允许操作范围 |
| A：试用与权限 | R01 → R02 → R03 → R04 | R00；数据库任务另获准 | 新账户能受控完成首条／首批生成，正确开始试用，前端诚实反映状态 |
| B：画像与问卷 | R05 → R06 | R00；可与 A 独立开发，按实际协作规则执行 | 用户能自愿保存、跳过、修改和撤回画像，学习不受影响 |
| B：研究统计 | R07 | R05、真实支付／学习数据合约 | 管理员能区分使用群体、真实付款、赠送与退款 |
| 政策与发布准备 | R08 | R00、R05—R07 的实际数据路径 | 告知、保存和撤回规则与真实实现一致 |
| 联合验收 | R09 | R01—R08 | 自动化、数据库并发与普通账户证据齐全 |
| 分步启用 | R10 | R09、原 G01—G05、G-R01—G-R05 | 获准环境中的实际部署与功能启用分别可证明 |

若数据库或政策尚未获准，继续完成已获授权的模型、界面与合成测试，并明确平台尚未接通；不得在生产环境伪造成功响应。优先完成 A，不因画像问题延误试用缺陷修复。

## 2．文件职责与拟新增文件

以下路径相对仓库根目录；「拟新增」只是后续文件清单，本轮没有创建这些代码文件。migration 编号执行前重新检查，发生占用时选择下一个未用编号并先更新本计划。

| 范围 | 主要文件 | 修改责任 |
|---|---|---|
| 试用数据库 | 拟新增 `supabase/migrations/007_trial_activation_closure.sql` | 在 006 之后增量增加预备状态、唯一约束、原子完成及修订后的准入／摘要 RPC；不改已应用历史迁移 |
| 生成共享层 | `supabase/functions/_shared/generation_admission.ts`、`membership_contract.ts`、`service_controls.ts` | 统一状态、预占、错误与可信控制行为 |
| 文本完成 | `supabase/functions/sentences-generate/index.ts`、`sentences-batch-generate/index.ts` | 接入共同事务，正确处理重放与首次结果 |
| 其他收费入口 | `supabase/functions/sentences-prepare/index.ts`、`speech-transcribe/index.ts`、`audio-generate/index.ts` | 预备期计量与统一准入，复用既有缓存／归属校验 |
| 会员前端 | `SelahFlutter/lib/web/domain/membership.dart`、`membership_controller.dart`、`ui/membership_widgets.dart` | 明确未起算、准备、有效、到期与读取失败 |
| 登录与生成入口 | `SelahFlutter/lib/web/learning_controller.dart`、`data/supabase_learning_gateway.dart`、`ui/web_learning_app.dart` | 保留草稿、明确登录反馈、刷新会员状态，不自动发送收费请求 |
| 研究数据库 | 拟新增 `supabase/migrations/008_research_profiles.sql` | 独立画像表、同意／邀请状态、RLS、受控读写与聚合 RPC |
| 研究接口 | 拟新增 `supabase/functions/_shared/research_profile_contract.ts`、`supabase/functions/user-research-profile/index.ts` | 只处理当前用户，校验资料和操作；不进入学习快照 |
| 研究前端 | 拟新增 `SelahFlutter/lib/web/domain/research_profile.dart`、`research_profile_controller.dart`、`ui/research_profile_widgets.dart` | 问卷、设置编辑、跳过、撤回与账户切换 |
| 管理统计 | `supabase/functions/admin-summary/index.ts`、`SelahFlutter/lib/web/domain/admin_dashboard.dart`、`admin/admin_controller.dart`、`ui/admin_dashboard_page.dart` | 新增聚合视图，复用现有管理员校验 |
| 本地化 | `SelahFlutter/lib/web/l10n/selah_strings.dart`、`selah_zh_hant.dart`、`selah_zh_hans.dart`、`selah_ja.dart` | 三语状态、字段、错误、用途说明与可访问名称 |
| 函数配置 | `supabase/config.toml` | 仅在对应授权下为新函数增加 `verify_jwt = true`，不削弱已有鉴权 |
| 验收与告知 | 拟新增 `docs/registration-profile-trial-acceptance.md`、`docs/registration-profile-privacy-notice.md` | 实际证据、数据路径及获确认的告知正文 |

## R00．冻结当前基线与启用条件

**文件：** 根与模块 `CLAUDE.md`、`ROADMAP.md`、本计划、`supabase/config.toml`、现有 migrations；记录写入后续验收文档。

- [ ] 读取当前未提交变更与部署记录，确认 006 的真实应用状态、007／008 编号可用性、浏览器实际构建版本及 Supabase 项目。
- [ ] 只读核对邮箱注册／确认策略、各生成函数与 `membership-status` 路由；记录方法、状态码、环境与时间，不输出凭据，不创建账户或发送付费样本。
- [ ] 将地区／年龄政策、画像用途与保留期限、数据库操作授权、测试账户与费用预算列入明确启用条件；不以本轮规划授权代替代码或部署授权。
- [ ] 建立测试账户角色清单：访客、新账户、预备试用、有效试用、到期试用、有效付费、赠送、退款、普通后台访问者、管理员；先使用合成 fixture。

**验收：** 基线能区分「已有代码」「本地数据库」「远端部署」「实际启用」。本计划不把前轮 404／401 当作开发当天的永久状态。

## R01．试用预备记录与原子准入

**文件：** 拟新增 007 migration；修改 `generation_admission.ts`、`membership_contract.ts`；拟新增 `supabase/tests/database/trial_access.test.sql`、`supabase/tests/database/trial_access_concurrency.ps1`；补现有 `supabase/tests/generation_admission.node.test.mjs`。

**接口：** 继续使用 `reserve_generation_allowance`；可信服务端提供用户、请求、功能、数量、费用上界和 payload hash。客户端不能选择试用状态或时间。

- [ ] 先复现：会员模式和试用开放时，无权益的新用户首条请求被当前逻辑返回 `membership_required`；记录当前表现，测试不得调用真实供应商。
- [ ] 在获准的隔离数据库新增唯一试用记录与 `preparing` 状态；只允许准备状态的起止时间为空，激活和月会员期间仍要求合法日期。
- [ ] 将准入改为「有效权益优先 → 已有准备试用 → 符合资格的新试用」；建立试用与权益／费用预占在同一事务完成。
- [ ] 准备期的转写、整理和失败费用归同一试用；单句与批量共享表达数量。预占失败不得留下可使用的无预算试用。
- [ ] 加入 8 路并发的新用户、不同请求和相同请求场景；验证只创建一个试用、原额度不可超售、相同请求不重复预占、payload 冲突拒绝。

**验收：** 新账户能够获得受预算保护的首次准入；准备阶段不产生开始时间；失败、设备切换与重新登录不重赠预算。数据库测试真实执行约束和 RPC，不只搜索 SQL 字符串。

## R02．单句／批量结果与试用激活同一事务

**文件：** 007 migration、单句／批量函数；拟新增 `supabase/tests/personal_generation_completion_test.ts`，扩充 R01 数据库测试与现有 `supabase/tests/sentences_generate_test.ts`。

**接口：** 内部 RPC `complete_personal_generation` 接收父请求 ID、原预占 ID、已校验的新结果项；结果项包含对应的已认领请求 ID 与响应 payload。单句一项，批量多项；返回可重放结果及真实试用日期。

- [ ] 先写故障场景：结果账已成功但激活 RPC 失败、首次批量没有激活、成功响应丢失后再次请求。
- [ ] 用共同 RPC 原子写入 `generation_requests.response_payload` 成功结果、成功表达计量及 `preparing → active`；只使用数据库当前时间。
- [ ] 替换单句的分离完成／激活调用和批量逐项完成调用；批量已有重放项不再收费计数，新增结果整批事务提交。
- [ ] 验证客户端收不到响应仍能重放原结果和原日期；不以客户端同步成功为起算条件；不为恢复原结果重新创建试用。
- [ ] 注入事务提交前后异常，以及首次单句／批量、购买、赠送并发；验证原预占归属稳定、失败不半激活、成功不重复计量。

**验收：** 任何成功交付的新试用个人结果均有同一事务确定的起算时间；单句和批量行为一致。英文成功而配音失败时保留原起算时间与英文结果。

## R03．覆盖全部入口与服务失效状态

**文件：** 三个其他收费函数、共享准入／服务控制、`supabase/functions/membership-status/index.ts`；拟新增 `supabase/tests/trial_access_test.ts`，补现有服务控制与转写测试。

- [ ] 为转写、长文整理和新增配音分别验证访客拒绝、准备期计量、有效期边界、功能触顶和平台预算不足；供应商用计数替身。
- [ ] 状态 GET 保持只读，返回 `trialState`；注册／登录／反复刷新会员中心均不能建预备记录或开始计时。
- [ ] 明确关闭新试用不撤销已接受的准备／有效试用；关闭新增生成阻止新的供应商发送，在途仍能保存和结算。
- [ ] 区分明确的服务端免费模式和配置读取失败。会员模式已启用的生产环境发生 RPC 缺失或错误时，不得自动退为免检查生成。
- [ ] 在数据库时间等于到期点时拒绝新请求；到期前已预占的结果可在到期后完成。缓存命中、取回已有结果及合法下载仍按归属和资源规则处理。

**验收：** 所有入口执行同一权限与费用原则；没有仅因界面按钮隐藏才成立的限制；断网、401、404、503 不被显示为免费或试用成功。

## R04．注册、草稿与会员状态界面

**文件：** 登录／生成入口与会员前端文件、本地化表；补 `SelahFlutter/test/web_gateway_test.dart`、`web_reliability_controller_test.dart`、`membership_controller_test.dart`、`membership_widgets_test.dart`。

- [ ] 保留邮箱与密码字段；补齐注册成功待邮箱确认、确认失败、已有账户、登录失效的清晰反馈，文案与 R00 查到的策略一致。
- [ ] 从生成入口触发登录后保留草稿和页面；登录成功不自动调用收费功能，用户继续明确点击生成。
- [ ] 展示未起算说明、正在准备、真实到期日期、试用结束和状态服务不可用；完成个人生成后重新读取摘要。
- [ ] 切换账户或退出时立即清除上一账户的会员摘要与在途 UI 响应；晚到响应不能污染新账户。
- [ ] 保持无用量余额界面；到期／额度触顶提供已有内容入口；三语、窄屏、大字、键盘和错误提示均覆盖。

**验收：** 用户能够明确区分注册、登录、试用开始与试用结束；没有虚假倒计时或自动收费请求；免费示例正常可用。

## R05．研究资料合约、存储与同意

**文件：** 拟新增 008 migration、`research_profile_contract.ts`、`user-research-profile/index.ts`；配置条目仅在获准范围内修改；拟新增 `supabase/tests/research_profile_test.ts`、`supabase/tests/database/research_profiles.test.sql`。

**接口：** `get_user_research_profile` 只读；`update_user_research_profile` 支持 `offer/save/skip/withdraw`。Edge GET／POST 通过当前已验证用户调用内部 RPC，复用现有 `LearningGateway.invoke`。

- [ ] 按设计建立稳定枚举、空值／不愿透露区别、最多 40 个 Unicode 字符的自定义性别描述、字段白名单与修订号；非法输入不能部分保存。
- [ ] 新增独立 `user_research_profiles` 表，保存答案、邀请状态、研究同意状态、告知版本、服务端时间与修订号。不得扩展学习备份或把资料塞入 `user_metadata` 作授权。
- [ ] 启用 RLS，撤销 PUBLIC／anon／authenticated 的直接写和内部 RPC 执行；服务端校验所有者。管理员研究视图只得到聚合结果。
- [ ] `offer` 原子领取一次邀请；`save` 需当前告知版本和明确同意；`skip` 不要求同意；`withdraw` 原子清空答案并停止后续关联，保留最小必要撤回状态。
- [ ] 验证跨用户、伪造用户 ID／时间／会员字段、缺失同意、旧版本告知、修订冲突、枚举非法、40／41 字符、空答案和重复撤回。
- [ ] 画像政策或数据库能力不可用时返回 `profile_unavailable`；年龄处理需要额外政策时返回 `profile_age_policy_required`，不自动放行儿童资料收集。

**验收：** 保存与同意一致，撤回后查不到研究答案；不能修改权益；现有学习偏好同步无变化。画像异常不影响认证、试用和播放。

## R06．问卷邀请与设置编辑

**文件：** 拟新增三个研究前端文件，局部接入 `learning_controller.dart`、`ui/web_learning_app.dart` 和三语文案；拟新增 `SelahFlutter/test/research_profile_controller_test.dart`、`research_profile_widgets_test.dart`。

- [ ] 控制器只复用 gateway 与现有账户变化订阅。读取研究资料不改登录／会员状态；资料只在当前账户内存保存，不进入 `LearningSnapshot` 或游客缓存。
- [ ] 当前账户首次完成聆听或练习并结束播放／保存后，申请一次轻量邀请；注册刚成功、录音中、播放中、离线、接口不可用时均不弹表单。
- [ ] 首轮最多学习目标、英语自评、年龄段三题，无默认答案；逐题可空，整页可跳过。身份与性别在设置中后续选填。
- [ ] 保存前展示用途说明和未预勾的同意控件。设置提供编辑及撤回入口，撤回前说明只处理研究资料；成功只在服务器确认后显示。
- [ ] 测试跳过、关闭、保存失败、告知版本变化、40／41 字符、多设备邀请竞争、退出账户、晚到响应、旧用户首次访问和主动重新参加。
- [ ] 检查三语、320px 窄屏、大字体、键盘顺序与读屏名称；表单不打断用户正在进行的学习任务。

**验收：** 不填、不愿透露、撤回均不改变试用；邀请不会每次登录弹出；账户切换无研究资料残留；未保存状态清晰。

## R07．后台使用与付费画像聚合

**文件：** 008 migration、`admin-summary/index.ts`、现有后台模型／控制器／页面；拟新增 `supabase/tests/admin_audience_test.ts`、`SelahFlutter/test/admin_audience_test.dart`，扩充研究数据库测试。

**接口：** `admin-summary` 的 `view=audience` 接受 UTC 注册区间及单一维度，调用 `get_admin_audience_summary`。维度仅允许 `learningGoal/englishLevel/ageGroup/lifeStage/gender`。

- [ ] 建立可人工核算的合成数据：不同注册时间、当前画像、未填写／拒答／撤回、有效学习、真实付费、赠送、补偿、退款和未决订单。
- [ ] 按设计实现注册人数、画像覆盖率、近 7 天活跃、第 7 天留存、30 天首购转化、赠送／补偿及退款单列；每项返回自己的实际分母和观察状态。
- [ ] 付款以服务端核实订单事实计数，不能使用客户端 `isPaidActive` 或把 `source=grant/compensation` 算收入；来源未知时明确未知。
- [ ] 使用当前有效同意资料关联注册同期组；修改和撤回影响后续结果。只显示单维聚合，小于 5 人的组显示样本不足；不增加个人画像和原始导出。
- [ ] 验证普通用户 403、撤回排除、非完整观察期、同一用户多笔付款去重、退款保留首购事实、跨 UTC 日期边界及过滤条件非法。

**验收：** 合成数据的人数和比率与人工结果一致；不把未观察完的群体算低转化，不把赠送算付款，不对未填者推测资料。

## R08．用途告知、保存期限与撤回执行

**文件：** 拟新增 `docs/registration-profile-privacy-notice.md`、实际界面文案与研究接口相关文件；沿用 R05／R06 测试。

- [ ] 按实际数据路径列明处理者、用途、字段、与学习／付款关联方式、访问权限、保存期限、权利入口及受托服务；不宣称不可识别的匿名数据。
- [ ] 在启用前取得目标地区、最低年龄／儿童路径及保存期限的明确产品决定，写入规范和告知版本。没有决定时继续关闭真实画像收集，开发测试使用合成资料。
- [ ] 明确执行数据到期、撤回、注销后的清除步骤，以及备份保留／恢复后重新执行删除的责任和可验证方式；不凭空承诺 Supabase 的备份保留天数。
- [ ] 验证清除后前端、接口、聚合查询和可恢复副本不会恢复有效研究资料；学习内容和必要订单记录按各自用途保留。

**验收：** 文案、实际权限及清除能力一致；G-R01／G-R02 有明确结论和负责人。没有完成的外部政策或备份处置不能写为已上线。

## R09．联合自动化与普通账户验收

**文件：** 上述测试、拟新增 `docs/registration-profile-trial-acceptance.md`；不顺带修改 CI。

- [ ] 运行下面的定向测试及现有回归，先修复新失败，再执行全量检查。
- [ ] 在获准的隔离数据库真实执行 RLS／事务／并发用例；测试运行器验证目标实例身份与获准范围，禁止默认连接生产库或清理已有数据。
- [ ] 在获准测试环境用普通账户核对访客示例、邮箱确认、登录、首条／首批生成、试用起算、原结果恢复、问卷与后台聚合。
- [ ] 到期与配额边界使用受控数据库 fixture 和注入时钟，不在客户端伪造当前时间；真实付费调用和账户创建分别沿用明确授权。
- [ ] 记录接口状态、数据库账、实际供应商请求次数、构建版本、设备、未验证项；Chrome 手机视口不等于真实手机验收。

**未来开发时的命令：** 以下只列执行方式，本轮没有运行。

在仓库根目录运行：

```powershell
node --test supabase/tests/generation_admission.node.test.mjs
deno test --allow-env --allow-read supabase/tests/trial_access_test.ts supabase/tests/personal_generation_completion_test.ts supabase/tests/research_profile_test.ts supabase/tests/admin_audience_test.ts
deno test --allow-env --allow-read supabase/tests
```

在 `SelahFlutter` 目录运行：

```powershell
flutter test --no-pub test/membership_controller_test.dart test/membership_widgets_test.dart test/research_profile_controller_test.dart test/research_profile_widgets_test.dart test/admin_audience_test.dart
flutter test --no-pub
flutter analyze --no-pub
```

数据库脚本只在已批准的隔离实例上运行 `trial_access.test.sql`、`research_profiles.test.sql` 与并发 PowerShell 测试；不在计划中嵌入数据库凭据。缺少现有工具时先核对本地可用版本，不安装全局依赖。

构建使用项目标准 `SelahFlutter/tool/web.ps1 -Action build`，核对 build ID 和浏览器缓存更新。验收期望是全部所涉行为用例通过、静态分析没有新问题、构建成功、真实环境证据与代码版本对应；历史测试数量不作为固定通过门槛。

## R10．按依赖逐项启用

**文件：** 验收文档、`ROADMAP.md` 与本计划；对应外部操作另获准。

- [ ] 先展示拟应用 migration、函数清单、数据影响、预算与恢复方案，待对应操作获准后执行；不得连续替用户确认多个外部步骤。
- [ ] 在封闭环境按数据库 → 函数 → 普通账户验收 → Web 构建的顺序推进，验证 `membership-status` 不再是 404 且摘要来自真实账。
- [ ] 原费用 G01—G05 和本设计 G-R01—G-R05 满足后，再分别申请启用新试用、会员限制／销售、研究资料收集；一个开关成功不代表全部完成。
- [ ] 控制异常时暂停新的生成／试用／画像收集，保留在途结算和历史学习；禁止通过删除权益记录、清零用量或退回免检查模式恢复服务。
- [ ] 发布后记录实际授权范围与证据；数据库、代码、平台、公开发布使用各自状态，不把本计划任务批量勾完。

**验收：** 用户真实注册后能够完成首次受控生成，试用时间正确；资料可跳过与撤回；后台数据可核算；开关与部署均有独立证据。

## 3．必须覆盖的验收矩阵

| 编号 | 输入／边界 | 期望 | 任务 |
|---|---|---|---|
| RA01 | 访客进入示例并播放内置音频 | 可学习，无新增上游调用 | R03、R04 |
| RA02 | 访客直接请求任一新增处理 | 401，供应商请求 0 次 | R03 |
| RA03 | 注册、登录、刷新状态、填问卷 | 不创建试用计时 | R03—R06 |
| RA04 | 新账户首条请求，新试用开放且预算足够 | 创建唯一准备试用，正常准入 | R01 |
| RA05 | 只转写／整理后反复重试 | 日期为空，额度与费用累计，不重赠 | R01、R03 |
| RA06 | 首条英文成功，配音失败 | 原英文可恢复，起算时间不变 | R02—R04 |
| RA07 | 首次批量，混合新项与重放项 | 新项同事务保存，仅新项计数并激活一次 | R02 |
| RA08 | 单句和批量合计达到表达上限 | 使用同一上限，不可分别用满两份 | R01、R03 |
| RA09 | 完成事务失败／提交成功后响应丢失 | 无半激活；成功重放不重复收费计数 | R02 |
| RA10 | 8 路首次并发、重复 ID、不同 payload | 一个试用、无超售；冲突明确拒绝 | R01、R02 |
| RA11 | 到期点前 1 毫秒／等于／之后 | 半开区间准确，已接收在途可交付 | R03 |
| RA12 | 新试用关闭、生成暂停、配置读取失败 | 各自语义正确，失败不退为免检查生成 | R03 |
| RA13 | 登录返回、退出、切账户、旧响应晚到 | 草稿保留，无自动收费请求，无跨账户状态 | R04 |
| RA14 | 试用期间付款／赠送并发 | 在途归原记录，界面优先显示有效月会员 | R01、R02 |
| RA15 | 状态接口 404／503／离线 | 明确不可用，不伪造免费或有效试用 | R03、R04 |
| RP01 | 完成学习、录音中、播放中、重复登录 | 合适时机最多邀请一次，不打断学习 | R06 |
| RP02 | 三题为空、部分填写、不愿透露、整页跳过 | 均可继续，状态与空值含义正确 | R05、R06 |
| RP03 | 缺同意、旧告知版本、非法枚举、40／41 字符 | 原子拒绝无效保存，有具体错误 | R05 |
| RP04 | 跨用户 ID、伪造日期／会员字段、普通用户聚合请求 | 拒绝，不能影响权益或读取他人资料 | R05、R07 |
| RP05 | 资料保存时断网／切账户／修订冲突 | 不假报成功，不串账户，不覆盖新版本 | R05、R06 |
| RP06 | 撤回后重登、聚合查询、备份恢复 | 答案清除且不重新关联；不自动再邀请 | R05、R08 |
| RP07 | 地区／年龄／保留政策未确定 | 新增画像收集关闭，学习与认证不受影响 | R05、R08 |
| RP08 | 当前画像修改／没有填写／全部拒答 | 分组与覆盖率可解释，不推测补齐 | R07 |
| RP09 | 付费、赠送、补偿、退款、未决订单 | 真实首购独立统计，各来源明确 | R07 |
| RP10 | 观察期不足、UTC 边界、小于 5 人 | 显示观察中或样本不足，分母正确 | R07 |
| RP11 | 繁中／简中／日语、窄屏、大字、键盘 | 字段、错误、状态与可访问名称完整 | R04、R06、R07 |
| RP12 | 旧用户与现有学习同步／备份 | 不必重注册，原数据不被研究资料覆盖 | R05、R06 |

## 4．后续交付记录格式

每完成一个任务，记录任务号、实际文件、验证命令、结果、环境／构建标识和剩余门槛，再更新 `ROADMAP.md`。只有代码和对应验证均完成时才勾选该任务；隔离数据库、真实账户、供应商费用和发布分别留证。

本轮交付物只有设计、任务计划和规范／路线图关联。下一次取得开发授权后从 R00 开始，优先完成 R01—R04；无需重新讨论已认可的简短注册、可选画像和 168 小时起算原则。

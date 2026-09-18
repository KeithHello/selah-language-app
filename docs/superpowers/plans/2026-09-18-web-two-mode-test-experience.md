# Web Two-Mode Test Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Web 产品整理为简单的「测试模式／生产模式」，让测试模式免登录使用完整功能，同时让首次输入精灵名字的引导足够明确，并在生产限制触发时原地提示。

**Architecture:** 沿用现有 Supabase 匿名会话和服务端开关，不新增数据库字段或迁移。匿名会话继续使用本机 `guest` 数据作用域，正式账户才切换到云端账户和同步；管理台把既有多个底层开关封装为一个模式操作。客户端通过 `LearningFailure.code` 判断是否需要展示登录入口，避免把所有匿名提示都误判为登录问题。

**Tech Stack:** Flutter Web、Dart、Supabase Edge Functions（现有合约）、Flutter widget/unit tests、现有纯 Dart 多语言文案表。

## Global Constraints

- 只修改 Web 客户端、管理台 UI、测试、文档和路线图；不新增或应用数据库 migration。
- 不修改 `.env`、密钥、CI/CD、供应商模型、音频方案或远端部署配置。
- 测试模式仍受服务端匿名开关和平台每日预算保护；“全功能”不等于无限费用。
- 正式账户才执行跨设备同步、会员摘要、研究资料和会员限制展示。
- 先写失败测试，再做最小实现；每项完成后运行针对性测试和格式检查。

---

### Task 1: 明确服务运行模式合约

**Files:**
- Modify: `SelahFlutter/lib/web/domain/admin_membership.dart`
- Modify: `SelahFlutter/lib/web/admin/admin_controller.dart`
- Test: `SelahFlutter/test/admin_membership_controller_test.dart`

**Interfaces:**
- `AdminServiceControls.productMode` 返回 `ProductMode.test` 或 `ProductMode.production`。
- `AdminServiceControls.productModeNeedsNormalization` 标记远端开关既不是完整测试配置也不是完整生产配置。
- `AdminController.setProductMode(ProductMode mode, {required String reason})` 将模式转换为现有服务开关请求。

- [x] **Step 1: Write the failing test**

为混合配置增加生产安全回退和测试模式成组更新断言。

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/admin_membership_controller_test.dart -r expanded`

Expected: FAIL，因为 `ProductMode`、`productMode` 和 `setProductMode` 尚不存在。

- [x] **Step 3: Write minimal implementation**

新增 `ProductMode`，测试模式要求匿名开关开启且会员限制关闭；生产模式为其他所有配置。新增控制器方法，测试模式发送匿名开启、会员关闭、生成开启；生产模式发送匿名关闭、会员开启、生成开启，并保留试用／销售当前值。混合配置按生产模式安全回退，并在管理台提供直接归一化为生产配置的操作。

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/admin_membership_controller_test.dart -r expanded`

Expected: PASS。

### Task 2: 匿名会话保持本机作用域，正式账户才切换同步

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart`
- Test: `SelahFlutter/test/web_controller_test.dart`

**Interfaces:**
- 新增 `LearningController.isRegistered`，值为 `hasSession && !isAnonymous`。
- 匿名会话不再触发 `_switchAccount` 清空当前页面；`_current`／`_sameAccount` 将匿名会话视为 `guest` 作用域。

- [x] **Step 1: Write the failing test**

增加匿名生成前已有本机输入时，匿名会话建立后输入和当前本机状态仍保留的回归测试；增加 `retryDraft` 在匿名会话下会先建立会话的测试。

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/web_controller_test.dart -r expanded`

Expected: FAIL，因为匿名登录事件会触发账户切换，且 `retryDraft` 直接经过未登录检查。

- [x] **Step 3: Write minimal implementation**

匿名会话保持 `_accountId == 'guest'`，监听认证变化时忽略匿名身份切换；初始化时已有匿名身份也强制解析为 `guest`，避免刷新后本机资料无法恢复。正式账户仍调用 `_switchAccount`。同步、会员和研究资料加载仅对 `isRegistered` 触发。`retryDraft` 先调用 `_ensureOnlineSession`。匿名状态下导入本机资料改为提示已直接使用本机资料，正式账户才执行合并。

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/web_controller_test.dart -r expanded`

Expected: PASS。

### Task 3: 错误提示只在真正的生产登录限制时提供登录入口

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart`
- Modify: `SelahFlutter/lib/web/ui/web_learning_app.dart`
- Modify: `SelahFlutter/lib/web/data/supabase_learning_gateway.dart`
- Test: `SelahFlutter/test/web_app_test.dart`

**Interfaces:**
- `LearningController.errorCode` 保存最近一次 `LearningFailure.code`。
- `_MessageBar` 仅在 `unauthorized`、`login_required`、`anonymous_test_ended` 等认证错误时展示登录按钮；预算、网络、音频和普通业务错误保持原地重试／关闭。

- [x] **Step 1: Write the failing test**

增加匿名预算错误不显示“注册／登录”，生产模式 `anonymous_test_ended` 显示“登录”按钮且不跳转页面的 widget 测试。

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/web_app_test.dart -r expanded`

Expected: FAIL，因为当前实现对所有匿名消息都显示登录入口。

- [x] **Step 3: Write minimal implementation**

在 `_run`、初始化、本机保存、试听、轮询和本机资料读取错误路径记录并清理 `errorCode`；错误文案统一映射 `anonymous_test_ended` 为生产模式登录提示。`_MessageBar` 根据错误码决定 CTA，继续使用当前弹窗，不做页面跳转。

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/web_app_test.dart -r expanded`

Expected: PASS。

### Task 4: 管理台改为单一「运行模式」控制

**Files:**
- Modify: `SelahFlutter/lib/web/ui/admin_dashboard_page.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_strings.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_zh_hans.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_zh_hant.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_ja.dart`
- Test: `SelahFlutter/test/admin_membership_controller_test.dart`

**Interfaces:**
- 管理台只展示当前 `ProductMode`、一条模式开关和风险说明。
- 开关调用 `AdminController.setProductMode`，底层服务开关仍保留兼容接口。

- [x] **Step 1: Write the failing test**

增加模式文案和单一模式控件的查找断言，确保旧的五个独立开关不再出现在管理台。

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/admin_dashboard_page_test.dart -r expanded`

Expected: FAIL，因为当前页面仍渲染五个独立开关。

- [x] **Step 3: Write minimal implementation**

替换 `_ServiceControlsCard` 为测试／生产二选一的 `SwitchListTile`，保留确认对话框、版本和错误显示；补齐三种语言文案。不开启测试模式时按生产安全默认显示。

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/admin_dashboard_page_test.dart test/admin_membership_controller_test.dart -r expanded`

Expected: PASS。

### Task 5: 强化首次精灵名字引导

**Files:**
- Modify: `SelahFlutter/lib/web/ui/web_learning_app.dart`
- Modify: `SelahFlutter/lib/web/ui/web_start_action.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_strings.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_zh_hans.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_zh_hant.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_ja.dart`
- Test: `SelahFlutter/test/web_start_action_test.dart`
- Test: `SelahFlutter/test/web_app_test.dart`

**Interfaces:**
- 首屏名称区带步骤标题、必填标识、说明、放大的输入框和实时预览。
- 点击“开始学习”即使未完成也执行校验，自动聚焦名称输入并显示缺项说明；忙碌时仍禁用。

- [x] **Step 1: Write the failing test**

更新启动按钮测试：未完成时按钮可点击并调用校验回调；引导页显示“第 1 步／必填／精灵名字”及空值提示。

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/web_start_action_test.dart test/web_app_test.dart -r expanded`

Expected: FAIL，因为当前按钮在缺项时禁用，名称区没有步骤和必填提示。

- [x] **Step 3: Write minimal implementation**

给 `WebStartAction` 增加 `onInvalid`，非忙碌时保持可点；名称区使用高对比卡片、较大输入框、FocusNode 和本地验证状态，滚动／聚焦到缺失项。新增三种语言文案，保留最少三句规则。

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/web_start_action_test.dart test/web_app_test.dart -r expanded`

Expected: PASS。

### Task 6: 全量验证与路线图记录

**Files:**
- Modify: `ROADMAP.md`
- Create: `docs/web-two-mode-acceptance-2026-09-18.md`

- [x] **Step 1: Run formatting and focused tests**

Run: `dart format --output=none <changed Dart files>` and the focused Flutter tests from Tasks 1–5。

- [x] **Step 2: Run the full Web test suite and build**

Run: `flutter test` and the repository’s standard Web build command from `SelahFlutter/tool/web.ps1`。

- [x] **Step 3: Record only verified results**

验收记录写明匿名本机作用域、生产登录提示、管理台二元模式、名称引导和测试／构建结果；未执行的远端部署保持“待确认”。修正 `ROADMAP.md` 中 migration 007 状态矛盾后再标记已完成。

# Selah 第一版免邮箱确认与测试期游客云端功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task after the owner explicitly authorizes code changes. Steps use checkbox (`- [ ]`) syntax for tracking. Do not dispatch subagents unless the owner requests it. Do not change secrets, run migrations, call billable OpenAI APIs, or deploy unless a later task is separately authorized.

**Goal:** 第一版注册后立刻进入登录状态，不再等邮件确认；测试期游客不需要先注册，也能完成「说出来 → 生成英文 → 补个人句子音频」，同时管理台继续要求管理员。

**Architecture:** 不把五个收费 Edge Function 改成无 JWT。游客第一次进入收费云端入口时，前端静默 `signInAnonymously()`，拿到 `auth.users` 身份后再走现有 `requireAuth` / `verify_jwt = true`。本机 `guest` 学习数据在匿名会话建立时合并进该身份。第一版不原地升级匿名账户。匿名数据只属于当前浏览器；正式注册走普通 `signUp`，关闭邮箱确认后直接获得正式会话。匿名转正式账户的数据合并留待后期 Manual Linking / 迁移流程。

**Tech Stack:** Flutter Web / Dart、`supabase_flutter ^2.17.1` Anonymous Sign-ins、现有 `sentences-generate` / `sentences-prepare` / `sentences-batch-generate` / `speech-transcribe` / `audio-generate` / `audio-download-url`。

**Product source:** 2026-09-17 主人确认：第一版关掉邮箱验证、注册成功立刻登录；测试期所有学习功能不要求账号；循环听种子和本机学习已放开；生成入口、个人句子音频补齐、备份导入、「说出来」英文生成按同一口径放开。远端旧 20 句种子不处理。SMTP 与正式邮件确认留到后期。

## Global Constraints

- 本文件是后续开发的唯一实施入口。先不改产品代码；主人明确说「去做／实现」之后才按 T1→T8 执行。
- 不关闭五个收费函数的 JWT。未带会话的直接 HTTP 调用必须继续 401。
- 不把「输入任意账号密码都算成功」做成产品行为。邮箱格式、密码至少 6 位、错误密码、重复注册仍要拦截。
- 测试期放开的是学习闭环，不是管理台、会员发放、费用同步或管理员 RPC。
- 本机备份导入已经不要求登录，保持现状。被登录墙拦住的是生成、转写、个人配音、循环听个人句补音频，以及「把游客资料合并到账户」。
- 匿名会话会创建 `auth.users` 行并可能产生 OpenAI 费用。预览站公开时等于公开体验；保留现有频率限制、请求大小限制和紧急停机。`membershipEnforcementEnabled` 继续为 false。
- 不新增依赖、数据库 schema、密钥、SMTP、CI 或自定义域名。`006_membership_cost_control.sql` 仍不应用。
- 远端 Auth 开关（Confirm email、Anonymous Sign-ins）属于外部配置，执行前必须再问主人。本地 `supabase/config.toml` 可在获准改代码后同步，方便以后本地模拟。
- 不处理远端旧 20 句种子，不删除源码里未打包的历史 MP3。
- 第一版不做匿名账户原地升级。匿名数据只属于当前浏览器；正式注册走普通 `signUp`，关闭邮箱确认后直接进入正式会话。Manual Linking、数据迁移和 SMTP 留到后续。
- Windows 本机若 `flutter analyze` 因 SDK lockfile 失败，使用 `D:/setup/flutter/bin/dart.bat analyze lib test`。

## Current Baseline

已完成、本轮直接复用：

- 循环听种子 10 句、60 条随包音频，游客可循环听。
- 本机 `guest` 学习、本机备份导入／导出。
- `selahAuthRedirectUrl()` 已传站点根地址。
- 五个收费函数远端 `OPTIONS 200`、无凭证 `POST 401`。
- 会员强制关闭；生成仍要求登录 JWT。
- `supabase_flutter: ^2.17.1` 支持 `signInAnonymously()`。

已确认仍挡住测试：

1. `LearningController._online()` 在 `!hasSession` 时抛出「请先登录，便能生成自己的英文和语音。」生成、整理、转写、云端配音都走这里。
2. 循环听个人句缺音频时抛出 `login_required`：「登录后即可为自己的句子补齐音频。」
3. `SupabaseLearningGateway._requireUser()` 无 `userId` 时拒绝 `invoke` / `transcribe` / `seedAudio`。
4. 远端 `mailer_autoconfirm=false`。`signUp` 无 session 时抛 `email_confirmation`，前端显示「请先通过邮件确认账户，再回来登录。」
5. 本地 `supabase/config.toml`：`enable_anonymous_sign_ins = false`，`enable_confirmations = false`。远端与本地确认开关不一致，以远端为准。
6. `web_app_test.dart` 把未登录生成横幅和「登录」按钮当作成功断言，本轮放开后必须改期望。
7. 管理台「请先登录管理员账号。」必须保留。

## File Map

| File | Responsibility this round |
| --- | --- |
| `SelahFlutter/lib/web/data/learning_gateway.dart` | 新增 `signInAnonymously()`、`isAnonymous`；`UnconfiguredGateway` 给出安全默认 |
| `SelahFlutter/lib/web/data/supabase_learning_gateway.dart` | 实现匿名登录；普通注册和找回密码继续使用现有 Auth API；`_requireUser()` 仍要求已有 userId |
| `SelahFlutter/lib/web/learning_controller.dart` | `ensureCloudSession()`；收费入口先拿会话再 `_online()`；循环听个人句补音频走同一会话；注册成功立刻进入正式会话 |
| `SelahFlutter/lib/web/ui/web_learning_app.dart` | 学习页不再把「请先登录」当作生成失败的主路径；管理台登录入口保留 |
| `SelahFlutter/lib/web/l10n/selah_strings.dart` 及 zh-Hant／zh-Hans／ja | 必要时补充「正在准备云端会话」类文案；删除测试期会误导的强制登录主路径依赖 |
| `supabase/config.toml` | 本地对齐：允许匿名登录；邮箱确认保持关闭 |
| `SelahFlutter/test/web_controller_test.dart` | FakeGateway 增加匿名登录；游客生成不再因无 session 失败 |
| `SelahFlutter/test/web_app_test.dart` | 未登录生成不再出现登录横幅；管理台仍要登录 |
| `SelahFlutter/test/web_loop_controller_test.dart` | 游客个人句缺音频时会先匿名登录再 generate，不再直接 `login_required` |
| `SelahFlutter/test/web_reliability_controller_test.dart` | 注册有 session 则立即登录；`email_confirmation` 只作为后期回归保留 |
| `docs/guest-cloud-access-acceptance.md` | 本地证据 |
| `ROADMAP.md` / `CLAUDE.md` | 只记录已验证结果 |

不改：五个 Edge Function 的 `requireAuth`、数据库 RLS、SMTP、Site URL、管理函数、会员 migration、种子 JSON、音频资源。

## Recommended approach

用匿名会话代替「把后端改成完全公开」。原因：现有句子、音频、用量都挂在 `auth.users(id)` 上；关掉 JWT 等于任何人都能打付费接口，也写不进现有表。匿名登录对用户不可见，对后端仍是普通 user_id。

明确不做：随机账号免密进入别人的数据、关闭 Confirm email 却继续依赖 SMTP、游客直接打无 JWT 的 generate、管理台免登录、匿名数据跨设备自动合并。

---

### Task 1: Gateway 增加匿名会话合约

**Files:**
- Modify: `SelahFlutter/lib/web/data/learning_gateway.dart`
- Modify: `SelahFlutter/lib/web/data/supabase_learning_gateway.dart`
- Modify: `SelahFlutter/test/web_controller_test.dart`
- Modify: 所有实现 `LearningGateway` 的测试替身（`web_app_test.dart`、`web_reliability_controller_test.dart`、会员／画像测试里的空实现）

**Interfaces:**
- Consumes: 现有 `signIn` / `signUp` / `userId`
- Produces: `Future<void> signInAnonymously();`、`bool get isAnonymous;`

- [ ] **Step 1: Write the failing test**

在 `SelahFlutter/test/web_controller_test.dart` 的 `FakeGateway` 增加：

```dart
bool anonymous = false;
int anonymousCalls = 0;

@override
bool get isAnonymous => anonymous;

@override
Future<void> signInAnonymously() async {
  anonymousCalls += 1;
  anonymous = true;
  user = newId();
}
```

`FakeGateway.user` 目前是 `final`，改为可变 `String? user;`，默认 `null` 的游客替身和默认已登录替身分开。现有已登录测试继续给 `user = newId()`。

新增测试：

```dart
test(''anonymous sign-in assigns a user id'', () async {
  final gateway = FakeGateway()..user = null;
  expect(gateway.userId, isNull);
  await gateway.signInAnonymously();
  expect(gateway.userId, isNotNull);
  expect(gateway.isAnonymous, isTrue);
});
```

接口尚未声明时，分析器会失败。

- [ ] **Step 2: Add the interface defaults**

`LearningGateway` 增加：

```dart
bool get isAnonymous;
Future<void> signInAnonymously();
```

`UnconfiguredGateway`：

```dart
@override
bool get isAnonymous => false;

@override
Future<void> signInAnonymously() async => _missing();
```

`SupabaseLearningGateway`：

```dart
@override
bool get isAnonymous => client.auth.currentUser?.isAnonymous == true;

@override
Future<void> signInAnonymously() async {
  await client.auth.signInAnonymously();
  if (userId == null) {
    throw const LearningFailure(''暂时无法开始云端学习，请稍后重试。'');
  }
}
```

`signUp` 保持普通注册。第一版不调用 `updateUser` 绑定匿名账户，因为 Supabase 官方转换路径要求开启 Manual Linking，且邮箱身份需要验证；这和「先不收确认邮件」冲突。

- [ ] **Step 3: Update test doubles**

所有测试里 `implements LearningGateway` 的空实现补上：

```dart
@override
bool get isAnonymous => false;
@override
Future<void> signInAnonymously() async {}
```

- [ ] **Step 4: Run tests**

Run: `D:/setup/flutter/bin/dart.bat analyze lib test`
Expected: 0 issues

Run: `D:/setup/flutter/bin/flutter.bat test --no-pub test/web_controller_test.dart`
Expected: 新增匿名测试通过，原有登录／备份测试通过。

---

### Task 2: 收费入口先建立云端会话

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart`
- Test: `SelahFlutter/test/web_controller_test.dart`
- Test: `SelahFlutter/test/web_loop_controller_test.dart`

**Interfaces:**
- Consumes: `gateway.signInAnonymously()`、`gateway.userId`、`store.load(''guest'')`
- Produces: `Future<void> ensureCloudSession()`

- [ ] **Step 1: Write the failing tests**

```dart
test(''unsigned generate silently opens an anonymous cloud session'', () async {
  final gateway = FakeGateway()
    ..user = null
    ..fail = false;
  final platform = MemoryPlatform();
  final controller = LearningController(
    gateway: gateway,
    platform: platform,
    seeds: const [],
    polling: false,
  );
  addTearDown(controller.dispose);
  await controller.initialize();
  expect(controller.hasSession, isFalse);

  await controller.generate(''今天想早点休息。'');

  expect(gateway.anonymousCalls, 1);
  expect(controller.hasSession, isTrue);
  expect(controller.accountId, gateway.userId);
  expect(controller.state.sentences, isNotEmpty);
});

test(''unsigned generate keeps guest today input after anonymous switch'', () async {
  final gateway = FakeGateway()
    ..user = null
    ..fail = false;
  final platform = MemoryPlatform();
  final controller = LearningController(
    gateway: gateway,
    platform: platform,
    seeds: const [],
    polling: false,
  );
  addTearDown(controller.dispose);
  await controller.initialize();
  controller.updateTodayInput(''今天想早点休息。'');
  await controller.generate(''今天想早点休息。'');
  expect(controller.todayInput, ''今天想早点休息。'');
});
```

Expected before implementation: `LearningFailure(''请先登录，便能生成自己的英文和语音。'')`。

循环听补音频测试：构造游客、一句非 seed 个人句、音频未缓存；`prepareLoop()` 应调用 `signInAnonymously` 和 `audio-generate`，而不是 `login_required`。

- [ ] **Step 2: Implement ensureCloudSession**

放在 `LearningController`，供收费入口使用：

```dart
Future<void> ensureCloudSession() async {
  if (hasSession) return;
  if (!configured) {
    throw const LearningFailure(''在线服务尚未配置。你可以继续学习种子句和已保存的内容。'');
  }
  if (platformInfo[''online''] == false) {
    throw const LearningFailure(''现在处于离线状态，联网后可继续生成。'');
  }
  final guest = await store.load(''guest'');
  await gateway.signInAnonymously();
  final id = gateway.userId;
  if (id == null) {
    throw const LearningFailure(''暂时无法开始云端学习，请稍后重试。'');
  }
  await _switchAccount(id);
  if (guest.todayInput.isNotEmpty || guest.sentences.isNotEmpty) {
    await _mergeImport(guest, _accountGeneration);
  }
}
```

注意：`accountChanges` 监听也会触发 `_switchAccount`。实现时用 generation / 当前 id 去重，避免并发切两次账户。若监听已经切到新 id，`ensureCloudSession` 只合并 guest，不再二次 load 空快照覆盖。

- [ ] **Step 3: Call it before paid cloud work**

`_online()` 改为：

```dart
void _online() {
  if (!configured) {
    throw const LearningFailure(''在线服务尚未配置。你可以继续学习种子句和已保存的内容。'');
  }
  if (!hasSession) {
    throw const LearningFailure(''请先登录，便能生成自己的英文和语音。'');
  }
  if (platformInfo[''online''] == false) {
    throw const LearningFailure(''现在处于离线状态，联网后可继续生成。'');
  }
}
```

`_online()` 仍要求已有会话。在这些方法进入 `_online()` 之前先 `await ensureCloudSession();`：

- `_generate`
- `prepare`
- `generatePreparedSegments`（走 batch 的路径，约 1553 行附近）
- `startRecording`
- `stopRecording` 里转写前
- 单句播放缺缓存时准备 `audio-generate` 的分支
- `_prepareLoop` 里个人句缺音频、当前会抛 `login_required` 的分支
- `importGuest` 仍要求正式登录语义：若当前是匿名会话，允许把本机 guest 合并进该匿名账户；不要再挡学习闭环

`bringGuestInput()` 改为依赖 `hasSession` 即可，匿名会话也算。测试期用户看不到「登录」，所以不要再抛「请先登录，再带入本机输入。」

- [ ] **Step 4: Run tests**

Run: `D:/setup/flutter/bin/flutter.bat test --no-pub test/web_controller_test.dart test/web_loop_controller_test.dart test/web_reliability_controller_test.dart`
Expected: 游客生成、游客循环听补音频、账户切换测试通过。

---

### Task 3: 注册立刻登录，正式会话与匿名测试身份分离

**Files:**
- Modify: `SelahFlutter/lib/web/data/supabase_learning_gateway.dart`
- Modify: `SelahFlutter/lib/web/learning_controller.dart`
- Test: `SelahFlutter/test/web_reliability_controller_test.dart`
- Test: `SelahFlutter/test/web_controller_test.dart`

**Interfaces:**
- Consumes: Task 1 的普通 `signUp` 会话
- Produces: 注册成功后 `hasSession == true`；当前匿名测试数据不原地合并到正式账户

- [ ] **Step 1: Write the failing tests**

```dart
test(''register with a live session logs the user in immediately'', () async {
  final gateway = LoginGateway();
  // LoginGateway.signUp should set current user instead of email_confirmation.
  await c.login(''user@example.com'', ''123456'', register: true);
  expect(c.hasSession, isTrue);
  expect(c.notice, ''已登录，学习内容将同步到你的账户。'');
});

test(''register with a live session enters a new permanent account'', () async {
  final gateway = FakeGateway()..fail = false;
  await controller.login(''user@example.com'', ''123456'', register: true);
  expect(controller.hasSession, isTrue);
});
```

`LoginGateway.signUp` 目前没有实现，会落到 `UnconfiguredGateway` 或空操作。让它在非 confirmation 模式下建立新的正式用户 id。

- [ ] **Step 2: Keep frontend login() session-first**

现有 `login()` 已是：注册后若 `gateway.userId == null` 才提示查邮箱。Confirm email 关闭后，这条路径自然变成立即登录。本任务只补：

1. Fake/Login gateway 的 `signUp` 必须建立 session。
2. 真实 gateway：普通注册返回 session；不在匿名会话中原地绑定邮箱。
3. 文案：第一版不再把「请检查邮箱并确认账户后登录。」当作成功态。只有远端仍返回无 session 时才显示这条，作为后期重新打开确认的兼容。

- [ ] **Step 3: Run tests**

Run: `D:/setup/flutter/bin/flutter.bat test --no-pub test/web_reliability_controller_test.dart test/web_controller_test.dart`
Expected: 立即登录与匿名升级通过；错误密码、短密码、非法邮箱仍失败。

---

### Task 4: 学习界面去掉强制登录墙，管理台保留

**Files:**
- Modify: `SelahFlutter/lib/web/ui/web_learning_app.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_strings.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_zh_hant.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_zh_hans.dart`
- Modify: `SelahFlutter/lib/web/l10n/selah_ja.dart`
- Test: `SelahFlutter/test/web_app_test.dart`
- Test: `SelahFlutter/test/web_l10n_test.dart`

- [ ] **Step 1: Rewrite the widget test**

把 `unsigned generation prompt offers a login shortcut on the banner` 改成：

```dart
testWidgets(''unsigned generation starts without a login banner'', (tester) async {
  final gateway = _SignedOutConfiguredGateway()..fail = false;
  // _SignedOutConfiguredGateway.userId starts null; FakeGateway.signInAnonymously fills it.
  ...
  await configuredController.generate(''今天想早点休息。'');
  await tester.pumpWidget(WebLearningApp(controller: configuredController));
  await tester.pumpAndSettle();
  expect(find.text(''请先登录，便能生成自己的英文和语音。''), findsNothing);
  expect(find.widgetWithText(TextButton, ''登录''), findsNothing);
});
```

管理台测试 `请先登录管理员账号。` 保持 findsOneWidget。

设置页「登录／注册」入口可以保留，方便以后绑邮箱，但测试期生成失败不得再逼登录。

- [ ] **Step 2: Banner helper**

`web_learning_app.dart` 里根据文案含「登录」就插入快捷按钮的逻辑，只在错误码仍是 `login_required` 或管理台未登录时出现。游客匿名成功后不应再命中。

如需等待会话，可用现有 notice，不必新建设计系统。三语文案若新增「正在连接学习服务…」，同步 `web_l10n_test.dart`。

- [ ] **Step 3: Run widget tests**

Run: `D:/setup/flutter/bin/flutter.bat test --no-pub test/web_app_test.dart test/web_l10n_test.dart`
Expected: 学习页无登录墙，管理台仍要管理员。

---

### Task 5: 本地 Auth 配置对齐

**Files:**
- Modify: `supabase/config.toml`

远端开关不在本任务自动执行。

- [ ] **Step 1: Local config**

```toml
[auth]
enable_signup = true
enable_anonymous_sign_ins = true

[auth.email]
enable_signup = true
enable_confirmations = false
```

这只影响以后 `supabase start` 的本地 Auth。当前 Web 连的是远端项目 `ijonabyyppmgvoufgamt`，所以测试期真要让预览站匿名登录，仍需主人确认后改远端：

1. Authentication → Providers / Settings：Enable Anonymous Sign-ins
2. Authentication → Providers → Email：Confirm email = off

- [ ] **Step 2: Record the remote checklist in the acceptance doc, do not apply it here**

---

### Task 6: 全量本地回归与验收记录

**Files:**
- Create: `docs/guest-cloud-access-acceptance.md`
- Modify: `ROADMAP.md`（仅在验证后）

- [ ] **Step 1: Analyze and Flutter tests**

Run:

```
D:/setup/flutter/bin/dart.bat analyze lib test
D:/setup/flutter/bin/flutter.bat test --no-pub
```

Expected: analyze 0 issues；Flutter 全量通过，数量按当时清单记录，不得低于改前 239。

- [ ] **Step 2: Node and Deno contracts**

Run 现有 Node 浏览器桥 / Service Worker 测试、Deno `requireAuth` 相关测试。Expected: 无凭证函数仍 401；不要改 cors.ts 放行空 token。

- [ ] **Step 3: Release build**

Run: `./tool/web.ps1 -Action build`
Expected: 成功；`main.dart.js` 含公开 Supabase 配置；不含 `OPENAI_ADMIN_API_KEY` / `SUPABASE_SERVICE_ROLE_KEY`。记录 Build ID。

- [ ] **Step 4: Write acceptance notes**

`docs/guest-cloud-access-acceptance.md` 必须写明：

- 本地自动化结果
- 远端 Confirm email / Anonymous Sign-ins 是否已改（未改就写待确认）
- 未跑真实 OpenAI 的原因或另获授权后的调用次数
- 管理台仍需管理员

---

### Task 7: 远端 Auth 开关（单独确认后才执行）

**Files:** 无代码。操作对象：Supabase Dashboard 项目 `ijonabyyppmgvoufgamt`。

权限：Organization Owner 或 Administrator。Developer 不够。

- [ ] **Step 1: Ask the owner immediately before changing remote Auth**

告知：将关闭 Confirm email、打开 Anonymous Sign-ins；会影响所有新注册和所有打开预览站后点生成的访客。

- [ ] **Step 2: Apply only after explicit yes**

1. Confirm email = disabled
2. Anonymous Sign-ins = enabled
3. 不改 SMTP、Site URL、Redirect allow list、邮件模板
4. 只读核对：用 publishable key 读 `/auth/v1/settings`，确认 `mailer_autoconfirm` 为 true 或等价「不需确认」，以及匿名登录已开

- [ ] **Step 3: Preview verification after deploy is separately authorized**

未登录浏览器：

1. 循环听 10 句种子仍可播
2. 输入中文点生成英文，不再出现登录横幅，得到英文句子
3. 「说出来」能转写
4. 个人句能生成并播放音频
5. 本机备份导入仍可用
6. `/#/admin` 仍要管理员
7. 直接 curl 无 Authorization 的 `sentences-generate` 仍 401

此步会产生少量 OpenAI 费用，必须先报预算再跑。

---

### Task 8: 后期加回限制（不在本轮实现，只锁定回退口）

本轮不写回退代码，但实现时不要拆掉这些开关点：

| 以后要恢复的限制 | 现在必须留下的口 |
| --- | --- |
| 生成／转写／配音要正式登录 | `ensureCloudSession()` 可改成「仅当已有非匿名 session 才继续」 |
| 重新打开邮箱确认 | `signUp` 无 session 时现有 `email_confirmation` 文案 |
| 关掉匿名登录 | 远端关闭 Anonymous Sign-ins；前端 `signInAnonymously` 失败要诚实报错 |
| SMTP 确认邮件 | 另按 2026-09-16 邮件方案配置，不混进本计划 |

---

## Remote vs local work split

| 工作 | 何时 | 风险 |
| --- | --- | --- |
| T1–T4 代码和测试 | 主人授权「去做」后 | 只动 Web 客户端和测试 |
| T5 本地 config.toml | 与代码同一授权 | 不影响当前远端 |
| T6 本地构建 | 代码完成后 | 无远端副作用 |
| T7 远端 Auth | 必须再问一次 | 立即改变注册和访客生成 |
| 预览部署最新 Build | 必须再问一次 | 预览站将公开可生成，产生 API 费用 |
| SMTP / Site URL / 旧种子 | 不做 | — |

## Spec coverage

- 注册后立刻登录，不验证邮箱：T3 + T7 Confirm email off
- 仍校验邮箱密码格式和正确性：T3 回归测试
- 测试期不要求登录即可生成、转写、补音频：T2 + T4 + T7 Anonymous
- 循环听种子／本机学习保持放开：不改已有成功路径
- 备份导入不挡游客：不改 `importBackup()`
- 管理台仍要管理员：T4
- 后端继续 JWT：不改 `requireAuth`，T6 核对 401
- 旧 20 句不动：File Map 排除
- SMTP 后期再做：T7 明确不改邮件

## Placeholder scan

无 TBD／TODO。远端开关写成独立 T7，避免执行代码任务时误改 Auth。

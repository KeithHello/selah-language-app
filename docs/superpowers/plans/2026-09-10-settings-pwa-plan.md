# Selah 设置信息架构与本机能力实施计划

> 原始实施分解文档。核心代码已按本计划执行；原有复选框保留用于追溯，实际状态以本文件「执行记录」与 `ROADMAP.md` 为准。本计划不触发自动实施、agent 分派、付费调用或部署。语言部分以 2026-09-10 的合并实施补充为准。

**目标：** 把设置拆成语言、陪伴、提醒、账户、备份、本机与应用；持久存储、安装和更新按真实浏览器状态显示。安装与保护不承诺防丢数据。

**架构：** 浏览器桥接扩展 `platformInfo`。Flutter 设置页只渲染状态，不猜测能力。更新仍只作用于 waiting Service Worker。

**技术栈：** 现有 `selah_bridge.js`、Service Worker、IndexedDB、Cache API、`beforeinstallprompt`、`StorageManager`。不新增 Flutter 或全局依赖。

**设计依据：** [设置／语言／PWA 设计](../specs/2026-09-10-settings-language-pwa-design.md) 。语言卡片文案与由 `nativeLanguage` 派生的 `uiLocale` 以 [界面语言计划](2026-09-10-interface-language-plan.md) 为准；本计划只负责本机存储、安装与更新状态。

**当前状态：** 2026-09-10 核心 Web／PWA 实施与本地验证已完成；iOS Safari／Android 真机安装更新仍待设备验收。

## 合并实施补充（2026-09-10）

语言卡片最终只显示一个“母語”三选一控件（繁體中文、簡體中文、日本語），并恢复「學習語言」的英语／日本語双选项：英语当前可用，日本語灰色禁用并标注「之後準備加入」。选择母语同时驱动界面文案与之后的输入路由；目标语言仍固定英语，PWA 的保护本机、安装到主屏幕、版本与更新状态机不因语言合并而改变。

## 执行记录（2026-09-10）

- [x] T00：确认设置／PWA 只改正式 Web，核对桥接能力并沿用 Node 内置测试，不新增依赖。
- [x] T01：完成 `platformInfo`、持久存储先读后写、安装状态分类、Build ID、更新检查与 waiting worker 显式应用，并覆盖桥接测试。
- [x] T02：完成语言、陪伴、提醒、账户与同步、备份与离线、本机与应用六组设置；语言区包含英语可用项与日本語禁用项，保护、安装、更新按真实状态渲染，已安装／已保护状态改为只读。
- [x] T03：完成设置内检查更新、全局更新提示、确认框与录音／未保存状态保护；更新只发送给 waiting worker。
- [x] T04：Node 31 项、Flutter 设置页测试与 Release Web 构建已通过；iOS Safari／Android 真机矩阵仍未宣称完成。

## 1．全局约束

- 只改正式 Web。不改数据库、密钥、CI、公开部署。
- 不把安装按钮做成设置页唯一实心主按钮。
- 不承诺「学习记录更不容易丢」「关闭网页后仍准点提醒」「保护等于加密」。
- 更新必须在有未保存输入、录音、待转写或未提交练习评分时拒绝。多窗口会一起刷新，确认框写明。
- iOS 没有 `beforeinstallprompt`。不能对 iOS 调用 `prompt()`。
- `persist()` 只在窗口环境调用，不在 Worker 里调用。
- 本计划不完成 iPhone／Android 真机矩阵；T10 真机发布仍是既有未完成项。
- 文案最终走界面语言表。语言卡片使用统一 `nativeLanguage` 的繁体／简体／日本語三个选项，不再预留独立的界面语言和母语两组控件。

## 2．阶段

| 阶段 | 任务 | 产出 |
| --- | --- | --- |
| 开工 | T00 | 基线与平台探测清单 |
| 桥接状态 | T01 | `storagePersisted`、`installKind`、`buildId`、`persisted()` |
| 设置改版 | T02 | 分组、状态行、安装／保护／更新 UI |
| 更新体验 | T03 | 任意页更新条、检查更新、多窗口文案 |
| 验收 | T04 | P01—P06 与浏览器核对 |

## 3．文件职责

| 文件 | 操作 | 职责 |
| --- | --- | --- |
| `SelahFlutter/web/selah_bridge.js` | 修改 | 扩展 `platformInfo`；`persistentStorage` 先读后写；安装分类；`checkUpdate` |
| `SelahFlutter/web/selah_service_worker.js` | 仅在需要时 | waiting worker 仍只在 `APPLY_UPDATE`／`SKIP_WAITING` 时 `skipWaiting` |
| `SelahFlutter/lib/web/learning_controller.dart` | 修改 | 把平台状态映射为设置 VM；保护／安装／更新的 notice 走状态而不是每次假成功 |
| `SelahFlutter/lib/web/ui/web_learning_app.dart` | 修改 | 设置分组；语言卡片占位或对接；本机与应用状态行；全局更新条 |
| `SelahFlutter/test/browser_bridge.test.mjs` | 扩展 | persist／install／update／platformInfo 契约 |
| `SelahFlutter/test/web_app_test.dart` | 扩展 | 已安装隐藏安装按钮；无更新时隐藏更新按钮；已保护隐藏申请按钮 |

### 3.1 平台信息合约

```js
{
  online: boolean,
  canRecord: boolean,
  canNotify: boolean,
  canPush: boolean,
  installed: boolean,
  canInstall: boolean,
  updateAvailable: boolean,
  storagePersisted: true | false | null,
  installKind: 'installed' | 'prompt' | 'ios-manual' | 'unsupported',
  buildId: string
}
```

判定：

- `installed`：`display-mode: standalone` 或 `navigator.standalone === true`
- `installKind === 'prompt'`：有 deferred prompt 且未安装
- `ios-manual`：iPhone／iPad／iPod 且未安装（UA 或 `navigator.standalone === false` 且无 prompt）
- `unsupported`：无 prompt 且非 iOS 手动路径
- `storagePersisted === null`：没有 `navigator.storage.persisted`

`persistentStorage`：

1. 无 `storage.persist` → 返回 `false`，并由 `platformInfo` 标 null／unsupported
2. `persisted() === true` → 返回 `true`，不再请求
3. 否则 `persist()`，返回布尔值

`checkUpdate`：`registration.update()`，然后看是否出现 waiting worker。无 Service Worker 时返回 `unsupported`。

## T00：开工检查

- [ ] 确认设置／PWA 代码授权。不自动扩大循环听或发布范围。
- [ ] 核对 `selah_bridge.js` 现有 `platformInfo`／`install`／`applyUpdate`／`persistentStorage`。
- [ ] 列出将改测试；浏览器桥测试继续用 Node 内置 runner，不新增 JS 依赖。

## T01：桥接状态机

**文件：** `selah_bridge.js`、`browser_bridge.test.mjs`。

- [ ] 测试：`persisted` 已是 true 时，`persistentStorage` 不调用 `persist`。
- [ ] 测试：无 Storage API 时 `storagePersisted === null`。
- [ ] 测试：有 `beforeinstallprompt` 时 `installKind === 'prompt'` 且 `canInstall === true`。
- [ ] 测试：`matchMedia('(display-mode: standalone)')` 为 true 时 `installKind === 'installed'`，`canInstall === false`。
- [ ] 测试：iOS UA 且无 prompt 时 `installKind === 'ios-manual'`。
- [ ] 测试：`applyUpdate` 只 `postMessage` 给 waiting worker，不给 active。
- [ ] 测试：`buildId` 来自 `meta[name="selah-build-id"]`。
- [ ] 实现上述行为。`install()` 在没有 deferred prompt 时返回 `false`，不抛造成整页错误。

运行：`node --test SelahFlutter/test/browser_bridge.test.mjs`
预期：新旧用例通过。

## T02：设置页改版

**文件：** `web_learning_app.dart`、`learning_controller.dart`、`web_app_test.dart`。

- [ ] 分组顺序：语言、陪伴、提醒、账户与同步、备份与离线、本机与应用。
- [x] 语言卡片对接统一 `nativeLanguage`：展示繁體中文／簡體中文／日本語三个选项，界面 locale 从选择派生，学习语言只读英語。
- [ ] 备份与离线只保留导出／导入／离线说明。
- [ ] 保护：`storagePersisted == true` 只读；`false` 显示「申請保護」次要按钮；`null` 只提示备份。
- [ ] 安装：`installed` 只读；`prompt` 次要按钮；`ios-manual` 三步说明；`unsupported` 菜单说明。禁止在已安装时保留珊瑚色主按钮。
- [ ] 更新：始终显示 Build ID。「更新到新版本」仅 `updateAvailable == true`。文案不用「發新版本」。
- [ ] Widget 测试覆盖：platformInfo 为已安装／已保护／无更新时，找不到「加入主畫面」主按钮、「申請保護」、「更新到新版本」。
- [ ] Widget 测试覆盖：`updateAvailable: true` 时按钮出现；有录音时按钮 disabled 或点击后说明原因。

运行：`flutter test --no-pub test/web_app_test.dart`

## T03：检查更新与全局条

**文件：** `web_learning_app.dart`、`learning_controller.dart`、桥接 `checkUpdate`。

- [ ] 设置提供「檢查更新」。结果三态：已是最新、发现新版本、不支持。
- [ ] `updateAvailable` 为真时，任意已登录／已引导页面顶部出现一条非模态条：「有新版本可用」，操作「稍后／现在更新」。录音或未保存时「现在更新」不可用。
- [ ] 确认框写明：更新会刷新本应用已打开的窗口，请先完成输入。
- [ ] 现有 `hasUnsavedChanges` 保护保持，并加测试。

## T04：验收

- [ ] `node --test SelahFlutter/test/browser_bridge.test.mjs`
- [ ] `flutter analyze --no-pub`、相关 `flutter test --no-pub`
- [ ] 浏览器核对：未安装 Chromium 显示次要安装；独立窗口只读已安装。无法在本机伪造 iOS 时，用 UA 替身测试记录，不宣称真机完成。
- [ ] 文案审查：安装／保护句子不含防丢承诺。
- [ ] 更新路径：人为放入 waiting worker 或现有测试替身，确认只在有更新时显示按钮。
- [ ] 更新 `ROADMAP.md`。真机 Safari／Android 安装仍标未完成。

**完成证据：** P01—P06 有测试或浏览器记录。不得把「设置里能看见三个按钮」当作完成。

| 合约 | 对应任务 |
| --- | --- |
| P01 已保护不再显示待办主按钮 | T01 persisted、T02 状态行 |
| P02 已安装不再显示安装主按钮 | T01 installKind、T02 UI |
| P03 iOS 手动步骤，不调用 prompt | T01 ios-manual、T02 说明 |
| P04 无 waiting worker 不显示更新按钮 | T02／T03 |
| P05 未保存输入或录音拒绝更新 | T03 与现有 hasUnsavedChanges |
| P06 文案不承诺防丢／后台提醒 | T02 文案、T04 审查 |

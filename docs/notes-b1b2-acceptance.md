# 笔记 B1＋B2 实施验收记录

日期：2026-09-10

## 已实施

- 正式 Web 笔记改为完整双语卡片，打开页面即可看到每句中文和英文。
- 重点表达取句子已有的第一条词汇；已有词汇在英文句中按最长、不区分大小写、首次出现匹配并可点击。
- 词汇面板在原卡片内显示原文、释义、当前状态和下一步状态操作；同一会话内关闭后保留页面状态。
- 拆解在原卡片内展开／收起，多个卡片可以同时展开；没有拆解和词汇时隐藏对应入口。
- 「听这句」和「练这句」分别复用现有选中句子和聆听／练习导航；笔记页点击不记作完成聆听或练习。
- 搜索、分类、空状态、会话内返回状态和成长回忆隐藏入口保持原有边界。
- 新增笔记相关简体中文、繁体中文和日语文案键。

## 自动化验证

以下命令已在实现后通过：

- `flutter test --no-pub test/web_notes_page_test.dart`
- `flutter test --no-pub test/web_app_test.dart`
- `flutter test --no-pub test/web_notes_page_test.dart test/web_l10n_test.dart`
- Dart formatter 的 `--set-exit-if-changed` 检查
- `git diff --check`

笔记测试覆盖完整双语、原卡片拆解、多卡同时展开、重点词和非重点词面板、无额外内容、搜索与展开状态返回、无匹配空状态、听／练路由，以及 320／390／768／1130／1440 逻辑像素和 200％文字缩放下的 Widget 级检查。

按当前 token 计算的对比度为：`#1A1614` 对白色卡片 `17.97:1`，`#1A1614` 对珊瑚主按钮 `5.48:1`，`#706B65` 对页面底色 `4.98:1`，均满足正文或按钮文字的 4.5:1 门槛。薰衣草色重点底用于辅助强调，不承担长段正文阅读。

`dart analyze` 已确认笔记改动无错误；全项目仍有 2 条原有的 admin 空安全写法提示，位置在 `SelahFlutter/lib/web/admin/admin_controller.dart:37` 和 `SelahFlutter/lib/web/admin/admin_controller.dart:38`，本任务未修改无关代码。

## 最终命令结果

- `flutter analyze --no-pub` 已完成，没有错误；仍报告 2 条既有的 admin info 提示，位置为 `SelahFlutter/lib/web/admin/admin_controller.dart:37` 和 `SelahFlutter/lib/web/admin/admin_controller.dart:38`。
- `flutter test --no-pub` 已通过，共 181 项。
- `powershell -ExecutionPolicy Bypass -File .\tool\web.ps1 -Action build` 已通过，产物目录为 `SelahFlutter/build/web`；本次 Flutter 产物 `.last_build_id` 为 `46f551526bb112d5a48fb3ab3a7933a6`，标准脚本生成的 `selah-build-id` 为 `89ba6d49a5b2a7b3`，用于让 Service Worker 识别本次笔记更新。
- 构建过程中的 Wasm dry run、字体 tree-shaking 仅为 Flutter 工具提示，不影响 release 构建成功。
- 在无旧 Service Worker 的本地 Release 端口 `5193` 完成实际页面核对：新版垂直卡片、完整双语、重点表达、句中词汇按钮、「听这句／练这句／展开拆解」均可见；旧的「列表＋空详情栏」不再出现。

## 待补的真实设备验收

- 真实 320／390／768／1130／1440 浏览器视口、真实 200％浏览器缩放、iPhone Safari 和 Android 真机仍标记为「未验收」。Widget 测试已覆盖这些逻辑尺寸和文字缩放，但不替代真机验收；现有旧页面若仍显示旧布局，需要刷新或在设置中应用可用更新。
- 未执行公开部署；本次只生成本地 release 产物。

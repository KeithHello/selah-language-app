# Web 圆形悬浮开始控件验收记录

日期：2026-09-05

## 交付范围

- 新增 `SelahFlutter/lib/web/ui/web_start_action.dart`。
- 新增 `SelahFlutter/test/web_start_action_test.dart`。
- 控件 API 保持为 `WebStartAction(selectedCount, hasName, busy, onStart)`，父页面负责业务校验与保存。
- 按钮为 64px 珊瑚色圆形操作，使用右箭头；旁边保留可见「开始学习」和当前状态。
- 启用条件：姓名非空、已选句子恰好 3 句、当前不忙。状态文案覆盖「先取名字」「已选 N/3」「可以开始了」「准备中…」。
- 使用 Flutter 原生 `FilledButton`，自带 Tab／Enter／Space 键盘路径和按钮语义；状态通过辅助功能语义节点提供。
- busy 且系统启用 Reduce Motion 时显示静态沙漏图标，不创建无限进度动画。

## TDD 证据

先运行测试时组件文件尚不存在，测试按预期因 import／类型缺失失败（RED）：

```text
Error when reading lib/web/ui/web_start_action.dart
Type 'WebStartAction' not found
```

补上最小实现后，聚焦测试通过（GREEN）：

```text
cd SelahFlutter
flutter test test/web_start_action_test.dart
00:01 +5: All tests passed!
```

覆盖内容：无效状态禁用、恰好三句启用与点击回调、Tab 后 Enter 键盘激活、busy／Reduce Motion、320px 窄屏无溢出。

静态检查也已通过：

```text
cd SelahFlutter
dart analyze lib/web/ui/web_start_action.dart test/web_start_action_test.dart
No issues found!
```

## 接线状态

上述记录保留子任务交付时的 5 项测试结果。根任务随后完成父页面接线，新增无名／0／2／3／4 句边界验证，控件现有 6 项测试；使用合并语义避免重复朗读「开始学习」。引导页新增滚动固定、最后填写姓名、320／820／900／960 宽度和失败提示可见性验证；与全套 68 项 Flutter 测试一同通过。

失败提示回归先得到提示底部 819、大于按钮顶部 754 的失败结果；移至按钮上方固定区域后通过。真实开始回调保持姓名、恰好三句和 busy 校验，保存失败不会完成引导。完整浏览器结果见 `docs/web-plush-acceptance.md`。

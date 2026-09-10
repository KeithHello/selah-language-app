# C 短绒角色 Web 实施计划

依据：主人已批准 C 设计交接包，并明确要求继续开发后续任务。实施 `docs/next-development.md` 第 1—4 项；D 继续保留为候选。现有主分支和未提交的 Web 工作保持原位，不重写其他客户端。

## 结构与职责

- `SelahFlutter/assets/sprites/SeedPlush*`：由已选 C 母版派生的运行图像，沿用已有素材目录，不增加依赖。
- `SelahFlutter/lib/web/ui/plush_companion.dart`：Web C 角色的固定坐标渲染、表情、原生微动效和成长装饰。身体保持比例；五官、叶根随身体移动。旧原生客户端保持当前入口。
- `SelahFlutter/lib/web/ui/plush_companion_art.dart`：单母版的素材轮廓与刺绣五官固定坐标。当前图集为 RGB，运行时裁切背景，独立透明 PNG 仍待补齐。
- `SelahFlutter/tool/preview_plush.dart`：开发专用效果页，直接使用正式角色组件检查十动作与五个成长阶段，不进入正式产品路由。
- `SelahFlutter/lib/web/ui/web_start_action.dart`：引导页圆形悬浮开始操作，父页面负责业务校验和保存。
- `SelahFlutter/lib/web/learning_controller.dart`：真实播放、录音、复习事件的角色展示状态，不持久化动画，不更改学习计数的判定。
- `SelahFlutter/test/plush_companion_test.dart`、`web_start_action_test.dart` 与现有 Web 测试：验证生命周期、状态优先级、启用条件、响应布局及原有业务。
- `design-system/selah/mascot/`：运行素材来源、提示词、锚点及实际效果记录；`docs/` 保存验收结果。

## 实施步骤

1. 从已选 C 生成运行素材，目视核对材质与比例，读取实际 alpha、尺寸及边缘。只有真实透明图像才能记录为透明素材完成；失败时记录限制，不把棋盘格当透明。
2. 测试先行，建立角色状态与事件：闲置浮动、眨眼、叶摆；播放准备、播放中、自然结束；录音中、录音完成；复习顺利与再练一次。真实结束才庆祝，同一事件不重复触发，取消和失败不伪装成功。
3. 实现 C 渲染，固定锚点、保守位移、不拉伸身体；一次性反馈后归位，后台页和 Reduce Motion 停止循环。成长记录沿用现有规则。
4. 实现圆形悬浮按钮，显示开始提示与已选数量；姓名非空、恰好三句且非忙碌时才能触发。保留底部安全距离、键盘可访问名称和窄屏布局。
5. 接入正式 Web 路径，运行 Flutter 静态检查、完整测试、Release 构建及相关浏览器桥测试。浏览器验收宽窄屏、滚动后开始、真实音频结束、角色状态、减少动态效果与离线资源。
6. 同步角色规范、剩余清单和 ROADMAP，展示真实运行截图。远端配置、发布及真机验收分别保留实际状态。

## 独立子任务：悬浮按钮

仅创建 `web_start_action.dart` 与 `web_start_action_test.dart`；不修改父页面或控制器。组件参数：`selectedCount`、`hasName`、`busy`、`onStart`。主按钮为 60—64 逻辑像素圆形，珊瑚色，右箭头，可访问名称「开始学习」。旁边显示简短状态：先取名字／已选 N/3／可以开始了／准备中。保留可见「开始学习」文字便于理解；忙碌时禁用并显示进度，Reduced Motion 下不使用无限进度动画。验证无名称、数量不足／超过三句、忙碌禁用；有效时点击或键盘只触发一次；320 像素宽度不溢出。测试先失败，再实现；仅跑聚焦测试。独立报告放在 `docs/superpowers/plans/2026-09-05-start-action-report.md`，说明验证命令和结果。根代理负责接线与最终回归。共享工作区已有大量未提交工作，不创建提交。

## 当前状态

已实施并验证：C 单母版渲染、五阶段装饰、十动作及真实事件接线、圆形悬浮开始操作、可见失败提示和矮窗口布局。Flutter analyze 无 issue，68 项 Flutter 测试和 13 项 Node 测试通过，正式 Release 构建成功。

部分完成：运行图集和固定锚点已可用，独立真实透明 PNG 仍待导出。两次图像生成实际输出 RGB，采用 Flutter 轮廓裁切接入，未将棋盘格当作透明。浏览器与平台验收边界详见 `docs/web-plush-acceptance.md`，后续联调按 `docs/next-development.md` 推进。

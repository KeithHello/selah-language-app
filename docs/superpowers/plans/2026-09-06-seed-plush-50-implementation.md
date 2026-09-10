# C 短绒五阶段五十动作接入计划

> **For agentic workers:** 使用 subagent-driven-development，按下面有明确文件边界的任务执行。主人已确认五阶段 V3 外形，明确授权并行生成全部五十张图片、更新程序和网站；本计划记录已授权工作的执行方式。

**Goal:** 五阶段各十张独立动作图全部生成、核验，当前 Flutter 程序与 Web 正式渲染按成长阶段和真实业务动作选择正确素材，并报告上线缺口。

**Architecture:** 沿用现有 DecorationStage 和 SpriteActionId，以及业务事件与 revision。新增单一纯映射目录，以真实生成的完整角色姿态替换旧图集／五官拼装。每张是独立动作状态关键图，状态变化时短暂淡入，轻微整体位移；不将十张不同动作循环当逐帧动画。Reduce Motion 保持对应姿态并停止动画。优先生成真实透明 PNG；若工具输出 RGB，先反馈实际格式并针对背景方案验证，不宣称透明已完成。

**Tech Stack:** 现有 Flutter／Dart、内置 image_gen、Windows PowerShell／System.Drawing；不新增 Flutter、全局依赖、图像 API 或运行时。

## 约束与文件契约

- 设计基准：`design-system/selah/mascot/seed-c-growth-v3-all-assets.json` 中的五张 V3 母版；各阶段只参考自己的母版。
- 单阶段十种动作按 `SpriteActionId.values` 顺序：gentleFloat、blink、leafSway、listenEnter、listenPlaying、listenComplete、recRecording、recDone、quizGood、quizFail。
- 设计稿命名：`design-system/selah/mascot/seed-c-s{stage}-a{01..10}-v4.png`；运行资源：`SelahFlutter/assets/sprites/PlushV4S{stage}A{01..10}.png`。stage 为 1—5，动作编号为两位数，平铺既有目录。
- 第一阶段保留已认可的十种姿态意图，按最新小折芽外形重绘。其余阶段均设计自己的站坐、重心、手势与表情，不仅换头顶装饰。无长叶披肩，无尖高花帽，不添加手指／拇指／额外肢体。
- 每图一次独立内置 image_gen 调用，可分批并行；先 view_image 检查本地参考。原件保留，副本无脚本改形或抠图；真实尺寸与色彩类型写清。
- 新规范取代早期仅出图不接入、固定旧图集的范围限制。本轮不改业务成长阈值、账户、学习记录或服务合约，不修改 schema、密钥、CI，不公开部署。
- 文件所有权：根代理负责阶段一、全局规范、汇总文档、缓存／构建／浏览器验收；图像代理分别负责阶段二三和四五的 PNG 与各自提示词／manifest；实现代理负责角色渲染、原生 Flutter 展示复用、gallery 和相关 Flutter 测试。不要覆盖其他人的修改。

## Task 1：生成与审核五十张动作素材

**Files:** 上述五十张设计 PNG、五十张运行 PNG，阶段提示词 `prompts-c-actions-v4-sN.md` 与元数据 `seed-c-actions-v4-sN-assets.json`。

- [x] 第一阶段透明待机试稿实测 RGB，带绘制棋盘格，弃用。后续采用已确认的暖白背景完整姿态图，公共约束见 `design-system/selah/mascot/prompts-c-actions-v4-common.md`；透明分层素材继续列为未完成，不能伪称 RGBA。
- [x] 根代理生成第一阶段十图；图像代理一生成第二、第三阶段；图像代理二生成第四、第五阶段。每次最多并行四张。
- [x] 逐图目视：阶段植物结构不漂移、姿态区分、四肢正确、全身无裁切、材质与五官一致；发现问题仅针对问题重绘。
- [x] 核验真实 PNG 解码、尺寸、色彩模式、透明像素分布、五十个唯一哈希，以及设计／运行副本与原件一致。汇总 manifest 与五阶段十动作审阅页。

## Task 2：程序与 Web 角色状态接入

**Files:** `SelahFlutter/lib/web/ui/plush_companion.dart`、新 `plush_companion_poses.dart`、现有 Flutter 精灵展示组件、`tool/preview_plush.dart`、相关 `test/plush_companion_test.dart` 与新姿态映射测试。

**Interfaces:** `String plushPoseAsset(DecorationStage stage, SpriteActionId action)` 返回 `assets/sprites/PlushV4S${stage.index + 1}A${(action.index + 1).toString().padLeft(2, '0')}.png`。映射封装后两处客户端共用，业务枚举不改。

- [x] 先写五十组合唯一映射、阶段变化、动作／revision 更新、Reduce Motion 正确姿态、后台停止和无反复反馈的测试，观察旧实现缺口。
- [x] 接入独立完整姿态，保留真实播放／录音／练习事件触发；不用旧图集裁切或原生绘制五官覆盖新图。
- [x] 验证自然姿态切换及加载稳定性，避免先显示错误成长阶段。资源按实际使用加载，不一次预加载五十张。
- [x] 将现有正式 gallery 改为可选择五阶段并查看各十动作，重播及减少动态效果使用正式组件。
- [x] 跑针对性测试与 analyze，交根代理审查，不执行公开部署。

## Task 3：整体验收与上线缺口

**Files:** PWA 缓存／构建脚本的必要局部修改、`docs/web-plush-50-acceptance.md`、`docs/next-development.md`、`ROADMAP.md`。

- [x] 检查完整资源覆盖及实际体积，避免 PWA 安装一次下载所有未来阶段。对修改的缓存逻辑跑相关 Node 测试。
- [x] 跑 Flutter analyze、全部 Flutter 测试、Node 浏览器桥测试、正式 Web 与 gallery Release 构建。
- [ ] 在本地程序／网站验证五阶段十动作可见、真实事件切换、缩略图／窄屏、Reduce Motion、离线及更新；桌面正式流程、五阶段预览及 Reduce Motion 已通过，本轮真实断网、旧来源更新和设备级记录保留仍列为发布门禁。
- [x] 复核现有真实后端可达性和部署源码证据，区分已完成本地工作与上线前真实认证／AI／TTS／转写／同步、种子音频、设备和 HTTPS 发布条件。
- [x] 写实际结果与限制，更新真实 Roadmap，不将静态关键图计作完整骨骼／逐帧动画或将本地运行计作生产发布。

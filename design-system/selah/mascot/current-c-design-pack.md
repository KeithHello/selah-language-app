# 当前角色设计包：C 短绒织物

日期：2026-09-05。当前采用 C「短绒织物」；D「磨砂琥珀」保留为以后开发其他吉祥物时的候选。

最新状态（2026-09-06）：五阶段统一外形已获确认，五个阶段各十张正式动作图均已生成、核验并接入程序与网站。设计与运行副本共 50 组，均为 1254 × 1254 RGB PNG；完整结果见 [五阶段五十动作总览](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-actions-v4-all-review.png) 和 [本地验收记录](E:/develop/self-dev/workbuddy/language-study/docs/web-plush-50-acceptance.md) 。

本包保留已获批的角色设定、首批十状态参考及 C 单独页面模拟。三张参考图均为 1536 × 1024，已做目视、PNG 完整性与复制哈希核验，尚非透明运行素材。获批后已完成 Web 接入，真实效果见下方运行记录。

## 当前真实运行效果

正式页面按成长阶段和业务动作选择独立完整姿态，不再使用旧图集裁切或叠加五官。当前本机正式服务为 `http://127.0.0.1:5181/`；本轮另用 `http://127.0.0.1:5191/` 验收正式构建、`http://127.0.0.1:5192/` 验收五十动作预览。两个验收端口的后台服务已保留，预览可切换五阶段、重播动作或开启减少动态效果。

![五阶段五十动作正式总览](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-actions-v4-all-review.png)

以下两张为 2026-09-05 的旧运行截图，仅保留布局与改版历史，不代表当前五十姿态形象。

![旧版 Web 的 C 与圆形悬浮开始操作](E:/develop/self-dev/workbuddy/language-study/output/playwright/selah-c-web.png)

![旧版组件的十动作与成长装饰](E:/develop/self-dev/workbuddy/language-study/output/playwright/selah-c-states.png)

## 角色设定

燕麦奶油色短绒身体、深棕刺绣五官、鼠尾草绿叶，保持圆润种子轮廓、小手脚和安静陪伴的气质。正面以主人选定的 V4 C 图为身份基准；侧面和背面用于补充结构理解，不代表已经建立或验证了 3D 模型。

![C 短绒织物角色设定图](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-design-sheet-v1.png)

## 十状态参考

覆盖待机、眨眼、叶片轻摆、准备聆听、播放中、聆听完成、录音中、录音完成、复习顺利、再试一次。动作沿用项目现有十个枚举；V4 的「休息」只保留作表情补充。

各状态用眼神、小手动作及叶片微动表达变化，身体比例和连接位置是后续实现约束。当前图是静态外观参考，不能直接作为逐帧动画轮播。

![C 短绒织物十状态参考](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-states-v1.png)

## 页面效果

展示设计阶段 C 放在双语选择列表旁边时的阅读关系。页面内是演示文案，图中明确标注为静态模拟；正式网页和悬浮按钮效果以本页顶部运行截图为准。

![C 短绒织物页面放置模拟](E:/develop/self-dev/workbuddy/language-study/design-system/selah/mascot/seed-c-page-preview-v1.png)

## 交接状态

| 项目 | 当前状态 |
| --- | --- |
| C 作为本阶段角色方向 | 主人已选定 |
| 角色设定、十状态与页面参考 | 已整理并核验 |
| 五阶段各十张独立姿态 | 50 张已生成，尺寸、RGB 类型、唯一哈希及副本一致性通过 |
| 程序与 Web 映射 | 正式 Web、原生 Flutter 展示和开发 Gallery 共用同一阶段／动作映射 |
| 独立透明 PNG、裁边与多分辨率发布素材 | 仍待导出；当前 50 张均为带暖白背景的 RGB PNG |
| C 接入 Web 与十动作触发 | 已实现，79 项 Flutter、17 项 Node 与本地浏览器验收通过 |
| 窄屏／宽屏、真实播放反馈及 Reduce Motion | 本地验证通过；真机与真实转写仍待验收 |
| D 作为其他吉祥物候选 | 已加入 Roadmap，本阶段不开发 |

早期三张设计参考图和当前五十张运行姿态均为带背景 RGB PNG，没有透明通道。当前运行版直接显示完整姿态，未用脚本抠图，也未把十张静态关键姿态当作逐帧序列。各阶段原始提示词与生成记录见 `prompts-c-actions-v4-s1.md` 至 `prompts-c-actions-v4-s5.md` 及对应 manifest。

角色约束见 `docs/superpowers/specs/2026-09-05-seed-plush-character.md`；实际提示词见本目录 `prompts-c-design-pack.md`；下一阶段任务见 `docs/next-development.md`，真实进度以根 `ROADMAP.md` 为准。

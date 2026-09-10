# Selah Flutter 与 Web 开发约定

遵循上级 `CLAUDE.md`。Web 产品代码采用 `lib/web/domain/`、`lib/web/data/`、`lib/web/platform/`、`lib/web/ui/` 结构，`learning_controller.dart` 负责流程，`web_entry.dart` 负责启动。`web/` 仅放浏览器桥接、入口和 PWA 资源。

现有 `lib/app/` 与原生 SQLite 保持为旧 Flutter 客户端入口，Web 不得导入其 Fixture 或数据库。共享现有精灵素材、设计 token 和必要的展示枚举。规范数据以 Swift 与 Supabase 当前实际字段为准。

本轮沿用暖米色 `#FBF8F4`、珊瑚 `#E06B54`、薰衣草和鼠尾草色，与当前 Flutter 产品一致；设计文件中的通用靛蓝／儿童字体生成内容不作为 Web 品牌依据。

当前 Web 吉祥物采用已选 C「短绒织物」外观，遵循根目录所指角色规范。2026-09-06 主人已确认五阶段 V3 外形，并授权五阶段各十张动作图接入程序与网站；按新计划以阶段／动作映射的完整姿态图替代旧 RGB 图集裁切与原生五官覆盖，现有 Flutter 客户端的角色展示复用同一资源与映射。姿态切换配短暂过渡和微动效，不作为逐帧动画轮播，Reduce Motion 保持对应静态姿态。真实色彩模式及透明度必须核验，不能将 RGB 记为透明素材。D「磨砂琥珀」继续保留为后续候选，不增加角色切换、额外运行时或依赖。

不得新增 Flutter 或全局依赖。优先复用现有 Supabase SDK、just_audio 和 Dart 标准库；浏览器标准 API 用 `dart:js_interop` 接入。测试替身必须位于测试代码，产品不能以固定英文、假音频完成或假同步充当真实成功。

测试命令：`flutter analyze`、`flutter test`、`flutter build web --release`。改动前明确无效输入、边界与期望；修改后跑对应测试。生产配置、schema、密钥、CI 和发布仍需独立确认。

2026-09-10 界面与设置实施：主人已授权按计划完整实施正式 Web。默认繁体中文 `zh-Hant`，支持简体中文 `zh-Hans` 与日语 `ja` 界面，以及中文／日语母语，均按本机保存。应用文案、启动页、系统弹窗与可访问名称纳入验收；界面切换不改用户句子，母语切换只作用于新的输入／转写／生成。本阶段使用纯 Dart 文案表与现有字体，不新增依赖；日语源语言 prompt 与合约随本次服务端改动验证。数据库 schema、密钥、CI、公开部署和循环听仍需独立授权。

2026-09-10 会员、试用与费用保护规划：主人已认可免费示例、7 天限额试用与 39.9 元月会员，并要求整理最终开发计划与 UI／UX 展示。本阶段只新增设计、计划与独立展示稿，不改产品代码、测试、数据库、支付、配置或部署。日常界面不展示剩余额度；生成入口与方案页需说明实际使用 OpenAI GPT，配音另披露 AI 合成。实施依据见上级 CLAUDE.md 与 docs/superpowers/plans/2026-09-10-membership-cost-control-plan.md。

2026-09-10 笔记 B1＋B2 实施：主人已明确要求按计划完整开发完整双语卡片、按词释义和原卡片展开拆解；允许修改正式 Web 笔记代码、对应测试与验收文档，不新增依赖、数据表或云端字段，不恢复成长回忆入口。实施依据见上级 CLAUDE.md 与 docs/superpowers/plans/2026-09-10-notes-b1b2-plan.md。

# Selah — 开发路线图

> 最后更新：2026-07-08
> 资料来源：selah-v8-unified-design-spec.md + selah-v8-ios-architecture.md
> 工程审查：CodeBuddy MCP deepseek-v4-pro（2026-07-08）

---

## 当前阶段：设计完成，待开发启动

项目处于从设计到实现的过渡期。v8 设计冻结，工程架构已定义，但尚未编写任何 iOS/SwiftUI 代码。以下前置准备工作需要用户（Kou）在开发启动前完成。

---

## 前置准备（开发启动前，用户完成）

### P0 — 必须

| 项目 | 状态 | 说明 |
|------|------|------|
| 后端技术栈选定 | ❌ 待定 | API Gateway + Worker 的技术方案（Supabase Edge Functions / Cloudflare Workers / 自建） |
| 翻译 LLM Provider 选定 | ❌ 待定 | 主选 + 备选方案，考虑成本与质量 |
| TTS Provider 选定 | ❌ 待定 | 需支持 v8 三种声线映射（温柔自然 / 清晰慢速 / 日常轻快） |
| Apple Developer 帐号 | ❌ 待定 | 确认开发者计划会员有效 |
| 种子句音频预生成 | ❌ 待定 | 需 15-30 句种子句 × 3 种声线 × 离线音频 |

### P1 — 建议

| 项目 | 状态 | 说明 |
|------|------|------|
| SwiftData 迁移策略 | ❌ 待定 | 定义 schema 版本化方案（SwiftData 迁移工具不成熟） |
| 同步策略决策 | ❌ 待定 | 无同步（MVP）/ iCloud / 自定义后端同步，会影响数据模型设计 |
| 冷启动种子句内容 | ❌ 待定 | 15-30 句英文种子句（6 类场景覆盖，含翻译 + 拆解 + 词汇） |
| 审核计划 | ❌ 待定 | 间隔重复算法的具体参数（SM-2 变体 或 自定义） |

---

## 里程碑路线图

### M0 — 原生原型壳（参考 v8 架构 M0）

**目标**：可运行的 SwiftUI App，全部画面用 Mock 数据可走通。

**预估**：2-3 周 | **前置**：P0 后端 / 种子句内容

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| Xcode 项目初始化（SwiftUI, iOS 17+） | ❌ | App shell + 2 Tab（今日/笔记）+ Push Navigation |
| SwiftData Schema 建立 | ❌ | Sentence / VocabItem / ReviewState / AudioAsset / GenerationJob / Companion / SpriteMemory / UserPreference |
| Design Tokens 实现 | ❌ | Color / Font / Spacing / Corner Radius / Shadow 的 Swift extension |
| Component Library 实现 | ❌ | iOSRow / Badge / CatChip / QuizCard / DeconstructBlock / VocabPopup / CoachHint / ProgressBar / StageBar / PetView |
| Today 画面 Mock | ❌ | 精靈 + 時間問候 + 智能推薦卡 + 推薦理由預覽 + 手動入口 |
| Today Sentence 画面 Mock | ❌ | 中文输入 → 确认 → 生成进度 → 英文结果 → 保存 |
| Listen 画面 Mock | ❌ | 聆听 → 预测 → 拆解 → 跟读，4 步沉浸式卡片 |
| Practice 画面 Mock | ❌ | 翻卡回忆 + 三选自评，3 句一组 |
| Night Preview 画面 Mock | ❌ | 3-5 句预览 + 词汇提示 |
| Notes 画面 Mock | ❌ | 句子列表 + 分类筛选 + 生词摘要 + 小豆回忆 |
| Settings 画面 Mock | ❌ | 声线选择 + 通知开关 |
| Onboarding 画面 Mock | ❌ | 语言选择 → 宠物命名 → 种子句选择 → 孵化动画 |
| Mock 服务层 | ❌ | MockSentenceGenerationService / MockAudioGenerationService / MockSpeechRecognitionService |
| 本地任务队列 Schema | ❌ | GenerationJob 实体的读写逻辑 |
| Companion 仓库（多宠就绪） | ❌ | CompanionRepository 协议 + 单活跃精灵实现 |

---

### M1 — 真实句子创建（参考 v8 架构 M1）

**目标**：用户可以输入中文、获得 AI 翻译英文、保存句子。

**预估**：3-4 周 | **前置**：M0 + 后端 API 可用 + LLM Provider 选定

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| iOS 语音识别集成 | ❌ | SFSpeechRecognizer + 中文识别 → 可编辑文字 |
| 后端 /v1/sentences/generate 实现 | ❌ | 中文 → 自然英文 + 词汇建议 + 拆解数据 + 分类 |
| 后端 /v1/audio/generate 实现 | ❌ | 英文文字 + 声线 → TTS 音频文件/URL |
| 后端 /v1/config/bootstrap 实现 | ❌ | 声线列表 + 种子句包 + Prompt 版本 + Feature Flags |
| SelahAPIClient 实现 | ❌ | iOS 端的 HTTP 客户端，含 token/retry |
| SentenceGenerationService 真实实现 | ❌ | 协议实现，调用后端 API |
| AudioGenerationService 真实实现 | ❌ | 协议实现，调用后端 API，含持久化任务队列 |
| Today Sentence 全流程接通 | ❌ | 中文输入 → API 翻译 → 本地保存 → 后台 TTS → 播放按钮 |
| 声线选择 UI | ❌ | 在 Today Sentence 或 Settings 中选择/试听声线 |
| 音频本地缓存 | ❌ | FileManager 缓存 + LRU 淘汰 + 大小上限（200MB） |
| 生成重试队列 | ❌ | 持久化 Job Queue + 指数退避 + 最大重试 |
| 内容审核 | ❌ | 用户句子送 AI 前做基本安全检查 |
| 速率限制 + 用量记录 | ❌ | 后端每用户每日请求上限，前端超限提示 |
| 中文确认步骤 | ❌ | STT 结果 → 用户编辑 → 确认 → 发送翻译（非直接发送） |

---

### M2 — 真实聆听与音频（参考 v8 架构 M2）

**目标**：用户可以完整经历聆听四步流程，音频生成可靠。

**预估**：2-3 周 | **前置**：M1 + TTS Provider 选定

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| AudioPlaybackService 完整实现 | ❌ | 播放、暂停、速度控制（0.7x/0.85x/1.0x/1.2x 循环）、A-B 循环 |
| 音频状态机 | ❌ | queued → translating → TTS → ready / failed |
| 音频生成分步处理 | ❌ | 翻译成功但 TTS 失败时句子仍可用，文本 + IPA 替代 |
| 音频去重 | ❌ | 相同句子 + 相同声线 → 复用已有文件 |
| 文件完整性校验 | ❌ | 下载后校验音频文件，损坏则重试 |
| 音频后台生成弹性 | ❌ | BGTaskScheduler + 前台恢复续传 |
| 音频生成取消 | ❌ | 用户删除句子 → 取消等待中的音频任务 |
| 聆听全集构建 | ❌ | 按句子状态构建 3 句聆听集 |
| 上下文桥接 | ❌ | 聆听完成后 → 可选「顺手续 3 句」的软引导 |
| Practice 仅允许已聆听句子 | ❌ | Practice 选题：previewed + listened 的句子 |
| 手动音频重生成入口 | ❌ | 已有句子的「重新生成语音」按钮 |
| Seed 音频离线捆绑 | ❌ | 15-30 句种子句的音频预置在 App 内（首启无需网络） |

---

### M3 — 学习引擎（参考 v8 架构 M3）

**目标**：间隔重复 + 智能推荐 + 词汇帮助规则全部运作。

**预估**：2-3 周 | **前置**：M2

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| ReviewScheduler 实现 | ❌ | 明确间隔：clear → 3 天后 / almost → 明天 / failed → 今天或明天 |
| 衰减处理 | ❌ | familiar → failed → 退回 learning，明天复习 |
| 安静句唤醒 | ❌ | quiet 的句子偶尔出现在混合复习中 |
| RecommendationEngine 实现 | ❌ | 状态优先 + 时间辅助的推荐逻辑（5 条规则链） |
| 推荐理由预览 | ❌ | 「为什么是这一步？」区域，2-3 条温暖文案 |
| 上下文学习集 | ❌ | 不强制日程，根据句子状态自然衔接 |
| 可扩展会话 | ❌ | 小量默认 → 温和完成点 → 可选继续 |
| VocabularyHelpUseCase 实现 | ❌ | 系统轻建议 + 行为驱动隐藏/再显示 + 用户手动添加/移除 |
| 生词状态转换规则 | ❌ | new→learning→familiar→owned 的自动转换逻辑 |
| 拆解中的生词显示规则 | ❌ | 仅显示 unfamiliar 词汇，familiar 词汇可点但不展开 |
| SpriteMemoryUseCase 实现 | ❌ | 首次盲听猜对 / 主动用词 / 句子从卡到顺 等里程碑 |
| Night Preview 列队 | ❌ | 基于内容池状态构建 3-5 句预览 |

---

### M4 — 产品打磨（参考 v8 架构 M4）

**目标**：健壮性、隐私、账号、发布准备。

**预估**：2-3 周 | **前置**：M3

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| 错误恢复完整实现 | ❌ | Provider 健康检查 + 熔断器 + 优雅降级（TTS 失败 → 文本 + IPA） |
| 离线处理 | ❌ | 离线 Banner + 禁用需网操作 + 本地队列持久化 |
| 本地通知 | ❌ | 复习提醒 + 温和文案 |
| Widget 就绪数据摘要 | ❌ | Today Widget 的数据源架构 |
| 无障碍 | ❌ | VoiceOver 标签 + Dynamic Type + 色彩不单独表意 |
| 本地化 | ❌ | 所有 UI 文字繁体中文 |
| Crash Reporting | ❌ | 集成崩溃报告工具 |
| Analytics Dashboard | ❌ | 学习留存率 + 学习效果指标 |
| 隐私政策 | ❌ | 句子处理说明 + 数据留存政策 + Provider 日志脱敏 |
| Apple Sign In（可选） | ❌ | 如需跨设备同步或 IAP 则必须 |

---

### M5 — 发布准备

**目标**：TestFlight + App Store 审核。

**预估**：2-3 周（含等待） | **前置**：M4

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| App Icon | ❌ | 1024×1024 |
| App Store 截图 | ❌ | 6.7 寸 + 5.5 寸各 5 张 |
| App 描述（中/英） | ❌ | 含关键词 |
| TestFlight 内部测试 | ❌ | 邀请 3-5 人 |
| Bug 修复 | ❌ | 根据反馈修复 |
| App Store 审核提交 | ❌ | 填表 + 提交 + 处理反馈 |
| 🚀 正式发布 | ❌ | |

---

## 设计资产状态

| 资产 | 状态 |
|------|------|
| 互动原型（selah-prototype-v7.html） | ✅ 完成，已审计并通过 |
| v8 统一设计规格 | ✅ 完成（archive/selah-v8-unified-design-spec.md） |
| v8 iOS 架构设计 | ✅ 完成（archive/selah-v8-ios-architecture.md） |
| iOS 设计规格（Design Tokens + 组件库） | ✅ 完成（selah-ios-design-spec.md） |
| 用户故事（18 Stories） | ✅ 完成（selah-user-stories.md） |
| 宠物流派方向（pet-concept-C.png） | ✅ 已选定 |
| 种子精灵多角度图（5 张） | ✅ 完成（seed-image/） |
| 种子动画参考样片（3 个 MP4） | ✅ 完成（seed-animations/） |
| 宠物流 Lottie/Rive 动画 | ❌ 待制作 |
| App Icon | ❌ 待设计 |
| App Store 截图 | ❌ 待制作 |

---

## 关键设计决策（v8 确认，不可回退）

以下从早期 PRD v1.2 继承的复杂系统已在 v8 明确废弃：

- ❌ 可见 XP / 连续天数 / 四维宠物状态 / 宠物死亡复活
- ❌ Smart Excel L0-L5 标签 / 六边形覆盖度雷达图
- ❌ 五 Tab 导航 / Daily Win+Goodnight 独立概念 / Clinking 独立功能
- ❌ Onboarding 中声线选择（改为默认声线 + 后续调整）
- ❌ 微型输出挑战独立模式
- ❌ ElevenLabs 6 音色全局设定（改为 3 种用户感知声线映射）

---

## 依赖关系图（简化）

```
P0 前置完成
  ├── M0 原生原型壳
  │     └── M1 真实句子创建 ← P0 后端 + LLM Provider
  │           └── M2 真实聆听与音频 ← P0 TTS Provider
  │                 └── M3 学习引擎
  │                       └── M4 产品打磨
  │                             └── M5 发布准备 → 🚀
  └── 种子句内容准备 ──────────→ M2（音频离线捆绑）
```

## 工程审查发现的关键风险（CodeBuddy MCP deepseek-v4-pro）

| 风险 | 严重度 | 建议 |
|------|--------|------|
| 冷启动仅 3 句种子句 | 🔴 高 | 改为 15-30 句，音频预置于 App 二进制 |
| 间隔重复缺少具体参数 | 🔴 高 | 定义每个状态的明确天数和切换规则 |
| SwiftData 迁移方案未定义 | 🟡 中 | v1 发布前定义 schema 版本化策略 |
| 同步策略悬而未决 | 🟡 中 | 决策前会影响数据模型设计，尽早锁定 |
| 异步音频生成缺少持久化队列 | 🟡 中 | 需持久化 Job Queue + 状态机 + 重试 |
| Provider 降级仅依赖 JSON | 🟡 中 | 需健康检查 + 熔断器 + 优雅降级 |
| 后台任务预算受限 | 🟢 低 | iOS BGTaskScheduler 30 秒限制，长生成需前台续传 |

# Selah - 开发路线图

> 最后更新：2026-07-14 22:50
> 资料来源：selah-v8-unified-design-spec.md + selah-v8-ios-architecture.md
> 工程审查：CodeBuddy MCP deepseek-v4-pro（2026-07-08）

---

## 当前阶段：M3 学习引擎接线完成，进入 M4 产品打磨

### 已完成

| 项目 | 状态 | 说明 |
|------|------|------|
| v8 设计冻结 | ✅ | 统一设计规格 + iOS 架构设计 |
| M0 iOS 原型壳 | ✅ | 22 Swift 源文件，39 编译单元，GitHub Actions CI 通过 |
| 单元测试（iOS） | ✅ | 9 测试文件，150+ 用例 |
| Supabase 后端 | ✅ | 11 表 Migration + RLS + 4 Edge Functions + 6 测试文件 |
| 种子句内容 | ✅ v2 | 30 句（繁体中文、网络流行语、年轻人真实口语），含完整翻译+拆解+词汇 |
| LLM System Prompt | ✅ | v8 翻译引擎定义 + JSON Schema |
| TTS 音色选定 | ✅ | nova/sage/ash/shimmer 映射到 3+1 种用户感知声线 |
| 后端技术栈 | ✅ | Supabase（已确认连通） |
| 翻译 LLM | ✅ | GPT-4o-mini（Edge Function 已集成） |
| TTS Provider | ✅ | OpenAI TTS tts-1（4 音色已映射） |
| Supabase 项目 | ✅ | 已创建，URL + Keys 已配置 |
| 部署脚本 | ✅ | 合并 Migration SQL + seed import Deno 脚本 + deploy 指南 |

### 待完成

| 项目 | 状态 | 说明 |
|------|------|------|
| Apple Developer 帐号 | ❌ | $99/年，TestFlight 必须 |
| OpenAI API Key | ✅ | 已提供，gpt-4o-mini + tts-1 已測試連通 |
| Supabase 部署權限 | ✅ | Access Token 已提供，Migration + Edge Functions + 種子句均已部署 |
| 种子句音频预生成 | ❌ M2 前 | 30 句 × 3 声线 = 90 mp3 |

---

## 里程碑路线图

### M0 - 原生原型壳 ✅ 完成

**目标**：可运行的 SwiftUI App，全部画面用 Mock 数据可走通。

| 任务 | 状态 |
|------|------|
| Xcode 项目初始化（SwiftUI, iOS 17+） | ✅ |
| SwiftData Schema 建立（9 实体） | ✅ |
| Design Tokens 实现 | ✅ |
| Component Library 实现（13 组件） | ✅ |
| Today 画面 Mock | ✅ |
| Today Sentence 画面 Mock | ✅ |
| Listen 画面 Mock | ✅ |
| Practice 画面 Mock | ✅ |
| Night Preview 画面 Mock | ✅ |
| Notes 画面 Mock | ✅ |
| Settings 画面 Mock | ✅ |
| Onboarding 画面 Mock | ✅ |
| Mock 服务层 | ✅ |
| 本地任务队列 Schema | ✅ |
| Companion 仓库（多宠就绪） | ✅ |
| GitHub Actions CI（macos-15, swift build） | ✅ |

---

### M1 - 真实句子创建

**目标**：用户可以输入中文、获得 AI 翻译英文、保存句子。

**前置**：M0 ✅ + 后端 API ✅ + OpenAI API Key ✅ + Supabase 部署權限 ✅

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| 后端 /v1/sentences/generate | ✅ | 已部署，GPT-4o-mini + v8 Prompt，測試 200 OK |
| 后端 /v1/audio/generate | ✅ | 已部署，OpenAI TTS + 3 声线映射，測試 200 OK |
| 后端 /v1/config/bootstrap | ✅ | 已部署，返回 30 句種子句 + 聲線配置，測試 200 OK |
| 后端 /v1/events | ✅ | 已部署，事件白名單驗證，測試 201 OK |
| Migration SQL + RLS | ✅ | 已執行至 DB，11 表 + 完整 RLS Policy |
| Edge Functions 部署到 Supabase | ✅ | 4 個端點全部部署完成 |
| Migration 執行到 Supabase DB | ✅ | 001 + 002 已執行 |
| 種子句匯入 seed_sentences | ✅ | 30 句已匯入，DB 驗證 count=30 |
| SelahAPIClient 实现 | ✅ | iOS HTTP 客户端 + Supabase Auth + 401 自動刷新 |
| SentenceGenerationService 真实实现 | ✅ | actor 實作，轉調 API Client |
| AudioGenerationService 真实实现 | ✅ | actor 實作，轉調 API Client |
| M1 測試 | ✅ | APIClient + Service Implementations；M3 回歸契約已補齊，GitHub Actions 215 tests：0 failures |
| iOS 语音识别集成 | ✅ | SpeechRecognitionServiceImpl（SFSpeechRecognizer zh-Hant-TW + #if os(iOS) 守衛） |
| Today Sentence 全流程接通 | ✅ | 完整狀態機：idle->recording->confirming->translating->reviewing->saving->done + 錯誤重試 |
| 声线选择 UI | ✅ | VoiceProfilePicker（4 種聲線含 shimmer 進階選項）+ SettingsView 默認聲線 |
| M1 前端測試 | ✅ | VoiceProfile + FlowState 測試 |
| 音频本地缓存 | ✅ | AudioCacheService：Application Support、SHA-256、原子寫入、100 MB LRU |
| 生成重试队列 | 🟡 部分完成 | GenerationJob 指數退避與 SwiftData repository 已接線；BGTaskScheduler 留 M4 |

---

### M2 - 真实聆听与音频

**目标**：用户可以完整经历聆听四步流程，音频生成可靠。

**前置**：M1 + TTS Provider ✅

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| AudioPlaybackService 完整实现 | ✅ | AVFoundation 實作、播放/暫停/seek/四速/A-B loop；真機中斷驗收待 Xcode |
| 音频状态机 | ✅ | manifest + AudioAsset 支援 queued -> generating -> ready / failed |
| 音频生成分步处理 | ✅ | AudioDeliveryCoordinator：句子保存不等待 TTS，失敗不回滾句子 |
| 音频去重 | ✅ | SHA-256 content hash + scope 唯一 manifest，cache hit 直接 signed URL |
| 文件完整性校验 | ✅ | HTTP、最小大小、預期大小、SHA-256、原子 move |
| 音频后台生成弹性 | 🟡 部分完成 | 持久化 job schema/指數退避已有；BGTaskScheduler 需 Xcode target/background mode |
| 聆听全集构建 | ✅ | ListenCollectionBuilder：今日新句 -> preview 未聽 -> due，最多 3 句 |
| 上下文桥接 | ✅ M3 | RecommendationEngine 已提供 listen/practice/preview 後的下一步建議 |
| Practice 仅允许已聆听句子 | ✅ M3 | SwiftData 題庫只接收 isPracticeReady 的句子；評分寫回 ReviewScheduler |
| 手动音频重生成 | ✅ 基礎層 | AudioDeliveryCoordinator.regenerate 保留舊檔直到新檔驗證；UI 入口留下一輪 |
| Seed 音频离线捆绑 | 🟡 已就緒 | 120 檔 prebuild dry-run 通過；實際 OpenAI 生成須主人另行確認成本 |

---

### M3 - 学习引擎

**目标**：间隔重复 + 智能推荐 + 词汇帮助规则全部运作。

**前置**：M2

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| ReviewScheduler 实现 | ✅ 已有 Swift 实现 | clear->3天 / almost->明天 / failed->今天 |
| RecommendationEngine 实现 | ✅ 已有 Swift 实现 | 5 条规则链，状态优先 |
| VocabularyHelpUseCase 实现 | ✅ 已有 Swift 实现 | 系统建议+行为驱动隐藏/再显示 |
| SpriteMemoryPresets | ✅ 已有 Swift 实现 | 30 个回憶預設 |
| 推荐理由预览 | ✅ M3 | Today 動態顯示推薦理由與最多 2 條明細 |
| 上下文学习集 | ✅ M3 | TodayRecommendation + BridgeSuggestion 依學習狀態銜接，不強制日程 |
| 生词状态转换规则 | ✅ 已有 Swift 实现 | new->learning->familiar->owned |
| Night Preview 列队 | ✅ M3 | SwiftData 依未預覽、個人句子與建立時間建立佇列 |

---

### M4 - 产品打磨

**目标**：健壮性、隐私、账号、发布准备。

**前置**：M3

| 任务 | 状态 |
|------|------|
| 错误恢复 + 熔断器 | ✅ M4-A | Typed error classification、3 次有界重試、句子／音頻獨立 circuit breaker、GenerationJob 中斷恢復；CI run 29255430137 通過 |
| 离线处理 | ✅ M4-B | ConnectivityMonitor、離線翻譯阻斷、待處理音訊 GenerationJob、AppState online-only retry；CI run 29258705736 通過 |
| 本地通知 | ✅ M4-C 核心层 | 可注入排程／撤销、HH:mm 解析与隐私安全文案；iOS UserNotifications adapter 已条件编译，CI run 29298637595 通過，真机权限验收待 Xcode |
| Widget 就绪 | ✅ M4-C Widget-ready | Codable 摘要契约、计数构建器、文本边界与隐私约束；未创建 WidgetKit target，CI run 29298637595 通過 |
| 无障碍 | ✅ M4-C 核心层 | VoiceOver 语义辅助、Reduce Motion 策略、Dynamic Type 缩放与 WCAG 对比度 helpers；CI run 29298637595 通過，完整 iOS UI 审计待 Xcode |
| 隐私政策 | ✅ M4-D 核心层 | 隐私与发布边界文档、Edge Functions/App 层敏感错误脱敏已完成；CI run 29338902674 通过；真实 Xcode 权限与 App Store Connect 隐私问卷验收待 M5 |

---

### M5 - 发布准备

**目标**：TestFlight + App Store 审核。

**前置**：M4 + Apple Developer 帐号

| 任务 | 状态 |
|------|------|
| App Icon | ❌ |
| App Store 截图 | ❌ |
| TestFlight 测试 | ❌ |
| App Store 审核提交 | ❌ |
| 🚀 正式发布 | ❌ |

---

## 设计资产状态

| 资产 | 状态 |
|------|------|
| 互动原型 | ✅ 已审计并通过 |
| v8 统一设计规格 | ✅ |
| v8 iOS 架构设计 | ✅ |
| iOS 设计规格 | ✅ |
| 用户故事（18 Stories） | ✅ |
| 宠物流派方向 | ✅ pet-concept-C.png |
| 种子精灵多角度图（5 张） | ✅ |
| 种子动画参考样片（3 个 MP4） | ✅ |
| 30 句种子句数据 | ✅ |
| LLM System Prompt | ✅ |
| Supabase Migration + RLS | ✅ |
| 4 Edge Functions | ✅ |
| 宠物 Lottie/Rive 动画 | ❌ |
| App Icon | ❌ |
| App Store 截图 | ❌ |

---

## 工程审查发现的关键风险（CodeBuddy MCP deepseek-v4-pro）

| 风险 | 严重度 | 状态 | 建议 |
|------|--------|------|------|
| 冷启动种子句不足 | 🔴 高 | ✅ 已解决 | 已扩充到 30 句 |
| 间隔重复缺少参数 | 🔴 高 | ✅ 已解决 | ReviewState 已定义明确天数 |
| SwiftData 迁移方案 | 🟡 中 | ❌ 待定 | v1 发布前定义 |
| 同步策略 | 🟡 中 | ✅ 已决定 | MVP 无同步，local-first |
| 异步音频生成队列 | 🟡 中 | ✅ 已解决 | GenerationJob 持久化队列已实现 |
| Provider 降级 | 🟡 中 | ❌ 待定 | M4 阶段实现熔断器 |
| 后台任务预算 | 🟢 低 | ❌ M4 | BGTaskScheduler 30s 限制 |

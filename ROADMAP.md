# Selah - 开发路线图

> 最后更新：2026-07-10
> 资料来源：selah-v8-unified-design-spec.md + selah-v8-ios-architecture.md
> 工程审查：CodeBuddy MCP deepseek-v4-pro（2026-07-08）

---

## 当前阶段：M0 完成 + Supabase 后端完成，进入 M1

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
| Supabase 部署權限 | ❌ | CLI 登入帳號無法存取 project ijonabyyppmgvoufgamt，需要 Access Token 或專案所有者授權 |
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

**前置**：M0 ✅ + 后端 API ✅ + OpenAI API Key ✅ + Supabase 部署權限 ❌

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| 后端 /v1/sentences/generate | ✅ | Edge Function 已写好（GPT-4o-mini + v8 Prompt） |
| 后端 /v1/audio/generate | ✅ | Edge Function 已写好（OpenAI TTS + 3 声线映射） |
| 后端 /v1/config/bootstrap | ✅ | Edge Function 已写好 |
| 后端 /v1/events | ✅ | Edge Function 已写好 |
| Migration SQL + RLS | ✅ | 11 表 + 完整 RLS Policy |
| Edge Functions 部署到 Supabase | ❌ | Supabase CLI 登入帳號無 project 權限，需 Access Token 或所有者授權 |
| Migration 執行到 Supabase DB | ❌ | 同上，需要 CLI/Management API 權限 |
| 種子句匯入 seed_sentences | ❌ | 需先執行 Migration 建立表 |
| iOS 语音识别集成 | ❌ | SFSpeechRecognizer + 中文识别 |
| SelahAPIClient 实现 | ❌ | iOS 端 HTTP 客户端 |
| SentenceGenerationService 真实实现 | ❌ | 调用后端 API |
| AudioGenerationService 真实实现 | ❌ | 调用后端 API |
| Today Sentence 全流程接通 | ❌ | 中文 -> API -> 英文 -> 保存 -> TTS |
| 声线选择 UI | ❌ | 在 Today Sentence 或 Settings 中 |
| 音频本地缓存 | ❌ | FileManager + LRU |
| 生成重试队列 | ❌ | 持久化 Job Queue |
| 速率限制 + 用量记录 | ❌ | 后端每日上限 |
| 中文确认步骤 | ❌ | STT -> 编辑 -> 确认 -> 翻译 |

---

### M2 - 真实聆听与音频

**目标**：用户可以完整经历聆听四步流程，音频生成可靠。

**前置**：M1 + TTS Provider ✅

| 任务 | 状态 | 关键产出 |
|------|------|---------|
| AudioPlaybackService 完整实现 | ❌ | 播放/暂停/速度/A-B 循环 |
| 音频状态机 | ❌ | queued -> generating -> ready / failed |
| 音频生成分步处理 | ❌ | 翻译成功但 TTS 失败时句子仍可用 |
| 音频去重 | ❌ | 相同句子+声线 -> 复用 |
| 文件完整性校验 | ❌ | 下载后校验 |
| 音频后台生成弹性 | ❌ | BGTaskScheduler + 前台续传 |
| 聆听全集构建 | ❌ | 按状态构建 3 句聆听集 |
| 上下文桥接 | ❌ | 完成后 -> 可选「顺手续 3 句」 |
| Practice 仅允许已聆听句子 | ❌ | 选题逻辑 |
| 手动音频重生成 | ❌ | 「重新生成语音」按钮 |
| Seed 音频离线捆绑 | ❌ | 30 句种子句音频预置 |

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
| 推荐理由预览 | ❌ | 「為什麼是這一步？」 |
| 上下文学习集 | ❌ | 不强制日程 |
| 生词状态转换规则 | ✅ 已有 Swift 实现 | new->learning->familiar->owned |
| Night Preview 列队 | ❌ | 基于内容池状态 |

---

### M4 - 产品打磨

**目标**：健壮性、隐私、账号、发布准备。

**前置**：M3

| 任务 | 状态 |
|------|------|
| 错误恢复 + 熔断器 | ❌ |
| 离线处理 | ❌ |
| 本地通知 | ❌ |
| Widget 就绪 | ❌ |
| 无障碍 | ❌ |
| 隐私政策 | ❌ |

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

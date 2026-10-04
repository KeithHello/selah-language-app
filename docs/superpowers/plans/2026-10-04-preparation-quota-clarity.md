# 长文整理计费透明化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改额度结构与数据库的前提下，让用户在确认生成分句前看清会占用几条个人表达：预览条数提示、额度不足预检、三语帮助文案补两层关系、整理提示词减少碎片分句。

**Architecture:** 全部改动在表现层与服务端提示词层。UI 改动集中在 _SegmentEditor 与其调用处，额度数据复用 MembershipSummary.usage，不新增接口。提示词改动只在 capture_contract.ts 的 buildCapturePreparationRequest，版本用新增 PREPARATION_PROMPT_VERSION 记录。客户端预检是软拦截，服务端 admission 仍是最终裁决。

**Tech Stack:** Flutter Web（现有 SelahColors／SelahTypography／locale 键机制）、Supabase Edge Functions（Deno）、Deno 合约测试、Flutter widget 测试。

## Global Constraints

- 不改数据库、不加 migration、不改 reserve_generation_allowance。
- Today 页不展示剩余、已用、百分比或进度条；只展示本次操作条数与被拦截时的受限说明，余额数字仍只在设置页会员卡。
- 客户端预检不得吞掉或改写服务端错误；request_exceeds_feature_limit 路径保持原样。
- 只对尚未成功且非空的待生成分句计算本次条数；已保存成功的分句不重复计入，失败待重试的分句仍计入。
- 仅在会员状态最近一次读取成功且 usage 存在时启用额度预检；刷新时暂时禁用确认按钮，刷新失败后不再按额度预检拦截。
- 新文案全部走三语 locale 键，不硬编码。
- 本地实现阶段不新增依赖、不连接远端数据库；生产部署按项目逐步确认规则处理。
- 提示词改动只影响 sentences-prepare；GENERATION_PROMPT_VERSION 保持 v8.0 不动。

---

## 文件

- 修改 SelahFlutter/lib/web/ui/web_learning_app.dart：_SegmentEditor 与 Today 页调用处。
- 修改 SelahFlutter/lib/web/l10n/selah_strings.dart、selah_zh_hans.dart、selah_zh_hant.dart、selah_ja.dart：新增三语键与基础回退。
- 修改 SelahFlutter/lib/web/ui/membership_widgets.dart：三语 sentencesHelp 与 preparationsHelp。
- 修改 supabase/functions/_shared/capture_contract.ts：两行提示词指令＋PREPARATION_PROMPT_VERSION。
- 修改 supabase/functions/sentences-prepare/index.ts：promptVersion 改传 PREPARATION_PROMPT_VERSION。
- 修改 SelahFlutter/test/web_app_test.dart：复用既有 Today 页测试夹具验证预览与额度预检。
- 修改 SelahFlutter/test/membership_widgets_test.dart。
- 修改 supabase/tests/capture_contract_test.ts。

## Task 1：条数提示与不足预检（UI）

**Files:**

- Modify: SelahFlutter/lib/web/l10n/selah_strings.dart、selah_zh_hans.dart、selah_zh_hant.dart、selah_ja.dart
- Modify: SelahFlutter/lib/web/ui/web_learning_app.dart
- Modify: SelahFlutter/test/web_app_test.dart

**Interfaces:**

- Consumes: MembershipSummary.usage.sentences.remaining（SelahFlutter/lib/web/domain/membership.dart）、LearningController.membership。
- Produces: locale 键 today.segmentQuotaHint／today.segmentQuotaBlocked／today.segmentQuotaRefresh；_SegmentEditor 新参数 quotaRemaining（int?）与 onRefreshQuota（VoidCallback?）。

- [x] **Step 1: 新增三语 locale 键**

按设计文档第 4 节的文案表，在三个 locale 文件中新增 today.segmentQuotaHint、today.segmentQuotaBlocked、today.segmentQuotaRefresh。

- [x] **Step 2: _SegmentEditor 渲染提示行**

在说明文案之后、分句列表之前渲染条数提示。N 为尚未成功保存且 trim 后非空的分句数；用 ListenableBuilder 监听分句 TextEditingController 的合并 Listenable，保证删句或清空文本时数字即时更新。已成功保存的分句不重复计入，失败待重试的分句仍计入。生成按钮在 busy、N 为 0 或额度不足时禁用。

- [x] **Step 3: 不足拦截与刷新入口**

quotaRemaining 为 null 时不拦截。N > quotaRemaining 时禁用生成按钮，在按钮上方显示 today.segmentQuotaBlocked（{count} 为 N），并在其右侧或下方提供 today.segmentQuotaRefresh 文字按钮，调用 onRefreshQuota。额度只在最近一次状态读取成功且未刷新时提供；加载中、读取失败、未登录或 usage 缺失都传 null。预检放行不代表服务端已批准。

- [x] **Step 4: 调用处接线**

Today 页用 AnimatedBuilder 监听 c.membership，构造 _SegmentEditor 时传入 quotaRemaining：已登录、membershipModeEnabled、checked、statusError 为空且 usage 非空时取 usage.sentences.remaining，否则传 null。onRefreshQuota 调用 c.membership.load()；AnimatedBuilder 接收加载、成功、失败状态并重建，不需额外 setState。手动刷新时沿用最近一次成功额度并暂时禁用确认和刷新，失败后 quotaRemaining 变为 null。

- [x] **Step 5: Today 页 widget 测试**

复用 web_app_test.dart 的 _SpokenGateway、_todayController 与平台助手，覆盖：预览出现 N 条提示；编辑或删除一句后数字减一；仅统计尚未成功的非空句子；最近一次会员读取成功且额度不足时按钮禁用并出现拦截文案；点击刷新后额度恢复足够时按钮恢复可用；usage 缺失或状态读取失败时不禁用。

- [x] **Step 6: 验证**

flutter analyze --no-pub 无问题；flutter test test/web_app_test.dart --plain-name "segment preview" 与相关既有测试通过。

## Task 2：帮助文案补两层关系

**Files:**

- Modify: SelahFlutter/lib/web/ui/membership_widgets.dart
- Modify: SelahFlutter/test/membership_widgets_test.dart

- [x] **Step 1: 更新三语 copy**

按设计文档第 4 节的文案表更新 sentencesHelp 与 preparationsHelp（简体约 1418／1421 行、繁体约 1489／1492 行、日文约 1560／1563 行附近）。ttsCharactersHelp 与 transcriptionHelp 不动。

- [x] **Step 2: 测试断言**

membership_widgets_test.dart 对三种语言断言：sentencesHelp 含「长文整理」关联句；preparationsHelp 含「不消耗个人表达」与「按实际保存」表述（按各语言实际文案取关键词）。

- [x] **Step 3: 验证**

flutter test test/membership_widgets_test.dart 通过。

## Task 3：整理提示词与版本记录

**Files:**

- Modify: supabase/functions/_shared/capture_contract.ts
- Modify: supabase/functions/sentences-prepare/index.ts
- Modify: supabase/tests/capture_contract_test.ts

**Interfaces:**

- Produces: capture_contract.ts 导出 PREPARATION_PROMPT_VERSION = "prep-v1"；buildCapturePreparationRequest 的 system 指令新增两行（见设计文档 3.4）。

- [x] **Step 1: 先写失败测试**

capture_contract_test.ts 新增断言：buildCapturePreparationRequest 返回的 system 内容包含两行新指令；PREPARATION_PROMPT_VERSION 导出且值为 prep-v1。

- [x] **Step 2: 实现提示词与常量**

capture_contract.ts 的 system 指令数组末尾（语言说明行之前）插入两行新指令；新增导出 PREPARATION_PROMPT_VERSION。

- [x] **Step 3: sentences-prepare 换用新版本常量**

promptVersion 从 GENERATION_PROMPT_VERSION 改为 PREPARATION_PROMPT_VERSION；GENERATION_PROMPT_VERSION 的 import 若不再使用则移除。静态合约测试断言该引用。

- [x] **Step 4: 验证**

按仓库现有 Supabase 测试命令跑 capture_contract_test.ts 与 generation 相关合约测试，全部通过。

## Task 4：整体验收与文档

**Files:**

- Modify: ROADMAP.md

- [x] **Step 1: 全量验证**

flutter analyze --no-pub；flutter test 全量；Deno 合约测试；tool/web.ps1 -Action build Release 构建成功。origin/main 当前版本为 1.6.1+11；本功能按新增能力升至 1.7.0+12，以通过生产版本唯一性门禁。

- [ ] **Step 2: 浏览器手工验收**

本地 Release 构建未配置公开 Supabase URL 与 publishable key，不能完成真实登录、长文整理接口和设置页额度闭环的浏览器验收。分句数、额度不足拦截、刷新恢复和额度数据缺失场景已由 Flutter widget 测试覆盖；线上端到端验收待部署环境执行。

真实浏览器走通：输入长文→整理→预览出现条数提示→删一句数字变化→确认生成→设置页会员卡用量变化与提示条数一致；构造剩余不足场景验证拦截与刷新；未登录场景不误伤。

- [x] **Step 3: 文档**

更新 ROADMAP.md：记录实现、验证结果、本地 commit 和候选构建编号；生产部署状态只能在 CI 与线上 Build ID 核验通过后填写。

# 长文整理计费透明化设计

日期：2026-10-04。状态：方向已由主人确认；实现与本地验证完成，生产发布待逐步确认。本文记录产品决策与计费口径，不改数据库结构或额度记账方式。

关联：[会员、试用与费用保护设计](2026-09-10-membership-cost-control-design.md) 、[设置页会员状态与方案变更设计](2026-09-28-settings-membership-status-design.md) 、[实施计划](../plans/2026-10-04-preparation-quota-clarity.md) 。

## 1．结论

四项额度与记账完全维持现状：长文整理按「次」，个人表达按「条」，整理产出的句子在确认生成时按实际保存条数计入个人表达。sentence 与 batch 已在 010_shared_sentence_batch_quota.sql 共用同一个个人表达池，Pro 900／月会员 300／试用 30 条不变，preparation 90／30／3 次不变。

本轮只补四件透明化的事，让用户在按下确认键之前看清会扣几条：

1. 分句预览显示本次待生成将占用的条数，随编辑实时变化；已成功保存与失败待重试的分句按真实待处理状态分别计算。
2. 使用最近一次成功读取的会员额度进行预检；读取失败时不预检，避免用失效数据误挡用户。额度不足时说明原因并附手动刷新入口。
3. 设置页四张额度卡的帮助文案，讲清「整理按次、确认按条」两层关系。
4. 整理提示词减少无意义碎片分句，降低「说了 4 句却被切出 5 段」的发生率。

不做的：不合并额度池、不设折算率、不改 reserve_generation_allowance、不加 migration、不在 Today 页展示剩余额度数字。

## 2．现状核对（2026-10-04）

- 记账：reserve_generation_allowance（supabase/migrations/010_shared_sentence_batch_quota.sql）已把 sentence 与 batch 合到同一池；preparation 单独按次。无需改动。
- 分句预览：SelahFlutter/lib/web/ui/web_learning_app.dart 的 _SegmentEditor 已展示「N / 20」计数、逐句编辑、删除与撤销，但没有条数与个人表达额度关系的说明。
- 确认生成：_generateSegments 单句走 sentences-generate，多句按 5 条一批走 sentences-batch-generate，逐条按保存成功计数；服务端已有 request_exceeds_feature_limit 拒绝路径。
- 会员余额：MembershipSummary.usage（SelahFlutter/lib/web/domain/membership.dart）已含四项 used／limit／remaining；LearningController 暴露 membership，生成成功后会 load() 刷新。
- 帮助文案：membership_widgets.dart 内置三语 copy，sentencesHelp 与 preparationsHelp 未说明两层关系。
- 整理提示词：supabase/functions/_shared/capture_contract.ts 的 buildCapturePreparationRequest 已要求去除语气碎片，但没有「能独立成句才切分」的约束；提示词版本 GENERATION_PROMPT_VERSION（v8.0）为生成、批量、整理三个功能共用。

## 3．方案

### 3.1 分句预览条数提示

_SegmentEditor 在说明文案之下、第一句输入框之前增加一行：「全部生成将占用 N 条个人表达」。N 为尚未成功保存、且 trim 后非空的分句数；已成功保存的分句不重复计入，失败待重试的分句仍计入。用户删句或编辑文字时实时更新。单句路径同样显示（占用 1 条），口径一致。N 为 0 时禁用确认生成按钮。

这行是「本次操作的价格」，不是余额展示；余额数字仍只在设置页会员卡展示。

### 3.2 额度不足预检

数据源为 c.membership.summary.usage.sentences.remaining，仅在已登录、usage 非空、且最近一次会员状态读取成功时可用。规则：

- usage 缺失或最近一次状态读取失败（未登录、会员模式关闭、首次读取尚未完成）：只显示条数提示，不因额度预检禁用按钮；服务端 admission 仍是最终裁决。
- 手动刷新时保留最近一次成功读取的额度判断，同时短暂禁用确认和刷新按钮；刷新成功后按新额度重算，刷新失败后取消客户端预检，不阻止用户请求服务端。
- N ≤ remaining：正常放行。
- N > remaining：生成按钮禁用，按钮上方显示「本次需要 N 条个人表达，已超出本期可用额度。可删减分句后再试。」，并提供「重新查询额度」文字按钮调用 membership.load()；刷新后仍不足则维持禁用。
- 预检是软拦截：客户端判断通过但服务端拒绝时，沿用现有 request_exceeds_feature_limit 错误路径与文案，不吞掉、不改写服务端错误。

### 3.3 帮助文案

更新 membership_widgets.dart 三语 sentencesHelp 与 preparationsHelp，把两层关系写进一句话；其余两个键不动。新文案见第 4 节。

### 3.4 整理提示词减少碎片分句

在 buildCapturePreparationRequest 的 system 指令中新增两行：

- "Prefer fewer, complete sentences: split only where each part can stand alone as a learnable sentence."
- "Do not emit standalone segments that are only meaningless conversational fillers. Keep short acknowledgements as standalone sentences when they convey a complete response or useful learning value; otherwise attach fillers to the neighbouring segment or omit them."

版本记录：capture_contract.ts 新增导出 PREPARATION_PROMPT_VERSION（值 prep-v1），由 sentences-prepare 单独记录；GENERATION_PROMPT_VERSION 保持 v8.0，不给未改提示词的生成功能换版本。

明确不做按字数阈值的确定性自动合并。中文「我很累。」「走吧」这类 2—4 字的完整句子真实存在，字数阈值必然误合并；静默改写用户文本比多出一段更伤害信任。碎片问题的兜底是 3.1 的可见性，加上预览编辑器已有的删句与手动合并能力（把一句的文字并进相邻句再删除原句）。

### 3.5 计费口径对照（不变，供验收比对）

| 场景 | 长文整理额度 | 个人表达额度 |
| --- | --- | --- |
| 整理并保存结果 | −1 次 | 不变 |
| 预览中删句或放弃 | 已扣的那次不退 | 不变 |
| 确认生成 N 句并保存成功 | 不变 | −N 条 |
| 生成失败 | 不变 | 不扣（沿用现有失败口径） |

新增 AI 配音额度继续按新增配音文本的字符数累计，英语与母语语音都会计入。现有三语帮助文案已明确说明两种语言都生成配音，因此本轮不改语音额度或其记账规则。

## 4．文案表

新增键（SelahFlutter/lib/web/l10n 三个 locale 文件）：

| 键 | 简体 | 繁体 | 日文 |
| --- | --- | --- | --- |
| today.segmentQuotaHint | 全部生成将占用 {count} 条个人表达。 | 全部產生將占用 {count} 條個人表達。 | すべて生成すると、個人表現 {count} 文を使用します。 |
| today.segmentQuotaBlocked | 本次需要 {count} 条个人表达，已超出本期可用额度。可删减分句后再试。 | 本次需要 {count} 條個人表達，已超過本期可用額度。可刪減分句後再試。 | 今回の生成には個人表現 {count} 文が必要で、今期の利用可能な枠を超えています。文を減らしてから再試行してください。 |
| today.segmentQuotaRefresh | 重新查询额度 | 重新查詢額度 | 利用枠を再確認する |

修改键（membership_widgets.dart 三语 copy）：

| 键 | 简体 | 繁体 | 日文 |
| --- | --- | --- | --- |
| sentencesHelp | 写下今天的母语句子，生成对应的英语学习内容；每成功生成一条，计一次。长文整理后确认生成的句子，也按条计入这里。 | 寫下今天的母語句子，產生對應的英語學習內容；每成功產生一條，計一次。長文整理後確認產生的句子，也按條計入這裡。 | 今日の母語の文を書くと、対応する英語学習コンテンツを生成します。生成 1 件ごとにカウントします。長文整理で確認生成した文も、ここに 1 文ずつカウントされます。 |
| preparationsHelp | 超过直接生成长度的长文，先自动分段整理再逐段生成；每整理一次计一次。整理本身不消耗个人表达条数；确认生成时，按实际保存的条数计入个人表达。 | 超過直接產生長度的長文，先自動分段整理再逐段產生；每整理一次計一次。整理本身不消耗個人表達條數；確認產生時，按實際保存的條數計入個人表達。 | 直接生成できる長さを超える長文は、先に分割して整理してから生成します。整理 1 回ごとにカウントします。整理自体は個人表現の件数を消費せず、確認生成時に実際に保存した文数が個人表現としてカウントされます。 |

## 5．与既有设计约束的关系

2026-09-28 设计规定 Today、聆听、练习和生成入口不展示剩余额度、已用数量、百分比或进度条，余额只在设置页会员卡展示。本方案不违反该约束：

- 条数提示只说明「本次操作占用几条」，不出现剩余或已用数字。
- 不足拦截提示与 2026-09-10 设计「额度触顶：在用户发起相应操作时提示」的口径一致，只说明受限类别与可做的事，不显示剩余数字。
- 「重新查询额度」是动作入口，点击后刷新数据；刷新结果仍不直接展示在 Today 页。

## 6．验证要点

- 预览出现 N 条提示；删一句或清空一句，数字即时减一。
- 已知剩余不足时按钮禁用并显示拦截文案；点「重新查询额度」后数据刷新，足够则恢复可用。
- usage 缺失时不误伤：未登录、会员模式关闭、首次读取中或最近一次读取失败时不因额度预检禁用按钮。
- 三语帮助文案更新，弹窗内容与键值一致。
- Deno 合约测试覆盖两行新提示词指令与 PREPARATION_PROMPT_VERSION。
- flutter analyze、相关 Flutter 测试、Deno 测试、Web Release 构建通过。

## 7．风险与边界

- 预检依赖客户端最近一次成功读取的 usage，可能过期（例如在另一设备升级会员后额度变多）。已用「重新查询额度」缓解；服务端始终是最终裁决。
- 提示词调整可能轻微改变分句风格；PREPARATION_PROMPT_VERSION 单独记录，便于按版本回溯。短回复只有在独立成句且有学习价值时才保留；单纯语气词并入相邻表达或省略。
- Today 页只新增一行文案与一个条件按钮状态，不新增组件层级，视觉与布局风险低。

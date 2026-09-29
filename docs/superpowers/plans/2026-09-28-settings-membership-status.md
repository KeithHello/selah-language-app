# 设置页会员状态与方案变更 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在设置页顶部显示当前会员和本账期四项剩余额度，并用一份服务端预览列出当前身份合法的方案变更。

**Architecture:** 额度合计、24 小时门槛和补差价全部放在服务端纯函数里。membership-status 只附加余额和未来账期。membership-plan-preview 只读，不写订单。设置页用一张会员卡替换现在的三张方案卡。立即升级落账和按比例覆盖额度需要新的数据库字段，在支付渠道确认前不实施。

**Tech Stack:** Flutter Web、现有 SelahColors 与 SelahTypography、Supabase Edge Functions、Deno 测试、PostgreSQL migration 草稿。

## Global Constraints

- 剩余额度只出现在已登录且 membershipModeEnabled 为真的设置页顶部。今天、聆听、练习和生成入口不展示剩余、已用、百分比或进度条。
- 不显示 0 额度来表示未开通、未登录、会员模式关闭或读取失败。读取失败不保留旧余额。
- 已用包含 reserved、dispatch_claimed、settled、unknown。released_unsent 不计入。sentence 与 batch 合成一个个人表达额度。
- 月会员升级 Pro：剩余不少于 24 小时才立即补差价。差价为 6000 分乘剩余毫秒除以总毫秒，一半向上取整。四项上限用 Pro 默认值乘同一比例后向下取整。已用量保留。
- 剩余不足 24 小时时不补差价，改为顺延购买下一个完整 Pro 账期，价格 9990 分。
- 再购买一个月从所有未结束账期最晚的 expires_at 开始。按钮不写「续费」。不提供账期中途降级、年费、加量包或自动扣款。
- 试用开通付费会员时，付款核实后立即开始，试用剩余不结转。
- 已排期未来账期不被立即升级修改。
- 客户端不计算价格，不本地扣减余额。
- 支付渠道未配置、销售关闭或 Pro 自助购买关闭时，行动仍显示，按钮禁用并写明原因。
- 不新增依赖。不在本计划的执行中连接远端数据库、部署函数或发起支付，除非主人对那一步单独确认。
- Task 3 可以在本地新增 migration 文件。未获确认前不得 db push、不得远程应用。membership-status 的余额字段不得早于该 migration 部署。
- Task 7 在支付渠道和验签确认前不得开始。

---

## 文件

- 新建 supabase/functions/_shared/membership_usage.ts：余额合计与方案预览纯函数。
- 新建 supabase/functions/_shared/membership_usage_test.ts。
- 修改 supabase/functions/_shared/membership_contract.ts：给 MembershipStatusResponse 增加 usage 与 futurePeriods。
- 修改 supabase/functions/membership-status/index.ts：查询预占和未来账期，调用纯函数。
- 新建 supabase/functions/membership-plan-preview/index.ts：只读预览。
- 新建 supabase/migrations/010_shared_sentence_batch_quota.sql：只改个人表达合计。本地草稿，不应用。
- 新建 supabase/tests/shared_sentence_batch_quota_migration_test.ts。
- 修改 SelahFlutter/lib/web/domain/membership.dart：解析新字段。
- 新建 SelahFlutter/lib/web/domain/membership_quota_format.dart。
- 新建 SelahFlutter/lib/web/ui/membership_status_card.dart。
- 新建 SelahFlutter/lib/web/ui/plan_change_sheet.dart。
- 修改 SelahFlutter/lib/web/membership_controller.dart：增加预览加载。
- 修改 SelahFlutter/lib/web/ui/web_learning_app.dart：把会员卡放到设置页顶部，删除旧的三卡区域。
- 修改 SelahFlutter/test/membership_widgets_test.dart，并新增格式与预览测试。
- Task 7 才允许新建 supabase/migrations/011_prorated_membership_limits.sql。本计划不执行它。

## Task 1：余额与补差价纯函数

**Files:**
- Create: supabase/functions/_shared/membership_usage.ts
- Test: supabase/functions/_shared/membership_usage_test.ts

**Interfaces:**
- Consumes: membership_contract.ts 里的 MONTHLY_PRICE_FEN_CNY、PRO_PRICE_FEN_CNY、TRIAL_ENTITLEMENTS、MONTHLY_ENTITLEMENTS、PRO_ENTITLEMENTS、PlanEntitlements、MembershipSource。
- Produces: aggregateUsage(rows, limits, asOf)、legalPlanQuotes(input)、PlanChangeQuote。

- [ ] **Step 1: 写失败测试**

把下面的文件写成 supabase/functions/_shared/membership_usage_test.ts。

    import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
    import { PRO_ENTITLEMENTS } from "./membership_contract.ts";
    import {
      aggregateUsage,
      legalPlanQuotes,
    } from "./membership_usage.ts";

    const startedAt = "2026-09-01T00:00:00.000Z";
    const expiresAt = "2026-09-11T00:00:00.000Z";

    Deno.test("sentence and batch share one pool and released rows are ignored", () => {
      const usage = aggregateUsage([
        { feature: "sentence", status: "settled", units: 20 },
        { feature: "batch", status: "reserved", units: 5 },
        { feature: "batch", status: "released_unsent", units: 9 },
        { feature: "tts", status: "unknown", units: 100 },
        { feature: "transcription", status: "dispatch_claimed", units: 60000 },
        { feature: "preparation", status: "settled", units: 1 },
      ], {
        maxSentences: 30,
        maxTtsCharacters: 3000,
        maxTranscriptionMs: 300000,
        maxPreparations: 3,
      }, startedAt);
      assertEquals(usage.sentences, { used: 25, limit: 30, remaining: 5 });
      assertEquals(usage.ttsCharacters.remaining, 2900);
      assertEquals(usage.transcriptionMs.remaining, 240000);
      assertEquals(usage.preparations.remaining, 2);
    });

    Deno.test("monthly upgrade at least 24 hours prorates price and caps", () => {
      const quotes = legalPlanQuotes({
        now: "2026-09-09T23:58:48.000Z",
        current: { plan: "monthly", startedAt, expiresAt },
        usage: zeroUsage(startedAt),
        futurePeriods: [],
        salesEnabled: true,
        paymentConfigured: true,
        proSalesEnabled: true,
      });
      const upgrade = quotes.find((quote) => quote.action === "upgrade_pro_now");
      assertEquals(upgrade?.chargeFenCny, 601);
      assertEquals(upgrade?.currentPeriodEffect, "replace_remainder");
      assertEquals(upgrade?.limitsAfter?.maxSentences, 90);
      assertEquals(upgrade?.limitsAfter?.maxTtsCharacters, 9007);
      assertEquals(upgrade?.limitsAfter?.maxTranscriptionMs, 1080900);
      assertEquals(upgrade?.limitsAfter?.maxPreparations, 9);
      assertEquals(quotes.some((quote) => quote.action === "schedule_pro"), false);
    });

    Deno.test("under 24 hours schedules a full Pro period instead of prorating", () => {
      const quotes = legalPlanQuotes({
        now: "2026-09-10T00:00:00.001Z",
        current: { plan: "monthly", startedAt, expiresAt },
        usage: zeroUsage(startedAt),
        futurePeriods: [],
        salesEnabled: true,
        paymentConfigured: false,
        proSalesEnabled: false,
      });
      assertEquals(quotes.some((quote) => quote.action === "upgrade_pro_now"), false);
      const scheduled = quotes.find((quote) => quote.action === "schedule_pro");
      assertEquals(scheduled?.chargeFenCny, 9990);
      assertEquals(scheduled?.effectiveAt, expiresAt);
      assertEquals(scheduled?.limitsAfter, PRO_ENTITLEMENTS);
      assertEquals(scheduled?.unavailableReason, "payment_not_configured");
    });

    Deno.test("trial purchase starts now and warns that trial remainder is dropped", () => {
      const quotes = legalPlanQuotes({
        now: startedAt,
        current: { plan: "trial", startedAt, expiresAt },
        usage: zeroUsage(startedAt),
        futurePeriods: [],
        salesEnabled: true,
        paymentConfigured: true,
        proSalesEnabled: true,
      });
      const monthly = quotes.find((quote) => quote.action === "buy_monthly");
      assertEquals(monthly?.chargeFenCny, 3990);
      assertEquals(monthly?.effectiveAt, startedAt);
      assertEquals(monthly?.warnings.includes("trial_remainder_dropped"), true);
      assertEquals(quotes.some((quote) => quote.action === "upgrade_pro_now"), false);
    });

    Deno.test("active Pro only offers another Pro period and keeps future periods", () => {
      const future = [{
        id: "future-1",
        plan: "monthly" as const,
        source: "grant" as const,
        startsAt: expiresAt,
        endsAt: "2026-10-11T00:00:00.000Z",
      }];
      const quotes = legalPlanQuotes({
        now: startedAt,
        current: { plan: "pro", startedAt, expiresAt },
        usage: zeroUsage(startedAt),
        futurePeriods: future,
        salesEnabled: false,
        paymentConfigured: true,
        proSalesEnabled: true,
      });
      assertEquals(quotes.map((quote) => quote.action), ["extend_pro"]);
      assertEquals(quotes[0].effectiveAt, "2026-10-11T00:00:00.000Z");
      assertEquals(quotes[0].unavailableReason, "sales_disabled");
      assertEquals(quotes[0].warnings, ["future_periods_unchanged"]);
    });

    function zeroUsage(asOf: string) {
      const row = { used: 0, limit: 0, remaining: 0 };
      return {
        asOf,
        sentences: row,
        ttsCharacters: row,
        transcriptionMs: row,
        preparations: row,
      };
    }

数字来源：账期 864000000 毫秒，剩余 86472000 毫秒。6000 乘该比例等于 600.5，一半向上为 601。900、90000、10800000、90 按同一比例向下取整，分别是 90、9007、1080900、9。剩余 86399999 毫秒走完整 Pro 账期。

- [ ] **Step 2: 运行测试并确认失败**

Run: deno test --allow-read supabase/functions/_shared/membership_usage_test.ts

Expected: FAIL，因为 membership_usage.ts 不存在。

- [ ] **Step 3: 写最小实现**

新建 supabase/functions/_shared/membership_usage.ts。

    import {
      MONTHLY_ENTITLEMENTS,
      MONTHLY_PRICE_FEN_CNY,
      PRO_ENTITLEMENTS,
      PRO_PRICE_FEN_CNY,
      TRIAL_ENTITLEMENTS,
      type MembershipSource,
      type PlanEntitlements,
    } from "./membership_contract.ts";

    export const DAY_MS = 86_400_000;
    const COUNTED = new Set(["reserved", "dispatch_claimed", "settled", "unknown"]);
    const PRICE_DELTA = PRO_PRICE_FEN_CNY - MONTHLY_PRICE_FEN_CNY;

    export interface FeatureUsage {
      used: number;
      limit: number;
      remaining: number;
    }

    export interface UsageSnapshot {
      asOf: string;
      sentences: FeatureUsage;
      ttsCharacters: FeatureUsage;
      transcriptionMs: FeatureUsage;
      preparations: FeatureUsage;
    }

    export interface ReservationUsageRow {
      feature: string;
      status: string;
      units: number;
    }

    export interface FuturePeriod {
      id: string;
      plan: "trial" | "monthly" | "pro";
      source: MembershipSource;
      startsAt: string;
      endsAt: string;
    }

    export interface CurrentPeriod {
      plan: "trial" | "monthly" | "pro";
      startedAt: string;
      expiresAt: string;
    }

    export type PlanChangeAction =
      | "upgrade_pro_now"
      | "schedule_pro"
      | "buy_monthly"
      | "buy_pro"
      | "extend_monthly"
      | "extend_pro";

    export interface PlanChangeQuote {
      action: PlanChangeAction;
      chargeFenCny: number;
      effectiveAt: string;
      currentPeriodEffect: "replace_remainder" | "schedule_after" | "start_now";
      limitsAfter: PlanEntitlements | null;
      usageAfter: UsageSnapshot | null;
      futurePeriods: FuturePeriod[];
      warnings: Array<"trial_remainder_dropped" | "future_periods_unchanged" | "feature_remaining_zero">;
      unavailableReason: "sales_disabled" | "payment_not_configured" | "pro_sales_disabled" | null;
    }

    export interface PlanQuoteInput {
      now: string;
      current: CurrentPeriod | null;
      usage: UsageSnapshot | null;
      futurePeriods: FuturePeriod[];
      salesEnabled: boolean;
      paymentConfigured: boolean;
      proSalesEnabled: boolean;
    }

    export function aggregateUsage(rows: readonly ReservationUsageRow[], limits: PlanEntitlements, asOf: string): UsageSnapshot {
      const used = { sentences: 0, tts: 0, transcription: 0, preparations: 0 };
      for (const row of rows) {
        if (!COUNTED.has(row.status) || !Number.isInteger(row.units) || row.units <= 0) continue;
        if (row.feature === "sentence" || row.feature === "batch") used.sentences += row.units;
        else if (row.feature === "tts") used.tts += row.units;
        else if (row.feature === "transcription") used.transcription += row.units;
        else if (row.feature === "preparation") used.preparations += row.units;
      }
      return {
        asOf,
        sentences: cap(used.sentences, limits.maxSentences),
        ttsCharacters: cap(used.tts, limits.maxTtsCharacters),
        transcriptionMs: cap(used.transcription, limits.maxTranscriptionMs),
        preparations: cap(used.preparations, limits.maxPreparations),
      };
    }

    export function legalPlanQuotes(input: PlanQuoteInput): PlanChangeQuote[] {
      const nowMs = time(input.now);
      const current = input.current;
      const remaining = current == null ? 0 : time(current.expiresAt) - nowMs;
      const total = current == null ? 0 : time(current.expiresAt) - time(current.startedAt);
      const active = current != null && remaining > 0 && total > 0 && remaining <= total;
      if (active && current.plan === "monthly" && remaining >= DAY_MS) {
        return [upgradeNow(input, total, remaining), extend(input, "extend_monthly", MONTHLY_PRICE_FEN_CNY, false)];
      }
      if (active && current.plan === "monthly") {
        return [schedulePro(input), extend(input, "extend_monthly", MONTHLY_PRICE_FEN_CNY, false)];
      }
      if (active && current.plan === "pro") return [extend(input, "extend_pro", PRO_PRICE_FEN_CNY, true)];
      if (active && current.plan === "trial") {
        return [startPaid(input, "buy_monthly", MONTHLY_PRICE_FEN_CNY, false), startPaid(input, "buy_pro", PRO_PRICE_FEN_CNY, true)];
      }
      return [buyLater(input, "buy_monthly", MONTHLY_PRICE_FEN_CNY, false), buyLater(input, "buy_pro", PRO_PRICE_FEN_CNY, true)];
    }

    function upgradeNow(input: PlanQuoteInput, total: number, remaining: number): PlanChangeQuote {
      if (input.usage == null) throw new Error("usage_required");
      const charge = Number((BigInt(PRICE_DELTA) * BigInt(remaining) + BigInt(total) / 2n) / BigInt(total));
      const limits = {
        maxSentences: scale(PRO_ENTITLEMENTS.maxSentences, remaining, total),
        maxTtsCharacters: scale(PRO_ENTITLEMENTS.maxTtsCharacters, remaining, total),
        maxTranscriptionMs: scale(PRO_ENTITLEMENTS.maxTranscriptionMs, remaining, total),
        maxPreparations: scale(PRO_ENTITLEMENTS.maxPreparations, remaining, total),
      };
      const usageAfter = {
        asOf: input.usage.asOf,
        sentences: cap(input.usage.sentences.used, limits.maxSentences),
        ttsCharacters: cap(input.usage.ttsCharacters.used, limits.maxTtsCharacters),
        transcriptionMs: cap(input.usage.transcriptionMs.used, limits.maxTranscriptionMs),
        preparations: cap(input.usage.preparations.used, limits.maxPreparations),
      };
      const warnings: PlanChangeQuote["warnings"] = [];
      if (Object.values(usageAfter).some((item) => typeof item !== "string" && item.remaining === 0)) warnings.push("feature_remaining_zero");
      if (input.futurePeriods.length > 0) warnings.push("future_periods_unchanged");
      return quote("upgrade_pro_now", charge, input.now, "replace_remainder", limits, usageAfter, input, true, warnings);
    }

    function schedulePro(input: PlanQuoteInput): PlanChangeQuote {
      const effectiveAt = latestEnd(input);
      return quote("schedule_pro", PRO_PRICE_FEN_CNY, effectiveAt, "schedule_after", PRO_ENTITLEMENTS, fresh(effectiveAt, PRO_ENTITLEMENTS), input, true, futureWarning(input));
    }

    function extend(input: PlanQuoteInput, action: "extend_monthly" | "extend_pro", price: number, pro: boolean): PlanChangeQuote {
      return quote(action, price, latestEnd(input), "schedule_after", null, null, input, pro, futureWarning(input));
    }

    function startPaid(input: PlanQuoteInput, action: "buy_monthly" | "buy_pro", price: number, pro: boolean): PlanChangeQuote {
      const limits = pro ? PRO_ENTITLEMENTS : MONTHLY_ENTITLEMENTS;
      return quote(action, price, input.now, "start_now", limits, fresh(input.now, limits), input, pro, ["trial_remainder_dropped"]);
    }

    function buyLater(input: PlanQuoteInput, action: "buy_monthly" | "buy_pro", price: number, pro: boolean): PlanChangeQuote {
      const effectiveAt = latestEnd(input);
      const limits = pro ? PRO_ENTITLEMENTS : MONTHLY_ENTITLEMENTS;
      const effect = time(effectiveAt) > time(input.now) ? "schedule_after" : "start_now";
      return quote(action, price, effectiveAt, effect, limits, fresh(effectiveAt, limits), input, pro, futureWarning(input));
    }

    function quote(action: PlanChangeAction, chargeFenCny: number, effectiveAt: string, currentPeriodEffect: PlanChangeQuote["currentPeriodEffect"], limitsAfter: PlanEntitlements | null, usageAfter: UsageSnapshot | null, input: PlanQuoteInput, pro: boolean, warnings: PlanChangeQuote["warnings"]): PlanChangeQuote {
      return { action, chargeFenCny, effectiveAt, currentPeriodEffect, limitsAfter, usageAfter, futurePeriods: input.futurePeriods, warnings, unavailableReason: reason(input, pro) };
    }

    function reason(input: PlanQuoteInput, pro: boolean): PlanChangeQuote["unavailableReason"] {
      if (!input.salesEnabled) return "sales_disabled";
      if (!input.paymentConfigured) return "payment_not_configured";
      if (pro && !input.proSalesEnabled) return "pro_sales_disabled";
      return null;
    }

    function futureWarning(input: PlanQuoteInput): PlanChangeQuote["warnings"] {
      return input.futurePeriods.length > 0 ? ["future_periods_unchanged"] : [];
    }

    function latestEnd(input: PlanQuoteInput): string {
      let latest = input.current == null ? time(input.now) : Math.max(time(input.now), time(input.current.expiresAt));
      for (const period of input.futurePeriods) latest = Math.max(latest, time(period.endsAt));
      return new Date(latest).toISOString();
    }

    function fresh(asOf: string, limits: PlanEntitlements): UsageSnapshot {
      return aggregateUsage([], limits, asOf);
    }

    function scale(limit: number, remaining: number, total: number): number {
      return Number((BigInt(limit) * BigInt(remaining)) / BigInt(total));
    }

    function cap(used: number, limit: number): FeatureUsage {
      return { used, limit, remaining: Math.max(0, limit - used) };
    }

    function time(value: string): number {
      const parsed = Date.parse(value);
      if (!Number.isFinite(parsed)) throw new Error("invalid_time");
      return parsed;
    }

    export function limitsForPlan(plan: string): PlanEntitlements {
      if (plan === "pro") return PRO_ENTITLEMENTS;
      if (plan === "monthly") return MONTHLY_ENTITLEMENTS;
      if (plan === "trial") return TRIAL_ENTITLEMENTS;
      return { maxSentences: 0, maxTtsCharacters: 0, maxTranscriptionMs: 0, maxPreparations: 0 };
    }

- [ ] **Step 4: 运行测试并确认通过**

Run: deno test --allow-read supabase/functions/_shared/membership_usage_test.ts

Expected: 5 passed。若 601 或上限断言失败，先检查整数乘除，不要改测试去迁就浮点。

- [ ] **Step 5: Commit**

    git add supabase/functions/_shared/membership_usage.ts supabase/functions/_shared/membership_usage_test.ts
    git commit -m "feat: 增加会员余额合计与补差价预览的纯函数"

## Task 2：membership-status 返回余额和未来账期

**Files:**
- Modify: supabase/functions/_shared/membership_contract.ts
- Modify: supabase/functions/membership-status/index.ts
- Test: supabase/tests/membership_status_test.ts

**Interfaces:**
- Consumes: aggregateUsage、limitsForPlan。
- Produces: MembershipStatusResponse.usage 与 futurePeriods。没有当前账期时 usage 为 null。

- [ ] **Step 1: 写失败测试**

在 supabase/tests/membership_status_test.ts 增加：

    Deno.test("membership status returns aggregated usage and future periods", () => {
      assertStringIncludes(SOURCE, "aggregateUsage");
      assertStringIncludes(SOURCE, "futurePeriods");
      assertStringIncludes(SOURCE, "released_unsent");
      assertStringIncludes(SOURCE, "usage: null");
    });

- [ ] **Step 2: 运行测试并确认失败**

Run: deno test --allow-read supabase/tests/membership_status_test.ts

Expected: FAIL，新断言找不到 aggregateUsage。

- [ ] **Step 3: 写最小实现**

在 MembershipStatusResponse 增加：

    usage: UsageSnapshot | null;
    futurePeriods: FuturePeriod[];

membership-status 在拿到当前会员后：

1. 用 service role 查询 user_memberships 中 started_at 晚于 now()、status 为 trial 或 active 的行，映射为 futurePeriods。
2. 有当前账期时，查询该 membership_id 的 membership_reservations，字段只取 feature、status、units_reserved。调用 aggregateUsage。上限使用 limitsForPlan(plan)，此任务不读取尚不存在的覆盖列。
3. 没有当前账期时 usage 为 null。
4. 查询失败且会员模式开启时，保持现有 membership_query_failed，不返回全 0。
5. 响应不得包含 nano_usd、预算或单笔预占。

- [ ] **Step 4: 运行测试并确认通过**

Run: deno test --allow-read supabase/tests/membership_status_test.ts supabase/functions/_shared/membership_usage_test.ts

Expected: PASS。

- [ ] **Step 5: Commit**

    git add supabase/functions/_shared/membership_contract.ts supabase/functions/membership-status/index.ts supabase/tests/membership_status_test.ts
    git commit -m "feat: 会员状态返回本账期剩余额度和已排期账期"

## Task 3：个人表达改为单句与批量同一个池

**Files:**
- Create: supabase/migrations/010_shared_sentence_batch_quota.sql
- Test: supabase/tests/shared_sentence_batch_quota_migration_test.ts

**Interfaces:**
- Consumes: 009 里的 reserve_generation_allowance。
- Produces: 同一个函数；sentence 与 batch 的已用合计后和同一个上限比较。

- [ ] **Step 1: 写失败测试**

    const SQL = await Deno.readTextFile("supabase/migrations/010_shared_sentence_batch_quota.sql");
    Deno.test("sentence and batch are summed together", () => {
      assertStringIncludes(SQL, "feature IN ('sentence', 'batch')");
      assertStringIncludes(SQL, "p_feature IN ('sentence', 'batch')");
      assertEquals(SQL.includes("db push"), false);
    });

- [ ] **Step 2: 运行测试并确认失败**

Run: deno test --allow-read supabase/tests/shared_sentence_batch_quota_migration_test.ts

Expected: FAIL，文件不存在。

- [ ] **Step 3: 写本地 migration 草稿**

以 009 中 reserve_generation_allowance 的最新函数体为基准，只替换已用查询：

    SELECT COALESCE(SUM(units_reserved), 0)
      INTO v_used
      FROM public.membership_reservations
     WHERE user_id = p_user_id
       AND membership_id = v_membership.id
       AND status IN ('reserved', 'dispatch_claimed', 'settled', 'unknown')
       AND (
         (p_feature IN ('sentence', 'batch') AND feature IN ('sentence', 'batch'))
         OR (p_feature NOT IN ('sentence', 'batch') AND feature = p_feature)
       );

文件头写明：本地草稿，未获主人确认不得应用到远端。不要执行 supabase db push，不要连接远端。

- [ ] **Step 4: 运行测试并确认通过**

Run: deno test --allow-read supabase/tests/shared_sentence_batch_quota_migration_test.ts

Expected: PASS。

- [ ] **Step 5: Commit**

    git add supabase/migrations/010_shared_sentence_batch_quota.sql supabase/tests/shared_sentence_batch_quota_migration_test.ts
    git commit -m "feat: 个人表达额度改为单句和批量共用一个池"

部署闸门：此文件进入远端之前，不得部署会返回 usage 的 membership-status。应用 migration 本身也要先单独向主人确认。

## Task 4：Flutter 解析余额并格式化

**Files:**
- Modify: SelahFlutter/lib/web/domain/membership.dart
- Create: SelahFlutter/lib/web/domain/membership_quota_format.dart
- Test: SelahFlutter/test/membership_quota_format_test.dart
- Modify: SelahFlutter/test/membership_controller_test.dart

**Interfaces:**
- Consumes: usage、futurePeriods JSON。
- Produces: MembershipSummary.usage、MembershipSummary.futurePeriods、formatQuotaValue。

- [ ] **Step 1: 写失败测试**

新建 SelahFlutter/test/membership_quota_format_test.dart：

    import 'package:flutter_test/flutter_test.dart';
    import 'package:selah/web/domain/membership_quota_format.dart';

    void main() {
      test('characters use wan only when the remainder stays exact', () {
        expect(formatQuotaValue(90000, QuotaUnit.characters, 'zh-Hans'), '9 万字符');
        expect(formatQuotaValue(42000, QuotaUnit.characters, 'zh-Hans'), '4.2 万字符');
        expect(formatQuotaValue(42150, QuotaUnit.characters, 'zh-Hans'), '42150 字符');
        expect(formatQuotaValue(3000, QuotaUnit.characters, 'zh-Hant'), '3000 字元');
      });

      test('transcription minutes floor to one decimal', () {
        expect(formatQuotaValue(300000, QuotaUnit.transcriptionMs, 'zh-Hans'), '5 分钟');
        expect(formatQuotaValue(5766000, QuotaUnit.transcriptionMs, 'zh-Hans'), '96.1 分钟');
        expect(formatQuotaValue(59999, QuotaUnit.transcriptionMs, 'ja'), '0.9 分');
      });
    }

在 membership_controller_test.dart 增加一个 JSON：usage 为 null 时 summary.usage 为 null；有 sentences.remaining 时按服务端数字读取，测试里不得先减一遍。

- [ ] **Step 2: 运行测试并确认失败**

Run: flutter test test/membership_quota_format_test.dart

工作目录：SelahFlutter。Expected: FAIL，格式化函数不存在。

- [ ] **Step 3: 写最小实现**

MembershipSummary 增加 usage 与 futurePeriods。缺失 usage 时为 null，不补 0。

formatQuotaValue 规则：

- characters：value 大于等于 10000 且 value 能被 100 整除时，用 value / 10000 表示万，去掉末尾 0。否则显示精确整数。简体单位「字符」，繁体「字元」，日文「文字」。
- transcriptionMs：floor(value / 6000) / 10。整数不保留小数。简体和繁体单位「分钟」或「分鐘」，日文「分」。
- sentences：简体「条」，繁体「條」，日文「文」。
- preparations：简体和繁体「次」，日文「回」。

- [ ] **Step 4: 运行测试并确认通过**

Run: flutter test test/membership_quota_format_test.dart test/membership_controller_test.dart

Expected: PASS。

- [ ] **Step 5: Commit**

    git add SelahFlutter/lib/web/domain/membership.dart SelahFlutter/lib/web/domain/membership_quota_format.dart SelahFlutter/test/membership_quota_format_test.dart SelahFlutter/test/membership_controller_test.dart
    git commit -m "feat: 解析服务端会员余额并按口径格式化"

## Task 5：设置页顶部会员卡与方案弹层

**Files:**
- Create: SelahFlutter/lib/web/ui/membership_status_card.dart
- Create: SelahFlutter/lib/web/ui/plan_change_sheet.dart
- Modify: SelahFlutter/lib/web/ui/web_learning_app.dart
- Modify: SelahFlutter/lib/web/membership_controller.dart
- Modify: SelahFlutter/test/membership_widgets_test.dart

**Interfaces:**
- Consumes: MembershipSummary、formatQuotaValue、controller.loadPlanPreview。
- Produces: MembershipStatusCard、PlanChangeSheet。设置页不再构造 MembershipCenter。

- [ ] **Step 1: 写失败测试**

在 membership_widgets_test.dart 增加四个 widget 测试：

1. membershipModeEnabled 为 false 时，MembershipStatusCard 不渲染「会员」「本账期剩余」或任何数字。
2. 月会员有效时，卡片在方案名下显示四行，剩余数字等于 JSON 中的 remaining，不显示百分比和 LinearProgressIndicator。
3. sentences.remaining 为 0 时，只该行显示「本账期已用完」，配音行仍显示剩余。
4. 打开弹层后显示「升级到 Pro」和「再购买一个月会员」。proSalesEnabled 为 false 时，升级按钮禁用且能找到「Pro 购买尚未开放。」。找不到「降级」。

现有 free mode 测试改为断言 MembershipStatusCard 不显示会员信息。

- [ ] **Step 2: 运行测试并确认失败**

Run: flutter test test/membership_widgets_test.dart

Expected: FAIL，新卡片不存在。

- [ ] **Step 3: 写界面**

MembershipStatusCard 使用 Card、内边距 17、19px 珊瑚色 Icons.workspace_premium_outlined、headlineMedium「会员」。方案名用 headlineLarge。次要信息用 bodySmall 与 textSecondary。有效期转本地时间，简体和繁体用 YYYY 年 M 月 D 日 HH:mm，日文用 YYYY/M/D HH:mm。

有 usage 才渲染「本账期剩余」和四行。行距 12，分隔线 borderLight，数字使用 FontFeature.tabularFigures。剩余为 0 的行只显示「本账期已用完」，颜色 textTertiary。不使用进度条、百分比、红色或琥珀色额度警告。

按钮「更改方案」是通栏 OutlinedButton，高 48，圆角 12。

文案按设计文档第 4、5、6 节，补齐 zh-Hans、zh-Hant、ja。行标签使用「个人表达」「新增 AI 配音」「录音转写」「长文整理」，不使用「语音转写」。试用尚未开始和准备中的两句说明继续使用 membership_widgets.dart 里现有的 trialNotStarted 与 trialPreparing 文案，不新写一套。

PlanChangeSheet 是最大宽度 560 的底部弹层，顶部圆角 20。打开时调用 loadPlanPreview。预览返回前只显示进度，不显示 0 元。每条 quote 显示行动名、生效时间、金额和警告。unavailableReason 为 null 时，本任务也只允许 buy_monthly 与 extend_monthly 调用现有 startMonthlyCheckout。升级、Pro 和试用购买 Pro 保持禁用，因为 Task 7 尚未允许落账。

controller.loadPlanPreview 调用 membership-plan-preview，请求体为空，并把 quotes 存入控制器。失败时使用「会员状态暂时无法读取，请稍后重试。」，清空旧预览。

_SettingsPage 在标题和副标题之后、语言区之前插入会员卡。条件是 c.isRegistered 且 c.membership.membershipModeEnabled。删除原「会员与方案」区段及其 MembershipCenter。确认 MembershipCenter、MembershipPlansView、ActiveMembershipBanner 没有剩余引用后删除这三个类，保留仍被新卡片使用的文案。账户区继续只处理登录和同步。

- [ ] **Step 4: 运行测试并确认学习页没有额度**

Run: flutter test test/membership_widgets_test.dart

Expected: PASS。

Run: rg -n "MembershipStatusCard|本账期剩余" SelahFlutter/lib/web/ui/web_learning_app.dart

Expected: 只出现在 _SettingsPage。_TodayPage、_ListenPage、_PracticePage 没有这些文本。

- [ ] **Step 5: Commit**

    git add SelahFlutter/lib/web/ui/membership_status_card.dart SelahFlutter/lib/web/ui/plan_change_sheet.dart SelahFlutter/lib/web/ui/web_learning_app.dart SelahFlutter/lib/web/membership_controller.dart SelahFlutter/test/membership_widgets_test.dart
    git commit -m "feat: 设置页顶部展示当前会员、剩余额度和方案行动"

## Task 6：只读方案预览函数

**Files:**
- Create: supabase/functions/membership-plan-preview/index.ts
- Test: supabase/functions/_shared/membership_usage_test.ts

**Interfaces:**
- Consumes: legalPlanQuotes、aggregateUsage、现有 membership summary 查询。
- Produces: { quotes: PlanChangeQuote[] }。不写表。

- [ ] **Step 1: 写失败测试**

在 membership_usage_test.ts 增加：显式 action 不在 legalPlanQuotes 结果中时，assertQuoteAction 抛出 plan_change_not_available。函数实现放在同一文件并导出。

再对 preview 函数源码做断言：包含 legalPlanQuotes，不包含 insert、update、upsert、membership_orders。

- [ ] **Step 2: 运行测试并确认失败**

Run: deno test --allow-read supabase/functions/_shared/membership_usage_test.ts

Expected: FAIL。

- [ ] **Step 3: 写只读函数**

membership-plan-preview 要求登录。它读取与 membership-status 相同的当前账期、预占和未来账期，调用 legalPlanQuotes。请求体为空时返回全部合法 quotes。请求体含 action 且该行动不合法时返回 409 和 plan_change_not_available。函数里不得出现数据库写入。

checkout 继续只接受月会员 SKU。不要在此任务放宽 validateCreateOrderInput。

- [ ] **Step 4: 运行测试并确认通过**

Run: deno test --allow-read supabase/functions/_shared/membership_usage_test.ts supabase/functions/_shared/payment_contract_test.ts

Expected: PASS。月会员 SKU 限制仍然存在。

- [ ] **Step 5: Commit**

    git add supabase/functions/membership-plan-preview/index.ts supabase/functions/_shared/membership_usage.ts supabase/functions/_shared/membership_usage_test.ts
    git commit -m "feat: 增加不落账的会员方案预览"

## Task 7：补差价落账（未获支付确认前停止）

**Files:**
- Create: supabase/migrations/011_prorated_membership_limits.sql
- Modify: supabase/functions/membership-checkout/index.ts
- Modify: reserve_generation_allowance，在 011 中替换函数

**Interfaces:**
- Consumes: PlanChangeQuote.limitsAfter。
- Produces: user_memberships 的四项可空上限。空值继续表示方案默认值。

- [ ] **Step 1: 确认授权**

开始前必须同时具备主人对支付渠道、验签流程和这份 migration 的明确确认。缺少任何一项就停止，不创建文件，不把本任务标成完成。

- [ ] **Step 2: 写失败测试**

测试覆盖三件事：当前月会员行的 plan 改为 pro；四项上限写成预览中的向下取整值；未来账期的 plan 和上限不变。reserve_generation_allowance 使用 coalesce(列, 方案默认值)。预览金额与订单金额必须来自同一次服务端计算，不能由客户端传入。

- [ ] **Step 3: 写 migration 与落账**

增加可空列 sentence_limit、tts_character_limit、transcription_ms_limit、preparation_limit，都要求为空或大于等于 0。立即升级只更新当前账期。试用购买把试用行的 expires_at 改到付费开始时刻。再购买一个月仍按最晚 expires_at 顺延，并使用完整方案上限，不写覆盖列。

- [ ] **Step 4: 验证**

本地静态测试通过后停止。远端应用、部署和真实扣款仍分别确认。

## 最后验证

在 SelahFlutter 运行：

    flutter test test/membership_quota_format_test.dart test/membership_widgets_test.dart test/membership_controller_test.dart
    flutter analyze

在仓库根目录运行：

    deno test --allow-read supabase/functions/_shared/membership_usage_test.ts supabase/tests/membership_status_test.ts supabase/tests/shared_sentence_batch_quota_migration_test.ts supabase/functions/_shared/payment_contract_test.ts

Expected: 全部通过，analyze 无新问题。未获确认时，不运行 db push，不部署 membership-status、membership-plan-preview 或 checkout。

## 自检

- 设计第 3 节的页面顺序由 Task 5 落实。
- 第 6 节的合计口径由 Task 1 与 Task 3 同时落实，缺一不可。
- 第 7 节的六种身份由 legalPlanQuotes 的测试覆盖。
- 第 8 节的只读预览由 Task 6 落实。落账明确留在 Task 7，并有停止条件。
- 学习页不展示额度由 Task 5 的搜索验证。

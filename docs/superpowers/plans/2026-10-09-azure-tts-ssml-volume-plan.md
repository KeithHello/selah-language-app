# Azure 语音 SSML 声线音量开发方案

> 后续校准已由 [azure-vol-v2 方案](2026-10-09-azure-tts-volume-v2-plan.md) 更新。该方案取代本文的 `-20.9 LUFS` 目标、v1 音量表、`azure-vol-v1`／`lufs-v2` 版本及种子 FFmpeg 重新编码步骤；本文其余 Azure 路由、在线生成、计费与 API 契约仍作背景记录。

日期：2026-10-09。状态：T0—T8 实施、资产与客观验收完成，试听待主人确认。T9 已完成远端主线集成、本地版本升级与 `main` 快进；远端密钥、Edge Function 和 Cloudflare Pages 生产发布仍待逐步确认。

依据：[Azure 语音响度校准实测](../../2026-10-09-azure-tts-loudness-calibration.md) 、[Azure 三语 TTS 与响度统一设计](../specs/2026-10-09-azure-tts-unification-design.md) ，以及项目 `CLAUDE.md` 的 2026-10-09 Azure 段落。本方案获批后，取代其中「每条音轨经独立 FFmpeg 处理服务校准」的规定。

## 1．决定

- 继续使用 Azure Speech 三语方案。声线路由、12 个 profile、会员配音额度口径和 Azure 计费字符规则沿用现有实现。
- 线上新生成的音频在 SSML 中按声线写固定 `volume`，不再经过 FFmpeg 处理服务，也不部署 Azure Container Apps。
- 统一目标为 -20.9 LUFS，即 Jenny 的自然响度；其他声线只衰减。
- SSML 只写非默认的 `rate`、`pitch`、`volume`；默认英语声线不再带 prosody 标签。
- 随包 60 条种子按新目标重做，继续用本机 FFmpeg 双遍校准。
- 版本标识：线上生成音频为 `azure-vol-v1`，随包种子为 `lufs-v2`。

## 2．依据

- 全部改用 Azure 后，同一句母语与英语的原始差距从旧方案的 6～11 LU 缩小到 0～5 LU；日语母语比 Jenny 英语平均响 3.75 LU，仍然听得出来。
- 各声线句间标准差 0.27～0.76 LU，同一声线不同 profile 最多相差 0.24 LU，按声线设一个固定值就够。
- SSML `volume` 是精确的线性增益：`-30%`、`-50%`、`+30%` 实测为 -3.10、-6.02、+2.28 dB，各句误差不超过 0.02 dB。
- 按 -20.9 LUFS 音量表模拟：120 句中 117 句在 ±1 LU 内，最大 1.59 LU；同一句母语与英语最多差 1.64 LU；最高真峰值 -1.96 dBTP。
- 目标选 -20.9 而不选现种子的 -22.45 LUFS：两者一致性相同，但前者让默认英语声线无需音量标签，整体也响约 1.5 dB。

## 3．设计

### 3.1 声线音量表 v1

| Azure 声线 | 适用 profile | 原始平均 LUFS | SSML volume | 增益 | 校准后预计 LUFS |
|---|---|---:|---:|---:|---:|
| en-US-JennyNeural | gentle-natural、clear-slow | -20.86 | 不写 | 0 dB | -20.86 |
| en-US-GuyNeural | daily-bright | -19.72 | -13% | -1.21 dB | -20.93 |
| en-GB-SoniaNeural | elegant-british | -18.96 | -20% | -1.94 dB | -20.89 |
| zh-TW-HsiaoChenNeural | 四个 native profile | -19.03 | -19% | -1.83 dB | -20.86 |
| ja-JP-NanamiNeural | 四个 native profile | -17.15 | -35% | -3.74 dB | -20.90 |

表按声线定义，同一声线的 profile 共用一个值。表中任何数值变化都要把 `azure-vol-v1` 升版。

### 3.2 SSML 规则

`prosody` 只写非默认属性；三项都是默认值时不写 `prosody`。计费字符继续由同一个 SSML builder 计算，`volume` 属性自动计入；会员额度仍按正文码点计。

| profile | `<voice>` 内的内容 |
|---|---|
| Jenny gentle-natural | `TEXT`（无 prosody） |
| 曉臻 native-gentle | `<prosody volume="-19%">TEXT</prosody>` |
| Guy daily-bright | `<prosody rate="+5%" pitch="+1st" volume="-13%">TEXT</prosody>` |

### 3.3 线上生成流程

流程改为：Azure 合成 → 校验 MP3 格式与大小 → 计算 SHA-256 与时长 → 上传成品 → 标记 ready。

- 移除：处理服务配置检查、`normalizeAudioBuffer` 调用、source 中间对象、标准化恢复分支与 `normalization_*` 错误码、处理器预算预留。
- 时长：Azure 输出固定为 160 kbit/s，按「字节数 ÷ 20」得到毫秒数，替代处理器回传值。旧的按英文词数估算对中日文不准，不再使用。
- 保留：身份校验、幂等与并发认领、会员与平台预算 admission、缓存命中、签名 URL 和 usage 记录。缺少 Azure key、region 或单价配置时继续 fail closed。

### 3.4 缓存与版本

- 服务端：`AUDIO_NORMALIZER_REVISION` 改为 `AUDIO_LEVEL_REVISION = "azure-vol-v1"`，用于生成音频的 text hash、cache key 与 Storage 路径；响应字段 `normalizerRevision` 改名为 `levelRevision`。客户端只在随包种子条目上读取 `normalizerRevision`，不读取接口返回的这个字段。
- 客户端：拆成两个常量。生成音频缓存键使用 `azure-vol-v1`；`isNormalizedAudioEntry` 校验随包种子的 `lufs-v2`。`audio:v3` 前缀尚未发布到生产，保持不变。
- 已有个人音频（旧 OpenAI 英语、旧版 Azure 繁中）与新缓存键不匹配，首次播放时会按新请求生成，计入会员配音额度和平台费用。生产目前未开放试用和销售，影响主要是测试账户；受影响账户数尚未核实。

### 3.5 验收口径

本节替换现行「每条 -22 LUFS ±1 LU」的规定。

- 线上生成音频：按声线校准，不逐条测量。校准验证时，每个声线 10 句的平均值与 -20.9 LUFS 相差不超过 0.5 LU，每句真峰值不高于 -1 dBTP。按实测，完整句子大多在 ±1 LU 内，极短句可偏离约 2 LU。
- 随包种子：本机 FFmpeg 双遍校准，成品实测为 -20.9 LUFS，沿用处理器 ±1 LU 与不高于 -1 dBTP 的验收。上次设定 -22.0 时成品实测为 -22.45，因此设定值以成品实测为准。
- 复测：新增声线或 profile、Azure 公告声线更新，或用户反馈音量不一致时运行复测工具；声线平均偏差超过 0.5 LU 就更新音量表并升版。

### 3.6 费用

单价按 Azure S1 Neural 公开零售价 US$15／百万计费字符；不含 Container Apps 和处理器预留，也不含其他 AI、存储与流量成本。

| 场景（按种子句平均长度，额度用满） | 试用 3,000 字 | 月会员 30,000 字 | Pro 90,000 字 |
|---|---:|---:|---:|
| 仅英语 | US$0.071 → 0.045 | US$0.71 → 0.45 | US$2.12 → 1.35 |
| 英语＋繁中 | US$0.095 → 0.071 | US$0.95 → 0.71 | US$2.84 → 2.12 |
| 英语＋日语 | US$0.085 → 0.063 | US$0.85 → 0.63 | US$2.55 → 1.90 |
| 仅繁中 | US$0.188 → 0.171 | US$1.88 → 1.71 | US$5.65 → 5.12 |

箭头左侧为现行 SSML（每次请求约 40 个标记字符），右侧为本方案。此前按正文字数做的估算没有计入标记字符，结果偏低。

## 4．开发任务

T0～T8 在功能分支 `codex/azure-ssml-volume` 上完成（从本机 `main` 建立），T9 负责集成与发布。

### T0 规范与文档（获批后第一步）

- `CLAUDE.md`：改写 2026-10-09 Azure 段落中的响度与处理服务规则，写入 SSML 声线音量、-20.9 LUFS、种子离线校准与复测规则，并记录本方案授权。
- `docs/superpowers/specs/2026-10-09-azure-tts-unification-design.md`：改写「响度处理」及计费中涉及处理器的部分，指向本方案。
- `supabase/.env.example`：删除三个 `AUDIO_NORMALIZER_*` 变量。`supabase/audio-normalizer/README.md`：改为离线种子校准说明。

### T1 SSML 与音量表

- `supabase/functions/_shared/audio_routing.ts`：新增按声线的音量表；`buildAzureSsml` 只输出非默认属性。
- `supabase/tests/audio_routing_test.ts`：逐个 profile 断言完整 SSML；Jenny 默认无 prosody；转义不变；计费字符随 SSML 变化，Jenny `gentle-natural` 的计费字符等于正文计费字符。

### T2 Edge 生成流程

- `supabase/functions/audio-generate/index.ts`：按 3.3 改为单段流程；`providerConfigured` 只检查 Azure key 与 region。
- `supabase/tests/audio_generate_test.ts`：覆盖缺配置 fail closed、缓存命中、上传失败不标 ready、usage 记录 Azure 计费字符与时长计算。

### T3 计费

- `supabase/functions/_shared/cost_policy.ts`：`calculateAzureTtsMaxCost` 去掉处理器预留参数，删除 `audio-normalizer` 预留路径与 `normalizerReserveNanoUsd`。
- 定价配置只需要 `AZURE_TTS_NANO_USD_PER_BILLABLE_CHARACTER` 与 `AZURE_TTS_PRICE_VERSION`，缺任一项仍 fail closed。
- 测试：`supabase/tests/cost_policy.node.test.mjs`、`supabase/functions/_shared/cost_policy_test.ts`。

### T4 缓存版本与客户端

- `supabase/functions/_shared/audio.ts`、`audio_routing.ts`、`audio-generate/index.ts`：按 3.4 更换版本常量与响应字段。
- `SelahFlutter/lib/web/domain/audio_preparation.dart` 及 `learning_controller.dart` 的调用处：拆分生成音频与随包种子的版本常量。
- 测试：`web_audio_preparation_test.dart`、`web_loop_controller_test.dart`、`web_loop_seed_audio_test.dart`、`web_reliability_controller_test.dart`。

### T5 种子工具与重做

- `supabase/audio-normalizer/server.py`：目标按 3.5 调整到成品 -20.9 LUFS，版本改为 `lufs-v2`。
- `SelahFlutter/tool/package_seed_audio.py`、`supabase/scripts/seed_audio_inventory.ts`：同步版本常量。
- `supabase/scripts/seed_audio_prebuild.ts`：去掉处理服务依赖，按线上同一 SSML 规则生成；本轮只做 dry-run。
- 重做 60 条种子：运行 `generate_azure_seed_audio.py --execute`（约 6,000 计费字符，约 US$0.09），再用打包器更新 `SelahFlutter/assets/content/seed-audio.json`；校验 SHA-256、格式、-20.9 LUFS、真峰值，以及 manifest 60 键与构建包一致。
- 测试：`supabase/tests/azure_seed_audio_script_test.py`、`SelahFlutter/test/seed_audio_packager_test.py`、`supabase/audio-normalizer/tests/test_server.py`。

### T6 复测工具

- 新增 `supabase/scripts/azure_voice_loudness_check.ts`（Deno）：直接复用线上 `buildAzureSsml` 与音量表。默认 dry-run，只列请求数与计费字符；`--execute --cost-approved` 才调用 Azure，并设计费字符上限；`--raw` 去掉音量，用于重新推算音量表。用本机 FFmpeg 测量，输出每个声线的平均值、偏差、真峰值与建议音量，结果写入 `output/`。
- 测试：请求清单、计费上限和建议音量计算的离线单元测试。

### T7 清理处理服务（删除文件需主人确认）

- 删除：`supabase/audio-normalizer/Dockerfile`、`supabase/functions/_shared/audio_normalizer.ts`、`supabase/tests/audio_normalizer_test.ts`。
- 修改：`server.py` 去掉 HTTP 服务入口，保留 `normalize_mp3` 供种子工具使用；`test_server.py` 删除 HTTP 用例。

### T8 验证

- 本地：受影响的 Deno 测试与格式检查、Python 测试（种子脚本、打包器、处理器）、Node 成本策略测试、`flutter test --no-pub`、`flutter analyze --no-pub`，以及 `SelahFlutter/tool/web.ps1 -Action build`。
- 付费验证（约 4,400 计费字符，约 US$0.07）：用 T6 工具以最终 SSML 合成 5 个声线默认 profile 各 10 句，要求每个声线平均值在 -20.9 ±0.5 LU、真峰值不高于 -1 dBTP；同时导出母语与英语交替的试听样本，交主人试听。

### T9 集成与发布

1. `git fetch origin`，把 `origin/main`（含 1.9.1 的性能与 Pages 修复）合入功能分支。本机 `main` 目前领先 `origin/main` 5 个提交、落后 4 个；解决冲突后重跑 T8 的本地检查。
2. 版本升至 `1.10.0+17`。
3. 写入 Supabase secrets：`AZURE_TTS_NANO_USD_PER_BILLABLE_CHARACTER=15000`（即 US$15／百万字符）、`AZURE_TTS_PRICE_VERSION=azure-s1-neural-tts-japaneast-2024-02-01`（Retail Prices API 的生效日期）；不再需要 `AUDIO_NORMALIZER_*`。
4. 部署 `audio-generate`，核对 ACTIVE 状态和路由健康检查，并确认生产旧前端 1.9.1 仍能正常取得音频。
5. 用测试账户在生产生成英语、繁中、日语各数句，下载后测量响度，并核对 usage 账本与额度扣减。
6. 按 `CLAUDE.md` 的合并规则合入 `main` 并 push，由 CI 部署 Cloudflare Pages 生产；核对版本、Build ID 和静态资源。
7. 更新 `ROADMAP.md`，关闭 Container Apps 相关待办，以及 OpenAI `tts-1` 将于 2027-01-06 退役的风险项。

## 5．授权与发布边界

1. 主人已明确授权执行 T0—T8，包括将线上目标改为约 -20.9 LUFS、覆盖 60 条随包种子、T7 列出的 3 个文件清理，以及 Azure 付费响度复测。现存的 60 个原始校准音频与种子句子、profile 一一对应；离线标准化可省去重复合成约 US$0.09，最终响度和峰值仍按相同标准验证。T8 预计约 US$0.07 的付费复测在授权范围内。
2. 本轮开发和本地验证不授权写入 Supabase secrets 或部署 Edge Function。T9 第 3、4 步执行前，将列明具体配置值、目标项目、函数版本、健康检查与旧前端兼容验证，并按届时适用的项目规则取得当步确认。
3. T9 第 6 步 push `main` 会触发 Cloudflare Pages 生产部署。执行前将单独说明目标项目、配置变化、风险、观察项和对其他项目的影响，并取得该步确认；本地合并不等于生产发布授权。

## 6．风险与回退

- Azure 更新声线模型可能改变电平：按 3.5 的条件复测，每次约 US$0.07。
- 不再逐条测量：单句偏差多在 ±1 LU 内，极短句约 2 LU；异常音频只能靠 MP3 格式和大小校验发现。如果试听后仍觉得不一致，可以恢复逐条处理，原处理服务代码保留在 Git 历史中。
- 旧个人音频首次播放会重新生成，计入额度和费用（见 3.4）。
- 回退：`git revert` 后重新部署 `audio-generate`，并经 CI 发布前端；本方案不涉及数据库 schema 或 migration。

## 7．完成条件

- 线上生成不再依赖处理服务；缺少 Azure 配置或单价时 fail closed。
- T8 付费验证中 5 个声线均达标，并经主人试听确认；60 条种子为 -20.9 LUFS，并与 manifest 一致。
- 本地检查全部通过，`ROADMAP.md` 记录真实验证结果。
- 生产 `audio-generate` 为 ACTIVE，真实账户三语生成与循环听播放正常；前端版本与 Build ID 核验通过。以上远端条件须在取得对应逐步授权后验收。

## 8．本轮执行结果

- 60 条随包种子使用已保存的原始校准音频离线重做，没有重复调用 Azure；成品为 24 kHz、单声道、160 kbit/s MP3，响度 `-21.36` 至 `-21.33 LUFS`，最高真峰值 `-2.05 dBTP`。manifest 60 项、60 个唯一文件，SHA-256、字节数与 `lufs-v2` 全部匹配。
- Azure 复测实际合成 50 条，计费字符估算 4,359，按 US$15／百万字符估算约 US$0.0654；实际账单未从 Azure 门户核验。五个声线的 10 句平均值分别为 Jenny `-20.886`、Guy `-20.928`、Sonia `-20.894`、HsiaoChen `-20.874`、Nanami `-20.875 LUFS`，均在目标 `-20.9 ±0.5 LU` 内；各自最高真峰值均低于 `-1 dBTP`。
- 已导出 10 组「繁中母语／Jenny 英语」及 10 组「日语母语／Jenny 英语」交替试听清单，保存在本机 `output/azure-voice-loudness-2026-10-09T09-51-18-313Z/listening-pairs/`。
- 验证通过：Deno 383 项、95 个文件 lint、20 个 Edge Function 类型检查；Python 24 项、Node 11 项；Flutter 441 项与静态分析；Deno 全目录格式检查通过（临时副本统一换行后检查）。最终 Web Release 为 `1.10.0+17`、Build ID `3abd7a0aa020dfa7`；包内 60 个种子文件的 SHA-256、字节数和 `lufs-v2` 全部匹配。
- T9 已将 `origin/main` 合入功能分支（`45726f0`），并将 `main` 快进至 `0920996`；完成本记录提交后，本地 `main` 比 `origin/main` ahead 10、behind 0。未 push、未写入远端 secrets、未部署 Edge Function，也未执行 Cloudflare 操作。
- 试听样本已生成，但「主人试听确认」仍待完成。后续远端 secrets、`audio-generate` 部署与真实动态音频验收，以及 GitHub／Cloudflare 发布，须依项目规则逐步确认。

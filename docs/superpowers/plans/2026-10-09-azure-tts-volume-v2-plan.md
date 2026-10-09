# Azure 语音整体音量 +0.5 dB 开发方案（azure-vol-v2）

日期：2026-10-09；实施记录更新：2026-10-10。状态：V0—V5 与本机 `main` 集成已完成；V6 远端发布尚未执行。

依据：本机试听对比测量 `output/azure-volume-ab-2026-10-09/measurements.json`（Git 忽略）、[Azure 语音响度校准实测](../../2026-10-09-azure-tts-loudness-calibration.md) 、[Azure 语音 SSML 声线音量开发方案](2026-10-09-azure-tts-ssml-volume-plan.md) （下称 v1 方案）。本方案获批后，取代 v1 方案中的音量表、-20.9 LUFS 目标和随包种子离线校准规定；v1 方案的 SSML 写法、线上单段生成流程和计费规则不变，其 T9 未完成的远端发布步骤并入本方案 V6。

## 1．决定

- 主人试听 A（现行）、B（+0.5 dB）、C（约 +2.5 dB 参考）后选定 B：五个 Azure 声线统一提高约 0.5 dB，声线平均响度目标由 -20.9 改为 -20.4 LUFS，各语言之间的相对平衡不变。
- 只用 Azure SSML `volume` 调整，不新增处理服务，也不在播放端加增益。
- 随包种子改走与线上相同的路径：由 Azure 按新音量表直接合成，保存 Azure 返回的 MP3，不再经本机 FFmpeg 重新编码。
- 线上生成音频与随包种子的版本标识统一为 `azure-vol-v2`。
- 设置页的声音设定不新增控件；所有选项按所属声线套用新音量。

## 2．依据

### 2.1 B 版实测

2026-10-09 用新音量表经 Azure 合成 5 个声线默认选项各 10 句，SSML 与线上 `buildAzureSsml` 一致（50 条计费字符逐条吻合），共 4,669 计费字符。

| 声线 | v1 平均 LUFS | v2 平均 LUFS | 每句变化 | v2 最高真峰值 |
|---|---:|---:|---:|---:|
| Jenny | -20.89 | -20.38 | +0.50～+0.51 dB | -1.82 dBTP |
| Guy | -20.93 | -20.44 | +0.47～+0.50 dB | -1.48 dBTP |
| Sonia | -20.89 | -20.37 | +0.51～+0.53 dB | -5.47 dBTP |
| 曉臻 | -20.87 | -20.35 | +0.51～+0.53 dB | -5.00 dBTP |
| Nanami | -20.88 | -20.36 | +0.51～+0.53 dB | -6.18 dBTP |

### 2.2 只靠 Azure 的上限

SSML `volume` 只做线性增益，没有压缩或限幅。v1 下 Guy、Jenny 最高真峰值为 -1.95、-2.32 dBTP，统一增益最多约 +0.9 dB 就会碰到 -1 dBTP 上限；B 取 +0.5 dB 留出余量。C 参考版要再响约 2 dB，Jenny／Guy 20 条中有 15 条必须动态压缩，需要 Azure 以外的处理，不在本方案范围。

### 2.3 种子为什么改为直接保存 Azure 输出

- 现有 60 条种子实测 -21.36～-21.33 LUFS，比线上目标低约 0.45 dB。
- 逐步拆解：Azure MP3 解码为 WAV，响度不变（-20.08 → -20.08 LUFS）；用本机 FFmpeg 7.1.1 的 libmp3lame 重新编码为 160 kbit/s MP3 后变为 -20.53 LUFS，峰值同步下降约 0.44 dB。调整截止频率、采样率参数或去掉 loudnorm 的 offset 参数，结果都不变；直接套用线性增益再编码，同样比 Azure 合成结果低 0.43～0.46 dB。
- 线上直接保存 Azure 输出，没有这一步损失。种子改走同一路径后，两者电平一致，也不再需要本机标准化处理器。

## 3．设置页声音设定

Flutter Web 设置页有「英文声线」「母语声线」「默认语速」三项；Flutter 原生入口的设置页只有声线与语速。

| 设置项 | 选项 | Azure 声线 | 其他 prosody（不变） | 音量 v1 → v2 |
|---|---|---|---|---|
| 英文声线 | 温柔自然（美音） `gentle-natural` | Jenny | 无 | 不写 → `+6%` |
| 英文声线 | 清晰慢速（美音） `clear-slow` | Jenny | rate `-10%` | 不写 → `+6%` |
| 英文声线 | 日常轻快（美音） `daily-bright` | Guy | rate `+5%`、pitch `+1st` | `-13%` → `-8%` |
| 英文声线 | 优雅英式（英音） `elegant-british` | Sonia | 无 | `-20%` → `-15%` |
| 母语声线（繁中） | 温柔自然、清晰平稳、明亮清晰、沉稳温和 | 曉臻 | 各 profile 原值 | `-19%` → `-14%` |
| 母语声线（日语） | 同上四项 | Nanami | 各 profile 原值 | `-35%` → `-31%` |
| 默认语速 | 预设与自定义 | 浏览器 `playbackRate` | — | 不改音频文件，不影响响度 |

- 同一声线的选项共用一个音量值；v1 校准显示同一声线不同 profile 之间最多差 0.24 LU。B 版只实测了默认选项，V5 补测全部 12 种组合（英文 4 种，繁中、日语各 4 种）。
- 正式播放元素已设为 `muted = false`、`volume = 1`。浏览器 audio 元素音量上限就是 1，设置页加音量滑杆只能调小，因此不加；用户需要更大声时仍调设备音量。
- 用户切换声线后：10 句起始句的 4 个英文选项和繁中／日语「温柔自然」使用随包种子，其余组合由 `audio-generate` 按同一音量表在线生成，两种来源电平一致。
- Flutter 原生入口的在线音频由同一后端生成，后端改动后自动生效，无需单独修改。

## 4．音量表 v2

| Azure 声线 | v1 | v2 | 增益变化 |
|---|---:|---:|---:|
| en-US-JennyNeural | 不写 | `+6%` | +0.51 dB |
| en-US-GuyNeural | `-13%` | `-8%` | +0.49 dB |
| en-GB-SoniaNeural | `-20%` | `-15%` | +0.53 dB |
| zh-TW-HsiaoChenNeural | `-19%` | `-14%` | +0.52 dB |
| ja-JP-NanamiNeural | `-35%` | `-31%` | +0.52 dB |

SSML 示例（`<voice>` 内）：

- Jenny `gentle-natural`：`<prosody volume="+6%">TEXT</prosody>`
- Jenny `clear-slow`：`<prosody rate="-10%" volume="+6%">TEXT</prosody>`
- Guy `daily-bright`：`<prosody rate="+5%" pitch="+1st" volume="-8%">TEXT</prosody>`
- 曉臻 `native-calm`：`<prosody rate="-8%" pitch="-1st" volume="-14%">TEXT</prosody>`

## 5．费用

Jenny 由「不写」改为 `+6%`，每次请求多 32 个计费字符（`<prosody volume="+6%">` 与 `</prosody>`）；其他声线标签长度不变（Guy 少 1 个字符）。默认英文声线的平台成本因此上升。下表按种子句平均长度、额度用满、英文用默认声线计算，单价 US$15／百万计费字符：

| 场景 | 试用 3,000 字 | 月会员 30,000 字 | Pro 90,000 字 |
|---|---:|---:|---:|
| 仅英语 | US$0.045 → 0.066 | US$0.45 → 0.66 | US$1.35 → 1.97 |
| 英语＋繁中 | US$0.071 → 0.087 | US$0.71 → 0.87 | US$2.12 → 2.61 |
| 英语＋日语 | US$0.063 → 0.078 | US$0.63 → 0.78 | US$1.90 → 2.34 |
| 仅繁中 | US$0.171（不变） | US$1.71（不变） | US$5.12（不变） |

用户会员额度按正文码点计，不受影响。一次性付费合成：种子重做约 5,809 计费字符（约 US$0.087），设置页全组合复测约 5,351（约 US$0.080），生产抽查约 US$0.01，合计约 US$0.18。

## 6．开发任务

分支：从本机 `main` 建立 `codex/azure-volume-v2`。

### V0 规范与文档

- `CLAUDE.md`：目标改为声线平均 -20.4 LUFS（每声线 ±0.5 LU、真峰值不高于 -1 dBTP）；随包种子与线上同路径、直接保存 Azure 输出；版本 `azure-vol-v2`；记录本方案授权。
- 设计规格 `docs/superpowers/specs/2026-10-09-azure-tts-unification-design.md` 同步；v1 方案标注被本方案取代的部分；校准实测记录补充 B 版数据与重新编码结论。

### V1 音量表与版本

- `supabase/functions/_shared/audio_routing.ts`：`AZURE_VOICE_VOLUME` 改为 v2 值。
- `supabase/functions/_shared/audio.ts`：`AUDIO_LEVEL_REVISION`、`SEED_AUDIO_REVISION` 均改为 `azure-vol-v2`。
- `supabase/scripts/generate_azure_seed_audio.py`：`VOICE_VOLUME` 同步。
- 测试：`supabase/tests/audio_routing_test.ts` 断言每个 profile 的完整 SSML 与计费字符（Jenny 现带 prosody）；`audio_generate_test.ts` 断言版本；`azure_seed_audio_script_test.py` 比对种子脚本与线上音量表一致，防止两处漂移。

### V2 种子流程

- `generate_azure_seed_audio.py`：Azure 合成后只校验 MP3、测量 LUFS 与真峰值写入索引，原样保存；移除 `normalize_mp3` 调用和 `--raw-audio-dir` 离线复用路径。
- `SelahFlutter/tool/package_seed_audio.py`、`supabase/scripts/seed_audio_inventory.ts`：版本常量改为 `azure-vol-v2`。
- 删除 `supabase/audio-normalizer/`（`server.py`、`tests/test_server.py`、`README.md`）：V2 后再无调用方。删除前须主人确认；不确认则保留。
- 测试：`supabase/tests/azure_seed_audio_script_test.py`、`SelahFlutter/test/seed_audio_packager_test.py`。

### V3 复测工具

- `supabase/scripts/azure_voice_loudness_check.ts`：`TARGET_LUFS` 改为 -20.4；建议音量允许调高，但以预计真峰值不高于 -1 dBTP 为限；检查范围改为设置页全部 12 种组合、每种 5 句，计费上限 6,000 字。
- 测试：`supabase/tests/azure_voice_loudness_check_test.ts`。

### V4 客户端

- `SelahFlutter/lib/web/domain/audio_preparation.dart`：`audioLevelRevision`、`seedAudioRevision` 改为 `azure-vol-v2`；缓存前缀 `audio:v3` 尚未发布，保持不变。
- 设置页界面与文案不改。版本号升到 `1.10.0+18`。
- 测试：`web_audio_preparation_test.dart`、`web_loop_controller_test.dart`、`web_loop_seed_audio_test.dart`、`web_reliability_controller_test.dart` 中的版本字符串。

### V5 本地验证与付费验收

1. 本地：受影响的 Deno 测试、lint、类型检查与格式检查，Python、Node 测试，`flutter test --no-pub`、`flutter analyze --no-pub`，以及 `SelahFlutter/tool/web.ps1 -Action build`。
2. 付费重做 60 条种子（约 US$0.087）并打包：manifest 60 键与构建包一致，SHA-256、字节数与版本吻合；每个声线 10 句平均 -20.4 ±0.5 LU，真峰值不高于 -1 dBTP。
3. 付费全组合复测（约 US$0.080）：12 种组合各自平均 -20.4 ±0.5 LU，真峰值不高于 -1 dBTP。
4. 用复测音频拼出「繁中／英语」「日语／英语」交替试听清单，供主人最终确认，不另付费。

### V6 发布（承接 v1 方案 T9 未完成步骤）

1. 合入本机 `main`。
2. 写入 Supabase secrets：`AZURE_TTS_NANO_USD_PER_BILLABLE_CHARACTER=15000`、`AZURE_TTS_PRICE_VERSION=azure-s1-neural-tts-japaneast-2024-02-01`。须当步确认。
3. 部署 `audio-generate`，核对 ACTIVE、健康检查，并确认生产旧前端 1.9.1 仍能取得音频。须当步确认。
4. 用生产测试账户生成英语、繁中、日语各数句，下载测量电平在目标内，核对 usage 账本与额度扣减（约 US$0.01）。
5. push `main` 由 CI 部署 Cloudflare Pages 生产：执行前按全局 `AGENTS.md` 逐项说明目标项目、配置变化、风险和影响并取得确认；完成后核对版本、Build ID 与种子资源。
6. 更新 `ROADMAP.md`。

## 7．授权与确认点

- 主人于 2026-10-10 授权 V0—V5 与约 US$0.17 的 Azure 合成；已完成，费用按公开单价估算且账单未核验。
- 主人随后要求把代码合入 Git `main`、push 并部署。本机 `main` 已纳入最新 `origin/main` 与 Azure v2；Supabase secrets、`audio-generate` 部署及 Cloudflare Pages 生产发布仍须按全局 `AGENTS.md` 与本计划逐项说明并取得当步确认。
- `supabase/audio-normalizer/` 未删除，继续保留。
- V6 第 2、3、5 步仍需各自当步确认；本轮未执行任何远端发布步骤。

## 8．风险与回退

- Guy 峰值余量：v2 实测最高 -1.48 dBTP，未测句子可能更接近 -1 dBTP；V5 全组合复测覆盖。若超标，只把 Guy 再回调 1 个百分点并升版，响度变化约 0.1 dB，听感无差别。
- 极短句仍可能偏离声线平均约 2 LU，这是 Azure 输出本身的波动。
- Jenny 新增标记字符使英语平台成本上升，见第 5 节。
- 已有个人音频：切换 Azure 后首次播放会重新生成（v1 方案已说明）；v1 未上线，本次升版不额外增加重新生成。
- 回退：`git revert` 后重新部署 `audio-generate`，经 CI 发布前端；不涉及数据库 schema 或 migration。

## 9．完成条件

- 线上与随包音频均按音量表 v2 生成，版本 `azure-vol-v2`；本机不再处理随包音频。
- V5 的种子与全组合复测全部达标，本地检查全部通过。试听文件已生成，主人可继续确认最终听感。
- 种子打包器按声线汇总检查 `-20.4 ±0.5 LUFS` 和 `-1 dBTP`；允许短句单条偏差不超过 `2.5 LU`，以兼容已观测到的自然波动。
- 实际复测结果与构建信息见 `ROADMAP.md` 的 2026-10-10 Azure 音量 v2 阶段。
- 生产 `audio-generate` 为 ACTIVE，真实账户三语生成与循环听播放正常；前端版本与 Build ID 核验通过。以上远端条件须在取得逐步授权后验收。
- `ROADMAP.md` 记录真实验证结果。

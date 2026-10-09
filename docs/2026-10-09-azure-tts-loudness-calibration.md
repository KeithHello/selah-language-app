# Azure 语音响度校准实测

日期：2026-10-09。用途：判断三语统一到 Azure Speech 后，能否只在 SSML 中设置音量，不再部署在线 FFmpeg 处理服务。据此制定的开发方案见 [Azure 语音 SSML 声线音量开发方案](superpowers/plans/2026-10-09-azure-tts-ssml-volume-plan.md)。

## 授权、范围与费用

- 主人于 2026-10-09 授权一次付费校准测量（预估约 US$0.2），只从 `.env` 读取 `AZURE_SPEECH_KEY` 与 `AZURE_SPEECH_REGION`（`japaneast`）。
- 共发送 153 次请求，全部成功。按项目计费字符规则估算 13,599 个字符，以 Azure S1 Neural 公开零售价 US$15／百万字符计约 US$0.20；实际账单未在订阅门户核验。
- 未访问 Supabase，未修改代码、配置或随包音频。原始 MP3 与逐条结果保存在 `output/azure-loudness-calibration-2026-10-09/`（`raw/`、`measurements.json`、`summary.json`）；该目录被 Git 忽略，只作本机证据。

## 方法

- SSML 由 `supabase/scripts/generate_azure_seed_audio.py` 的 `build_ssml` 生成，结构、转义和 prosody 与线上 `buildAzureSsml` 一致；输出格式为 `audio-24khz-160kbitrate-mono-mp3`。
- 基线：10 句 starter 种子分别用 12 个 profile（英语 4 个；繁中、日语各 4 个母语 profile）在默认音量下合成，共 120 条。
- 边界句：5 个声线的默认 profile 各合成 3 句（极短句、短问句、长句），共 15 条。
- SSML 音量：Jenny `gentle-natural` 与曉臻 `native-gentle` 各取前 3 句，`volume` 设为 `-30%`、`-50%`、`+30%`，共 18 条。
- 测量：本机 FFmpeg 7.1.1 `loudnorm` 首遍测量 EBU R128 综合响度与真峰值，与现有处理器 `lufs-v1` 的测量方式相同。

## 结果

### 原始响度（默认音量，每行 10 句）

| 语言 | profile | Azure 声线 | 平均 LUFS | 标准差 LU | 范围 LUFS | 最高真峰值 dBTP |
|---|---|---|---:|---:|---|---:|
| 日语 | native-gentle | ja-JP-NanamiNeural | -17.13 | 0.29 | -17.69～-16.53 | -2.94 |
| 日语 | native-clear | ja-JP-NanamiNeural | -17.16 | 0.27 | -17.60～-16.71 | -2.97 |
| 日语 | native-bright | ja-JP-NanamiNeural | -17.04 | 0.27 | -17.60～-16.56 | -2.94 |
| 日语 | native-calm | ja-JP-NanamiNeural | -17.28 | 0.29 | -17.74～-16.75 | -2.95 |
| 繁中 | native-gentle | zh-TW-HsiaoChenNeural | -19.04 | 0.32 | -19.50～-18.68 | -3.70 |
| 繁中 | native-clear | zh-TW-HsiaoChenNeural | -19.01 | 0.31 | -19.48～-18.68 | -3.70 |
| 繁中 | native-bright | zh-TW-HsiaoChenNeural | -18.99 | 0.32 | -19.51～-18.53 | -3.72 |
| 繁中 | native-calm | zh-TW-HsiaoChenNeural | -19.09 | 0.30 | -19.60～-18.74 | -3.79 |
| 英式英语 | elegant-british | en-GB-SoniaNeural | -18.96 | 0.72 | -19.94～-17.40 | -4.03 |
| 美式英语 | daily-bright | en-US-GuyNeural | -19.72 | 0.39 | -20.38～-19.01 | -0.75 |
| 美式英语 | gentle-natural | en-US-JennyNeural | -20.89 | 0.76 | -21.68～-19.38 | -2.32 |
| 美式英语 | clear-slow | en-US-JennyNeural | -20.84 | 0.74 | -21.69～-19.31 | -2.31 |

- 12 个 profile 的平均值相差 3.84 LU。按声线合并后为 Nanami -17.15、Sonia -18.96、曉臻 -19.03、Guy -19.72、Jenny -20.86 LUFS，相差 3.71 LU。
- 同一声线的四个 profile 之间最多相差 0.24 LU（Nanami），语速和音高设置对响度影响很小。
- Guy 原始真峰值达 -0.75 dBTP，不衰减就会超出现行不高于 -1 dBTP 的规范。
- 本次曉臻原始平均 -19.04 LUFS，与旧版 16 kHz 种子实测的 -19.13 LUFS 相近，换输出格式基本不影响电平。

### 同一句母语与英语的原始差距

数值为母语 `native-gentle` 减英语，单位 LU，括号内为 10 句范围。

| 母语 | gentle-natural | clear-slow | daily-bright | elegant-british |
|---|---|---|---|---|
| 繁中 | +1.85（+0.66～+3.00） | +1.80（+0.59～+2.89） | +0.68（+0.01～+1.32） | -0.08（-1.57～+1.26） |
| 日语 | +3.75（+2.24～+4.81） | +3.70（+2.17～+4.67） | +2.59（+1.87～+3.21） | +1.82（+0.37～+2.54） |

旧方案（Azure 繁中原始输出对 OpenAI 英语）同一句相差 6～11 LU。全部改用 Azure 后差距明显缩小，但日语对 Jenny 仍有约 3.7 LU。

### SSML 音量的实际效果

| 声线 | `-30%` | `-50%` | `+30%` |
|---|---:|---:|---:|
| Jenny gentle-natural | -3.10 dB | -6.02 dB | +2.28 dB |
| 曉臻 native-gentle | -3.10 dB | -6.02 dB | +2.27 dB |
| 按线性振幅换算 | -3.10 dB | -6.02 dB | +2.28 dB |

各句误差不超过 0.02 dB，相对 `volume` 是精确的线性增益。调高也有效，但 Jenny 在 `+30%` 时真峰值升到 -0.35 dBTP，所以校准只做衰减。

### 按声线固定音量的模拟

| 目标 | 音量表 | 120 句在 ±1 LU 内 | 最大偏差 | 同句母语对英语最大差 | 边界句偏差 | 最高真峰值 |
|---|---|---:|---:|---:|---|---:|
| -20.9 LUFS | Jenny 0%、Guy -13%、Sonia -20%、曉臻 -19%、Nanami -35% | 117 | 1.59 LU | 1.64 LU | -2.20～+0.92 LU | -1.96 dBTP |
| -22.45 LUFS（现种子电平） | Jenny -17%、Guy -27%、Sonia -33%、曉臻 -33%、Nanami -46% | 117 | 1.57 LU | 1.73 LU | -2.27～+0.93 LU | -3.48 dBTP |
| 不调整 | 无 | 54 | 2.93 LU | 4.81 LU | 未计算 | -0.75 dBTP |

音量表取整数百分比；「不调整」一行按 120 句的总平均计算偏差。

### 边界句

极短句和短问句偏离本声线平均值最多 2.21 LU（Jenny「Wait, really?」偏轻），长句都在 0.66 LU 以内。固定音量对完整句子效果好；极短句仍有 1～2 LU 的自然波动。

### SSML 标记的计费影响

- 现行 SSML 每次请求都带 `<prosody rate="…" pitch="…">…</prosody>`，即使取值是 `0%` 也计费，约 40～43 个字符。
- 种子句平均正文：英语 70 个字符（计费 70）、繁中 17.9 个字符（计费 34.9）、日语 28.0 个字符（计费 35.0）。中文短句的标记字符接近或超过正文计费字符。
- 只写非默认属性并加入 -20.9 LUFS 音量表后：Jenny `gentle-natural` 为 0，`clear-slow` 为 31，Sonia 与母语 `native-gentle` 为 33，`native-clear` 为 44，`daily-bright`、`native-bright`、`native-calm` 为 57。

## 结论

1. 统一 Azure 后，供应商不同造成的大落差消失，但声线之间仍差约 3.8 LU；日语母语与 Jenny 英语交替播放时听得出来，需要校准。
2. 各声线句间稳定、profile 影响很小，SSML `volume` 又是精确的线性增益，按声线固定音量即可让绝大多数完整句子落在 ±1 LU 内，不需要线上逐条 FFmpeg 处理。
3. 目标取 Jenny 的自然电平 -20.9 LUFS：一致性与 -22.45 LUFS 相同，所有声线只衰减，默认英语声线不需要任何标记字符。

## 2026-10-09 B 版试听与种子编码复核

主人试听后选择 B：五个声线统一提高约 0.5 dB，目标改为 `-20.4 LUFS`。Azure 用 v2 SSML 重合成 50 句，共 4,669 个计费字符；每句比 v1 提高 `+0.47`～`+0.53 dB`。

| 声线 | B 版平均 LUFS | B 版最高真峰值 |
|---|---:|---:|
| Jenny | -20.38 | -1.82 dBTP |
| Guy | -20.44 | -1.48 dBTP |
| Sonia | -20.37 | -5.47 dBTP |
| HsiaoChen | -20.35 | -5.00 dBTP |
| Nanami | -20.36 | -6.18 dBTP |

种子偏小的原因不是 Azure 输出差异，而是本机 MP3 重新编码：Azure MP3 解码到 WAV 后仍为 `-20.08 LUFS`；再编码成 160 kbit/s MP3 后变为 `-20.53 LUFS`，约低 `0.45 dB`，真峰值也低约 `0.44 dB`。因此 v2 种子会直接保存 Azure 返回的 MP3；FFmpeg 只测量，不重新编码。当前 60 条旧种子的实测值为 `-21.34`～`-21.33 LUFS`。

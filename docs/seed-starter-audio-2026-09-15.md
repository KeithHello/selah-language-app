# 十句 starter 与中日母语音频验收记录

日期：2026-09-15

## 结论

本地 Web 首发候选已经从 30 句收敛为 10 句。每句同时具备繁体中文、日语和英文内容；循环听的种子音轨现在按母语区分，当前包内共有 20 段母语 MP3。

| 项目 | 当前结果 |
| --- | --- |
| Starter 种子 | 10 句，`seed-001`、`seed-006`、`seed-027`、`seed-012`、`seed-016`、`seed-021`、`seed-004`、`seed-010`、`seed-030`、`seed-020` |
| 内容字段 | 每句都有 `zh_text`、`ja_text`、`en_translation` |
| 分类覆盖 | 工作 2、朋友 2、生活日常 2、吐槽 1、心里话 2、想法 1 |
| 英文目标音频 | 10 句 × 4 声线 = 40 条 |
| 母语音频 | 中文 10 条、日语 10 条 |
| 音频清单 | 60 条，旧式 `:source` 键为 0 |
| Release 候选 | Build ID `3c5e4fd11eb124c6` |

## 实现范围

- `SeedContent/seed-sentences.json` 和 `SelahFlutter/assets/content/seed-sentences.json` 已同步为同一组 10 句。
- `LearnSentence` 保留种子的 `ja_text`；设置为日语母语时，`LearningController.seeds` 显示日语文本，并把 source 音轨解析为 `seed-xxx:source:ja`。
- 中文母语使用 `seed-xxx:source:zh-Hant`；英文目标继续使用现有四种声线。
- 循环听内置音频统一按 Flutter Web 的 `assets/assets/audio/...` 入口生成 URL；回归测试覆盖中文和日文母语音轨，避免缺少 Web 资源前缀。
- `package_seed_audio.py --local` 只读取和校验本地 MP3，不调用 TTS；清单记录每个文件的 SHA-256 与字节数。

## 验证证据

| 验证 | 结果 |
| --- | --- |
| Flutter 种子／循环音轨测试 | 5 项通过 |
| `dart analyze lib/web test/seed_starter_content_test.dart test/web_loop_seed_audio_test.dart` | `No issues found` |
| Python 打包器回归 | 6 项通过 |
| 本地资产完整性 | 60 条清单逐条存在，SHA-256、字节数、MP3 头均匹配 |
| Web Release 构建 | 成功；公共 Supabase 配置存在，未发现 OpenAI 私钥 |
| 本地 HTTP 资源 | 种子 JSON、音频 JSON 和代表性日语 MP3 均返回 HTTP 200；前两者解析出 10 句、60 条，MP3 为 63360 字节 |

## 尚未声称完成的部分

- 没有执行 Supabase 远端 seed 导入、数据库 schema／migration、真实账户同步或 Cloudflare Pages 部署；远端数据库不能据此视为已经变成 10 句。
- `SelahFlutter/assets/audio/` 中原有的 120 段旧英文 MP3 仍保留，当前清单不引用它们；未获明确授权不会删除。
- iPhone Safari、Android、PWA 锁屏和长时间循环播放尚未做真机验收。
- 2026-09-15 循环听修正规划中的自定义时长、准备／开始分离、暂停改序和独立截止，不属于本次 starter 音频交付。

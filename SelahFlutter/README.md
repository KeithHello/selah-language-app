# Selah Flutter Web

这里包含正式 Flutter Web／PWA 客户端及原有 Flutter 原生预览。Web 使用真实 Supabase 合约与浏览器标准 API，原生预览仍走既有 Fixture／SQLite 入口。两者通过 `lib/main.dart` 的条件导入隔离。

## 运行

在仓库根目录：

```powershell
.\SelahFlutter\tool\web.ps1 -Action run
```

默认地址是 [http://127.0.0.1:5180](http://127.0.0.1:5180) 。仅生成产物：`-Action build`。产物位于 `SelahFlutter/build/web/`。脚本不会部署网站或修改环境文件。

脚本读取已有的 `SUPABASE_URL` 与 `SUPABASE_PUBLISHABLE_KEY`，进程环境覆盖根 `.env`。仅使用 HTTPS Supabase 地址和 publishable／旧 anon key，禁止 service-role／OpenAI secret。缺少公开配置时进入明确的本地模式。

其他系统可在本目录构建：

```bash
flutter pub get
flutter build web --release --no-web-resources-cdn
python -m http.server 5180 --bind 127.0.0.1 --directory build/web
```

需要云端时，通过同名 `--dart-define` 提供公开配置。上述手工构建可本地启动；对已安装的 PWA 发布更新时，还必须更新 `index.html` 的 `selah-build-id`。Windows 脚本自动按产物内容生成版本号和完整 precache 清单，是本项目的标准构建入口。

## 已接线的功能

C 短绒角色已用于正式 Web 页面；五个成长阶段各有十张独立完整姿态，并由 Web 与原生 Flutter 共用同一映射。运行素材采用 768 × 768 RGBA PNG，原始 RGB 设计图保留；Today 的主精灵、名字与状态和欢迎文案居中展示。圆形开始操作在引导页滚动时保持可达。最新改善候选与离线音频证据见 [Web 改善验收](../docs/web-improvement-acceptance-2026-09-09.md) ，素材与布局验证见 [开发路线图](../ROADMAP.md) 。

开发时单独查看真实角色组件：在本目录运行 `./tool/web.ps1 -Action run -PreviewPlush -Port 5182`。预览含十动作重播、减少动态效果开关及五个成长阶段；产物位于 `build/plush-preview/`，不进入正式产品导航。重新构建预览后，关闭该预览的全部标签再打开以应用缓存更新。

| 区域 | 功能 |
| --- | --- |
| 开场 | 命名、三句种子选择、幂等保存 |
| Today | 中文输入、长文分段编辑、AI 生成、失败草稿重试、30 条种子浏览与加入 |
| Listen | 真实 MP3、暂停／续播／重播、进度、语速、英文揭示、SHA-256 校验与缓存 |
| Practice | 到期复习、主动温习、三种自评、实际调度与完成记录 |
| Notes | 中英文搜索、分类、拆解、词汇熟悉度、夜间预览和成长回忆 |
| Settings | 昵称、声线、提醒时间、登录注册、同步、备份、存储保护、安装与显式更新 |

IndexedDB 按账户保存快照，写入失败不显示保存成功。登录后手动选择「导入本机学习记录」合并访客资料；退出账户保留各自分区。同步沿用现有 RLS 表，使用稳定事件 ID 与带版本条件的更新；中途失败保留本地状态，联网／手动重试后继续。

## 离线和数据边界

- 30 条种子文本与 120 段现有 MP3 随包附带：每条种子均含 `gentle-natural`、`clear-slow`、`daily-bright`、`elegant-british` 四种声线。2026-09-09 Release 候选已在 Chrome 中断网验证 120 段音频均可读取且 SHA-256 匹配，并对四种声线抽样解码；新增 TTS 调用为 0。
- 首次联网加载并完成 Service Worker 缓存后，可以离线重启、学习已保存内容和播放缓存音频。字体与 CanvasKit 随包提供。首次下载包含较大的中文字体，暂未做移动网络性能验收。
- Today 输入和分段编辑会按账户即时写入本机快照，刷新后恢复；生成成功只清理本次提交且未再编辑的版本，等待期间的新编辑不会被旧结果覆盖。网络恢复后在草稿区重试生成，同一请求复用 UUID；主动「重新生成」会创建新请求。云同步自动恢复。
- JSON 备份包含句子、词汇、复习进度、偏好、回忆和生成草稿，不包含原始录音、音频文件或有时效的下载地址。先校验版本／大小／关联 ID，再合并；不能直接读取 iOS SwiftData。旧 iOS 本地记录仍需导出适配或实际云同步验收。
- 录音最长 180 秒，10 MiB 上限。失败后的录音仅保留于当前页面会话内供重试；刷新或切换账户会清除未转写录音。文字确认后才进入生成。
- 提醒目前在页面运行时触发。Push 的订阅持久化、服务端调度和 VAPID 配置尚未实施，详见 [上线方案](../docs/web-push-plan.md) 。系统 Widget 与原生后台任务不能直接搬入网页。

## 验证与上线

```bash
flutter analyze
flutter test
node --test test/browser_bridge.test.mjs test/browser_unload_protection.test.mjs test/service_worker_poses.test.mjs test/plush_assets.test.mjs
```

浏览器与服务端证据见 [Web 改善验收](../docs/web-improvement-acceptance-2026-09-09.md) 与 [Web 验收记录](../docs/web-acceptance.md) 。`speech-transcribe` 与四个生成／音频改善函数均已部署；2026-09-09 零费用检查为 `OPTIONS 200`、无凭证 `POST 401 UNAUTHORIZED_NO_AUTH_HEADER`，16 个远端 TypeScript 文件与本地核对一致。只有完成测试账户的真实 AI／TTS／转写和跨设备验收后，才能宣称在线服务可用。

公开托管需要 HTTPS、正确的 JS／Wasm MIME 与缓存策略。根 `index.html`、Service Worker 和 manifest 应短缓存／重新校验；版本化静态资源可长缓存。生产部署、密钥、CI 和 schema 变更仍需主人独立确认。

## 目录与素材

`lib/web/domain/` 放数据契约与学习算法，`data/` 放账户和存储，`platform/` 放 JS 边界，`ui/` 放界面。`web/` 只放浏览器适配与 PWA 入口。沿用 Quiet Growth 暖米色与珊瑚色、C 短绒角色；字体来源见 [字体许可证说明](assets/fonts/README.md) 。

不新增 Flutter 包或全局依赖，未改动旧 Swift 业务。Windows 不支持 Xcode／iOS 真机构建，本轮不据此宣称原生平台通过验收。

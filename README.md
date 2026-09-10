# Selah

把真实的中文想法变成自然英文，听懂、复习，再慢慢说出来。现在以 Flutter Web／PWA 为主客户端，保留既有 SwiftUI iOS 工程和 Flutter 原生预览。

## 当前状态

Web 客户端已实现命名与选句、今日表达、长文整理、真实音频播放、复习自评、笔记词汇、精灵成长、账户同步、备份、录音和 PWA 适配。实际验证范围与外部阻塞见 [ROADMAP.md](ROADMAP.md) 和 [Web 验收记录](docs/web-acceptance.md) 。

当前 Web 角色采用 C「短绒织物」，五个成长阶段各有十张独立动作图，并已接入正式 Web、原生 Flutter 展示和五十动作预览；查看 [五阶段五十动作验收](docs/web-plush-50-acceptance.md) 。

未登录时可在本机学习 30 条正式种子文本。当前 Release 候选随包附带 120 段已有 MP3：30 条种子 × 4 种声线（`gentle-natural`、`clear-slow`、`daily-bright`、`elegant-british`）。2026-09-09 已在 Chrome 断网状态下验证 120 段音频均可读取且哈希匹配，并对四种声线抽样解码；新增 TTS 调用为 0。个人英文生成与云同步依赖可用的在线服务，不回退模拟数据。

2026-09-09，本地 Web 改善候选已通过自动化与浏览器离线验收；首装预缓存优化后的 Build ID 为 `1c0036e1c11f90a9`，实测记录见 [首装性能验收](docs/web-performance-2026-09-09.md) 。`speech-transcribe` 与四个生成／音频改善函数已部署到远端，零费用检查均为 `OPTIONS 200`、无凭证 `POST 401`，部署源码已与本地核对一致；真实登录、AI／TTS、转写、RLS 及跨设备同步尚未完成线上闭环验收。本轮没有修改密钥、数据库 schema 或 CI。

## 本地启动

需要已安装的 Flutter 和 Python。在仓库根目录使用 PowerShell：

```powershell
.\SelahFlutter\tool\web.ps1 -Action run
```

打开 [本地 Web](http://127.0.0.1:5180) 。脚本构建 Release 页面，打包本地渲染器和字体，生成离线资源清单，再启动本机静态服务。只构建时使用 `-Action build`；可通过 `-Port 5181` 指定本地端口。

脚本只读取根 `.env` 中已有的 `SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEY`，进程环境变量优先。未提供这两个公开配置时仍能使用本机学习。服务器 secret 和 OpenAI key 不得传入 Web 构建。详细运行方式见 [Flutter Web README](SelahFlutter/README.md) 。

## 工程结构

- `SelahFlutter/lib/web/`：Web 领域模型、学习引擎、控制器、Supabase 与响应式界面。
- `SelahFlutter/web/`：IndexedDB、音频、录音、通知、安装和 Service Worker。
- `SelahFlutter/assets/`：正式种子内容、已有音频、字体及分层精灵。
- `Selah/`、`SelahWidget/`：既有 SwiftUI／SwiftData iOS App 与 Widget。
- `supabase/`：既有 schema、RLS 与 Edge Functions；`speech-transcribe` 与四个生成／音频改善函数已完成远端部署，尚未进行普通账户付费链路验收。
- `SeedContent/`：30 条正式种子内容源。

## 验证

```powershell
cd SelahFlutter
flutter analyze
flutter test
node --test test/browser_bridge.test.mjs test/browser_unload_protection.test.mjs test/service_worker_poses.test.mjs test/plush_assets.test.mjs
.\tool\web.ps1 -Action build
```

服务端在仓库根目录运行：

```bash
deno test --allow-env --allow-read supabase/tests
```

Swift／iOS 的历史 CI 与真机状态单独记录于路线图；本轮 Windows Web 验证不代表 iPhone Safari、iOS 真机或 TestFlight 验收。

## 开发与上线资料

- [Web 开发计划](docs/superpowers/plans/2026-09-05-selah-web-development.md) 。
- [Web 设计与边界](docs/superpowers/specs/2026-09-05-selah-web-design.md) 。
- [语音转写接口](docs/web-speech-service.md) 。
- [Web Push 上线方案](docs/web-push-plan.md) 。
- [Web 改善候选验收](docs/web-improvement-acceptance-2026-09-09.md) 。
- [原版产品设计](archive/selah-v8-unified-design-spec.md) 。

Private — all rights reserved. 第三方字体保留各自许可证。

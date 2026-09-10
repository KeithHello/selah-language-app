# Web 首次离线安装性能验收

日期：2026-09-09。最新本地候选：`1c0036e1c11f90a9`。本次只调整 Service Worker 预缓存及其回归测试，未部署 Web 或调用付费服务。

## 实现与实测结论

此前首次安装预缓存了 CanvasKit、Skwasm、Skwasm Heavy、Wimp 与实验版 WebParagraph。当前生成的 `flutter_bootstrap.js` 仅声明 `dart2js`＋`canvaskit`，没有启用 Wasm 或实验渲染配置。对照现有 Flutter SDK 的 `flutter_js/src/canvaskit_loader.js` 与实际浏览器请求，当前自动选择的是 Chromium CanvasKit；通用 CanvasKit 为其他浏览器保留。

已从固定预缓存清单移出 8 个未启用的渲染器文件，合计 16,667,798 字节；运行文件仍在发布包中。预缓存继续包含两种 CanvasKit、14 张初始角色姿态、字体和全部 120 段种子音频。静态资源按需缓存路径保持可用；未来启用 Wasm 或实验渲染器时须同步检查预缓存。

| 指标 | 修改前 `7e0a4516b041c795` | 修改后 `1c0036e1c11f90a9` |
| --- | --- | --- |
| 首装 Cache Storage 响应正文总量 | 73,515,852 字节 | 56,847,959 字节 |
| 缓存条目数 | 188 | 180 |
| 首次加载至离线安装完成的本地 HTTP 响应正文总量 | 104,083,662 字节 | 87,415,674 字节 |
| 断网后种子音频 SHA-256／字节数匹配 | 120／120 | 120／120 |
| 浏览器未捕获异常 | 0 | 0 |
| 发布目录文件数／磁盘体积 | 231／99,790,053 字节 | 231／99,789,958 字节 |

首装缓存减少 16,667,893 字节，约 22.7％；除 8 个资源外还包含 Service Worker 文本减少的 95 字节。收益发生在首次安装下载和浏览器存储，发布目录仍保留 Flutter 随包资源。

## 测量条件与范围

- Windows、无头 Microsoft Edge `152.0.4191.66`，CSS 视口 390×844；每轮新建浏览器上下文，没有既有 HTTP 或 Service Worker 缓存。
- 通过仅绑定 `127.0.0.1` 的临时静态服务器读取实际 Release，未启用压缩、网络限速或 CPU 限速；外部源请求被阻止，实际外部请求源为 0。
- 以 `flutter-first-frame` 事件记录首帧，以 `navigator.serviceWorker.ready` 记录安装完成，再遍历实际 Cache Storage 统计响应正文。
- 安装完成后显式断网并刷新，等待新的 Flutter 首帧；通过正常 `fetch` 逐个读取 120 段音频并校验大小和 SHA-256。
- 新候选额外以 `canvasKitVariant: "full"` 执行一轮通用 CanvasKit 测试。这个参数仅由测量服务器注入测试响应，产品启动配置没有更改。该轮实际加载通用 CanvasKit 的 JS／Wasm，离线重开、120 段音频校验与异常检查全部通过。
- 两个新候选测试均观察到完整引导页。通用渲染器测试仍运行于 Edge，不能替代 iPhone Safari／Android 真机验收。

单轮首帧采样为修改前 3,168.8 ms、修改后 2,732.3 ms；安装完成为 7,657.6 ms、7,003.7 ms。它们受本机负载影响，仅作为此次诊断样本，不是 Core Web Vitals、真实移动网络结果或性能提升承诺。离线首帧分别为 962.4 ms、995.5 ms。

## 代码与验证

- [Service Worker](../SelahFlutter/web/selah_service_worker.js) ：只移出未启用渲染器的固定预缓存条目。
- [回归测试](../SelahFlutter/test/service_worker_poses.test.mjs) ：先复现安装时多下载 8 个渲染器文件，再验证只缓存两种实际支持的 CanvasKit，且断网均可读取。
- Node 浏览器测试 22 项通过；Flutter 静态分析无 issue，Flutter 测试 140 项通过，Release 构建通过。
- 发布包内 Service Worker 与源码一致，SHA-256 为 `c068afc62db61f93ff1f32a638dde67b00d145568f90b7170791ecfc924bb2e0`。

本地原始证据位于 `output/playwright/final-web-acceptance/`：`performance-baseline.json`、`performance-candidate.json`、`performance-candidate-full.json`；对应离线截图使用同名前缀。测量入口为同目录 `measure-install.cjs`，使用本机已有 Playwright 和 Edge，不安装新依赖。

## 尚未验收

实体麦克风、iPhone Safari／主屏幕 PWA、Android、真实弱网、生产 HTTPS 压缩与缓存响应头、旧安装升级和后台恢复仍待 T10。普通账户的转写、生成、TTS、权限与跨设备测试仍待 T09；用量统计 schema 和 Web 公开发布分别等待独立确认。后续条件见 [开发清单](next-development.md) 。

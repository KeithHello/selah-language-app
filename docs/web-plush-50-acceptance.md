# C 短绒五阶段五十动作验收记录

日期：2026-09-06。本文记录五阶段 × 十动作素材及其在 Flutter 程序、正式 Web 和开发预览中的本地交付结果，不代表生产部署、线上服务或真实手机已经验收。

2026-09-07 更新：主人已明确选择保留原图并用本地脚本批量抠图，运行副本现改为真实 RGBA。本文的 RGB 体积与副本一致性属于 9 月 6 日历史基线；最新导出方式、透明度和 Today 布局验证见 [开发路线图](../ROADMAP.md) 。

## 交付结论

- 五个成长阶段各有十张独立动作图，共 50 张；顺序统一为待机、眨眼、叶片轻摆、准备聆听、播放中、聆听完成、录音中、录音完成、复习顺利、再试一次。
- 每张图片均为 1254 × 1254、8-bit RGB PNG，带暖白背景，没有 alpha 通道。50 个 SHA-256 均不同，设计稿与 `SelahFlutter/assets/sprites/` 中的运行副本逐字节一致。
- 正式 Web 和原生 Flutter 展示共用 `plushPoseAsset(stage, action)` 映射。运行时按成长阶段和动作选择完整姿态，不再用旧图集裁切或叠加绘制五官。
- 五十动作开发预览可切换阶段、重播一次性动作和开启「减少动态效果」。正式 Web 的学习、播放、录音和复习状态继续驱动既有业务动作。
- 正式 Web 初次引导显示第一阶段，保存引导后进入第二阶段。空闲时偶尔短暂眨眼、轻摆；业务动作立即接管，减少动态或页面隐藏时不自动换姿态。
- 原生 Flutter 本轮更新的是共享展示组件和 Gallery；旧原生页面仍有固定阶段且缺少学习事件驱动成长，不代表原生业务闭环已经完成。当前主产品为 Web，SwiftUI 客户端未在本轮替换。

完整总览：

![C 短绒五阶段五十动作总览](../design-system/selah/mascot/seed-c-actions-v4-all-review.png)

## 素材与运行接线

设计稿使用 `design-system/selah/mascot/seed-c-s{1..5}-a{01..10}-v4.png`，运行资源使用 `SelahFlutter/assets/sprites/PlushV4S{1..5}A{01..10}.png`。每阶段的提示词、原始生成位置、尺寸、哈希和目视记录保存在对应的 `seed-c-actions-v4-sN-assets.json`。

核心运行文件：

- `SelahFlutter/lib/features/companion/plush_companion_poses.dart`：唯一映射、完整姿态图片及按阶段预热。
- `SelahFlutter/lib/web/ui/plush_companion.dart`：正式 Web 过渡、一次性反馈、循环待机、后台暂停和 Reduce Motion。
- `SelahFlutter/lib/features/companion/selah_sprite.dart`：原生 Flutter 复用同一套五十张资源；循环转折已改为往返播放，避免周期末跳帧。
- `SelahFlutter/lib/features/companion/companion_gallery_screen.dart` 与 `SelahFlutter/tool/preview_plush.dart`：五阶段 × 十动作检查入口。
- `SelahFlutter/web/selah_service_worker.js`：首装缓存第一阶段十动作和其余四阶段待机图，其他动作首次访问后缓存。

按阶段预热会合并同阶段的并发请求；更大的显示尺寸会在低分辨率预热结束后继续升级。某张素材加载失败时不会把整个阶段误记为已缓存，下次请求会重试。

## 体积与限制

50 张运行 PNG 合计 72,065,102 字节，即 68.73 MiB。首装选择的 14 张合计约 17.73 MiB；正式 Web Release 当前总大小约 131.21 MiB。Service Worker 已修复重复请求，首装的 14 张姿态各只获取一次，其余阶段动作按需下载。

这批素材适合作为设计确认稿和当前本地运行版，但不适合作为最终移动网络发布资源。上线前需要从母版导出透明、裁边和多尺寸版本，并评估 WebP／AVIF；不能把当前 RGB 文件写成透明素材，也不能用脚本抠图伪造正式交付。

## 自动化结果

在 `SelahFlutter` 目录执行并通过：

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
node --test test/browser_bridge.test.mjs test/service_worker_poses.test.mjs test/plush_assets.test.mjs
.\tool\web.ps1 -Action build
.\tool\web.ps1 -Action build -PreviewPlush
```

- Flutter 静态分析：无 issue。
- Flutter：79 项全部通过，包含 50 组合唯一映射、完整姿态选图、失败重试、并发预热、不同缓存尺寸升级、首次引导阶段、空闲眨眼／轻摆和业务优先、一次性反馈、后台暂停、Reduce Motion、原生循环连续性及现有学习流程回归。
- Node：17 项全部通过，其中真实素材测试读取全部 50 张文件并检查 manifest、PNG 尺寸／色彩类型、唯一哈希和运行副本；Service Worker 测试验证首装无重复姿态请求及后续动作离线复用。
- 正式 Release：构建成功，版本 `bcd6314a55cb0fac`，Wasm dry run 通过。
- 五十动作预览 Release：构建成功，版本 `c774a8589cee3d2f`。

## 浏览器验收

为避免旧 Service Worker 把上一版资源误当成新构建，本轮使用全新本地来源检查：正式站 `http://127.0.0.1:5191/`，五十动作预览 `http://127.0.0.1:5192/`。

- 预览页逐一切换初见、萌芽、绿叶、花苞和开花，五个阶段均显示十张正确姿态，无错误阶段、破图、裁断或拉伸。
- 「减少动态效果」可切换为开启状态，重播按钮保持可用。
- 正式站完成取名、推荐三句、开始学习，进入 Today 后显示「新芽」阶段及新的双叶短绒角色。
- 预览来源的旧 Service Worker 已注销并刷新注册为 `c774a8589cee3d2f`；切换五个阶段与重播动作均使用当前预览构建。
- 在 `5191` 通过浏览器网络条件模拟断网后刷新：页面离线启动，精灵名「小芽」、两句成长回忆和第二阶段十姿态均从缓存恢复，没有退回首次引导；恢复网络后版本仍为 `bcd6314a55cb0fac`。
- 已有 `5181` 初次引导没有更新按钮，本轮通过浏览器开发接口向等待中的新 worker 发送既有 `APPLY_UPDATE` 消息，再刷新未填内容的标签。页面和活动 worker 均为 `bcd6314a55cb0fac`，实证加载第一阶段十张 `PlushV4S1Axx.png`，截图显示单枚小折芽。没有清理学习存储；另一未提交引导标签未刷新。生产环境仍需补验完整应用内更新入口。

本轮尚未执行低速网络、iPhone Safari、Android 实机、实体麦克风或生产 PWA 更新验收；这些项目继续作为上线门禁。上面的断网结果来自桌面浏览器的网络条件模拟，不能替代真实设备和弱网测试。

## 上线前剩余项

1. 把 68.73 MiB 的 RGB 姿态转成透明、裁边、响应式尺寸和现代格式，测量首屏、阶段切换、内存峰值和低速网络表现。
2. 用测试账户完成真实登录、中文生成、TTS、转写、复习保存和跨设备同步；当前只读后端可达与数据计数不能代替这条闭环。
3. 注册并部署 Web 转写函数，验证麦克风授权、拒绝、取消、超时和录音资源释放。
4. 在 iPhone Safari、Android 浏览器及安装后的 PWA 上完成触控、软键盘、离线、更新、存储清理和后台恢复验收。
5. 完成 HTTPS 托管、缓存头、监控、隐私政策与发布清单；生产部署仍需单独确认。

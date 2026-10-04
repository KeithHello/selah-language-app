# Web 正式环境加载与交互动效调研报告

> 验证日期：2026-10-04，Asia/Tokyo。正式站：https://selah-language-app.pages.dev/ 。版本：`1.5.0`，Build ID：`32645f749a16a878`。
>
> 本轮完成线上只读检查、测试专用匿名浏览器验收、性能采样、资源与代码核对，并整理后续修改依据。未修改产品代码、账号数据、数据库、部署配置或重新部署。

## 判断

正式环境可用，先前部署的字体瘦身、按钮按压反馈、页面和弹层过渡已经接入实际运行路径。主要按钮的反馈可以看见，桌面弹窗与手机抽屉能够正常操作，循环时长保存后的即时刷新也已通过。

整体速度与动效暂不应标记为「全部验收通过」。应用首次渲染仍有约 2～4 秒等待；页面切换出现可重复的长帧；关闭「动画效果」后，底部抽屉和精灵 GIF 仍在播放。资源检查还发现可明确避免的重复预缓存，优先处理这些问题比继续加大动画幅度更有价值。

## 正式环境与验证范围

| 项目 | 本次结果 |
| --- | --- |
| 页面版本与设置页版本 | 均为 `1.5.0 · 32645f749a16a878` |
| 首页、主 JS、预缓存清单、Chromium CanvasKit Wasm、子集字体、精灵资源 | HTTP 200，类型和缓存响应头已核对 |
| 线上 Service Worker 与当前源码 | 统一换行后内容一致 |
| GitHub main 与本地／origin main | 核对时均为 `d682a4fb712ad14b02fce2297f46244f5e6b9af8` |
| 当前产品发布 CI | [run 37139155819](https://github.com/KeithHello/selah-language-app/actions/runs/37139155819) 的五个任务全部成功，产品提交为 `d186656` |
| 浏览器运行异常 | 检查会话控制台 Errors 0；独立普通指针验收页面异常 0 |

浏览器覆盖 1280×720、1280×800 和 390×844。首次移动视口采样还使用了移动 UA 与 DPR 3。所有性能数据均来自本机 Chrome 无头浏览器、未限速的网络和 CPU；其他 Chrome 页面在同一台电脑上运行。这不是手机真机、受控 4G、Safari 或线上真实用户分布的成绩。

本轮使用真实内置句子完成匿名引导和学习页面操作，仅保存测试浏览器的本机偏好。未提交生成、录音、认证、支付、管理员操作或远端学习资料变更。真实账户、会员／管理台业务、麦克风和付费生成不属于本轮已验收范围。

## 加载速度

### 应用首帧

以页面实际发出的 `flutter-first-frame` 为主要启动观察指标。它仍不等同于全部图片加载完毕或所有操作都已可用，但比本页面的 HTML LCP 更接近用户等待应用的时间。

| 场景 | TTFB | FCP | Flutter 首帧 | 判断 |
| --- | --- | --- | --- | --- |
| 移动视口首次进入，引导页，样本一 | 89ms | 256ms | 2.12s | 可以进入，仍有等待 |
| 移动视口首次进入，引导页，样本二 | 112ms | 400ms | 3.03s | 波动明显 |
| 桌面首次进入，引导页 | 222ms | 420ms | 3.88s | 启动仍偏慢 |
| 桌面重载，引导页 | 187ms | 456ms | 2.15s | 缓存有收益，仍需启动工作 |
| 桌面已有匿名资料，直接进入今天页，动画关闭、未启用语义层 | 38ms | 144ms | 2.29s | 应用先渲染，之后继续下载精灵 |
| 上述今天页同一上下文重载 | 41ms | 124ms | 1.14s | 首帧改善，后续流量仍大 |

场景、观察窗口和设置不同，不把这些样本当成同一条件下的平均值、P75 或前后优化百分比。

### Core Web Vitals 的适用边界

| 指标 | 观察值 | 本次可得结论 |
| --- | --- | --- |
| LCP | 已捕获样本约 124～456ms | 最近样本明确指向 `SPAN`「正在準備你的學習空間…」，不能代表 Flutter 主页面加载完成 |
| CLS | 0 | HTML／DOM 层未记录偏移；CanvasKit 内部布局变化不能依靠该值完整判断 |
| INP | 未取得真实用户分布 | 不给线上 INP 达标结论，RAF 间隔也不替代 INP |
| TTFB／FCP | 上表所示 | 服务端响应和加载提示出现较快，主要等待发生在后续应用启动与渲染 |

[Google 的指标口径](https://web.dev/articles/vitals) 要求用真实访问的第 75 百分位判断整体达标；[LCP 支持的元素范围](https://web.dev/articles/lcp) 也解释了为什么此处加载提示不能作为整个 CanvasKit 应用的完成证据。本轮不提供 Lighthouse 分数，也不把长任务总时长称为 TBT。

### 首帧与进入后的卡顿要分开处理

最近今天页冷启动样本中，主 JS 传输约 1.07MB，Chromium CanvasKit Wasm 约 2.14MB，子集中文字体约 0.58MB；对应解码文件尺寸约 3.78MB、5.76MB 和 0.83MB。启动阶段出现最大 578ms 的主线程长任务，说明下载之外仍有较重的执行／渲染工作。具体编译、解码和布局占比未在本轮分摊到唯一根因。

同一样本的精灵请求从约 2.56s 才开始，晚于 2.29s 的应用首帧。因此，不能把这一组精灵下载全部说成首帧阻塞；它更直接影响应用已经出现后的网络、解码和交互负担。

移动冷启动观察到约 22.74MB 的页面资源传输；第一阶段十个精灵文件合计 18,685,823 字节。已有匿名资料的桌面今天页进入第二阶段后，十个文件合计 19,666,222 字节，页面资源传输约 23.73MB。重载该今天页时仍观察到约 17.73MB 的页面传输，主要是第二阶段 A02—A10 再次取回。

这些是页面 Resource Timing 的观察窗口数据，不含所有独立 Service Worker 安装请求。部分样本结束时 Service Worker 尚未接管，不能据此宣称完整离线缓存已安装，或把所有重载重复请求统一归因于某一缓存故障。

## 精灵资源与预缓存

### 「PNG」路径实际加载循环 GIF

50 个 `PlushV4S…png` 源文件全部是 `GIF89a`，尺寸 768×768，每个 16 帧，包含无限循环设置；与 50 个同名 `.gif` 副本逐对 SHA-256 相同。

正式站的 `PlushV4S1A01.png` 实际下载同样是 GIF，HTTP 类型却为 `image/png`。它包含 16 帧，单轮约 2.8 秒。线上 `.gif` 抽检与本地同名 PNG 路径的字节哈希一致。项目已有 `plush_assets.test.mjs` 也明确规定了这种兼容路径与双副本关系，所以不能将它描述为此次部署新产生的文件损坏。

实际表现是：Flutter `Image` 会播放资源自身的多帧动画。停止外层 `AnimationController` 并不等于停止 GIF。[Flutter Image 文档](https://api.flutter.dev/flutter/widgets/Image-class.html) 明确给出多帧图像通过 `TickerMode` 或 `MediaQueryData.disableAnimations` 暂停的机制。

### 可明确避免的重复预缓存

线上预缓存清单包含两套 50 个精灵资源。当前 Service Worker 策略选入每套第一阶段十个动作，再加第二至第五阶段各一个默认动作。

| 当前选入初装缓存的精灵组 | 数量 | 同版本源文件字节数 |
| --- | --- | --- |
| `.png` 路径，实际为 GIF | 14 | 26,007,077 |
| 同名 `.gif` 副本 | 14 | 26,007,077 |
| 两套合计 | 28 | 52,014,154 |

正式 Flutter 渲染路径使用 `.png`，`lib` 中未发现 `.gif` 路径调用；Service Worker 和构建清单仍将副本纳入缓存。保留源码素材，排除正式 Web 未使用的副本，按编码文件尺寸可避免约 26.0MB 的重复预缓存候选资源。此处是清单与字节盘点，不是对全量后台安装流量的独立实测。

`PlushPosePrecache.ensureStage` 在精灵首次显示后还会依次预加载当前阶段全部十个动作。当前实现限制了解码尺寸，却没有降低原文件的下载字节数。下一轮应先加载当前可见动作，其余动作在需要时加载，或在交互稳定后的空闲阶段有限预热，并将离线全量准备单独安排。

## 页面、按钮与组件验收

| 场景 | 结果 | 证据／边界 |
| --- | --- | --- |
| 引导页推荐三句、开始学习 | 通过 | 真实匿名流程进入今天页 |
| 主按钮按下与释放 | 反馈可见 | 开始按钮按住截图可见缩小，松开进入学习；不是所有按钮的逐项验收 |
| 桌面今天、聆听；手机今天、聆听 | 布局和入口可用 | 已保存截图，未发现主要操作区域被裁切 |
| 五个导航入口 | 导航冒烟完成 | 深度学习、答题和账户功能不在本轮操作范围 |
| 桌面语速菜单与自订语速弹窗 | 通过 | 菜单打开、自订窗口显示与取消正常 |
| 桌面循环设置弹窗 | 通过 | 打开、关闭和自订时长入口正常 |
| 手机循环设置抽屉 | 功能通过 | 可打开、关闭，内容与操作区域可见 |
| 循环时长保存后更新 | 通过 | 改为 45 分钟后，未关闭设置即显示「自訂 · 45 分鐘」选中 |
| 保存通知 | 可见 | 成功横幅出现；本轮不另给通知时序认证 |
| 动画开关保存 | 通过 | 语义树核对关闭、重新开启状态 |
| 关闭动画后的手机抽屉 | 未通过 | 录制帧中仍从底部滑入 |
| 关闭动画后的精灵 | 未通过 | 三次间隔采样仍出现位移与姿态变化，GIF 自身继续播放 |

### 页面切换仍有长帧

为排除语义层和截图录制的主要干扰，又在独立匿名上下文中关闭 Flutter 无障碍语义层、保持应用动画开启，通过真实指针操作桌面导航。每次记录约 1.2 秒 RAF 和主线程长任务，测量窗口内没有截图或 trace 录制。

| 普通指针场景 | RAF 间隔中位数 | 最大 RAF 间隔 | 最大长任务 |
| --- | --- | --- | --- |
| 初始页面空闲 | 12.1ms | 36.4ms | 无 ≥50ms 长任务 |
| 首次进入聆听 | 30.3ms | 224.3ms | 149ms |
| 首次进入笔记 | 42.4ms | 175.7ms | 168ms |
| 返回今天 | 48.5ms | 206.1ms | 208ms |
| 再次进入聆听 | 48.5ms | 115.1ms | 96ms |

这是可重复的实验室流畅度风险信号，不能换算成手机真实 FPS，也不能归因全部来自网站。此前带截图录制和语义层的结果开销更大，只作为可视化证据使用。

源代码还确认：懒栈访问过的页面会保持常驻，未给隐藏 Tab 包裹 `TickerMode(enabled: false)`；精灵外层虽检查 `TickerMode`，当前栈没有随 Tab 可见性关闭它。需在下一轮隔离验证隐藏页动画、GIF 解码和整页淡入的实际占比，而不是仅延长过渡时间来掩盖掉帧。

### 总开关覆盖存在两个确定遗漏

第一，`MotionScope` 位于 `MaterialApp.home` 内，新的 Navigator 弹层不会自然继承这个自定义作用域。`showSelahSheet` 没有捕获并传递开关，也没有将原生抽屉路由过渡归零；`SelahSheetEntrance` 在新路由中可能回退到系统设置。这与关闭开关后抽屉仍滑入的线上录制相符。

第二，精灵的 GIF 解码播放不由 `MotionScope` 或外层控制器直接控制。关闭应用动画开关后，固定区域截图仍在变化，确认为真实运行遗漏。应将多帧资源播放也接入应用开关和 Tab 可见性。

桌面 `showMenu`、原生 Material 组件反馈和 HTML 启动脉冲也需要纳入统一门控梳理。此处不能只检查自定义控制器是否停了就宣称「全部动画已关闭」。

### 按钮反馈未完全统一

目前主要按钮 0.94、次级按钮 0.96、图标按钮 0.90 的分级已经存在，主入口的按压反馈可见。仍有明确未接入统一按压组件的入口，例如紧凑语速按钮、自订语速弹窗的保存／取消按钮、循环设置的关闭图标，以及部分 Chip／菜单项。

这些仍有 Material 默认反馈，功能可以操作；问题是反馈强度和时序不一致。下一轮应按主按钮、次级按钮、图标、Chip、菜单行分别列覆盖清单，不把所有控件都套同一个大缩放。

## 下一轮修改顺序与验收条件

1. **先修动效总开关。** 将应用开关传入 Navigator／Overlay；抽屉与菜单关闭时使用零时长过渡；GIF／隐藏 Tab 使用正确的 `TickerMode` 或对应图像暂停机制。验收包括主页面、直接弹窗、抽屉、抽屉内再次打开的弹窗和精灵，关闭后全部停止运动，状态与可访问操作仍正常。
2. **减少已确认的资源负担。** 正式 Web 构建和预缓存排除未使用的同名副本，保留源文件和已有动作设计；阶段预热改为可见动作优先、按需／有限空闲预热。明确可避免的副本候选量约 26.0MB；十动作下载不再自动跟随首次显示。离线能力必须重新验收，不能只改清单。
3. **优化切换时的工作量。** 对隐藏页面停 ticker，检查 GIF 解码、已访问页面布局和整页 opacity／scale 的代价；用同一受控环境比较修改前后，而不是由这轮样本承诺具体快几秒。保留页面状态、草稿和播放位置。
4. **补齐控件反馈。** 重点补紧凑语速、弹窗动作、关闭图标、选择项和菜单；保持当前清晰的主按钮反馈，避免反复强调同一点击导致视觉拖沓。验证快速点击、连续点击、取消和退出过程中不丢动作。
5. **最后评估资源格式和渲染器。** 在保持透明、外观和已有动作时序的前提下比较静态／动画 WebP 或复用批准姿态的原生微动效。skwasm、跨源隔离和 Cloudflare 响应头作为单独评估项，不直接承诺收益或顺带更改生产配置。

下轮验收需包括 375px／390px 与桌面，冷启动、热重载和缓存接管后的重载，受控移动网络与 CPU 条件，以及至少一次真实手机检查。核心成功条件是进入应用后可及时操作、重复切页没有明显停顿、所有弹层开关一致；仅有单元测试成功或漂亮的加载提示 LCP 不够。

## 证据入口

全部本机证据在 `output/playwright/selah-production-audit-20261004/`，该目录为忽略的验收产物，不进入产品资源或预缓存。

- [启动与普通指针测量数据](../output/playwright/selah-production-audit-20261004/measurements.json) 。
- [线上清单、响应头与源码匹配盘点](../output/playwright/selah-production-audit-20261004/public-inventory.json) 。
- [50 对精灵副本哈希检查](../output/playwright/selah-production-audit-20261004/duplicate-sprite-check.json) 与 [GIF 帧数、尺寸和循环信息](../output/playwright/selah-production-audit-20261004/gif-metadata.json) 。
- [桌面今天页](../output/playwright/selah-production-audit-20261004/03-today-desktop.png) 、[手机今天页](../output/playwright/selah-production-audit-20261004/21-today-mobile.png) 、[手机循环设置](../output/playwright/selah-production-audit-20261004/15-loop-sheet-mobile.png) 。
- [主按钮按压](../output/playwright/selah-production-audit-20261004/02-primary-pressed.png) 、[自订语速弹窗](../output/playwright/selah-production-audit-20261004/09-custom-speed-dialog.png) 、[45 分钟即时更新](../output/playwright/selah-production-audit-20261004/13-duration-saved-45.png) 。
- [导航 Chrome trace](../output/playwright/selah-production-audit-20261004/04-navigation-trace.json) 、[手机抽屉 trace](../output/playwright/selah-production-audit-20261004/15-mobile-sheet-trace.json) 、[关闭动画后抽屉 trace](../output/playwright/selah-production-audit-20261004/18-motion-off-sheet-trace.json) 。这些 JSON 可导入 Chrome Performance 面板。
- 关闭动画后精灵截图：[A](../output/playwright/selah-production-audit-20261004/23-mascot-motion-off-a.png) 、[B](../output/playwright/selah-production-audit-20261004/24-mascot-motion-off-b.png) 、[C](../output/playwright/selah-production-audit-20261004/25-mascot-motion-off-c.png) 。

关键实现依据：[精灵阶段预热与 Image](../SelahFlutter/lib/features/companion/plush_companion_poses.dart) 、[懒栈](../SelahFlutter/lib/design/selah_lazy_indexed_stack.dart) 、[应用作用域与页面过渡](../SelahFlutter/lib/web/ui/web_learning_app.dart) 、[抽屉](../SelahFlutter/lib/design/selah_sheet.dart) 、[语速控件](../SelahFlutter/lib/web/ui/speed_selector.dart) 、[Service Worker](../SelahFlutter/web/selah_service_worker.js) 、[GIF 资产合约](../SelahFlutter/test/plush_assets.test.mjs) 。

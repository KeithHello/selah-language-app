# 版本号体系与动效整体开发方案（2026-10-03）

> 状态：主人已批准并授权完整开发。本文件为实施依据，进度以 ROADMAP.md 为准。

## 第一轮 v1.1.0：版本号体系

- 版本源：SelahFlutter/pubspec.yaml 的 version 字段（语义版本）。功能轮升次版本、修复轮升补丁，构建序号同步递增；本轮发布 1.1.0+2。
- 构建注入：tool/web.ps1 构建后先读取 pubspec 版本并注入产物 index.html 的 selah-version meta，再计算 Build ID 内容指纹并注入；版本变化必然改变指纹。
- 桥接：web/selah_bridge.js 新增 appVersion()，读取 selah-version，随 platformInfo 与 checkUpdate 返回，缺省 dev。
- 界面：设置页「版本」行副标题改为「语义版本 · Build ID」。
- CI：build.yml web 任务读取版本与指纹；线上校验两者一致；部署成功后把版本、指纹、环境写入 GitHub Actions Summary。
- 规范：CLAUDE.md 部署规范新增版本升级规则与「每次生产部署后向主人汇报实际版本号、Build ID 与线上校验结果」义务。
- 测试：browser_bridge.test.mjs 覆盖 meta 读取与 dev 回退；tool_web_cloud_config.test.mjs 断言版本注入存在。

## 第二轮 v1.2.0：动效 M0—M2

- M0 导航过渡：IndexedStack 外加转场包装，didUpdateWidget 检测 tab 变化，新内容约 200ms 淡入＋上浮（easeOutCubic）；IndexedStack 本体不动，页面滚动、草稿与播放状态保留；走 MotionScope 门控，关闭即直出。
- M1 按压反馈：design 层新增轻量按压组件（按压缩至约 0.97、约 110ms 回弹），覆盖立即同步、儲存資料、生成、播放等主 CTA；开关关闭时缩放恒为 1，树形结构稳定不丢状态。
- M2 首次入场 stagger：抽取会员卡入场模式为通用组件（40ms 间隔淡入上移），今天／聆聽／練習／筆記四页每页首次进入时播放；访问记录存内存不持久化；再次切换只走 M0。
- 验收：切 tab 有过渡、主按钮有手感、首次进页卡片依次浮现、关闭動畫效果全部直出；flutter analyze 与全量测试通过；375px 与桌面浏览器冒烟。
- M3 骨架屏排下一轮，待性能 P0 基线拍板。

## 发版与汇报

- v1.1.0 与 v1.2.0 分别 push main，走 push main 自动构建部署通道；每次部署后向主人汇报实际版本号、Build ID 与线上校验结果。
- 可选项（默认不做）：应用内「已更新到 vX」提示、檢查更新文案带版本号。
- 范围外：M3、Swift 原生 App 版本体系、.env、数据库、Cloudflare 配置。

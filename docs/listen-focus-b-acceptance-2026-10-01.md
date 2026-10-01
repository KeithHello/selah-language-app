# 聆听方案 B 验收记录（2026-10-01）

## 自动化与构建

- 聆听实现提交：`1ceccc3`，标题为 `feat: 聆听页聚焦单句并新增固定前后句播放控件`。
- 当前干净分支的 `flutter analyze --no-pub` 通过，无问题；`flutter test --no-pub` 379 项全部通过；`git diff --check` 通过。
- 从提交 `1ceccc3` 的干净源码快照运行 `SelahFlutter/tool/web.ps1 -Action build` 成功。Build ID 为 `aad1d4ede820b49c`，预缓存清单含 189 项。该构建没有 Supabase 公共配置，明确只适合本地浏览器验证。
- Build ID `71a94e0c469f3320` 的 Web 构建含 189 项预缓存，已确认包含聆听专注控件及 Supabase 公共配置。仓库现有部署记录显示它已随提交 `6c5bc8d` 部署到 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名；GitHub 比较确认 `6c5bc8d` 包含本功能提交 `1ceccc3`。版本地址：[预览版本](https://dd3dde92.selah-language-app-preview.pages.dev) ；别名地址：[预览别名](https://codex-web-ux-reliability.selah-language-app-preview.pages.dev) 。本任务没有再次执行部署或独立访问线上页面。

## 桌面浏览器冒烟

- 环境：Codex 内置浏览器，本地 Web 构建，1280×720 视口，繁体中文界面，使用内置示例句。
- 页面默认展示一张当前句卡片，并把句库放在按需打开的入口后；卡片提供上一句、播放和聆下一句控件。
- 点击「聆下一句」后，位置由第 1／3 句变为第 2／3 句，随即自动播放示例音频并正常结束。
- 响应式组件自动化测试覆盖 320—1440px。没有在 iPhone Safari 或 Android Chrome 真机上验收。

## 尚未完成

- U01—U16 的完整人工浏览器清单、真实移动设备、已登录账户及在线服务端端到端验收仍待完成。
- 已部署记录仅涉及 Cloudflare Pages 预览项目及其 `codex-web-ux-reliability` 别名；没有生产部署、DNS 或项目配置变更。部署来源与实现提交的包含关系已通过 GitHub compare 核对。
- 本轮未独立打开线上预览地址验收；U01—U16 完整人工清单、窄屏流程、iPhone Safari／Android Chrome 真机及登录账户在线端到端测试仍待完成。

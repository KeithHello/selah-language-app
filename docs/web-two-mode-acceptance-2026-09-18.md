# Web 二元运行模式与首次引导验收记录

日期：2026-09-18

本轮完成 Web 客户端实现，目标是把产品行为收敛为「测试模式」和「生产模式」两种模式，并改善首次输入精灵名字的可理解性。没有修改 `.env`、数据库 schema、Supabase 远端开关或 Edge Function；已按授权部署 Cloudflare Pages 预览版本。

## 已验证行为

| 场景 | 验证结果 |
| --- | --- |
| 管理台模式配置 | 测试模式发送匿名开启、会员限制关闭、生成开启；生产模式发送匿名关闭、会员限制开启、生成开启。混合配置按生产模式安全回退，并显示风险提示与「应用生产模式」归一化操作。 |
| 匿名会话 | 匿名 Supabase 身份仍可用于收费入口，但本机数据保持 `guest` 作用域，不触发账户切换、页面清空或云端同步；浏览器刷新后已有匿名会话也会恢复 `guest` 资料。 |
| 草稿重试 | 匿名会话不存在时，重试草稿会先建立匿名会话，再沿用原请求 ID 调用生成。 |
| 错误提示 | 预算保护、网络和音频错误不会自动出现登录按钮；`unauthorized`、`login_required`、`anonymous_test_ended` 仍在当前页面提供登录／注册入口，试听／轮询／加载新错误会清除旧认证错误码。 |
| 首次引导 | 名称区域展示步骤、必填标识、帮助说明和实时问候；点击开始会聚焦名称输入或提示至少三句，不跳转页面。 |
| 正式账户 | 只有非匿名会话加载会员／研究资料并执行同步；已有正式账户入口与管理员校验保持不变。 |

## 验证命令

```text
dart analyze lib/web/learning_controller.dart lib/web/ui/web_learning_app.dart lib/web/ui/web_start_action.dart lib/web/ui/admin_dashboard_page.dart lib/web/admin/admin_controller.dart lib/web/domain/admin_membership.dart
flutter test
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\web.ps1 -Action build
git diff --check
```

结果：Dart analyze 0 issues，Flutter 全量 251 项通过，Release Web 构建成功，`git diff --check` 通过。本地和远端 Build ID 均为 `c19efc446a159867`。远端首页、种子 JSON、音频清单、预缓存清单和代表性中文 MP3 均返回 200；种子 10 句、音频 60 条、预缓存 189 项。

## 后续需要单独确认

- 使用真实管理员账号在管理台切换两种模式，并用浏览器分别验证匿名生成、转写、TTS 和生产模式登录提示。
- 生产环境上线前确认匿名测试开关、每日平台预算、Supabase Anonymous Sign-ins 和会员限制的最终状态。
- 本轮已将提交 `a38c811` 推送到 GitHub 分支 `codex/web-ux-reliability`，并部署 Cloudflare Pages 预览；没有更改 Supabase 远端配置、DNS 或正式生产域名。

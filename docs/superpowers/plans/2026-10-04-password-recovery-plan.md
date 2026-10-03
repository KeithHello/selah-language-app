# Selah Web 密码恢复闭环开发计划

> **实施范围：** 根据主人已确认的密码恢复设计，补齐正式 Flutter Web 登录、邮件回调和设置新密码流程，并记录验证结果。
>
> **发布边界：** 推送到 `main` 会触发现有 GitHub Actions 工作流，将新版本部署到 Cloudflare Pages 生产。生产发布按根目录 `CLAUDE.md` 的逐步告知与确认规则执行。

**目标：** 让 Supabase 密码恢复邮件返回 Selah 后能显示恢复表单，成功设置新密码并安全处理失效链接。

**架构：** 沿用现有登录对话框、`LearningController`、`LearningGateway` 和 Supabase Auth。启动时先识别回调 fragment，再让已配置的 Supabase SDK 消费回调并建立会话。恢复表单作为现有页面上的覆盖层呈现。

**限制：** 不增加依赖，不改数据库、Edge Functions、密钥、Supabase／Cloudflare 配置或 CI。新文案覆盖繁中、简中、日语；旧用户用量与学习数据不受影响。

## 任务

### T1：连接回调识别与 Supabase 会话

- [x] 在初始化 Supabase 前识别 `type=recovery` 和 JWT 邮箱提示。
- [x] 确认 Supabase Flutter 当前锁定版本会处理初始回调 URL 并建立恢复会话。
- [x] 控制器在会话缺失或账户邮箱不匹配时关闭表单并提示重新申请链接。

### T2：实现密码更新服务与控制器验证

- [x] 在 `LearningGateway` 增加更新密码接口；Supabase 实现调用 Auth `updateUser`。
- [x] 在控制器校验至少 6 个字符及两次输入一致，再调用网关。
- [x] 映射密码策略、限流和失效链接错误；成功后结束恢复状态。
- [x] 添加密码恢复控制器测试，覆盖错误输入、成功更新与过期会话。

### T3：实现三语界面

- [x] 登录模式增加忘记密码入口，注册模式隐藏此入口。
- [x] 添加可滚动的新密码覆盖层，展示账户提示、密码确认、错误与结果。
- [x] 添加繁中、简中、日语文案及 UI 回归测试。

### T4：本地验证与文档

- [x] 修复新 UI 测试对持续页面动画使用 `pumpAndSettle` 的等待问题，并关闭测试中的计时器。
- [x] `flutter analyze --no-pub` 通过。
- [x] Flutter 全量测试 423 项通过。
- [x] `tool/web.ps1 -Action build` Release Web 构建成功；版本 `1.5.0`，Build ID `f255c608aab51cf4`。
- [x] 更新 `ROADMAP.md`，把生产发布保持为待确认事项。

### T5：提交、推送与生产核验

- [x] 创建中文 Conventional Commit，检查提交只含本功能、验证记录及此前尚未推送的路线图记录。
- [x] 按 Cloudflare 逐步确认规则，将 `main` 推送到 GitHub；确认后由 Actions 自动部署生产。
- [x] Actions run `37139155819` 全部成功；线上版本 `1.5.0`、CI Build ID `32645f749a16a878` 与 CI 构建一致，首页、`main.dart.js`、`selah-precache.json` 均返回 HTTP 200。
- [x] 更新路线图中的生产提交、Actions run 和线上核验结果。

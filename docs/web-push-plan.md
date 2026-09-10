# Web Push 上线方案

当前交付支持网页打开时的提醒、权限申请、浏览器 Push 订阅适配和 Service Worker 收到推送后的展示。尚未实现订阅持久化及服务端定时发送，关闭网页后的准点提醒不属于已完成功能。

## 需要批准的改动

新增 `web_push_subscriptions` 表，保存 `id`、`user_id`、`endpoint`、`p256dh`、`auth`、IANA 时区、提醒时间、启用状态、更新时间和上次推送日期。`endpoint` 唯一；RLS 限制用户只能读写自己的订阅，服务端发送器使用独立服务权限。订阅密钥不写入学习事件或日志。

新增受认证的订阅／退订接口：校验 endpoint 为受支持推送服务的 HTTPS 地址，保存 `PushSubscription.toJSON()`；退出账户时解除当前浏览器与账户的关联，不影响其他设备。订阅接口限制每账户的设备数和请求频率。

新增服务端每分钟执行的发送器，以用户时区确定当地提醒时间。先原子认领「订阅＋当地日期」发送任务，避免重叠调度重复提醒；随后按 Web Push 协议发送加密消息，记录状态码和重试时间。HTTP 404／410 移除失效订阅，429／5xx 有上限退避重试。计划需要同时处理夏令时跳过／重复时段，不承诺浏览器／操作系统能准点显示。

VAPID 公钥仅发给前端；私钥与联系地址保存在服务端 secrets。新增 schema、密钥配置、定时任务和公开部署，均按根 `CLAUDE.md` 与主人全局红线另行确认后执行。本轮没有生成迁移或修改现有生产配置。

## 上线验收

用独立测试账户验证订阅、拒绝权限、关闭网页收取推送、多设备退出隔离、跨时区、同日去重、失效订阅与取消订阅。iPhone 使用实际 Safari／主屏幕 Web App 验证，不把 Windows 上的窄屏预览算作 iPhone 验收。

消息统一调用 Service Worker 的 `showNotification()`，避免只依赖页面的 Notification 构造器。API 的权限和安全上下文要求见 [MDN 官方文档](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/showNotification) 。

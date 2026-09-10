# Selah Web 开发计划

> 执行方式：在当前任务连续实施，按阶段验证；实现工作可使用职责独立的子代理，主代理负责集成与最终审查。

**目标：** 交付能实际运行的 Flutter Web／PWA 学习客户端，覆盖中文表达、AI 英文、音频、聆听、复习、词汇笔记、精灵、数据同步与离线使用。

**架构：** `main.dart` 条件选择 Web 入口；`lib/web/domain/` 定义规范数据与学习算法；`lib/web/data/` 处理本地存储和 Supabase；`lib/web/learning_controller.dart` 串联流程；`lib/web/ui/` 呈现响应式应用；`web/` 提供浏览器与 PWA 适配。

**全局约束：** 遵循根 `CLAUDE.md`；不新增 Flutter 包或全局依赖；不改旧 Swift 业务；不删除已有文件；不修改密钥、CI 或执行生产部署；远端 schema 变更需单独确认。真实生成不回退 Fixture。全部功能区分代码、测试、浏览器、线上四种证据。

## 执行结果（2026-09-05）

| 阶段 | 当前结果 |
| --- | --- |
| 一：入口与持久化 | 完成 Web 条件入口、版本化数据、账户隔离和真实 seed 资源，模型／持久化测试通过 |
| 二：服务端合约与同步 | 客户端完成，认证、生成、音频、版本冲突和失败恢复通过本地合约测试；真实远端验收受 DNS 阻塞 |
| 三：学习与页面 | 六个区域已实现，调度、词汇、精灵与响应式交互通过测试及浏览器核心验收 |
| 四：媒体、离线与 PWA | 浏览器媒体、离线缓存、显式更新及转写服务源码完成；实体设备、转写部署与后台 Push 仍有外部前置条件 |
| 五：验证与文档 | 47 项 Flutter、13 项 Node、163 项 Deno 测试通过；analyze 无 issue，Release 构建与本地 Edge 验收通过 |

最终本地构建版本为 `d068817d378f5aa0`。标准启动入口为 `SelahFlutter/tool/web.ps1`。完整证据、内容范围和上线前置条件见 [Web 验收记录](../../web-acceptance.md) 。

交付边界：没有修改 `.env`、服务端 secret、CI、部署配置或数据库 schema，没有执行生产发布。旧 iOS 本地历史还需要专用导出适配；随包包含 30 条文本与 11 段音频，其他种子音频需后端恢复后取得。Push 和转写部署分别已有可审阅方案，尚未执行外部变更。

## 任务一：可运行入口与持久化

文件：修改 `SelahFlutter/lib/main.dart`；新增 `lib/app/native_entry.dart`、`lib/web/web_entry.dart`、`lib/web/platform/`、`lib/web/domain/learning_models.dart`、`web/index.html` 与 `web/selah_bridge.js`。

1. 编写学习模型、版本化备份、无效字段和 ID 幂等合并测试，运行 `flutter test test/web_models_test.dart` 记录初始失败。
2. 用纯 Dart 实现数据契约，浏览器适配使用以下单入口，避免 DOM 类型扩散到领域层：

```dart
abstract class LearningPlatform {
  Future<Object?> invoke(String action, [Map<String, Object?> payload = const {}]);
}
```

3. IndexedDB 以账户键保存快照，事务完成后才能反馈保存成功；导入失败不得覆盖原数据。
4. 将 30 条真实 seed 打包为资源，首次命名至少选择三句后进入；未登录的真实本地学习不依赖网络 AI。
5. 运行模型测试与 `flutter build web --release`，确认没有 `dart:io` 或 FFI 进入 Web。

## 任务二：服务端合约与账户同步

文件：新增 `lib/web/data/learning_gateway.dart`、`supabase_learning_gateway.dart`、`learning_store.dart`、`test/web_gateway_test.dart`、`test/web_sync_test.dart`。

1. 按当前服务端返回值测试 `targetText`、`vocabulary`、`deconstruction`、音频 manifest 与 signed URL，缺失核心字段必须失败。
2. 对每次生成建立 UUID 请求 ID，重试复用同一 ID；认证错误、额度不足、网络不可用和 provider 失败分别向用户反馈。
3. Supabase 会话恢复、邮箱登录／注册／退出，公开配置来自构建参数；浏览器不能接收服务器 secret。
4. 同步使用现有表与 RLS，保留本地未同步记录；云端较新记录覆盖旧记录，事件按稳定 ID 防重复。按账户隔离缓存和音频。
5. 覆盖账户切换、重复同步、同 ID 较新内容和失败后保留数据的测试。

## 任务三：完整学习与响应式页面

文件：新增 `lib/web/learning_controller.dart`、`lib/web/domain/learning_engine.dart`、`lib/web/ui/`、`test/web_learning_test.dart`、`test/web_app_test.dart`。

1. 复现三种复习信号、到期排序、完成播放才能推进状态、一次事件只解锁一次回忆的预期。
2. 实现 Today 输入与长文本整理、可编辑分段确认；生成结果可保存并进入聆听。
3. 实现真实音频播放／暂停／进度／速度／重播／切句；到达媒体结束事件才记录完成。
4. 实现中文提示→回想英文→揭示答案→自评；到期为空时提供明确的已学内容复习入口。
5. 实现 Notes 搜索／分类／句子详情／词汇掌握、夜间预览、精灵成长和回忆。
6. 实现 Settings 声线、速度、昵称、提醒时间、同步状态、备份导入导出；保存失败不显示成功。
7. 采用暖米色、珊瑚与柔和植物配色；宽屏侧栏、手机底栏，所有控制有可访问名称，空状态提供可执行下一步。

## 任务四：浏览器媒体、离线与 PWA

文件：新增 `web/manifest.json`、`web/selah_service_worker.js`、浏览器适配测试；补 `supabase/functions/speech-transcribe/` 及对应 Deno 测试。

1. MediaRecorder 检测可用 MIME，支持停止、时长上限和异常回收；录音发给受认证的转写 endpoint，确认文字后再整理。
2. 音频按内容版本缓存并校验散列；signed URL 失效重新获取；缓存缺失时不可显示为可离线播放。
3. 应用壳与 seed 静态资源离线缓存；Service Worker 更新不强制中断正在录音或未保存编辑的用户。
4. 提醒区分前台提醒和 Web Push。订阅表与服务端调度需要 schema／外部授权的部分先准备具体方案，授权后执行对应动作。
5. 浏览器实测拒绝麦克风、断网、恢复、刷新、缓存音频、安装及手机尺寸。

## 任务五：交付验证与运行文档

文件：更新根 `README.md`、`SelahFlutter/README.md`、`ROADMAP.md`；新增本地运行工具与 `docs/web-acceptance.md`。

1. 运行 `flutter analyze`，结果不得有 issue。
2. 运行 `flutter test`，保留原有测试并运行全部 Web 测试。
3. 运行 `flutter build web --release`，产物位于 `SelahFlutter/build/web/`。
4. 启动本地静态服务，实测首页、学习、备份、刷新与窄屏；记录截图和浏览器结果。
5. 运行新服务端功能相关测试，区分无网络合约验证与真实服务验收。
6. 子代理进行最终任务范围审查，修复影响正确性的发现，再复跑相关验证。
7. 更新路线图，只勾选实现且验证完成的条目；列出需要主人完成登录或授权部署的具体动作。

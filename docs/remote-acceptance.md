# 真实远端验收说明

## 目的

`supabase/scripts/remote_acceptance.ts` 用于在远端 Supabase 和已部署 Edge Functions 就绪后，验证 Selah 的真实闭环：

`认证 → config-bootstrap → 长语音整理 → 单句翻译幂等重放 → 1–5 句批量翻译 → TTS → signed URL → 音频下载`

脚本默认是 dry-run，不会访问网络，也不会产生 OpenAI 或 Supabase 费用。

## 运行方式

先准备一个专用测试账号。不要使用个人生产账号，也不要把账号密码写入仓库。

```bash
deno run --allow-net --allow-env supabase/scripts/remote_acceptance.ts
```

上面的命令只显示检查计划。真实执行必须由主人在密钥轮换、远端部署和费用确认后单独授权：

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
export SUPABASE_TEST_EMAIL="dedicated-test@example.com"
export SUPABASE_TEST_PASSWORD="use-a-dedicated-password"
export REMOTE_ACCEPTANCE_ALLOW_BILLABLE="true"

deno run --allow-net --allow-env supabase/scripts/remote_acceptance.ts --execute
```

脚本只需要 publishable key 和专用测试账号，不需要 service role key，也不会打印 access token、密码或原始转录内容。

## 费用和数据边界

- `--execute` 会调用真实翻译和 TTS，产生 OpenAI 费用，并在测试账号下写入生成 ledger、音频 manifest 和 Storage 文件。
- 固定测试 request ID 用于验证幂等重放；重复执行时可能命中已有 manifest，但仍应把每次结果记录下来。
- 脚本不会执行 migration、部署、seed 导入、删除数据或修改密钥。
- 网络重试策略由 Swift 单元测试验证；远端脚本验证已部署端点的真实响应链路，不模拟断网。
- 本仓库当前阶段只完成脚本和契约验证，未执行 `--execute`，也未接触聊天中暴露的旧 OpenAI key。

## 验收证据

真实执行后应保存以下信息，而不是保存任何密钥：执行时间、Git commit、Supabase project ref、各端点 HTTP 结果、segment 数量、音频字节数、是否命中缓存、失败时的错误 code。真实设备上的麦克风、Speech、AVAudioSession、Listen 播放结束和 Practice 权限流程仍需在 macOS／iPhone 上单独验收。

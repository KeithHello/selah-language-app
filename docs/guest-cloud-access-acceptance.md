# 2026-09-17 免邮箱确认与测试期游客云端功能本地验收

## 范围

- Web 收费入口在游客使用时静默建立 Supabase Anonymous Sign-ins 会话。
- 生成英文、长文整理、批量生成、录音转写、个人句音频补齐与循环听个人句补音频继续走现有 JWT 保护的 Edge Functions。
- 本机备份导入／导出、循环听 10 句种子和本地学习保持可用。
- 管理台继续要求管理员。
- 本地 Supabase CLI 配置启用匿名登录。

## 已实现口径

1. `LearningGateway` 新增 `isAnonymous` 和 `signInAnonymously()`。
2. `SupabaseLearningGateway` 使用 `client.auth.signInAnonymously()`，普通邮箱注册仍走 `signUp`。
3. 第一版不把匿名账户原地绑定为邮箱账户。Supabase 官方匿名转正式账户路径要求 Manual Linking，并且邮箱身份需要验证；这与当前「先不收确认邮件」冲突。
4. 游客收费入口先保存当前 `guest` 本机快照，再建立匿名会话，随后合并本机内容。
5. 五个收费 Edge Function 没有改成无 JWT；未带会话的直接 HTTP 调用仍应返回 401。

## 本地验证

| 验证 | 结果 |
| --- | --- |
| `D:/setup/flutter/bin/dart.bat analyze lib test` | 通过，0 issues |
| `D:/setup/flutter/bin/flutter.bat test --no-pub` | 通过，241 tests passed |
| `node --test test/*.test.mjs` | 通过，35 tests passed |
| `./tool/web.ps1 -Action build` | 通过 |
| Release Build ID | `ebd23fdd5327ba6d` |

Release 构建产物核对：

- 10 句正式种子。
- 60 个 MP3。
- `selah-precache.json` 共 189 个资源，其中 60 个音频。
- 编入公开 Supabase URL。
- 未编入 `OPENAI_ADMIN_API_KEY` 或 `SUPABASE_SERVICE_ROLE_KEY`。

## 未执行／未验证

- 本机 PATH 中没有 `deno`，本次未重跑 Deno 测试；本轮没有修改 Edge Function TypeScript，只修改了本地 `supabase/config.toml` 开关。
- 远端 Supabase Auth 未修改：Confirm email 与 Anonymous Sign-ins 的远端状态仍需单独确认后操作。
- Cloudflare Pages 预览站未部署。
- 未调用真实 OpenAI，未做真实转写／生成／TTS 付费验收。
- SMTP、Site URL、邮件模板和旧 20 句远端种子均未处理。

## 远端启用前检查

远端项目 `ijonabyyppmgvoufgamt` 需要主人单独确认后执行：

1. Authentication → Providers → Anonymous Sign-ins：启用。
2. Authentication → Email → Confirm email：关闭。
3. 部署 Build `46f551526bb112d5a48fb3ab3a7933a6` 到预览项目。
4. 用未注册浏览器验证游客生成、说出来、个人句音频与循环听补音频。
5. 直接 curl 无 Authorization 的收费函数，确认仍返回 401。

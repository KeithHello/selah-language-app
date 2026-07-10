#!/usr/bin/env bash
# Selah Supabase 完整部署腳本
# 需要環境變數：SUPABASE_ACCESS_TOKEN、OPENAI_API_KEY、SUPABASE_SERVICE_ROLE_KEY、SUPABASE_ANON_KEY
#
# 取得 SUPABASE_ACCESS_TOKEN：
#   1. 登入 https://supabase.com/dashboard
#   2. 左下角 Account → Access Tokens → Generate new token
#
# 用法：
#   export SUPABASE_ACCESS_TOKEN=sbp_xxxxxxxx
#   export OPENAI_API_KEY=sk-xxxxxxxx
#   export SUPABASE_SERVICE_ROLE_KEY=sb_secret_xxxxxxxx
#   export SUPABASE_ANON_KEY=sb_publishable_xxxxxxxx
#   bash supabase/scripts/deploy-full.sh

set -euo pipefail

PROJECT_REF="ijonabyyppmgvoufgamt"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"

echo "=== Selah Supabase 完整部署 ==="
echo "Project: ${PROJECT_REF}"

# 驗證環境變數
if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "錯誤：缺少 SUPABASE_ACCESS_TOKEN"
  echo "請到 https://supabase.com/dashboard/account/tokens 產生 token"
  exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "錯誤：缺少 OPENAI_API_KEY"
  exit 1
fi

if [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  echo "錯誤：缺少 SUPABASE_SERVICE_ROLE_KEY"
  exit 1
fi

if [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "錯誤：缺少 SUPABASE_ANON_KEY"
  exit 1
fi

# 登入 Supabase CLI（使用 access token）
echo ""
echo "[1/7] 登入 Supabase CLI..."
echo "${SUPABASE_ACCESS_TOKEN}" | supabase login --token -

# 連結專案
echo ""
echo "[2/7] 連結專案 ${PROJECT_REF}..."
supabase link --project-ref "${PROJECT_REF}"

# 執行 Migration
echo ""
echo "[3/7] 執行資料庫 Migration..."
supabase db push

# 設定 Edge Function Secrets
echo ""
echo "[4/7] 設定 Edge Function Secrets..."
supabase secrets set OPENAI_API_KEY="${OPENAI_API_KEY}"
supabase secrets set SUPABASE_URL="${SUPABASE_URL}"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

# 部署 Edge Functions
echo ""
echo "[5/7] 部署 Edge Functions..."
supabase functions deploy sentences-generate
supabase functions deploy audio-generate
supabase functions deploy config-bootstrap
supabase functions deploy events

# 匯入種子句
echo ""
echo "[6/7] 匯入 30 句種子句..."
SUPABASE_URL="${SUPABASE_URL}" \
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}" \
deno run --allow-net --allow-read --allow-env supabase/scripts/seed_import.ts

# 驗證
echo ""
echo "[7/7] 驗證部署..."
BOOTSTRAP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${SUPABASE_URL}/functions/v1/config-bootstrap" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")

if [ "${BOOTSTRAP_STATUS}" = "200" ]; then
  echo "✅ config-bootstrap 端點正常 (HTTP 200)"
else
  echo "⚠️ config-bootstrap 端點回傳 HTTP ${BOOTSTRAP_STATUS}"
  echo "請檢查 Edge Function 日誌"
fi

echo ""
echo "=== 部署完成 ==="
echo "下一步：在 iOS App 中配置 SUPABASE_URL 和 SUPABASE_PUBLISHABLE_KEY"

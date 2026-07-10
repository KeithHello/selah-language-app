# Selah Supabase Deployment Guide
# =============================================
# Steps to deploy the backend to Supabase:

# === STEP 1: Run the migration SQL ===
# 1. Go to https://supabase.com/dashboard/project/ijonabyyppmgvoufgamt
# 2. Click "SQL Editor" in the left sidebar
# 3. Click "New query"
# 4. Copy-Paste the contents of: supabase/migrations/000_combined.sql
# 5. Click "Run" (Cmd+Enter or Ctrl+Enter)
# 6. Verify: Check "Table Editor" - you should see 11 tables created

# === STEP 2: Deploy Edge Functions ===
# Prerequisites: Install Supabase CLI
#   npm install -g supabase
#
# Login to Supabase:
#   supabase login
#
# Deploy all functions:
#   supabase functions deploy sentences-generate --project-ref ijonabyyppmgvoufgamt
#   supabase functions deploy audio-generate --project-ref ijonabyyppmgvoufgamt
#   supabase functions deploy config-bootstrap --project-ref ijonabyyppmgvoufgamt
#   supabase functions deploy events --project-ref ijonabyyppmgvoufgamt
#
# Set OpenAI API Key as secret:
#   supabase secrets set OPENAI_API_KEY=sk-your-key --project-ref ijonabyyppmgvoufgamt

# === STEP 3: Import Seed Sentences ===
# After Edge Functions are deployed:
#   deno run --allow-net --allow-read --allow-env supabase/scripts/seed_import.ts

# === STEP 4: Verify ===
# Test endpoints with curl:
#   curl "https://ijonabyyppmgvoufgamt.supabase.co/functions/v1/config-bootstrap" \
#     -H "Authorization: Bearer <anon-key>"

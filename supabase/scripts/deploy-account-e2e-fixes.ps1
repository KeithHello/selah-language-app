param(
  [switch]$Execute,
  [string]$ProjectRef = "ijonabyyppmgvoufgamt",
  [string]$SupabaseVersion = "2.117.0",
  [string]$Origin = "https://codex-web-ux-reliability.selah-language-app-preview.pages.dev"
)

$ErrorActionPreference = "Stop"
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$functions = @(
  "sentences-batch-generate",
  "events",
  "user-research-profile"
)

function Invoke-Supabase {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  & npx.cmd --yes "supabase@$SupabaseVersion" @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase CLI failed with exit code $LASTEXITCODE."
  }
}

function Get-EndpointStatus {
  param(
    [Parameter(Mandatory = $true)][string]$FunctionName,
    [Parameter(Mandatory = $true)][string]$Method,
    [hashtable]$Headers = @{}
  )

  $url = "https://$ProjectRef.supabase.co/functions/v1/$FunctionName"
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $url -Headers $Headers -TimeoutSec 20
    return [int]$response.StatusCode
  } catch {
    if ($null -eq $_.Exception.Response) {
      throw "No HTTP response for $FunctionName $Method health check."
    }
    return [int]$_.Exception.Response.StatusCode
  }
}

Write-Host "=== Account E2E fixes: scoped Supabase deployment ==="
Write-Host "Project ref: $ProjectRef"
Write-Host "Mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY RUN' })"
Write-Host "Functions: $($functions -join ', ')"
Write-Host "Scope: Edge Functions only; no database migrations, secrets, seed import, or function pruning."

$configPath = Join-Path $projectRoot "supabase\config.toml"
$config = Get-Content -LiteralPath $configPath -Raw
foreach ($functionName in $functions) {
  $escapedName = [regex]::Escape($functionName)
  $section = [regex]::Match($config, "(?ms)^\[functions\.$escapedName\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)")
  if (!$section.Success -or
      $section.Groups['body'].Value -notmatch '(?m)^verify_jwt\s*=\s*true\s*$') {
    throw "$functionName must be registered with verify_jwt = true in supabase/config.toml."
  }

  $functionPath = Join-Path $PSScriptRoot "..\functions\$functionName\index.ts"
  if (!(Test-Path -LiteralPath $functionPath)) {
    throw "Missing Edge Function entry: $functionPath"
  }
}

if (!$Execute) {
  Write-Host "Dry run passed: local files and JWT configuration checked; no CLI or network request was made."
  foreach ($functionName in $functions) {
    Write-Host "Command: npx --yes supabase@$SupabaseVersion --workdir `"$projectRoot`" functions deploy $functionName --project-ref $ProjectRef --use-api"
  }
  return
}

Write-Host "Checking project access using the existing CLI login or process token..."
try {
  Invoke-Supabase -Arguments @("projects", "list") | Out-Null
} catch {
  throw "The current CLI credentials cannot list Supabase projects. Complete Supabase CLI login and check whether a stale SUPABASE_ACCESS_TOKEN overrides that login. No deployment was attempted."
}

foreach ($functionName in $functions) {
  Write-Host "Deploying $functionName..."
  Invoke-Supabase -Arguments @(
    "--workdir",
    $projectRoot,
    "functions",
    "deploy",
    $functionName,
    "--project-ref",
    $ProjectRef,
    "--use-api"
  )

  $optionsHeaders = @{
    Origin = $Origin
    "Access-Control-Request-Method" = "POST"
    "Access-Control-Request-Headers" = "authorization, apikey, content-type"
  }
  $optionsStatus = Get-EndpointStatus -FunctionName $functionName -Method "Options" -Headers $optionsHeaders
  if ($optionsStatus -ne 200) {
    throw "$functionName OPTIONS expected 200, received $optionsStatus."
  }
  Write-Host "$functionName OPTIONS HTTP $optionsStatus"

  $postStatus = Get-EndpointStatus -FunctionName $functionName -Method "Post"
  if ($postStatus -ne 401) {
    throw "$functionName unauthenticated POST expected 401, received $postStatus."
  }
  Write-Host "$functionName unauthenticated POST HTTP $postStatus"
}

Write-Host "Scoped deployment and zero-cost route checks passed. Run authenticated account E2E acceptance next."

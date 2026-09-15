param(
  [switch]$Execute,
  [string]$ProjectRef = "ijonabyyppmgvoufgamt",
  [string]$SupabaseVersion = "2.117.0"
)

$ErrorActionPreference = "Stop"
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))

function Invoke-Supabase {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  & npx.cmd --yes "supabase@$SupabaseVersion" @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase CLI failed with exit code $LASTEXITCODE."
  }
}

Write-Host "=== speech-transcribe minimal deployment ==="
Write-Host "Project ref: $ProjectRef"
Write-Host "Mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY RUN' })"
Write-Host "Scope: one Edge Function only; no migrations, secrets, seed import, or pruning."

$configPath = Join-Path $projectRoot "supabase\config.toml"
$config = Get-Content -LiteralPath $configPath -Raw
$speechSection = [regex]::Match($config, '(?ms)^\[functions\.speech-transcribe\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)')
if (!$speechSection.Success -or
    $speechSection.Groups['body'].Value -notmatch '(?m)^verify_jwt\s*=\s*true\s*$') {
  throw "speech-transcribe must be registered with verify_jwt = true in supabase/config.toml."
}

$functionPath = Join-Path $PSScriptRoot "..\functions\speech-transcribe\index.ts"
if (!(Test-Path -LiteralPath $functionPath)) {
  throw "Missing Edge Function entry: $functionPath"
}

if (!$Execute) {
  Write-Host "Dry run passed: local files and JWT configuration checked; no CLI or network request was made."
  Write-Host "Command: npx --yes supabase@$SupabaseVersion --workdir `"$projectRoot`" functions deploy speech-transcribe --project-ref $ProjectRef --use-api"
  return
}

Write-Host "Checking CLI version..."
Invoke-Supabase -Arguments @("--version") | Write-Host

Write-Host "Checking project access using the existing CLI login or process token..."
try {
  Invoke-Supabase -Arguments @("projects", "list") | Out-Null
} catch {
  throw "The current CLI credentials cannot list Supabase projects. Complete Supabase CLI login and check whether a stale SUPABASE_ACCESS_TOKEN overrides that login. No deployment was attempted."
}

Write-Host "Deploying speech-transcribe only..."
Invoke-Supabase -Arguments @(
  "--workdir",
  $projectRoot,
  "functions",
  "deploy",
  "speech-transcribe",
  "--project-ref",
  $ProjectRef,
  "--use-api"
)

function Get-EndpointStatus {
  param([string]$Method)
  $url = "https://$ProjectRef.supabase.co/functions/v1/speech-transcribe"
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $url -TimeoutSec 20
    return [int]$response.StatusCode
  } catch {
    if ($null -eq $_.Exception.Response) { throw "No HTTP response for $Method health check." }
    return [int]$_.Exception.Response.StatusCode
  }
}

$optionsStatus = Get-EndpointStatus -Method Options
if ($optionsStatus -ne 200) { throw "OPTIONS expected 200, received $optionsStatus."
}
Write-Host "OPTIONS HTTP $optionsStatus"
$postStatus = Get-EndpointStatus -Method Post
if ($postStatus -ne 401) { throw "Unauthenticated POST expected 401, received $postStatus."
}
Write-Host "Unauthenticated POST HTTP $postStatus"
Write-Host "Single-function deployment and zero-cost health checks passed. Run authenticated STT acceptance with the approved sample and budget."

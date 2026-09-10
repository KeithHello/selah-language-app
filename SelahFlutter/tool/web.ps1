param(
  [ValidateSet('build', 'run')][string]$Action = 'run',
  [int]$Port = 5180,
  [switch]$PreviewPlush
)
$ErrorActionPreference = 'Stop'
$flutterRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $flutterRoot
$publicConfig = @{}
$envPath = Join-Path $repoRoot '.env'
if (Test-Path -LiteralPath $envPath) {
  foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match '^(SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY)=(.*)$') {
      $publicConfig[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
    }
  }
}
foreach ($key in @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')) {
  $value = [Environment]::GetEnvironmentVariable($key)
  if ($value) { $publicConfig[$key] = $value }
}
$flutterArgs = @('build', 'web', '--release', '--no-web-resources-cdn')
$outputDirectory = 'build/web'
if ($PreviewPlush) {
  $outputDirectory = 'build/plush-preview'
  $flutterArgs += @('--target', 'tool/preview_plush.dart', '--output', $outputDirectory, '--no-wasm-dry-run')
}
foreach ($key in $publicConfig.Keys) { $flutterArgs += "--dart-define=$key=$($publicConfig[$key])" }
Push-Location -LiteralPath $flutterRoot
try {
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) { throw 'Flutter Web build failed.' }
  $bundleRoot = Join-Path $flutterRoot $outputDirectory
  $indexPath = Join-Path $bundleRoot 'index.html'
  $assetPaths = Get-ChildItem -LiteralPath (Join-Path $bundleRoot 'assets') -File -Recurse |
    ForEach-Object { $_.FullName.Substring($bundleRoot.Length + 1).Replace('\', '/') }
  $precache = @{ assets = @($assetPaths) } | ConvertTo-Json -Depth 3
  [System.IO.File]::WriteAllText((Join-Path $bundleRoot 'selah-precache.json'), $precache, [System.Text.UTF8Encoding]::new($false))
  $bundleHashes = Get-ChildItem -LiteralPath $bundleRoot -File -Recurse |
    Where-Object { $_.Name -ne '.last_build_id' } |
    Sort-Object FullName |
    ForEach-Object { $_.FullName.Substring($bundleRoot.Length) + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  $hasher = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($bundleHashes -join "`n"))
    $buildId = [System.BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-', '').Substring(0, 16).ToLowerInvariant()
  } finally { $hasher.Dispose() }
  $index = [System.IO.File]::ReadAllText($indexPath)
  $index = $index -replace '(name="selah-build-id" content=")[^"]*(")', ('${1}' + $buildId + '${2}')
  [System.IO.File]::WriteAllText($indexPath, $index, [System.Text.UTF8Encoding]::new($false))
  if ($Action -eq 'run') {
    Write-Host "Selah Web: http://127.0.0.1:$Port"
    & python -m http.server $Port --bind 127.0.0.1 --directory $bundleRoot
  }
} finally { Pop-Location }

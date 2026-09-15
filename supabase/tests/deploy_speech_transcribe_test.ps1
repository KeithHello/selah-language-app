$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$fixtureRoot = Join-Path $repoRoot "output\deployment-helper-test-$([guid]::NewGuid().ToString('N'))"
$fixtureScripts = Join-Path $fixtureRoot 'supabase\scripts'
New-Item -ItemType Directory -Path $fixtureScripts -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'supabase\functions\speech-transcribe') -Force | Out-Null
$targetScript = Join-Path $fixtureScripts 'deploy-speech-transcribe.ps1'
Copy-Item -LiteralPath (Join-Path $repoRoot 'supabase\scripts\deploy-speech-transcribe.ps1') -Destination $targetScript
$fixtureConfig = Join-Path $fixtureRoot 'supabase\config.toml'
Set-Content -LiteralPath $fixtureConfig -Value "[functions.speech-transcribe]`nverify_jwt = true"
Set-Content -LiteralPath (Join-Path $fixtureRoot 'supabase\functions\speech-transcribe\index.ts') -Value '// Test fixture only.'

$global:selahDeployTest = @{
  cliCalls = [System.Collections.Generic.List[object]]::new()
  httpCalls = [System.Collections.Generic.List[string]]::new()
  failProjectList = $false
  optionsStatus = 200
  postStatus = 401
}

function npx.cmd {
  $global:selahDeployTest.cliCalls.Add(@($args))
  $global:LASTEXITCODE = 0
  if ($args -contains '--version') { return '2.117.0' }
  if ($args -contains 'list' -and $global:selahDeployTest.failProjectList) { $global:LASTEXITCODE = 1 }
}

function Invoke-WebRequest {
  param($Uri, $Method, $TimeoutSec, [switch]$UseBasicParsing)
  $global:selahDeployTest.httpCalls.Add([string]$Method)
  $status = if ($Method -eq 'Options') { $global:selahDeployTest.optionsStatus } else { $global:selahDeployTest.postStatus }
  if ($status -ge 400) {
    $failure = [System.Exception]::new("HTTP $status")
    $failure | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = $status })
    throw $failure
  }
  return [pscustomobject]@{ StatusCode = $status }
}

function Assert-True($Condition, $Message) {
  if (!$Condition) { throw $Message }
}

function Assert-Fails([scriptblock]$Action, [string]$Expected) {
  try { & $Action } catch {
    Assert-True ($_.Exception.Message -like "*$Expected*") "Unexpected failure: $($_.Exception.Message)"
    return
  }
  throw "Expected failure containing: $Expected"
}

& $targetScript
Assert-True ($global:selahDeployTest.cliCalls.Count -eq 0 -and $global:selahDeployTest.httpCalls.Count -eq 0) 'Dry run must be offline and must not invoke npx.'

Push-Location -LiteralPath $repoRoot
try { & $targetScript -Execute } finally { Pop-Location }
$deployCalls = @($global:selahDeployTest.cliCalls | Where-Object { $_ -contains 'deploy' })
Assert-True ($deployCalls.Count -eq 1) 'Execute must deploy exactly one function.'
$deployArgs = $deployCalls[0]
Assert-True ($deployArgs -contains 'speech-transcribe' -and $deployArgs -contains '--use-api') 'Unexpected deployment scope.'
$workdirIndex = [Array]::IndexOf($deployArgs, '--workdir')
Assert-True ($workdirIndex -ge 0 -and $deployArgs[$workdirIndex + 1] -eq $fixtureRoot) 'Deployment must resolve the script project independently of the calling directory.'
Assert-True (($global:selahDeployTest.httpCalls -join ',') -eq 'Options,Post') 'Execute must verify both routing and unauthenticated rejection.'

$global:selahDeployTest.cliCalls.Clear()
$global:selahDeployTest.httpCalls.Clear()
$global:selahDeployTest.failProjectList = $true
Assert-Fails { & $targetScript -Execute } 'cannot list Supabase projects'
Assert-True (@($global:selahDeployTest.cliCalls | Where-Object { $_ -contains 'deploy' }).Count -eq 0) 'Failed authentication must stop before deployment.'
$global:selahDeployTest.failProjectList = $false

$global:selahDeployTest.optionsStatus = 500
Assert-Fails { & $targetScript -Execute } 'OPTIONS expected 200'
Assert-True (($global:selahDeployTest.httpCalls -join ',') -eq 'Options') 'A failed route check must stop immediately.'
$global:selahDeployTest.optionsStatus = 200

$global:selahDeployTest.postStatus = 200
Assert-Fails { & $targetScript -Execute } 'Unauthenticated POST expected 401'
$global:selahDeployTest.postStatus = 401

$global:selahDeployTest.cliCalls.Clear()
Set-Content -LiteralPath $fixtureConfig -Value "[functions.speech-transcribe]`nverify_jwt = false`n[functions.events]`nverify_jwt = true"
Assert-Fails { & $targetScript } 'speech-transcribe must be registered with verify_jwt = true'
Assert-True ($global:selahDeployTest.cliCalls.Count -eq 0) 'Another function JWT setting must not satisfy the speech-transcribe check.'

Write-Output '6 deployment helper checks passed; all CLI and HTTP calls were replaced with local test doubles.'

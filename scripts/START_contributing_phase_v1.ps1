param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$TvRoot
)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }

$RepoRoot = (Resolve-Path $RepoRoot).Path

if(-not $TvRoot){
  $TvRoot = Join-Path $RepoRoot "test_vectors\minimal_valid"
}

$TvRoot = (Resolve-Path $TvRoot).Path

Write-Host "=== CONTRIBUTION PHASE START ===" -ForegroundColor Cyan
Write-Host ("RepoRoot: " + $RepoRoot)
Write-Host ("TvRoot:   " + $TvRoot)

# --- Build ---
& (Join-Path $RepoRoot "scripts\build_contribution_ledger_v1.ps1") `
  -RepoRoot $RepoRoot `
  -TvRoot $TvRoot | Out-Host

# --- Verify ---
& (Join-Path $RepoRoot "scripts\verify_contribution_ledger_v1.ps1") `
  -RepoRoot $RepoRoot `
  -TvRoot $TvRoot | Out-Host

$VerifyPath = Join-Path $TvRoot "verify_result.json"
if(-not (Test-Path -LiteralPath $VerifyPath)){
  Die ("VERIFY_RESULT_MISSING: " + $VerifyPath)
}

$res = Get-Content -LiteralPath $VerifyPath -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host ""
Write-Host "=== CONTRIBUTION RESULT ===" -ForegroundColor Cyan
Write-Host ("OK: " + $res.ok)

if($res.ok){
  Write-Host "STATUS: VALID CONTRIBUTION" -ForegroundColor Green
}else{
  Write-Host "STATUS: INVALID CONTRIBUTION" -ForegroundColor Yellow
  Write-Host ("FAILURES: " + (@($res.failures) -join "|"))
}

Write-Host ("RULESET_HASH: " + $res.ruleset_hash)

$Ledger = Join-Path $TvRoot "ledger.ndjson"
if(Test-Path $Ledger){
  Write-Host ("LEDGER: " + $Ledger)
}

Write-Host ""
Write-Host "CONTRIBUTION_PHASE_DONE" -ForegroundColor Green
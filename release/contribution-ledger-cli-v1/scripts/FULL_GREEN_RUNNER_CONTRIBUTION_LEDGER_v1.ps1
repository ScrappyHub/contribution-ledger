param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }

$RepoRoot=(Resolve-Path $RepoRoot).Path
$Scripts=Join-Path $RepoRoot "scripts"

$paths=@(
 (Join-Path $Scripts "_lib_contribution_ledger_v1.ps1"),
 (Join-Path $Scripts "build_contribution_ledger_v1.ps1"),
 (Join-Path $Scripts "verify_contribution_ledger_v1.ps1"),
 (Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1")
)

foreach($p in $paths){
 $t=$null;$e=$null
 [void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)
 if($e.Count){ throw ("PARSE_FAIL: "+$p) }
}

Write-Host "PARSE_OK: all scripts" -ForegroundColor Green

& (Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot | Out-Host

Write-Host "FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1" -ForegroundColor Green

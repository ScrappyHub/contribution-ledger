param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$false)][string]$WorkspaceName = "default"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$msg)
    Write-Host $msg
}

function Ensure-Dir {
    param([string]$p)
    if(-not (Test-Path -LiteralPath $p)){
        New-Item -ItemType Directory -Path $p | Out-Null
    }
}

# Paths
$workspaces = Join-Path $RepoRoot "workspaces"
Ensure-Dir $workspaces

$tvRoot = Join-Path $workspaces $WorkspaceName

# Phase script
$phaseScript = Join-Path $RepoRoot "scripts\START_contributing_phase_v2.ps1"

if(-not (Test-Path -LiteralPath $phaseScript)){
    throw "MISSING_SCRIPT: $phaseScript"
}

Write-Log "=== CONTRIBUTION LEDGER RUN ==="
Write-Log ("RepoRoot: " + $RepoRoot)
Write-Log ("Workspace: " + $tvRoot)

# Execute phase
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File $phaseScript `
    -RepoRoot $RepoRoot `
    -TvRoot $tvRoot | Out-Host

if($LASTEXITCODE -ne 0){
    throw ("CONTRIBUTION_PHASE_FAILED: " + $LASTEXITCODE)
}

Write-Log "CONTRIBUTION_LEDGER_RUN_OK"
exit 0
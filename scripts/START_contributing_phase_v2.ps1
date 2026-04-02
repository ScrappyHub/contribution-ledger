param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$TvRoot
)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }

function EnsureDir([string]$Path){
  if([string]::IsNullOrWhiteSpace($Path)){ Die "ENSUREDIR_EMPTY_PATH" }
  if(-not (Test-Path -LiteralPath $Path -PathType Container)){
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  if([string]::IsNullOrWhiteSpace($Path)){ Die "WRITE_EMPTY_PATH" }
  $dir = Split-Path -Parent $Path
  if($dir){ EnsureDir $dir }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if([string]::IsNullOrWhiteSpace($TvRoot)){
  $TvRoot = Join-Path $RepoRoot "test_vectors\minimal_valid"
} else {
  if([System.IO.Path]::IsPathRooted($TvRoot)){
    $TvRoot = $TvRoot
  } else {
    $TvRoot = Join-Path $RepoRoot $TvRoot
  }
}

# Auto-bootstrap workspace if missing
if(-not (Test-Path -LiteralPath $TvRoot -PathType Container)){
  $Inputs = Join-Path $TvRoot "inputs"
  EnsureDir $Inputs

  $Receipts = Join-Path $Inputs "receipts.ndjson"
  $Rules    = Join-Path $Inputs "ruleset.json"

  WriteUtf8NoBomLf $Receipts (@(
    '{"schema":"receipt.synthetic.v1","receipt_hash":"starter_r1","event_type":"watchtower.verify","units":1}'
    '{"schema":"receipt.synthetic.v1","receipt_hash":"starter_r2","event_type":"device.uptime","units":60}'
  ) -join "`n")

  WriteUtf8NoBomLf $Rules '{"schema":"ruleset.v1","ruleset_id":"starter_workspace_v1","rules":[{"event_type":"watchtower.verify","weight":5},{"event_type":"device.uptime","weight":1}]}'

  Write-Host ("WORKSPACE_BOOTSTRAPPED: " + $TvRoot) -ForegroundColor Green
}

$TvRoot = (Resolve-Path -LiteralPath $TvRoot).Path

Write-Host "=== CONTRIBUTION PHASE START ===" -ForegroundColor Cyan
Write-Host ("RepoRoot: " + $RepoRoot)
Write-Host ("TvRoot:   " + $TvRoot)

& (Join-Path $RepoRoot "scripts\build_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot -TvRoot $TvRoot | Out-Host
& (Join-Path $RepoRoot "scripts\verify_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot -TvRoot $TvRoot | Out-Host

$VerifyPath = Join-Path $TvRoot "verify_result.json"
if(-not (Test-Path -LiteralPath $VerifyPath -PathType Leaf)){
  Die ("VERIFY_RESULT_MISSING: " + $VerifyPath)
}

$res = Get-Content -LiteralPath $VerifyPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

Write-Host ""
Write-Host "=== CONTRIBUTION RESULT ===" -ForegroundColor Cyan
Write-Host ("OK: " + $res.ok)

if([bool]$res.ok){
  Write-Host "STATUS: VALID CONTRIBUTION" -ForegroundColor Green
} else {
  Write-Host "STATUS: INVALID CONTRIBUTION" -ForegroundColor Yellow
  Write-Host ("FAILURES: " + (@($res.failures) -join "|"))
}

Write-Host ("RULESET_HASH: " + $res.ruleset_hash)

$Ledger = Join-Path $TvRoot "ledger.ndjson"
if(Test-Path -LiteralPath $Ledger -PathType Leaf){
  Write-Host ("LEDGER: " + $Ledger)
}

Write-Host ""
Write-Host "CONTRIBUTION_PHASE_DONE" -ForegroundColor Green
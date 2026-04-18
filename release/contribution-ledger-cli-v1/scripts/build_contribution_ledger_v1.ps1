param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TvRoot
)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")

function Die([string]$m){ throw $m }

$TvRoot = (Resolve-Path -LiteralPath $TvRoot).Path
$InDir = Join-Path $TvRoot "inputs"
$OutLedger = Join-Path $TvRoot "ledger.ndjson"
$Receipts = Join-Path $InDir "receipts.ndjson"
$Rules = Join-Path $InDir "ruleset.json"

if(-not (Test-Path -LiteralPath $Receipts -PathType Leaf)){ Die ("MISSING_RECEIPTS: " + $Receipts) }
if(-not (Test-Path -LiteralPath $Rules -PathType Leaf)){ Die ("MISSING_RULESET: " + $Rules) }

$rulesObj = Get-Content -LiteralPath $Rules -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$ruleHash = CL-Sha256HexFile $Rules

$weights = @{}
foreach($r in @($rulesObj.rules)){
  $weights[[string]$r.event_type] = [int]$r.weight
}

$lines = CL-ReadLinesUtf8 $Receipts
$new = New-Object System.Collections.Generic.List[string]

foreach($ln in @($lines)){
  $o = $ln | ConvertFrom-Json -ErrorAction Stop
  $etype = [string]$o.event_type
  $units = [int]$o.units
  if(-not $weights.ContainsKey($etype)){ continue }
  $w = [int]$weights[$etype]
  $credit = $units * $w
  $receiptHash = [string]$o.receipt_hash
  $eventRef = CL-EventRef $receiptHash $ruleHash $etype $units
  $row = @{
    schema="contrib.ledger.line.v1"
    event_ref=$eventRef
    receipt_hash=$receiptHash
    ruleset_hash=$ruleHash
    event_type=$etype
    units=$units
    weight=$w
    credit=$credit
  }
  [void]$new.Add((CL-ToCanonJson $row))
}

$added = CL-AppendNdjsonUniqueByEventRef $OutLedger @($new.ToArray())

$out = @{
  schema="contrib.build.result.v1"
  ok=$true
  tv_root=$TvRoot
  added_count=@($added).Count
  ledger=$OutLedger
  ruleset_hash=$ruleHash
}

[System.IO.File]::WriteAllBytes((Join-Path $TvRoot "build_result.json"),(CL-CanonJsonBytes $out))
Write-Host ("BUILD_OK: added=" + @($added).Count + " tv=" + $TvRoot) -ForegroundColor Green

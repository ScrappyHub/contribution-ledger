param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TvRoot
)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")

function NowUtc(){ return [DateTime]::UtcNow.ToString("o") }
function Die([string]$m){ throw $m }

function WriteResult([string]$OutPath,[hashtable]$Obj){
  CL-WriteUtf8NoBomLf $OutPath (CL-ToCanonJson $Obj)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$TvRoot   = (Resolve-Path -LiteralPath $TvRoot).Path
$OutPath  = Join-Path $TvRoot "verify_result.json"

$fail = New-Object System.Collections.Generic.List[string]
$ruleset_hash = ""
$ledger_hash  = ""

try {
  $inputsDir = Join-Path $TvRoot "inputs"
  $rulesPath = Join-Path $inputsDir "ruleset.json"
  $recvPath  = Join-Path $inputsDir "receipts.ndjson"
  $ledPath   = Join-Path $TvRoot "ledger.ndjson"

  if(-not (Test-Path -LiteralPath $rulesPath -PathType Leaf)){ [void]$fail.Add("MISSING_RULESET") }
  if(-not (Test-Path -LiteralPath $recvPath  -PathType Leaf)){ [void]$fail.Add("MISSING_RECEIPTS") }
  if(-not (Test-Path -LiteralPath $ledPath   -PathType Leaf)){ [void]$fail.Add("MISSING_LEDGER") }

  if(@($fail).Count -eq 0){
    $rulesBytes = [System.IO.File]::ReadAllBytes($rulesPath)
    $ledBytes   = [System.IO.File]::ReadAllBytes($ledPath)
    $ruleset_hash = CL-Sha256HexBytes $rulesBytes
    $ledger_hash  = CL-Sha256HexBytes $ledBytes

    $rulesObj = Get-Content -LiteralPath $rulesPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $weights = @{}
    foreach($r in @($rulesObj.rules)){
      $weights[[string]$r.event_type] = [int]$r.weight
    }

    # Build expected rows from receipts exactly like build script does
    $expected = @{}   # event_ref -> expected credit
    $recvSeen = @{}   # duplicate detection at receipt-derived event_ref level

    foreach($ln in @(CL-ReadLinesUtf8 $recvPath)){
      if([string]::IsNullOrWhiteSpace($ln)){ continue }
      $ro = $ln | ConvertFrom-Json -ErrorAction Stop

      $receiptHash = [string]$ro.receipt_hash
      $etype       = [string]$ro.event_type
      $units       = [int]$ro.units

      if([string]::IsNullOrWhiteSpace($receiptHash)){ [void]$fail.Add("RECEIPT_MISSING_RECEIPT_HASH"); continue }
      if([string]::IsNullOrWhiteSpace($etype)){ [void]$fail.Add("RECEIPT_MISSING_EVENT_TYPE"); continue }

      if(-not $weights.ContainsKey($etype)){ continue }

      $w = [int]$weights[$etype]
      $credit = $units * $w
      $eventRef = CL-EventRef $receiptHash $ruleset_hash $etype $units

      if($recvSeen.ContainsKey($eventRef)){ [void]$fail.Add("DUP_EVENT_REF"); continue }
      $recvSeen[$eventRef] = $true
      $expected[$eventRef] = $credit
    }

    # Verify ledger rows
    $ledgerSeen = @{}
    foreach($ln in @(CL-ReadLinesUtf8 $ledPath)){
      if([string]::IsNullOrWhiteSpace($ln)){ continue }
      $lo = $ln | ConvertFrom-Json -ErrorAction Stop

      $eref = ""
      if($lo.PSObject.Properties.Name -contains "event_ref"){ $eref = [string]$lo.event_ref }
      if([string]::IsNullOrWhiteSpace($eref)){ [void]$fail.Add("LEDGER_MISSING_EVENT_REF"); continue }

      if($ledgerSeen.ContainsKey($eref)){ [void]$fail.Add("DUP_EVENT_REF"); continue }
      $ledgerSeen[$eref] = $true

      $lh = ""
      if($lo.PSObject.Properties.Name -contains "ruleset_hash"){ $lh = [string]$lo.ruleset_hash }
      if($lh -ne $ruleset_hash){ [void]$fail.Add("RULESET_HASH_MISMATCH") }

      $got = 0
      if($lo.PSObject.Properties.Name -contains "credit"){ $got = [int]$lo.credit }

      if($expected.ContainsKey($eref)){
        $exp = [int]$expected[$eref]
        if($got -ne $exp){ [void]$fail.Add("CREDIT_MISMATCH") }
      } else {
        [void]$fail.Add("LEDGER_EVENT_REF_NOT_IN_RECEIPTS")
      }
    }
  }
}
catch {
  [void]$fail.Add("VERIFY_EXCEPTION")
}
finally {
  $ok = (@($fail).Count -eq 0)
  $res = @{
    schema       = "contrib.verify_result.v1"
    ok           = $ok
    failures     = @(@($fail.ToArray()))
    ruleset_hash = $ruleset_hash
    ledger_hash  = $ledger_hash
  }
  WriteResult $OutPath $res
  if($ok){
    Write-Host ("VERIFY_OK: " + $TvRoot) -ForegroundColor Green
  } else {
    Write-Host ("VERIFY_FAIL: " + $TvRoot + " :: " + (@($fail.ToArray()) -join "|")) -ForegroundColor Yellow
  }
}

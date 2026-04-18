param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")

function Die([string]$m){ throw $m }
function NowUtc(){ return [DateTime]::UtcNow.ToString("o") }

function AppendReceipt([string]$Path,[string]$Line){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $dir = Split-Path -Parent $Path
  if($dir){ CL-EnsureDir $dir }
  [System.IO.File]::AppendAllText($Path, ($Line + "`n"), $enc)
}

function MakeReceiptLine([hashtable]$obj){
  $tmp = @{}
  foreach($k in @($obj.Keys)){ $tmp[$k] = $obj[$k] }
  if($tmp.ContainsKey("receipt_hash")){ [void]$tmp.Remove("receipt_hash") }
  $h = CL-Sha256HexBytes (CL-CanonJsonBytes $tmp)
  $obj["receipt_hash"] = $h
  return (CL-ToCanonJson $obj)
}

function RunBuild([string]$TvRoot){
  & (Join-Path $RepoRoot "scripts\build_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot -TvRoot $TvRoot | Out-Host
  $br = Join-Path $TvRoot "build_result.json"
  if(-not (Test-Path -LiteralPath $br -PathType Leaf)){ Die ("MISSING_build_result: " + $br) }
}

function RunVerify([string]$TvRoot){
  & (Join-Path $RepoRoot "scripts\verify_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot -TvRoot $TvRoot | Out-Host
  $vr = Join-Path $TvRoot "verify_result.json"
  if(-not (Test-Path -LiteralPath $vr -PathType Leaf)){ Die ("MISSING_verify_result: " + $vr) }
  return (Get-Content -LiteralPath $vr -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
}

function AssertNeg([psobject]$res,[string]$token,[string]$name){
  if([bool]$res.ok){ Die ($name + "_EXPECT_FAIL_BUT_OK") }
  $arr = @($res.failures)
  if(-not ($arr -contains $token)){
    Die ($name + "_MISSING_TOKEN: expected " + $token + " got " + ($arr -join "|"))
  }
}

$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\contribution_ledger.ndjson"
$BaseTV = (Resolve-Path -LiteralPath (Join-Path $RepoRoot "test_vectors\minimal_valid")).Path
$Gold = Join-Path $BaseTV "golden"
CL-EnsureDir $Gold

# POSITIVE
RunBuild $BaseTV
$pos = RunVerify $BaseTV
if(-not [bool]$pos.ok){ Die ("POS_VERIFY_FAIL: " + (@($pos.failures) -join "|")) }

$Ledger  = Join-Path $BaseTV "ledger.ndjson"
$Verify  = Join-Path $BaseTV "verify_result.json"
$gLedger = Join-Path $Gold "ledger.ndjson"
$gVerify = Join-Path $Gold "expected_verify.json"

if(-not (Test-Path -LiteralPath $gLedger -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gLedger,[System.IO.File]::ReadAllBytes($Ledger)) }
if(-not (Test-Path -LiteralPath $gVerify -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gVerify,[System.IO.File]::ReadAllBytes($Verify)) }

$a=[System.IO.File]::ReadAllBytes($Ledger)
$b=[System.IO.File]::ReadAllBytes($gLedger)
if($a.Length -ne $b.Length){ Die "GOLDEN_LEDGER_MISMATCH_LEN" }
for($i=0;$i -lt $a.Length;$i++){ if($a[$i] -ne $b[$i]){ Die ("GOLDEN_LEDGER_MISMATCH_AT_" + $i) } }

$a2=[System.IO.File]::ReadAllBytes($Verify)
$b2=[System.IO.File]::ReadAllBytes($gVerify)
if($a2.Length -ne $b2.Length){ Die "GOLDEN_VERIFY_MISMATCH_LEN" }
for($i=0;$i -lt $a2.Length;$i++){ if($a2[$i] -ne $b2[$i]){ Die ("GOLDEN_VERIFY_MISMATCH_AT_" + $i) } }

$posReceipt = @{
  schema="contrib.receipt.v1"
  ts_utc=(NowUtc)
  kind="selftest"
  vector="positive"
  ok=$true
  failures=@()
  ruleset_hash=[string]$pos.ruleset_hash
}
AppendReceipt $ReceiptPath (MakeReceiptLine $posReceipt)
Write-Host "POS_OK" -ForegroundColor Green

$baseInputs = Join-Path $BaseTV "inputs"

# NEG1: DUP_EVENT_REF
$Neg1 = Join-Path $RepoRoot "test_vectors\neg_dup_event_ref"
CL-EnsureDir $Neg1
CL-EnsureDir (Join-Path $Neg1 "inputs")
Copy-Item -LiteralPath (Join-Path $baseInputs "ruleset.json") -Destination (Join-Path $Neg1 "inputs\ruleset.json") -Force
Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg1 "inputs\receipts.ndjson") -Force
Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg1 "ledger.ndjson") -Force

$lns = CL-ReadLinesUtf8 (Join-Path $Neg1 "ledger.ndjson")
if(@($lns).Count -lt 1){ Die "NEG1_NO_LEDGER_LINES" }
$dup = @($lns[0], $lns[0]) + @($lns | Select-Object -Skip 1)
CL-WriteUtf8NoBomLf (Join-Path $Neg1 "ledger.ndjson") ((@($dup) -join "`n") + "`n")

$neg1 = RunVerify $Neg1
AssertNeg $neg1 "DUP_EVENT_REF" "NEG1"
$neg1Receipt = @{
  schema="contrib.receipt.v1"
  ts_utc=(NowUtc)
  kind="selftest"
  vector="neg_dup_event_ref"
  ok=$false
  failures=@($neg1.failures)
  ruleset_hash=[string]$neg1.ruleset_hash
}
AppendReceipt $ReceiptPath (MakeReceiptLine $neg1Receipt)
Write-Host "NEG1_OK (DUP_EVENT_REF)" -ForegroundColor Green

# NEG2: RULESET_HASH_MISMATCH
$Neg2 = Join-Path $RepoRoot "test_vectors\neg_ruleset_hash_mismatch"
CL-EnsureDir $Neg2
CL-EnsureDir (Join-Path $Neg2 "inputs")
Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg2 "inputs\receipts.ndjson") -Force
Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg2 "ledger.ndjson") -Force

$rulesTampered = '{ "schema":"ruleset.v1","ruleset_id":"tampered","rules":[{"event_type":"watchtower.verify","weight":999},{"event_type":"device.uptime","weight":1}] }'
CL-WriteUtf8NoBomLf (Join-Path $Neg2 "inputs\ruleset.json") $rulesTampered

$neg2 = RunVerify $Neg2
AssertNeg $neg2 "RULESET_HASH_MISMATCH" "NEG2"
$neg2Receipt = @{
  schema="contrib.receipt.v1"
  ts_utc=(NowUtc)
  kind="selftest"
  vector="neg_ruleset_hash_mismatch"
  ok=$false
  failures=@($neg2.failures)
  ruleset_hash=[string]$neg2.ruleset_hash
}
AppendReceipt $ReceiptPath (MakeReceiptLine $neg2Receipt)
Write-Host "NEG2_OK (RULESET_HASH_MISMATCH)" -ForegroundColor Green

# NEG3: CREDIT_MISMATCH
$Neg3 = Join-Path $RepoRoot "test_vectors\neg_credit_mismatch"
CL-EnsureDir $Neg3
CL-EnsureDir (Join-Path $Neg3 "inputs")
Copy-Item -LiteralPath (Join-Path $baseInputs "ruleset.json") -Destination (Join-Path $Neg3 "inputs\ruleset.json") -Force
Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg3 "inputs\receipts.ndjson") -Force
Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg3 "ledger.ndjson") -Force

$rows = CL-ReadLinesUtf8 (Join-Path $Neg3 "ledger.ndjson")
if(@($rows).Count -lt 1){ Die "NEG3_NO_LEDGER_LINES" }
$first = $rows[0] | ConvertFrom-Json -ErrorAction Stop
$first.credit = ([int]$first.credit) + 1
$rows2 = New-Object System.Collections.Generic.List[string]
[void]$rows2.Add((CL-ToCanonJson $first))
foreach($x in @($rows | Select-Object -Skip 1)){ [void]$rows2.Add($x) }
CL-WriteUtf8NoBomLf (Join-Path $Neg3 "ledger.ndjson") ((@($rows2.ToArray()) -join "`n") + "`n")

$neg3 = RunVerify $Neg3
AssertNeg $neg3 "CREDIT_MISMATCH" "NEG3"
$neg3Receipt = @{
  schema="contrib.receipt.v1"
  ts_utc=(NowUtc)
  kind="selftest"
  vector="neg_credit_mismatch"
  ok=$false
  failures=@($neg3.failures)
  ruleset_hash=[string]$neg3.ruleset_hash
}
AppendReceipt $ReceiptPath (MakeReceiptLine $neg3Receipt)
Write-Host "NEG3_OK (CREDIT_MISMATCH)" -ForegroundColor Green

Write-Host "SELFTEST_CONTRIBUTION_LEDGER_OK" -ForegroundColor Green

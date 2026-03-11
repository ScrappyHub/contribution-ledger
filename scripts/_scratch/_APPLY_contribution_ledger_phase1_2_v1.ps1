param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "EMPTY_PATH" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBomLf([string]$Path,[string]$Text){ $dir=Split-Path -Parent $Path; if($dir){ EnsureDir $dir }; $t=$Text.Replace("`r`n","`n").Replace("`r","`n"); if(-not $t.EndsWith("`n")){ $t += "`n" }; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$t,$enc) }
function ParseGate([string]$Path){ $t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e); if($e -and @($e).Count -gt 0){ $x=$e[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message) } }

$Scripts = Join-Path $RepoRoot "scripts"
$Lib = Join-Path $Scripts "_lib_contribution_ledger_v1.ps1"
$Self = Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1"
$Full = Join-Path $Scripts "FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1"
$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\contribution_ledger.ndjson"
EnsureDir (Join-Path $RepoRoot "proofs\receipts")

WriteUtf8NoBomLf $Self @'
param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")
function Die([string]$m){ throw $m }

function NowUtc(){ return [DateTime]::UtcNow.ToString("o") }
function ReceiptLine($obj){
  # deterministic canonical json line
  return (CL-ToCanonJson $obj)
}
function AppendReceipt([string]$Path,[string]$Line){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $dir = Split-Path -Parent $Path
  if($dir){ CL-EnsureDir $dir }
  [System.IO.File]::AppendAllText($Path, ($Line + "`n"), $enc)
}

$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\contribution_ledger.ndjson"
$BaseTV = Join-Path $RepoRoot "test_vectors\minimal_valid"
$Gold = Join-Path $BaseTV "golden"
CL-EnsureDir $Gold

# Helper: run verify and return result object
function RunVerify([string]$TvRoot){
  $verifyPath = Join-Path $RepoRoot "scripts\verify_contribution_ledger_v1.ps1"
  & $verifyPath -RepoRoot $RepoRoot | Out-Host
  $vr = Join-Path $TvRoot "verify_result.json"
  if(-not (Test-Path -LiteralPath $vr -PathType Leaf)){ Die ("MISSING_verify_result: " + $vr) }
  $o = (Get-Content -LiteralPath $vr -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
  return $o
}

# --- POSITIVE ---
& (Join-Path $RepoRoot "scripts\build_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot | Out-Host
$pos = RunVerify $BaseTV

if(-not [bool]$pos.ok){ Die ("POS_VERIFY_FAIL: " + (@($pos.failures) -join "|")) }

# stamp goldens if absent; then byte-compare
$Ledger = Join-Path $BaseTV "ledger.ndjson"
$Verify = Join-Path $BaseTV "verify_result.json"
$gLedger = Join-Path $Gold "ledger.ndjson"
$gVerify = Join-Path $Gold "expected_verify.json"

if(-not (Test-Path -LiteralPath $gLedger -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gLedger,[System.IO.File]::ReadAllBytes($Ledger)) }
if(-not (Test-Path -LiteralPath $gVerify -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gVerify,[System.IO.File]::ReadAllBytes($Verify)) }

$a=[System.IO.File]::ReadAllBytes($Ledger); $b=[System.IO.File]::ReadAllBytes($gLedger)
if($a.Length -ne $b.Length){ Die "GOLDEN_LEDGER_MISMATCH_LEN" }
for($i=0;$i -lt $a.Length;$i++){ if($a[$i] -ne $b[$i]){ Die ("GOLDEN_LEDGER_MISMATCH_AT_" + $i) } }

$a2=[System.IO.File]::ReadAllBytes($Verify); $b2=[System.IO.File]::ReadAllBytes($gVerify)
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
$posReceipt.receipt_hash = (CL-Sha256HexBytes (CL-BytesUtf8NoBomLf (CL-ToCanonJson $posReceipt)))
AppendReceipt $ReceiptPath (ReceiptLine $posReceipt)
Write-Host "POS_OK" -ForegroundColor Green

# --- NEGATIVE VECTORS ---
# V1: duplicate event_ref (copy first line twice)
$Neg1 = Join-Path $RepoRoot "test_vectors\neg_dup_event_ref"
CL-EnsureDir $Neg1
CL-EnsureDir (Join-Path $Neg1 "inputs")
$baseInputs = Join-Path $BaseTV "inputs"
Copy-Item -LiteralPath (Join-Path $baseInputs "ruleset.json") -Destination (Join-Path $Neg1 "inputs\ruleset.json") -Force
Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg1 "inputs\receipts.ndjson") -Force

# Build ledger by copying base ledger then duplicate first line
Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg1 "ledger.ndjson") -Force
$lns = CL-ReadLinesUtf8 (Join-Path $Neg1 "ledger.ndjson")
if(@($lns).Count -lt 1){ Die "NEG1_NO_LEDGER_LINES" }
$dup = @($lns[0], $lns[0]) + @($lns | Select-Object -Skip 1)
CL-WriteUtf8NoBomLf (Join-Path $Neg1 "ledger.ndjson") ((@($dup) -join "`n") + "`n")

$neg1Res = RunVerify $Neg1
if([bool]$neg1Res.ok){ Die "NEG1_EXPECT_FAIL_BUT_OK" }
if(-not (@($neg1Res.failures) -contains "DUP_EVENT_REF")){ Die ("NEG1_MISSING_TOKEN: expected DUP_EVENT_REF got " + (@($neg1Res.failures) -join "|")) }
$neg1Receipt=@{ schema="contrib.receipt.v1"; ts_utc=(NowUtc); kind="selftest"; vector="neg_dup_event_ref"; ok=$false; failures=@($neg1Res.failures) }
$neg1Receipt.receipt_hash=(CL-Sha256HexBytes (CL-BytesUtf8NoBomLf (CL-ToCanonJson $neg1Receipt)))
AppendReceipt $ReceiptPath (ReceiptLine $neg1Receipt)
Write-Host "NEG1_OK (DUP_EVENT_REF)" -ForegroundColor Green

# V2: ruleset_hash mismatch (tamper ruleset.json)
$Neg2 = Join-Path $RepoRoot "test_vectors\neg_ruleset_hash_mismatch"
CL-EnsureDir $Neg2
CL-EnsureDir (Join-Path $Neg2 "inputs")
Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg2 "inputs\receipts.ndjson") -Force
# tamper ruleset by changing weight
$rulesTampered = '{ "schema":"ruleset.v1","ruleset_id":"tampered","rules":[{"event_type":"watchtower.verify","weight":999},{"event_type":"device.uptime","weight":1}] }'
CL-WriteUtf8NoBomLf (Join-Path $Neg2 "inputs\ruleset.json") $rulesTampered
Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg2 "ledger.ndjson") -Force

$neg2Res = RunVerify $Neg2
if([bool]$neg2Res.ok){ Die "NEG2_EXPECT_FAIL_BUT_OK" }
if(-not (@($neg2Res.failures) -contains "RULESET_HASH_MISMATCH")){ Die ("NEG2_MISSING_TOKEN: expected RULESET_HASH_MISMATCH got " + (@($neg2Res.failures) -join "|")) }
$neg2Receipt=@{ schema="contrib.receipt.v1"; ts_utc=(NowUtc); kind="selftest"; vector="neg_ruleset_hash_mismatch"; ok=$false; failures=@($neg2Res.failures) }
$neg2Receipt.receipt_hash=(CL-Sha256HexBytes (CL-BytesUtf8NoBomLf (CL-ToCanonJson $neg2Receipt)))
AppendReceipt $ReceiptPath (ReceiptLine $neg2Receipt)
Write-Host "NEG2_OK (RULESET_HASH_MISMATCH)" -ForegroundColor Green

# V3: credit mismatch (tamper credit field in first ledger line)
$Neg3 = Join-Path $RepoRoot "test_vectors\neg_credit_mismatch"
CL-EnsureDir $Neg3
CL-EnsureDir (Join-Path $Neg3 "inputs")
Copy-Item -LiteralPath (Join-Path $baseInputs "ruleset.json") -Destination (Join-Path $Neg3 "inputs\ruleset.json") -Force
Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg3 "inputs\receipts.ndjson") -Force
Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg3 "ledger.ndjson") -Force

$lns3 = CL-ReadLinesUtf8 (Join-Path $Neg3 "ledger.ndjson")
if(@($lns3).Count -lt 1){ Die "NEG3_NO_LEDGER_LINES" }
$o3 = $lns3[0] | ConvertFrom-Json -ErrorAction Stop
$o3.credit = ([int]$o3.credit + 1)
$lns3[0] = (CL-ToCanonJson $o3)
CL-WriteUtf8NoBomLf (Join-Path $Neg3 "ledger.ndjson") ((@($lns3) -join "`n") + "`n")

$neg3Res = RunVerify $Neg3
if([bool]$neg3Res.ok){ Die "NEG3_EXPECT_FAIL_BUT_OK" }
if(-not (@($neg3Res.failures) -contains "CREDIT_MISMATCH")){ Die ("NEG3_MISSING_TOKEN: expected CREDIT_MISMATCH got " + (@($neg3Res.failures) -join "|")) }
$neg3Receipt=@{ schema="contrib.receipt.v1"; ts_utc=(NowUtc); kind="selftest"; vector="neg_credit_mismatch"; ok=$false; failures=@($neg3Res.failures) }
$neg3Receipt.receipt_hash=(CL-Sha256HexBytes (CL-BytesUtf8NoBomLf (CL-ToCanonJson $neg3Receipt)))
AppendReceipt $ReceiptPath (ReceiptLine $neg3Receipt)
Write-Host "NEG3_OK (CREDIT_MISMATCH)" -ForegroundColor Green

Write-Host "SELFTEST_OK: CONTRIBUTION_LEDGER_V1_POS+NEG" -ForegroundColor Green
'@
Write-Host ("WROTE: " + $Self) -ForegroundColor Green
ParseGate $Self
Write-Host "PARSE_OK: selftest (pos+neg+receipts)" -ForegroundColor Green

WriteUtf8NoBomLf $Full @'
param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function ParseGate([string]$Path){
  $t=$null; $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and @($e).Count -gt 0){
    $x=$e[0]
    Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

$Scripts = Join-Path $RepoRoot "scripts"
$Lib = Join-Path $Scripts "_lib_contribution_ledger_v1.ps1"
$Build = Join-Path $Scripts "build_contribution_ledger_v1.ps1"
$Verify = Join-Path $Scripts "verify_contribution_ledger_v1.ps1"
$Self = Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1"

ParseGate $Lib
ParseGate $Build
ParseGate $Verify
ParseGate $Self
Write-Host "PARSE_OK: all scripts" -ForegroundColor Green

& (Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe") -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Self -RepoRoot $RepoRoot | Out-Host

Write-Host "FULL_GREEN_OK: CONTRIBUTION_LEDGER_TIER0" -ForegroundColor Green
'@
Write-Host ("WROTE: " + $Full) -ForegroundColor Green
ParseGate $Full
Write-Host "PARSE_OK: full green runner" -ForegroundColor Green

Write-Host "APPLY_OK: PHASE_1_2_WRITTEN" -ForegroundColor Green
& (Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe") -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Full -RepoRoot $RepoRoot | Out-Host
Write-Host "FINAL_OK: CONTRIBUTION_LEDGER_PHASE1_2_V1" -ForegroundColor Green

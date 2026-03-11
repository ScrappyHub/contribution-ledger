param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ Die "EnsureDir: empty" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}
function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  if([string]::IsNullOrWhiteSpace($Path)){ Die "WriteUtf8NoBomLf: empty path" }
  $dir = Split-Path -Parent $Path
  if($dir){ EnsureDir $dir }
  $lf = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function ParseGate([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("PARSE_GATE_MISSING: " + $Path) }
  $t=$null; $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and @($e).Count -gt 0){
    $x=$e[0]
    Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$Scripts  = Join-Path $RepoRoot "scripts"
$Scratch  = Join-Path $Scripts "_scratch"
EnsureDir $Scratch

$SelfPath = Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1"
if(-not (Test-Path -LiteralPath $SelfPath -PathType Leaf)){ Die ("MISSING_SELFTEST: " + $SelfPath) }

# backup
$bkDir = Join-Path $Scratch "backups"
EnsureDir $bkDir
$stamp = (Get-Date -Format "yyyyMMdd_HHmmss")
$bk = Join-Path $bkDir ("_SELFTEST_contribution_ledger_v1.ps1.bak_" + $stamp)
[System.IO.File]::WriteAllBytes($bk,[System.IO.File]::ReadAllBytes($SelfPath))

# rewrite selftest with RepoRoot-only contract
$S = New-Object System.Collections.Generic.List[string]
[void]$S.Add('param([Parameter(Mandatory=$true)][string]$RepoRoot)')
[void]$S.Add('')
[void]$S.Add('$ErrorActionPreference="Stop"')
[void]$S.Add('Set-StrictMode -Version Latest')
[void]$S.Add('')
[void]$S.Add('. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")')
[void]$S.Add('function Die([string]$m){ throw $m }')
[void]$S.Add('function NowUtc(){ return [DateTime]::UtcNow.ToString("o") }')
[void]$S.Add('')
[void]$S.Add('function AppendReceipt([string]$Path,[string]$Line){')
[void]$S.Add('  $enc = New-Object System.Text.UTF8Encoding($false)')
[void]$S.Add('  $dir = Split-Path -Parent $Path')
[void]$S.Add('  if($dir){ CL-EnsureDir $dir }')
[void]$S.Add('  [System.IO.File]::AppendAllText($Path, ($Line + "`n"), $enc)')
[void]$S.Add('}')
[void]$S.Add('')
[void]$S.Add('function MakeReceiptLine([hashtable]$obj){')
[void]$S.Add('  $tmp = @{}')
[void]$S.Add('  foreach($k in @($obj.Keys)){ $tmp[$k] = $obj[$k] }')
[void]$S.Add('  if($tmp.ContainsKey("receipt_hash")){ [void]$tmp.Remove("receipt_hash") }')
[void]$S.Add('  $h = CL-Sha256HexBytes (CL-CanonJsonBytes $tmp)')
[void]$S.Add('  $obj["receipt_hash"] = $h')
[void]$S.Add('  return (CL-ToCanonJson $obj)')
[void]$S.Add('}')
[void]$S.Add('')
[void]$S.Add('function RunBuild([string]$TvRoot){')
[void]$S.Add('  & (Join-Path $RepoRoot "scripts\build_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot -TvRoot $TvRoot | Out-Host')
[void]$S.Add('  $br = Join-Path $TvRoot "build_result.json"')
[void]$S.Add('  if(-not (Test-Path -LiteralPath $br -PathType Leaf)){ Die ("MISSING_build_result: " + $br) }')
[void]$S.Add('}')
[void]$S.Add('')
[void]$S.Add('function RunVerify([string]$TvRoot){')
[void]$S.Add('  & (Join-Path $RepoRoot "scripts\verify_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot -TvRoot $TvRoot | Out-Host')
[void]$S.Add('  $vr = Join-Path $TvRoot "verify_result.json"')
[void]$S.Add('  if(-not (Test-Path -LiteralPath $vr -PathType Leaf)){ Die ("MISSING_verify_result: " + $vr) }')
[void]$S.Add('  return (Get-Content -LiteralPath $vr -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)')
[void]$S.Add('}')
[void]$S.Add('')
[void]$S.Add('$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\contribution_ledger.ndjson"')
[void]$S.Add('$BaseTV = (Resolve-Path -LiteralPath (Join-Path $RepoRoot "test_vectors\minimal_valid")).Path')
[void]$S.Add('$Gold = Join-Path $BaseTV "golden"')
[void]$S.Add('CL-EnsureDir $Gold')
[void]$S.Add('')
[void]$S.Add('# POSITIVE')
[void]$S.Add('RunBuild $BaseTV')
[void]$S.Add('$pos = RunVerify $BaseTV')
[void]$S.Add('if(-not [bool]$pos.ok){ Die ("POS_VERIFY_FAIL: " + (@($pos.failures) -join "|")) }')
[void]$S.Add('')
[void]$S.Add('# golden stamp if missing; then byte-compare')
[void]$S.Add('$Ledger = Join-Path $BaseTV "ledger.ndjson"')
[void]$S.Add('$Verify = Join-Path $BaseTV "verify_result.json"')
[void]$S.Add('$gLedger = Join-Path $Gold "ledger.ndjson"')
[void]$S.Add('$gVerify = Join-Path $Gold "expected_verify.json"')
[void]$S.Add('if(-not (Test-Path -LiteralPath $gLedger -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gLedger,[System.IO.File]::ReadAllBytes($Ledger)) }')
[void]$S.Add('if(-not (Test-Path -LiteralPath $gVerify -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gVerify,[System.IO.File]::ReadAllBytes($Verify)) }')
[void]$S.Add('$a=[System.IO.File]::ReadAllBytes($Ledger); $b=[System.IO.File]::ReadAllBytes($gLedger)')
[void]$S.Add('if($a.Length -ne $b.Length){ Die "GOLDEN_LEDGER_MISMATCH_LEN" }')
[void]$S.Add('for($i=0;$i -lt $a.Length;$i++){ if($a[$i] -ne $b[$i]){ Die ("GOLDEN_LEDGER_MISMATCH_AT_" + $i) } }')
[void]$S.Add('$a2=[System.IO.File]::ReadAllBytes($Verify); $b2=[System.IO.File]::ReadAllBytes($gVerify)')
[void]$S.Add('if($a2.Length -ne $b2.Length){ Die "GOLDEN_VERIFY_MISMATCH_LEN" }')
[void]$S.Add('for($i=0;$i -lt $a2.Length;$i++){ if($a2[$i] -ne $b2[$i]){ Die ("GOLDEN_VERIFY_MISMATCH_AT_" + $i) } }')
[void]$S.Add('')
[void]$S.Add('$posReceipt = @{ schema="contrib.receipt.v1"; ts_utc=(NowUtc); kind="selftest"; vector="positive"; ok=$true; failures=@(); ruleset_hash=[string]$pos.ruleset_hash }')
[void]$S.Add('AppendReceipt $ReceiptPath (MakeReceiptLine $posReceipt)')
[void]$S.Add('Write-Host "POS_OK" -ForegroundColor Green')
[void]$S.Add('')
[void]$S.Add('function AssertNeg([psobject]$res,[string]$token,[string]$name){')
[void]$S.Add('  if([bool]$res.ok){ Die ($name + "_EXPECT_FAIL_BUT_OK") }')
[void]$S.Add('  $arr = @($res.failures)')
[void]$S.Add('  if(-not ($arr -contains $token)){ Die ($name + "_MISSING_TOKEN: expected " + $token + " got " + ($arr -join "|")) }')
[void]$S.Add('}')
[void]$S.Add('')
[void]$S.Add('$baseInputs = Join-Path $BaseTV "inputs"')
[void]$S.Add('')
[void]$S.Add('# NEG1: DUP_EVENT_REF')
[void]$S.Add('$Neg1 = Join-Path $RepoRoot "test_vectors\neg_dup_event_ref"')
[void]$S.Add('CL-EnsureDir $Neg1; CL-EnsureDir (Join-Path $Neg1 "inputs")')
[void]$S.Add('Copy-Item -LiteralPath (Join-Path $baseInputs "ruleset.json") -Destination (Join-Path $Neg1 "inputs\ruleset.json") -Force')
[void]$S.Add('Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg1 "inputs\receipts.ndjson") -Force')
[void]$S.Add('Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg1 "ledger.ndjson") -Force')
[void]$S.Add('$lns = CL-ReadLinesUtf8 (Join-Path $Neg1 "ledger.ndjson")')
[void]$S.Add('if(@($lns).Count -lt 1){ Die "NEG1_NO_LEDGER_LINES" }')
[void]$S.Add('$dup = @($lns[0], $lns[0]) + @($lns | Select-Object -Skip 1)')
[void]$S.Add('CL-WriteUtf8NoBomLf (Join-Path $Neg1 "ledger.ndjson") ((@($dup) -join "`n") + "`n")')
[void]$S.Add('$neg1 = RunVerify $Neg1')
[void]$S.Add('AssertNeg $neg1 "DUP_EVENT_REF" "NEG1"')
[void]$S.Add('$neg1Receipt = @{ schema="contrib.receipt.v1"; ts_utc=(NowUtc); kind="selftest"; vector="neg_dup_event_ref"; ok=$false; failures=@($neg1.failures); ruleset_hash=[string]$neg1.ruleset_hash }')
[void]$S.Add('AppendReceipt $ReceiptPath (MakeReceiptLine $neg1Receipt)')
[void]$S.Add('Write-Host "NEG1_OK (DUP_EVENT_REF)" -ForegroundColor Green')
[void]$S.Add('')
[void]$S.Add('# NEG2: RULESET_HASH_MISMATCH')
[void]$S.Add('$Neg2 = Join-Path $RepoRoot "test_vectors\neg_ruleset_hash_mismatch"')
[void]$S.Add('CL-EnsureDir $Neg2; CL-EnsureDir (Join-Path $Neg2 "inputs")')
[void]$S.Add('Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg2 "inputs\receipts.ndjson") -Force')
[void]$S.Add('Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg2 "ledger.ndjson") -Force')
[void]$S.Add('$rulesTampered = ''{ "schema":"ruleset.v1","ruleset_id":"tampered","rules":[{"event_type":"watchtower.verify","weight":999},{"event_type":"device.uptime","weight":1}] }''')
[void]$S.Add('CL-WriteUtf8NoBomLf (Join-Path $Neg2 "inputs\ruleset.json") $rulesTampered')
[void]$S.Add('$neg2 = RunVerify $Neg2')
[void]$S.Add('AssertNeg $neg2 "RULESET_HASH_MISMATCH" "NEG2"')
[void]$S.Add('$neg2Receipt = @{ schema="contrib.receipt.v1"; ts_utc=(NowUtc); kind="selftest"; vector="neg_ruleset_hash_mismatch"; ok=$false; failures=@($neg2.failures); ruleset_hash=[string]$neg2.ruleset_hash }')
[void]$S.Add('AppendReceipt $ReceiptPath (MakeReceiptLine $neg2Receipt)')
[void]$S.Add('Write-Host "NEG2_OK (RULESET_HASH_MISMATCH)" -ForegroundColor Green')
[void]$S.Add('')
[void]$S.Add('# NEG3: CREDIT_MISMATCH')
[void]$S.Add('$Neg3 = Join-Path $RepoRoot "test_vectors\neg_credit_mismatch"')
[void]$S.Add('CL-EnsureDir $Neg3; CL-EnsureDir (Join-Path $Neg3 "inputs")')
[void]$S.Add('Copy-Item -LiteralPath (Join-Path $baseInputs "ruleset.json") -Destination (Join-Path $Neg3 "inputs\ruleset.json") -Force')
[void]$S.Add('Copy-Item -LiteralPath (Join-Path $baseInputs "receipts.ndjson") -Destination (Join-Path $Neg3 "inputs\receipts.ndjson") -Force')
[void]$S.Add('Copy-Item -LiteralPath $Ledger -Destination (Join-Path $Neg3 "ledger.ndjson") -Force')
[void]$S.Add('$rows = CL-ReadLinesUtf8 (Join-Path $Neg3 "ledger.ndjson")')
[void]$S.Add('if(@($rows).Count -lt 1){ Die "NEG3_NO_LEDGER_LINES" }')
[void]$S.Add('$first = $rows[0] | ConvertFrom-Json -ErrorAction Stop')
[void]$S.Add('$first.credit = ([int]$first.credit) + 1')
[void]$S.Add('$rows2 = New-Object System.Collections.Generic.List[string]')
[void]$S.Add('[void]$rows2.Add((CL-ToCanonJson $first))')
[void]$S.Add('foreach($x in @($rows | Select-Object -Skip 1)){ [void]$rows2.Add($x) }')
[void]$S.Add('CL-WriteUtf8NoBomLf (Join-Path $Neg3 "ledger.ndjson") ((@($rows2.ToArray()) -join "`n") + "`n")')
[void]$S.Add('$neg3 = RunVerify $Neg3')
[void]$S.Add('AssertNeg $neg3 "CREDIT_MISMATCH" "NEG3"')
[void]$S.Add('$neg3Receipt = @{ schema="contrib.receipt.v1"; ts_utc=(NowUtc); kind="selftest"; vector="neg_credit_mismatch"; ok=$false; failures=@($neg3.failures); ruleset_hash=[string]$neg3.ruleset_hash }')
[void]$S.Add('AppendReceipt $ReceiptPath (MakeReceiptLine $neg3Receipt)')
[void]$S.Add('Write-Host "NEG3_OK (CREDIT_MISMATCH)" -ForegroundColor Green')
[void]$S.Add('')
[void]$S.Add('Write-Host "SELFTEST_CONTRIBUTION_LEDGER_OK" -ForegroundColor Green')

WriteUtf8NoBomLf $SelfPath ((@($S.ToArray()) -join "`n"))
ParseGate $SelfPath

Write-Host ("PATCH_OK: selftest contract fixed (RepoRoot-only). Backup => " + $bk) -ForegroundColor Green

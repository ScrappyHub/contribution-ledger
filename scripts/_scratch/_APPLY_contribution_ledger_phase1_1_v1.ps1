param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "EMPTY_PATH" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function ReadBytes([string]$p){ return [System.IO.File]::ReadAllBytes($p) }
function WriteBytes([string]$p,[byte[]]$b){ $dir=Split-Path -Parent $p; if($dir){ EnsureDir $dir }; [System.IO.File]::WriteAllBytes($p,$b) }
function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir){ EnsureDir $dir }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}
function ParseGate([string]$Path){
  $t=$null; $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and @($e).Count -gt 0){ $x=$e[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message) }
}

# Paths
$Scripts = Join-Path $RepoRoot "scripts"
$TV = Join-Path $RepoRoot "test_vectors\minimal_valid"
$InDir = Join-Path $TV "inputs"
$Gold = Join-Path $TV "golden"
EnsureDir $Scripts; EnsureDir $TV; EnsureDir $InDir; EnsureDir $Gold

$LibPath = Join-Path $Scripts "_lib_contribution_ledger_v1.ps1"
$BuildPath = Join-Path $Scripts "build_contribution_ledger_v1.ps1"
$VerifyPath = Join-Path $Scripts "verify_contribution_ledger_v1.ps1"
$SelfPath = Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1"

# ---------------------------------------------------------
# LIB: canonical JSON (stable), SHA-256, NDJSON append, ids
# ---------------------------------------------------------
WriteUtf8NoBomLf $LibPath @'
param()
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function CL-Die([string]$m){ throw $m }
function CL-EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ CL-Die "EMPTY_PATH" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function CL-WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir){ CL-EnsureDir $dir }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}
function CL-BytesUtf8NoBomLf([string]$Text){
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  return $enc.GetBytes($t)
}
function CL-Sha256HexBytes([byte[]]$b){
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $h = $sha.ComputeHash($b) } finally { $sha.Dispose() }
  return ([BitConverter]::ToString($h).Replace("-","").ToLowerInvariant())
}
function CL-Sha256HexFile([string]$Path){ return (CL-Sha256HexBytes ([System.IO.File]::ReadAllBytes($Path))) }
function CL-JsonEscape([string]$s){
  if($null -eq $s){ return "" }
  $sb = New-Object System.Text.StringBuilder
  foreach($ch in $s.ToCharArray()){
    $c = [int][char]$ch
    if($c -eq 34){ [void]$sb.Append("\"") }
    elseif($c -eq 92){ [void]$sb.Append("\\") }
    elseif($c -eq 8){ [void]$sb.Append("\b") }
    elseif($c -eq 9){ [void]$sb.Append("\t") }
    elseif($c -eq 10){ [void]$sb.Append("\n") }
    elseif($c -eq 12){ [void]$sb.Append("\f") }
    elseif($c -eq 13){ [void]$sb.Append("\r") }
    elseif($c -lt 32){ [void]$sb.Append(("\u{0}" -f $c.ToString("x4"))) }
    else { [void]$sb.Append($ch) }
  }
  return $sb.ToString()
}
function CL-ToCanonJson($v){
  if($null -eq $v){ return "null" }
  if($v -is [bool]){ return ($(if($v){"true"}else{"false"})) }
  if($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]){ return ([string]$v) }
  if($v -is [string]){ return ("`"" + (CL-JsonEscape $v) + "`"") }
  if($v -is [System.Collections.IDictionary]){
    $keys = @($v.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach($k in @($keys)){
      $pair = ("`"" + (CL-JsonEscape $k) + "`":" + (CL-ToCanonJson $v[$k]))
      [void]$pairs.Add($pair)
    }
    return ("{" + (@($pairs.ToArray()) -join ",") + "}")
  }
  if($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])){
    $items = New-Object System.Collections.Generic.List[string]
    foreach($x in @($v)){ [void]$items.Add((CL-ToCanonJson $x)) }
    return ("[" + (@($items.ToArray()) -join ",") + "]")
  }
  # object with properties
  $props = @($v.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" -or $_.MemberType -eq "Property" })
  $dict = @{}
  foreach($p in @($props)){ $dict[$p.Name] = $p.Value }
  return (CL-ToCanonJson $dict)
}
function CL-CanonJsonBytes($obj){ return (CL-BytesUtf8NoBomLf (CL-ToCanonJson $obj)) }
function CL-EventRef([string]$ReceiptHash,[string]$RuleHash,[string]$EventType,[int]$Units){
  $s = ("receipt=" + $ReceiptHash + "|rule=" + $RuleHash + "|type=" + $EventType + "|units=" + $Units)
  return (CL-Sha256HexBytes (CL-BytesUtf8NoBomLf $s))
}
function CL-ReadLinesUtf8([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return @() }
  $enc = New-Object System.Text.UTF8Encoding($false)
  $txt = [System.IO.File]::ReadAllText($Path,$enc)
  $t = $txt.Replace("`r`n","`n").Replace("`r","`n")
  $lines = @($t -split "`n")
  $out = New-Object System.Collections.Generic.List[string]
  foreach($ln in @($lines)){ if($ln -ne $null -and $ln.Trim().Length -gt 0){ [void]$out.Add($ln) } }
  return @($out.ToArray())
}
function CL-AppendNdjsonUniqueByEventRef([string]$LedgerPath,[string[]]$NewLines){
  $existing = CL-ReadLinesUtf8 $LedgerPath
  $seen = @{}
  foreach($ln in @($existing)){
    try{ $o = $ln | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if($o -ne $null -and ($o.PSObject.Properties.Name -contains "event_ref")){ $seen[[string]$o.event_ref] = $true }
  }
  $toAdd = New-Object System.Collections.Generic.List[string]
  foreach($ln in @($NewLines)){
    $o = $ln | ConvertFrom-Json -ErrorAction Stop
    $er = [string]$o.event_ref
    if(-not $seen.ContainsKey($er)){ $seen[$er] = $true; [void]$toAdd.Add($ln) }
  }
  if(@($toAdd.ToArray()).Count -gt 0){
    $txt = ((@($toAdd.ToArray()) -join "`n") + "`n")
    $enc = New-Object System.Text.UTF8Encoding($false)
    $dir = Split-Path -Parent $LedgerPath
    if($dir){ CL-EnsureDir $dir }
    [System.IO.File]::AppendAllText($LedgerPath,$txt,$enc)
  }
  return @($toAdd.ToArray())
}
'@
Write-Host ("WROTE: " + $LibPath) -ForegroundColor Green
ParseGate $LibPath
Write-Host "PARSE_OK: lib" -ForegroundColor Green

# ---------------------------------------------------------
# BUILD: receipts + ruleset => ledger.ndjson (idempotent)
# ---------------------------------------------------------
WriteUtf8NoBomLf $BuildPath @'
param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")
function Die([string]$m){ throw $m }
$TV = Join-Path $RepoRoot "test_vectors\minimal_valid"
$InDir = Join-Path $TV "inputs"
$OutLedger = Join-Path $TV "ledger.ndjson"
$Receipts = Join-Path $InDir "receipts.ndjson"
$Rules = Join-Path $InDir "ruleset.json"
if(-not (Test-Path -LiteralPath $Receipts -PathType Leaf)){ Die ("MISSING_RECEIPTS: " + $Receipts) }
if(-not (Test-Path -LiteralPath $Rules -PathType Leaf)){ Die ("MISSING_RULESET: " + $Rules) }
$rulesObj = Get-Content -LiteralPath $Rules -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$ruleHash = CL-Sha256HexFile $Rules
$weights = @{}
foreach($r in @($rulesObj.rules)){ $weights[[string]$r.event_type] = [int]$r.weight }
$lines = CL-ReadLinesUtf8 $Receipts
$new = New-Object System.Collections.Generic.List[string]
foreach($ln in @($lines)){
  $o = $ln | ConvertFrom-Json -ErrorAction Stop
  $etype = [string]$o.event_type
  $units = [int]$o.units
  $w = 0
  if($weights.ContainsKey($etype)){ $w = [int]$weights[$etype] } else { continue }
  $credit = $units * $w
  $receiptHash = [string]$o.receipt_hash
  $eventRef = CL-EventRef $receiptHash $ruleHash $etype $units
  $row = @{ schema="contrib.ledger.line.v1"; event_ref=$eventRef; receipt_hash=$receiptHash; ruleset_hash=$ruleHash; event_type=$etype; units=$units; weight=$w; credit=$credit }
  $json = (CL-ToCanonJson $row)
  [void]$new.Add($json)
}
$added = CL-AppendNdjsonUniqueByEventRef $OutLedger @($new.ToArray())
$out = @{ ok=$true; added_count=@($added).Count; ledger=$OutLedger; ruleset_hash=$ruleHash }
$bytes = CL-CanonJsonBytes $out
[System.IO.File]::WriteAllBytes((Join-Path $TV "build_result.json"),$bytes)
Write-Host ("BUILD_OK: added=" + @($added).Count + " ledger=" + $OutLedger) -ForegroundColor Green
'@
Write-Host ("WROTE: " + $BuildPath) -ForegroundColor Green
ParseGate $BuildPath
Write-Host "PARSE_OK: build" -ForegroundColor Green

# ---------------------------------------------------------
# VERIFY: recompute expected ledger lines and validate
# ---------------------------------------------------------
WriteUtf8NoBomLf $VerifyPath @'
param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")
function Die([string]$m){ throw $m }
$TV = Join-Path $RepoRoot "test_vectors\minimal_valid"
$InDir = Join-Path $TV "inputs"
$Ledger = Join-Path $TV "ledger.ndjson"
$Receipts = Join-Path $InDir "receipts.ndjson"
$Rules = Join-Path $InDir "ruleset.json"
if(-not (Test-Path -LiteralPath $Ledger -PathType Leaf)){ Die ("MISSING_LEDGER: " + $Ledger) }
$rulesObj = Get-Content -LiteralPath $Rules -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$ruleHash = CL-Sha256HexFile $Rules
$weights = @{}
foreach($r in @($rulesObj.rules)){ $weights[[string]$r.event_type] = [int]$r.weight }
$seen=@{}
$fail = New-Object System.Collections.Generic.List[string]
$rows = CL-ReadLinesUtf8 $Ledger
foreach($ln in @($rows)){
  $o = $ln | ConvertFrom-Json -ErrorAction Stop
  $er = [string]$o.event_ref
  if($seen.ContainsKey($er)){ [void]$fail.Add("DUP_EVENT_REF"); continue }
  $seen[$er]=$true
  if([string]$o.ruleset_hash -ne $ruleHash){ [void]$fail.Add("RULESET_HASH_MISMATCH") }
  $etype=[string]$o.event_type; $units=[int]$o.units; $w=[int]$o.weight; $credit=[int]$o.credit
  if(-not $weights.ContainsKey($etype)){ [void]$fail.Add("UNKNOWN_EVENT_TYPE") ; continue }
  if($w -ne [int]$weights[$etype]){ [void]$fail.Add("WEIGHT_MISMATCH") }
  if($credit -ne ($units * $w)){ [void]$fail.Add("CREDIT_MISMATCH") }
  $expEr = CL-EventRef ([string]$o.receipt_hash) $ruleHash $etype $units
  if($er -ne $expEr){ [void]$fail.Add("EVENT_REF_MISMATCH") }
}
$ok = (@($fail.ToArray()).Count -eq 0)
$res = @{ schema="contrib.verify.result.v1"; ok=$ok; failures=@($fail.ToArray()); ruleset_hash=$ruleHash; ledger=$Ledger }
[System.IO.File]::WriteAllBytes((Join-Path $TV "verify_result.json"),(CL-CanonJsonBytes $res))
if($ok){ Write-Host "VERIFY_OK" -ForegroundColor Green } else { Write-Host ("VERIFY_FAIL: " + (@($fail.ToArray()) -join "|")) -ForegroundColor Red }
'@
Write-Host ("WROTE: " + $VerifyPath) -ForegroundColor Green
ParseGate $VerifyPath
Write-Host "PARSE_OK: verify" -ForegroundColor Green

# ---------------------------------------------------------
# SELFTEST: build -> verify -> generate golden -> compare
# ---------------------------------------------------------
WriteUtf8NoBomLf $SelfPath @'
param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")
function Die([string]$m){ throw $m }
$TV = Join-Path $RepoRoot "test_vectors\minimal_valid"
$Gold = Join-Path $TV "golden"
CL-EnsureDir $Gold
& (Join-Path $RepoRoot "scripts\build_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot | Out-Host
& (Join-Path $RepoRoot "scripts\verify_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot | Out-Host
$Ledger = Join-Path $TV "ledger.ndjson"
$Verify = Join-Path $TV "verify_result.json"
if(-not (Test-Path -LiteralPath $Ledger -PathType Leaf)){ Die "MISSING_LEDGER_AFTER_BUILD" }
if(-not (Test-Path -LiteralPath $Verify -PathType Leaf)){ Die "MISSING_VERIFY_AFTER_VERIFY" }
$gLedger = Join-Path $Gold "ledger.ndjson"
$gVerify = Join-Path $Gold "expected_verify.json"
# (v1) set golden if missing, otherwise compare bytes
if(-not (Test-Path -LiteralPath $gLedger -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gLedger,[System.IO.File]::ReadAllBytes($Ledger)) }
if(-not (Test-Path -LiteralPath $gVerify -PathType Leaf)){ [System.IO.File]::WriteAllBytes($gVerify,[System.IO.File]::ReadAllBytes($Verify)) }
$a = [System.IO.File]::ReadAllBytes($Ledger)
$b = [System.IO.File]::ReadAllBytes($gLedger)
if($a.Length -ne $b.Length){ Die "GOLDEN_LEDGER_MISMATCH_LEN" }
for($i=0;$i -lt $a.Length;$i++){ if($a[$i] -ne $b[$i]){ Die ("GOLDEN_LEDGER_MISMATCH_AT_" + $i) } }
$a2 = [System.IO.File]::ReadAllBytes($Verify)
$b2 = [System.IO.File]::ReadAllBytes($gVerify)
if($a2.Length -ne $b2.Length){ Die "GOLDEN_VERIFY_MISMATCH_LEN" }
for($i=0;$i -lt $a2.Length;$i++){ if($a2[$i] -ne $b2[$i]){ Die ("GOLDEN_VERIFY_MISMATCH_AT_" + $i) } }
Write-Host "SELFTEST_OK: CONTRIBUTION_LEDGER_V1" -ForegroundColor Green
'@
Write-Host ("WROTE: " + $SelfPath) -ForegroundColor Green
ParseGate $SelfPath
Write-Host "PARSE_OK: selftest" -ForegroundColor Green

Write-Host "APPLY_OK: lib+build+verify+selftest written+parse_ok" -ForegroundColor Green
& (Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe") -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $SelfPath -RepoRoot $RepoRoot | Out-Host
Write-Host "FINAL_OK: CONTRIBUTION_LEDGER_PHASE1_1_V1" -ForegroundColor Green

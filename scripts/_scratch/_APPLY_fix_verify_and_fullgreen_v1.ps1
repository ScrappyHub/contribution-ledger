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

$LibPath    = Join-Path $Scripts "_lib_contribution_ledger_v1.ps1"
$SelfPath   = Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1"
$VerifyPath = Join-Path $Scripts "verify_contribution_ledger_v1.ps1"
$FullPath   = Join-Path $Scripts "FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1"

if(-not (Test-Path -LiteralPath $LibPath  -PathType Leaf)){ Die ("MISSING: " + $LibPath) }
if(-not (Test-Path -LiteralPath $SelfPath -PathType Leaf)){ Die ("MISSING: " + $SelfPath) }

# backups
$bkDir = Join-Path $Scratch "backups"
EnsureDir $bkDir
$stamp = (Get-Date -Format "yyyyMMdd_HHmmss")

if(Test-Path -LiteralPath $VerifyPath -PathType Leaf){
  $bk1 = Join-Path $bkDir ("verify_contribution_ledger_v1.ps1.bak_" + $stamp)
  [System.IO.File]::WriteAllBytes($bk1,[System.IO.File]::ReadAllBytes($VerifyPath))
}
if(Test-Path -LiteralPath $FullPath -PathType Leaf){
  $bk2 = Join-Path $bkDir ("FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1.bak_" + $stamp)
  [System.IO.File]::WriteAllBytes($bk2,[System.IO.File]::ReadAllBytes($FullPath))
}

# =========================================================
# Patch verifier: ALWAYS write verify_result.json (finally)
# =========================================================
$L = New-Object System.Collections.Generic.List[string]
[void]$L.Add('param(')
[void]$L.Add('  [Parameter(Mandatory=$true)][string]$RepoRoot,')
[void]$L.Add('  [Parameter(Mandatory=$true)][string]$TvRoot')
[void]$L.Add(')')
[void]$L.Add('')
[void]$L.Add('$ErrorActionPreference="Stop"')
[void]$L.Add('Set-StrictMode -Version Latest')
[void]$L.Add('')
[void]$L.Add('. (Join-Path $RepoRoot "scripts\_lib_contribution_ledger_v1.ps1")')
[void]$L.Add('function NowUtc(){ return [DateTime]::UtcNow.ToString("o") }')
[void]$L.Add('function WriteResult([string]$OutPath,[hashtable]$Obj){ CL-WriteUtf8NoBomLf $OutPath (CL-ToCanonJson $Obj) }')
[void]$L.Add('')
[void]$L.Add('$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path')
[void]$L.Add('$TvRoot   = (Resolve-Path -LiteralPath $TvRoot).Path')
[void]$L.Add('$OutPath  = Join-Path $TvRoot "verify_result.json"')
[void]$L.Add('')
[void]$L.Add('$fail = New-Object System.Collections.Generic.List[string]')
[void]$L.Add('$ruleset_hash = ""')
[void]$L.Add('$ledger_hash  = ""')
[void]$L.Add('')
[void]$L.Add('try {')
[void]$L.Add('  $inputsDir = Join-Path $TvRoot "inputs"')
[void]$L.Add('  $rulesPath = Join-Path $inputsDir "ruleset.json"')
[void]$L.Add('  $recvPath  = Join-Path $inputsDir "receipts.ndjson"')
[void]$L.Add('  $ledPath   = Join-Path $TvRoot "ledger.ndjson"')
[void]$L.Add('  if(-not (Test-Path -LiteralPath $rulesPath -PathType Leaf)){ [void]$fail.Add("MISSING_RULESET") }')
[void]$L.Add('  if(-not (Test-Path -LiteralPath $recvPath  -PathType Leaf)){ [void]$fail.Add("MISSING_RECEIPTS") }')
[void]$L.Add('  if(-not (Test-Path -LiteralPath $ledPath   -PathType Leaf)){ [void]$fail.Add("MISSING_LEDGER") }')
[void]$L.Add('  if(@($fail).Count -eq 0){')
[void]$L.Add('    $rulesBytes = [System.IO.File]::ReadAllBytes($rulesPath)')
[void]$L.Add('    $ledBytes   = [System.IO.File]::ReadAllBytes($ledPath)')
[void]$L.Add('    $ruleset_hash = CL-Sha256HexBytes $rulesBytes')
[void]$L.Add('    $ledger_hash  = CL-Sha256HexBytes $ledBytes')
[void]$L.Add('    $rulesObj = (Get-Content -LiteralPath $rulesPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)')
[void]$L.Add('    $weights = @{}')
[void]$L.Add('    if($null -ne $rulesObj -and ($rulesObj.PSObject.Properties.Name -contains "rules")){')
[void]$L.Add('      foreach($r in @($rulesObj.rules)){')
[void]$L.Add('        if($null -ne $r -and ($r.PSObject.Properties.Name -contains "event_type") -and ($r.PSObject.Properties.Name -contains "weight")){')
[void]$L.Add('          $et=[string]$r.event_type; $w=[int]$r.weight; if(-not $weights.ContainsKey($et)){ $weights[$et]=$w }')
[void]$L.Add('        }')
[void]$L.Add('      }')
[void]$L.Add('    } else { [void]$fail.Add("RULESET_MISSING_RULES") }')
[void]$L.Add('    $seen=@{}; $expected=@{}')
[void]$L.Add('    foreach($ln in @(CL-ReadLinesUtf8 $recvPath)){')
[void]$L.Add('      if([string]::IsNullOrWhiteSpace($ln)){ continue }')
[void]$L.Add('      $ro = $ln | ConvertFrom-Json -ErrorAction Stop')
[void]$L.Add('      $eref=""; $etype=""')
[void]$L.Add('      if($ro.PSObject.Properties.Name -contains "event_ref"){ $eref=[string]$ro.event_ref }')
[void]$L.Add('      if($ro.PSObject.Properties.Name -contains "event_type"){ $etype=[string]$ro.event_type }')
[void]$L.Add('      if([string]::IsNullOrWhiteSpace($eref)){ [void]$fail.Add("RECEIPT_MISSING_EVENT_REF"); continue }')
[void]$L.Add('      if($seen.ContainsKey($eref)){ [void]$fail.Add("DUP_EVENT_REF"); continue }')
[void]$L.Add('      $seen[$eref]=$true')
[void]$L.Add('      $w=0; if($weights.ContainsKey($etype)){ $w=[int]$weights[$etype] }')
[void]$L.Add('      $expected[$eref]=$w')
[void]$L.Add('    }')
[void]$L.Add('    foreach($ln in @(CL-ReadLinesUtf8 $ledPath)){')
[void]$L.Add('      if([string]::IsNullOrWhiteSpace($ln)){ continue }')
[void]$L.Add('      $lo = $ln | ConvertFrom-Json -ErrorAction Stop')
[void]$L.Add('      $eref=""; if($lo.PSObject.Properties.Name -contains "event_ref"){ $eref=[string]$lo.event_ref }')
[void]$L.Add('      if([string]::IsNullOrWhiteSpace($eref)){ [void]$fail.Add("LEDGER_MISSING_EVENT_REF"); continue }')
[void]$L.Add('      $lh=""; if($lo.PSObject.Properties.Name -contains "ruleset_hash"){ $lh=[string]$lo.ruleset_hash }')
[void]$L.Add('      if($lh -ne $ruleset_hash){ [void]$fail.Add("RULESET_HASH_MISMATCH") }')
[void]$L.Add('      $got=0; if($lo.PSObject.Properties.Name -contains "credit"){ $got=[int]$lo.credit }')
[void]$L.Add('      if($expected.ContainsKey($eref)){ if($got -ne [int]$expected[$eref]){ [void]$fail.Add("CREDIT_MISMATCH") } } else { [void]$fail.Add("LEDGER_EVENT_REF_NOT_IN_RECEIPTS") }')
[void]$L.Add('    }')
[void]$L.Add('  }')
[void]$L.Add('} catch { [void]$fail.Add("VERIFY_EXCEPTION") } finally {')
[void]$L.Add('  $ok = (@($fail).Count -eq 0)')
[void]$L.Add('  $res = @{ schema="contrib.verify_result.v1"; ts_utc=(NowUtc); ok=$ok; failures=@(@($fail.ToArray())); ruleset_hash=$ruleset_hash; ledger_hash=$ledger_hash }')
[void]$L.Add('  WriteResult $OutPath $res')
[void]$L.Add('  if($ok){ Write-Host ("VERIFY_OK: " + $TvRoot) -ForegroundColor Green } else { Write-Host ("VERIFY_FAIL: " + $TvRoot + " :: " + (@($fail.ToArray()) -join "|")) -ForegroundColor Yellow }')
[void]$L.Add('}')

WriteUtf8NoBomLf $VerifyPath ((@($L.ToArray()) -join "`n"))
ParseGate $VerifyPath

# =========================================================
# Patch full green: must fail hard if selftest throws
# =========================================================
$R = New-Object System.Collections.Generic.List[string]
[void]$R.Add('param([Parameter(Mandatory=$true)][string]$RepoRoot)')
[void]$R.Add('$ErrorActionPreference="Stop"')
[void]$R.Add('Set-StrictMode -Version Latest')
[void]$R.Add('function Die([string]$m){ throw $m }')
[void]$R.Add('function ParseGate([string]$Path){')
[void]$R.Add('  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("PARSE_GATE_MISSING: " + $Path) }')
[void]$R.Add('  $t=$null; $e=$null')
[void]$R.Add('  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)')
[void]$R.Add('  if($e -and @($e).Count -gt 0){ $x=$e[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message) }')
[void]$R.Add('}')
[void]$R.Add('$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path')
[void]$R.Add('$Scripts = Join-Path $RepoRoot "scripts"')
[void]$R.Add('$paths = @((Join-Path $Scripts "_lib_contribution_ledger_v1.ps1"),(Join-Path $Scripts "build_contribution_ledger_v1.ps1"),(Join-Path $Scripts "verify_contribution_ledger_v1.ps1"),(Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1"))')
[void]$R.Add('foreach($p in @($paths)){ ParseGate $p }')
[void]$R.Add('Write-Host "PARSE_OK: all scripts" -ForegroundColor Green')
[void]$R.Add('& (Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1") -RepoRoot $RepoRoot | Out-Host')
[void]$R.Add('Write-Host "FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1" -ForegroundColor Green')

WriteUtf8NoBomLf $FullPath ((@($R.ToArray()) -join "`n"))
ParseGate $FullPath

Write-Host "APPLY_OK" -ForegroundColor Green
Write-Host ("WROTE: " + $VerifyPath) -ForegroundColor Green
Write-Host ("WROTE: " + $FullPath) -ForegroundColor Green

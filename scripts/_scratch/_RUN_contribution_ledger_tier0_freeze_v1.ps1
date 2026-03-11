param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Die([string]$Message){
  throw $Message
}

function Ensure-Dir([string]$Path){
  if([string]::IsNullOrWhiteSpace($Path)){ Die "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $Path -PathType Container)){
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  if([string]::IsNullOrWhiteSpace($Path)){ Die "WRITE_PATH_EMPTY" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("PARSE_GATE_MISSING: " + $Path)
  }
  $tok = $null
  $err = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tok,[ref]$err)
  if($err -and @($err).Count -gt 0){
    $first = $err[0]
    Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$first.Extent.StartLineNumber,$first.Extent.StartColumnNumber,$first.Message)
  }
}

function Read-AllBytes([string]$Path){
  return [System.IO.File]::ReadAllBytes($Path)
}

function Sha256-HexBytes([byte[]]$Bytes){
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha.ComputeHash($Bytes)
  } finally {
    $sha.Dispose()
  }
  return ([BitConverter]::ToString($hash).Replace("-","").ToLowerInvariant())
}

function Sha256-HexFile([string]$Path){
  return (Sha256-HexBytes (Read-AllBytes $Path))
}

function Read-Utf8Text([string]$Path){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText($Path,$enc)
}

function To-JsonStringLiteral([string]$Value){
  if($null -eq $Value){ return '""' }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  foreach($ch in $Value.ToCharArray()){
    $c = [int][char]$ch
    if($c -eq 34){
      [void]$sb.Append([char]92)
      [void]$sb.Append([char]34)
    }
    elseif($c -eq 92){
      [void]$sb.Append([char]92)
      [void]$sb.Append([char]92)
    }
    elseif($c -eq 8){
      [void]$sb.Append([char]92)
      [void]$sb.Append('b')
    }
    elseif($c -eq 9){
      [void]$sb.Append([char]92)
      [void]$sb.Append('t')
    }
    elseif($c -eq 10){
      [void]$sb.Append([char]92)
      [void]$sb.Append('n')
    }
    elseif($c -eq 12){
      [void]$sb.Append([char]92)
      [void]$sb.Append('f')
    }
    elseif($c -eq 13){
      [void]$sb.Append([char]92)
      [void]$sb.Append('r')
    }
    elseif($c -lt 32){
      [void]$sb.Append([char]92)
      [void]$sb.Append('u')
      [void]$sb.Append($c.ToString('x4'))
    }
    else {
      [void]$sb.Append($ch)
    }
  }
  [void]$sb.Append('"')
  return $sb.ToString()
}

function New-CanonicalObjectJson([hashtable]$Map){
  $keys = @($Map.Keys | ForEach-Object { [string]$_ } | Sort-Object)
  $parts = New-Object System.Collections.Generic.List[string]
  foreach($k in @($keys)){
    $v = $Map[$k]
    $valueText = $null
    if($v -is [bool]){
      if($v){ $valueText = 'true' } else { $valueText = 'false' }
    }
    elseif($v -is [int] -or $v -is [long]){
      $valueText = [string]$v
    }
    else {
      $valueText = To-JsonStringLiteral ([string]$v)
    }
    [void]$parts.Add((To-JsonStringLiteral $k) + ':' + $valueText)
  }
  return '{' + (@($parts.ToArray()) -join ',') + '}'
}

function Copy-FileDeterministic([string]$Source,[string]$Destination){
  if(-not (Test-Path -LiteralPath $Source -PathType Leaf)){
    Die ("COPY_SOURCE_MISSING: " + $Source)
  }
  $dir = Split-Path -Parent $Destination
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllBytes($Destination,[System.IO.File]::ReadAllBytes($Source))
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$ScriptsDir = Join-Path $RepoRoot "scripts"
$ScratchDir = Join-Path $ScriptsDir "_scratch"
$ProofsDir  = Join-Path $RepoRoot "proofs"
$FreezeRoot = Join-Path $ProofsDir "freeze"
$FreezeDir  = Join-Path $FreezeRoot "contribution_ledger_tier0_green_20260308"

Ensure-Dir $ScratchDir
Ensure-Dir $FreezeRoot
Ensure-Dir $FreezeDir

$RunnerPath = Join-Path $ScriptsDir "FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1"
Parse-GateFile $RunnerPath
Parse-GateFile (Join-Path $ScriptsDir "_lib_contribution_ledger_v1.ps1")
Parse-GateFile (Join-Path $ScriptsDir "build_contribution_ledger_v1.ps1")
Parse-GateFile (Join-Path $ScriptsDir "verify_contribution_ledger_v1.ps1")
Parse-GateFile (Join-Path $ScriptsDir "_SELFTEST_contribution_ledger_v1.ps1")

$TranscriptPath = Join-Path $FreezeDir "full_green_transcript.txt"
$StdoutPath     = Join-Path $ScratchDir "_tmp_contribution_ledger_full_green_stdout.txt"
$StderrPath     = Join-Path $ScratchDir "_tmp_contribution_ledger_full_green_stderr.txt"

if(Test-Path -LiteralPath $StdoutPath -PathType Leaf){ Remove-Item -LiteralPath $StdoutPath -Force }
if(Test-Path -LiteralPath $StderrPath -PathType Leaf){ Remove-Item -LiteralPath $StderrPath -Force }

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$argList = @(
  '-NoProfile'
  '-NonInteractive'
  '-ExecutionPolicy','Bypass'
  '-File', $RunnerPath
  '-RepoRoot', $RepoRoot
)

$proc = Start-Process -FilePath $PSExe -ArgumentList $argList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
$exitCode = [int]$proc.ExitCode

$stdoutText = ''
$stderrText = ''
if(Test-Path -LiteralPath $StdoutPath -PathType Leaf){ $stdoutText = Read-Utf8Text $StdoutPath }
if(Test-Path -LiteralPath $StderrPath -PathType Leaf){ $stderrText = Read-Utf8Text $StderrPath }

$combined = New-Object System.Collections.Generic.List[string]
[void]$combined.Add('CONTRIBUTION_LEDGER_TIER0_FREEZE_TRANSCRIPT_V1')
[void]$combined.Add('repo_root=' + $RepoRoot)
[void]$combined.Add('runner=' + $RunnerPath)
[void]$combined.Add('exit_code=' + $exitCode)
[void]$combined.Add('--- STDOUT BEGIN ---')
if($stdoutText.Length -gt 0){
  foreach($line in @($stdoutText.Replace("`r`n","`n").Replace("`r","`n") -split "`n")){
    [void]$combined.Add($line)
  }
}
[void]$combined.Add('--- STDOUT END ---')
[void]$combined.Add('--- STDERR BEGIN ---')
if($stderrText.Length -gt 0){
  foreach($line in @($stderrText.Replace("`r`n","`n").Replace("`r","`n") -split "`n")){
    [void]$combined.Add($line)
  }
}
[void]$combined.Add('--- STDERR END ---')

Write-Utf8NoBomLf $TranscriptPath ((@($combined.ToArray()) -join "`n"))

if($exitCode -ne 0){
  Die ("FULL_GREEN_EXIT_NONZERO: " + $exitCode)
}
if($stdoutText -notmatch 'FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1'){
  Die "FULL_GREEN_TOKEN_MISSING"
}
if($stdoutText -notmatch 'SELFTEST_CONTRIBUTION_LEDGER_OK'){
  Die "SELFTEST_TOKEN_MISSING"
}

# Freeze copy set
$FreezeFiles = New-Object System.Collections.Generic.List[string]

$Sources = @(
  (Join-Path $ScriptsDir "_lib_contribution_ledger_v1.ps1"),
  (Join-Path $ScriptsDir "build_contribution_ledger_v1.ps1"),
  (Join-Path $ScriptsDir "verify_contribution_ledger_v1.ps1"),
  (Join-Path $ScriptsDir "_SELFTEST_contribution_ledger_v1.ps1"),
  (Join-Path $ScriptsDir "FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1"),
  (Join-Path $RepoRoot "test_vectors\minimal_valid\inputs\receipts.ndjson"),
  (Join-Path $RepoRoot "test_vectors\minimal_valid\inputs\ruleset.json"),
  (Join-Path $RepoRoot "test_vectors\minimal_valid\ledger.ndjson"),
  (Join-Path $RepoRoot "test_vectors\minimal_valid\build_result.json"),
  (Join-Path $RepoRoot "test_vectors\minimal_valid\verify_result.json"),
  (Join-Path $RepoRoot "test_vectors\minimal_valid\golden\ledger.ndjson"),
  (Join-Path $RepoRoot "test_vectors\minimal_valid\golden\expected_verify.json"),
  (Join-Path $RepoRoot "test_vectors\neg_dup_event_ref\inputs\receipts.ndjson"),
  (Join-Path $RepoRoot "test_vectors\neg_dup_event_ref\inputs\ruleset.json"),
  (Join-Path $RepoRoot "test_vectors\neg_dup_event_ref\ledger.ndjson"),
  (Join-Path $RepoRoot "test_vectors\neg_dup_event_ref\verify_result.json"),
  (Join-Path $RepoRoot "test_vectors\neg_ruleset_hash_mismatch\inputs\receipts.ndjson"),
  (Join-Path $RepoRoot "test_vectors\neg_ruleset_hash_mismatch\inputs\ruleset.json"),
  (Join-Path $RepoRoot "test_vectors\neg_ruleset_hash_mismatch\ledger.ndjson"),
  (Join-Path $RepoRoot "test_vectors\neg_ruleset_hash_mismatch\verify_result.json"),
  (Join-Path $RepoRoot "test_vectors\neg_credit_mismatch\inputs\receipts.ndjson"),
  (Join-Path $RepoRoot "test_vectors\neg_credit_mismatch\inputs\ruleset.json"),
  (Join-Path $RepoRoot "test_vectors\neg_credit_mismatch\ledger.ndjson"),
  (Join-Path $RepoRoot "test_vectors\neg_credit_mismatch\verify_result.json"),
  (Join-Path $RepoRoot "proofs\receipts\contribution_ledger.ndjson"),
  $TranscriptPath
)

foreach($src in @($Sources)){
  if(-not (Test-Path -LiteralPath $src -PathType Leaf)){
    Die ("FREEZE_SOURCE_MISSING: " + $src)
  }
  $rel = $src.Substring($RepoRoot.Length).TrimStart('\')
  $dst = Join-Path $FreezeDir $rel
  Copy-FileDeterministic $src $dst
  [void]$FreezeFiles.Add($dst)
}

$ShaPath = Join-Path $FreezeDir "sha256sums.txt"
$ReceiptPath = Join-Path $FreezeDir "freeze_receipt.json"

$shaLines = New-Object System.Collections.Generic.List[string]
foreach($abs in @($FreezeFiles.ToArray() | Sort-Object)){
  $rel = $abs.Substring($FreezeDir.Length).TrimStart('\').Replace('\','/')
  $hash = Sha256-HexFile $abs
  [void]$shaLines.Add(($hash + '  ' + $rel))
}
Write-Utf8NoBomLf $ShaPath ((@($shaLines.ToArray()) -join "`n"))
$shaHash = Sha256-HexFile $ShaPath
$transcriptHash = Sha256-HexFile (Join-Path $FreezeDir "full_green_transcript.txt")
$receiptLedgerHash = Sha256-HexFile (Join-Path $FreezeDir "proofs\receipts\contribution_ledger.ndjson")

$receiptMap = @{
  build_script_hash      = (Sha256-HexFile (Join-Path $FreezeDir "scripts\build_contribution_ledger_v1.ps1"))
  freeze_id              = "contribution_ledger_tier0_green_20260308"
  freeze_scope           = "tier0-standalone-economic-layer"
  full_green_runner_hash = (Sha256-HexFile (Join-Path $FreezeDir "scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1"))
  ledger_receipt_hash    = $receiptLedgerHash
  repo_root              = $RepoRoot
  schema                 = "contribution_ledger.freeze.receipt.v1"
  sha256sums_hash        = $shaHash
  status                 = "FULL_GREEN"
  transcript_hash        = $transcriptHash
  verify_script_hash     = (Sha256-HexFile (Join-Path $FreezeDir "scripts\verify_contribution_ledger_v1.ps1"))
}
$receiptJson = New-CanonicalObjectJson $receiptMap
Write-Utf8NoBomLf $ReceiptPath $receiptJson

Write-Host "CONTRIBUTION_LEDGER_TIER0_FREEZE_OK" -ForegroundColor Green
Write-Host ("FREEZE_DIR=" + $FreezeDir) -ForegroundColor Green
Write-Host ("TRANSCRIPT=" + $TranscriptPath) -ForegroundColor Green
Write-Host ("SHA256SUMS=" + $ShaPath) -ForegroundColor Green
Write-Host ("RECEIPT=" + $ReceiptPath) -ForegroundColor Green
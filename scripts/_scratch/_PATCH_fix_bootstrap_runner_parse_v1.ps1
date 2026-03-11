param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function EnsureDir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
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

$Scratch = Join-Path $RepoRoot "scripts\_scratch"
EnsureDir $Scratch
$Runner = Join-Path $Scratch "_RUN_bootstrap_contribution_ledger_phase1_v1.ps1"

# Rebuild runner with fixed array literals (no trailing comma) + fixed parentheses
$L = New-Object System.Collections.Generic.List[string]
[void]$L.Add('param([Parameter(Mandatory=$true)][string]$RepoRoot)')
[void]$L.Add('$ErrorActionPreference="Stop"')
[void]$L.Add('Set-StrictMode -Version Latest')
[void]$L.Add('')
[void]$L.Add('function Die([string]$m){ throw $m }')
[void]$L.Add('function EnsureDir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }')
[void]$L.Add('function WriteUtf8NoBomLf([string]$Path,[string]$Text){')
[void]$L.Add('  $dir = Split-Path -Parent $Path')
[void]$L.Add('  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }')
[void]$L.Add('  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")')
[void]$L.Add('  if(-not $t.EndsWith("`n")){ $t += "`n" }')
[void]$L.Add('  $enc = New-Object System.Text.UTF8Encoding($false)')
[void]$L.Add('  [System.IO.File]::WriteAllText($Path,$t,$enc)')
[void]$L.Add('}')
[void]$L.Add('')
[void]$L.Add('# dirs')
[void]$L.Add('$docs = Join-Path $RepoRoot "docs"')
[void]$L.Add('$schemas = Join-Path $RepoRoot "schemas"')
[void]$L.Add('$scripts = Join-Path $RepoRoot "scripts"')
[void]$L.Add('$proofs = Join-Path $RepoRoot "proofs\receipts"')
[void]$L.Add('$tv = Join-Path $RepoRoot "test_vectors\minimal_valid"')
[void]$L.Add('EnsureDir $docs; EnsureDir $schemas; EnsureDir $scripts; EnsureDir $proofs; EnsureDir $tv')
[void]$L.Add('EnsureDir (Join-Path $scripts "_scratch")')
[void]$L.Add('EnsureDir (Join-Path $tv "inputs")')
[void]$L.Add('EnsureDir (Join-Path $tv "golden")')
[void]$L.Add('')
[void]$L.Add('# SPEC')
[void]$L.Add('$specPath = Join-Path $docs "SPEC_contribution_ledger_v1.md"')
[void]$L.Add('$specLines = @(')
[void]$L.Add('  "# Contribution Ledger v1 (Tier-0 Instrument)",')
[void]$L.Add('  "",')
[void]$L.Add('  "## What this is",')
[void]$L.Add('  "A deterministic standalone instrument that converts verifiable receipts/transcripts into append-only contribution credits (weight), not speculative tokens.",')
[void]$L.Add('  "",')
[void]$L.Add('  "## Core invariants",')
[void]$L.Add('  "- UTF-8 no BOM, LF only.",')
[void]$L.Add('  "- Canonical JSON bytes for hashing.",')
[void]$L.Add('  "- Append-only NDJSON ledger.",')
[void]$L.Add('  "- Idempotent scan: same inputs => byte-identical outputs.",')
[void]$L.Add('  "- No double-counting: event_ref unique.",')
[void]$L.Add('  "- Verifier never mutates; repairs are explicit commands.",')
[void]$L.Add('  "",')
[void]$L.Add('  "## Inputs/Outputs",')
[void]$L.Add('  "Inputs: receipts.ndjson + ruleset.json (hash pinned). Outputs: ledger.ndjson + verify_result.json + deterministic receipts."')
[void]$L.Add(')')
[void]$L.Add('WriteUtf8NoBomLf $specPath (($specLines -join "`n") + "`n")')
[void]$L.Add('Write-Host ("WROTE: " + $specPath) -ForegroundColor Green')
[void]$L.Add('')
[void]$L.Add('# schemas placeholders')
[void]$L.Add('WriteUtf8NoBomLf (Join-Path $schemas "contrib.event.v1.json") "{`n  `"schema`":`"contrib.event.v1`"`n}`n"' )
[void]$L.Add('WriteUtf8NoBomLf (Join-Path $schemas "contrib.ledger.line.v1.json") "{`n  `"schema`":`"contrib.ledger.line.v1`"`n}`n"' )
[void]$L.Add('WriteUtf8NoBomLf (Join-Path $schemas "contrib.rule.v1.json") "{`n  `"schema`":`"contrib.rule.v1`"`n}`n"' )
[void]$L.Add('WriteUtf8NoBomLf (Join-Path $schemas "contrib.verify.result.v1.json") "{`n  `"schema`":`"contrib.verify.result.v1`"`n}`n"' )
[void]$L.Add('Write-Host ("WROTE: " + $schemas) -ForegroundColor Green')
[void]$L.Add('')
[void]$L.Add('# synthetic inputs')
[void]$L.Add('$r = Join-Path $tv "inputs\receipts.ndjson"' )
[void]$L.Add('$rules = Join-Path $tv "inputs\ruleset.json"' )
[void]$L.Add('$rcptLines = @(')
[void]$L.Add('  "{`"schema`":`"receipt.synthetic.v1`",`"receipt_hash`":`"r1`",`"event_type`":`"watchtower.verify`",`"units`":60}",')
[void]$L.Add('  "{`"schema`":`"receipt.synthetic.v1`",`"receipt_hash`":`"r2`",`"event_type`":`"device.uptime`",`"units`":1440}"')
[void]$L.Add(')')
[void]$L.Add('WriteUtf8NoBomLf $r (($rcptLines -join "`n") + "`n")' )
[void]$L.Add('WriteUtf8NoBomLf $rules "{`"schema`":`"ruleset.v1`",`"ruleset_id`":`"minimal`",`"rules`":[{`"event_type`":`"watchtower.verify`",`"weight`":1},{`"event_type`":`"device.uptime`",`"weight`":1}]}`n"' )
[void]$L.Add('Write-Host ("WROTE: " + $tv) -ForegroundColor Green' )
[void]$L.Add('')
[void]$L.Add('Write-Host "PHASE1_BOOTSTRAP_OK: skeleton + spec + schemas + inputs written" -ForegroundColor Green' )

$text = (@($L.ToArray()) -join "`n") + "`n"
WriteUtf8NoBomLf $Runner $text
ParseGate $Runner
Write-Host ("PATCH_OK: runner fixed+parse_ok => " + $Runner) -ForegroundColor Green

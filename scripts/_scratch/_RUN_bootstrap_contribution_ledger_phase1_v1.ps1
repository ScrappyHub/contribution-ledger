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

# dirs
$docs = Join-Path $RepoRoot "docs"
$schemas = Join-Path $RepoRoot "schemas"
$scripts = Join-Path $RepoRoot "scripts"
$proofs = Join-Path $RepoRoot "proofs\receipts"
$tv = Join-Path $RepoRoot "test_vectors\minimal_valid"
EnsureDir $docs; EnsureDir $schemas; EnsureDir $scripts; EnsureDir $proofs; EnsureDir $tv
EnsureDir (Join-Path $scripts "_scratch")
EnsureDir (Join-Path $tv "inputs")
EnsureDir (Join-Path $tv "golden")

# SPEC
$specPath = Join-Path $docs "SPEC_contribution_ledger_v1.md"
$specLines = @(
  "# Contribution Ledger v1 (Tier-0 Instrument)",
  "",
  "## What this is",
  "A deterministic standalone instrument that converts verifiable receipts/transcripts into append-only contribution credits (weight), not speculative tokens.",
  "",
  "## Core invariants",
  "- UTF-8 no BOM, LF only.",
  "- Canonical JSON bytes for hashing.",
  "- Append-only NDJSON ledger.",
  "- Idempotent scan: same inputs => byte-identical outputs.",
  "- No double-counting: event_ref unique.",
  "- Verifier never mutates; repairs are explicit commands.",
  "",
  "## Inputs/Outputs",
  "Inputs: receipts.ndjson + ruleset.json (hash pinned). Outputs: ledger.ndjson + verify_result.json + deterministic receipts."
)
WriteUtf8NoBomLf $specPath (($specLines -join "`n") + "`n")
Write-Host ("WROTE: " + $specPath) -ForegroundColor Green

# schemas placeholders
WriteUtf8NoBomLf (Join-Path $schemas "contrib.event.v1.json") "{`n  `"schema`":`"contrib.event.v1`"`n}`n"
WriteUtf8NoBomLf (Join-Path $schemas "contrib.ledger.line.v1.json") "{`n  `"schema`":`"contrib.ledger.line.v1`"`n}`n"
WriteUtf8NoBomLf (Join-Path $schemas "contrib.rule.v1.json") "{`n  `"schema`":`"contrib.rule.v1`"`n}`n"
WriteUtf8NoBomLf (Join-Path $schemas "contrib.verify.result.v1.json") "{`n  `"schema`":`"contrib.verify.result.v1`"`n}`n"
Write-Host ("WROTE: " + $schemas) -ForegroundColor Green

# synthetic inputs
$r = Join-Path $tv "inputs\receipts.ndjson"
$rules = Join-Path $tv "inputs\ruleset.json"
$rcptLines = @(
  "{`"schema`":`"receipt.synthetic.v1`",`"receipt_hash`":`"r1`",`"event_type`":`"watchtower.verify`",`"units`":60}",
  "{`"schema`":`"receipt.synthetic.v1`",`"receipt_hash`":`"r2`",`"event_type`":`"device.uptime`",`"units`":1440}"
)
WriteUtf8NoBomLf $r (($rcptLines -join "`n") + "`n")
WriteUtf8NoBomLf $rules "{`"schema`":`"ruleset.v1`",`"ruleset_id`":`"minimal`",`"rules`":[{`"event_type`":`"watchtower.verify`",`"weight`":1},{`"event_type`":`"device.uptime`",`"weight`":1}]}`n"
Write-Host ("WROTE: " + $tv) -ForegroundColor Green

Write-Host "PHASE1_BOOTSTRAP_OK: skeleton + spec + schemas + inputs written" -ForegroundColor Green

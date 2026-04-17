# CLI Usage

Contribution Ledger is a deterministic CLI for building and verifying contribution ledgers from receipts and rulesets.

## Main command
powershell -File scripts\RUN_CONTRIBUTION_LEDGER.ps1 -RepoRoot . -WorkspaceName my_run

## Direct phase
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\START_contributing_phase_v2.ps1 -RepoRoot . -TvRoot .\workspaces\demo_phase

## Full validation
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1 -RepoRoot .
EXPECTED: FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1

## Freeze runner
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\_scratch\_RUN_contribution_ledger_tier0_freeze_v1.ps1 -RepoRoot .
EXPECTED: CONTRIBUTION_LEDGER_TIER0_FREEZE_OK

## What it is for
- proof-backed contribution accounting
- building canonical ledger entries from receipts and rulesets
- verifying that contribution output is valid

## What it is not
- not a wallet
- not a payment processor
- not a token engine
- not a rewards distributor

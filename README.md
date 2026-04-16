# Contribution Ledger

Contribution Ledger is a deterministic accounting engine that converts verifiable receipts into a reproducible, auditable ledger.

It is designed to:

* ingest canonical receipts
* apply a fixed ruleset
* build ledger entries deterministically
* verify correctness with strict failure modes

This is not a financial system. It does not issue tokens, process payments, or manage balances.

It is a proof-first accounting layer.

---

## What it does

* Converts receipts → ledger lines
* Ensures deterministic builds
* Verifies ledger correctness
* Fails on inconsistencies (no silent repair)
* Produces reproducible outputs across machines

---

## Quick Start

### Run selftest (engine validation)

```
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1 -RepoRoot .
```

Expected:

```
FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1
```

---

### Create and run a contribution workspace

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\START_contributing_phase_v2.ps1 -RepoRoot . -TvRoot .\workspaces\demo_phase
```

This will:

* bootstrap the workspace
* ingest receipts
* build ledger
* verify correctness

---

### Run again (idempotent)

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\START_contributing_phase_v2.ps1 -RepoRoot . -TvRoot .\workspaces\demo_phase
```

Expected:

* no new additions
* still valid

---

## Outputs

Workspace example:

```
workspaces/demo_phase/
  inputs/
    receipts.ndjson
  ledger.ndjson
  build_result.json
  verify_result.json
```

---

## Determinism guarantees

* Same inputs → same outputs
* No mutation during verify
* Strict failure on mismatch
* All outputs reproducible

---

## What this is not

* Not a payment system
* Not a token system
* Not a wallet
* Not a database of record

It is a deterministic computation layer.

---

## Status

* CLI engine: stable
* Selftest + vectors: complete
* Freeze artifact: complete
* UI: local workbench (non-canonical)

---

## License

TBD

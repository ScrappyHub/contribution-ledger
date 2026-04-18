# Contribution Ledger

Contribution Ledger is a deterministic accounting instrument that converts verified receipts into canonical contribution ledger entries and provable contribution credit.

It provides the accounting backbone for incentive and contribution systems by ensuring that all contribution claims are derived strictly from verifiable receipts and deterministic rules.

---

## What This Project Is

Contribution Ledger performs deterministic accounting over verified events.

Given:

* verified receipt inputs
* a deterministic ruleset

the system produces:

* canonical ledger entries
* deterministic contribution credit
* a verifiable accounting state

The ledger is append-only and independently verifiable.

Its purpose is to answer:

* who contributed
* what they contributed
* how much credit that contribution is worth
* whether the resulting accounting surface is valid

---

## What This Project Is Not

Contribution Ledger does not:

* issue tokens
* price assets
* process payments
* act as a policy engine
* manage identity
* act as a verification authority

Those responsibilities belong to other systems.

Contribution Ledger only performs deterministic contribution accounting over already verified events.

---

## Current Status

**Standalone accounting surface: FULL_GREEN**

The system currently includes:

* deterministic build pipeline
* deterministic verification pipeline
* positive and negative proof vectors
* append-only accounting receipts
* reproducible freeze artifacts
* full green runner

Canonical success token:

```text
FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1
```

Freeze success token:

```text
CONTRIBUTION_LEDGER_TIER0_FREEZE_OK
```

Freeze proof bundle:

```text
proofs/freeze/contribution_ledger_tier0_green_20260308/
```

Contents include:

* full_green_transcript.txt
* sha256sums.txt
* freeze_receipt.json

---

## What the Instrument Performs

Contribution Ledger provides:

1. Deterministic accounting
   Converts receipts + ruleset → canonical ledger lines

2. Verification
   Ensures ledger outputs are valid and reproducible

3. Credit derivation
   Computes contribution credit from ruleset weights

4. Failure enforcement
   Rejects invalid accounting surfaces deterministically

5. Append-only outputs
   Produces verifiable ledger and receipt artifacts

---

## Proof Surface

The current proof vectors include:

* minimal valid contribution flow
* duplicate event reference failure
* ruleset hash mismatch failure
* credit mismatch failure

Deterministic failure tokens:

```text
DUP_EVENT_REF
RULESET_HASH_MISMATCH
CREDIT_MISMATCH
```

---

## Running the Project

### Validate the engine

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1 `
  -RepoRoot .
```

Expected:

```text
FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1
```

---

### Run a contribution workspace

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\START_contributing_phase_v2.ps1 `
  -RepoRoot . `
  -TvRoot .\workspaces\demo_phase
```

This will:

* bootstrap the workspace (if needed)
* ingest receipts
* build ledger entries
* verify correctness

---

### Re-run (idempotent)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\START_contributing_phase_v2.ps1 `
  -RepoRoot . `
  -TvRoot .\workspaces\demo_phase
```

Expected:

* no additional ledger entries
* verification remains valid

---

## Workspace Layout

```text
workspaces/demo_phase/
  inputs/
    receipts.ndjson
    ruleset.json
  ledger.ndjson
  build_result.json
  verify_result.json
```

---

## Deterministic Environment

The system is designed for reproducible execution using:

* Windows PowerShell 5.1
* StrictMode enabled
* UTF-8 (no BOM)
* LF line endings
* write → parse-gate → execute discipline

---

## Use Cases

Contribution Ledger can account for:

* infrastructure uptime
* verification work
* artifact validation
* telemetry verification
* any provable contribution surface backed by receipts

It provides the deterministic accounting layer for systems built on verifiable events.

---

## UI vs CLI

* CLI: canonical, stable, shippable surface
* UI: local workbench for interaction (non-canonical)

---

## License

TBD

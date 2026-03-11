# Contribution Ledger

Contribution Ledger is the Tier-0 standalone economic / incentive accounting instrument of the ecosystem.

It converts verified receipts into canonical contribution ledger entries, deterministic credit totals, and provable incentive weight.

Contribution Ledger does not mint currency, price assets, or settle payments. Its role is narrower and more fundamental: it records *who contributed what* based on verifiable receipts, using deterministic rules and append-only ledger outputs.

This is the current standalone nucleus of the Economic / Incentive Layer.

---

## What This Project Is

Contribution Ledger is a deterministic accounting instrument that ingests verified receipt events and produces canonical contribution ledger lines.

Its job is to answer:

- who contributed
- what they contributed
- how much deterministic credit that contribution is worth
- whether the resulting accounting surface is valid and independently verifiable

The instrument is designed to prevent:

- double-counting
- ruleset drift
- silent credit inflation
- non-verifiable contribution claims

It is a proof-driven economic layer, not a speculative token system.

---

## What This Project Is Not

Contribution Ledger is not:

- a payment processor
- a cryptocurrency
- a market pricing engine
- a token mint
- an identity authority
- a transport law
- a policy engine

Those responsibilities belong elsewhere in the ecosystem.

Contribution Ledger only performs deterministic contribution accounting over already-proven events.

---

## Current Status

**Tier-0 standalone surface: FULL_GREEN**

Proven current surface includes:

- deterministic build
- deterministic verify
- positive vector pass
- negative vector pass
- append-only receipt emission
- frozen proof artifacts
- full green runner

Freeze proof bundle:

`proofs/freeze/contribution_ledger_tier0_green_20260308/`

Key outputs:

- `full_green_transcript.txt`
- `sha256sums.txt`
- `freeze_receipt.json`

Canonical success token:

`FULL_GREEN_OK: CONTRIBUTION_LEDGER_V1`

Freeze success token:

`CONTRIBUTION_LEDGER_TIER0_FREEZE_OK`

---

## What the Instrument Performs Today

Contribution Ledger currently performs:

1. Deterministic contribution accounting  
   Converts receipts + rulesets into canonical ledger lines.

2. Contribution verification  
   Validates that ledger outputs match deterministic expectations.

3. Credit derivation  
   Computes contribution credit from ruleset weights and receipt inputs.

4. Negative-vector enforcement  
   Proves deterministic failure on malformed or tampered accounting surfaces.

5. Append-only economic receipts  
   Emits auditable receipt artifacts for selftest and freeze operations.

---

## Current Tier-0 Proof Surface

Current vectors cover:

- minimal valid contribution ledger flow
- duplicate event reference failure
- ruleset hash mismatch failure
- credit mismatch failure

Deterministic failure tokens currently proven:

- `DUP_EVENT_REF`
- `RULESET_HASH_MISMATCH`
- `CREDIT_MISMATCH`

Additional failure tokens may appear in some negative cases depending on how a tampered surface breaks multiple invariants at once; Tier-0 currently requires the expected primary token to be present.

---

## Repository Layout

```text
docs/
proofs/
  freeze/
  receipts/
scripts/
  _lib_contribution_ledger_v1.ps1
  build_contribution_ledger_v1.ps1
  verify_contribution_ledger_v1.ps1
  _SELFTEST_contribution_ledger_v1.ps1
  FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1
  _scratch/
test_vectors/
  minimal_valid/
  neg_dup_event_ref/
  neg_ruleset_hash_mismatch/
  neg_credit_mismatch/

# Contribution Ledger v1 (Tier-0 Instrument)

## What this is
A deterministic standalone instrument that converts verifiable receipts/transcripts into append-only contribution credits (weight), not speculative tokens.

## Core invariants
- UTF-8 no BOM, LF only.
- Canonical JSON bytes for hashing.
- Append-only NDJSON ledger.
- Idempotent scan: same inputs => byte-identical outputs.
- No double-counting: event_ref unique.
- Verifier never mutates; repairs are explicit commands.

## Inputs/Outputs
Inputs: receipts.ndjson + ruleset.json (hash pinned). Outputs: ledger.ndjson + verify_result.json + deterministic receipts.

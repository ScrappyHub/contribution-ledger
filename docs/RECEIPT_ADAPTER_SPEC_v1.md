- Contribution Ledger remains standalone
- upstream systems can evolve independently
- receipt normalization is explicit
- contribution accounting only depends on a stable intake contract

This prevents tight coupling to unfinished or changing systems.

---

## Canonical Intake Contract

Each normalized receipt must be representable as a single NDJSON line with this minimum shape:

```json
{
  "schema": "contrib.receipt.v1",
  "receipt_hash": "string",
  "event_type": "string",
  "units": 1
}

Optional fields may be added later, but the minimum required fields are:

schema
receipt_hash
event_type
units
Field Definitions
schema

Required.

Must be:

contrib.receipt.v1
receipt_hash

Required.

A stable unique identifier for the upstream receipt or contribution event.

This is the canonical uniqueness anchor used by Contribution Ledger to prevent duplicate accounting.

event_type

Required.

A deterministic event class string used by the ruleset to assign contribution weight.

Examples:

watchtower.verify
device.uptime
artifact.verify
dataset.contribution
units

Required.

Integer count associated with the contribution event.

Examples:

1 for a single verification event
60 for 60 uptime minutes
1440 for one full day of uptime minutes
Ruleset Contract

Contribution Ledger rulesets map event types to weights.

Example:

{
  "schema": "ruleset.v1",
  "ruleset_id": "demo_v1",
  "rules": [
    { "event_type": "watchtower.verify", "weight": 5 },
    { "event_type": "device.uptime", "weight": 1 }
  ]
}

Contribution credit is derived deterministically from:

credit = units * weight
Adapter Responsibility

An adapter is responsible for:

reading upstream input
extracting or deriving a stable receipt_hash
mapping upstream event classes to canonical event_type
assigning deterministic integer units
emitting NDJSON lines conforming to contrib.receipt.v1

Adapters do not perform ledger accounting themselves.

Adapters only normalize input into the canonical intake boundary.

What Adapters Must Not Do

Adapters must not:

mutate ledger files
assign contribution credit directly
bypass ruleset evaluation
write unverifiable receipt hashes
emit non-integer units
depend on UI state

Adapters are normalization surfaces only.

Example Canonical Receipt Lines
{"schema":"contrib.receipt.v1","receipt_hash":"wt_r1","event_type":"watchtower.verify","units":1}
{"schema":"contrib.receipt.v1","receipt_hash":"wt_r2","event_type":"device.uptime","units":1440}
Planned Future Adapters

Examples of future adapter names:

scripts/adapters/adapter_synthetic_v1.ps1
scripts/adapters/adapter_watchtower_v1.ps1
scripts/adapters/adapter_artifact_verify_v1.ps1
scripts/adapters/adapter_execution_v1.ps1

These may be implemented later as upstream systems become stable.

Current State

At present, Contribution Ledger is using synthetic normalized receipts and workspace inputs.

This is intentional.

It allows the accounting surface to be fully operational without coupling to unfinished external systems.
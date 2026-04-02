\# Receipt Adapter Spec v1



This document defines the canonical receipt intake boundary for Contribution Ledger.



It exists to keep Contribution Ledger independent from unfinished or evolving upstream systems while still allowing future integrations to normalize their output into a stable accounting contract.



Contribution Ledger does not ingest arbitrary external system formats directly.



All upstream systems must pass through an adapter layer that emits canonical receipt objects accepted by the ledger.



\---



\## Purpose



The adapter boundary ensures:



\- Contribution Ledger remains standalone

\- upstream systems can evolve independently

\- receipt normalization is explicit

\- contribution accounting only depends on a stable intake contract



This prevents tight coupling to unfinished or changing systems.



\---



\## Canonical Intake Contract



Each normalized receipt must be representable as a single NDJSON line with this minimum shape:



```json

{

&#x20; "schema": "contrib.receipt.v1",

&#x20; "receipt\_hash": "string",

&#x20; "event\_type": "string",

&#x20; "units": 1

}


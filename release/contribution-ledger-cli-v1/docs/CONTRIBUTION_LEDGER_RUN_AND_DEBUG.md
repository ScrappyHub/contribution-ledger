\# Contribution Ledger — Run and Debug



This document preserves the canonical run commands, freeze commands, and core debug workflow for Contribution Ledger.



It exists so the operational surface does not get lost.



\---



\## Repo Root



```powershell

C:\\dev\\contribution-ledger

Canonical Full Validation Run



Run the full standalone accounting surface from repo root:



powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\FULL\_GREEN\_RUNNER\_CONTRIBUTION\_LEDGER\_v1.ps1 -RepoRoot .



Expected success surface:



PARSE\_OK: all scripts

BUILD\_OK: added=0 tv=C:\\dev\\contribution-ledger\\test\_vectors\\minimal\_valid

VERIFY\_OK: C:\\dev\\contribution-ledger\\test\_vectors\\minimal\_valid

POS\_OK

NEG1\_OK (DUP\_EVENT\_REF)

NEG2\_OK (RULESET\_HASH\_MISMATCH)

NEG3\_OK (CREDIT\_MISMATCH)

SELFTEST\_CONTRIBUTION\_LEDGER\_OK

FULL\_GREEN\_OK: CONTRIBUTION\_LEDGER\_V1



Notes:



Negative vectors intentionally print VERIFY\_FAIL for the tampered surfaces before the selftest confirms the expected token.

The required success token is:

FULL\_GREEN\_OK: CONTRIBUTION\_LEDGER\_V1

Canonical Freeze Run



Run the freeze/evidence pack from repo root:



powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\\_scratch\\\_RUN\_contribution\_ledger\_tier0\_freeze\_v1.ps1 -RepoRoot .



Expected freeze success token:



CONTRIBUTION\_LEDGER\_TIER0\_FREEZE\_OK



Expected freeze outputs:



proofs\\freeze\\contribution\_ledger\_tier0\_green\_20260308\\full\_green\_transcript.txt

proofs\\freeze\\contribution\_ledger\_tier0\_green\_20260308\\sha256sums.txt

proofs\\freeze\\contribution\_ledger\_tier0\_green\_20260308\\freeze\_receipt.json

Core Product Scripts



Canonical product surface:



scripts\\\_lib\_contribution\_ledger\_v1.ps1

scripts\\build\_contribution\_ledger\_v1.ps1

scripts\\verify\_contribution\_ledger\_v1.ps1

scripts\\\_SELFTEST\_contribution\_ledger\_v1.ps1

scripts\\FULL\_GREEN\_RUNNER\_CONTRIBUTION\_LEDGER\_v1.ps1



Freeze runner:



scripts\\\_scratch\\\_RUN\_contribution\_ledger\_tier0\_freeze\_v1.ps1

Core Test Vectors



Canonical vectors:



test\_vectors\\minimal\_valid

test\_vectors\\neg\_dup\_event\_ref

test\_vectors\\neg\_ruleset\_hash\_mismatch

test\_vectors\\neg\_credit\_mismatch



Expected primary negative tokens:



DUP\_EVENT\_REF

RULESET\_HASH\_MISMATCH

CREDIT\_MISMATCH



Note:

Some negative cases may emit additional failure tokens if multiple invariants are broken by the same tampered surface. The current selftest requires the expected primary token to be present.



Deterministic Environment



Contribution Ledger is currently run under:



Windows PowerShell 5.1

Set-StrictMode -Version Latest

UTF-8 without BOM

LF newlines

write-to-disk -> parse-gate -> execute discipline

append-only receipt surface

deterministic local execution

Quick Health Check



From repo root:



powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\FULL\_GREEN\_RUNNER\_CONTRIBUTION\_LEDGER\_v1.ps1 -RepoRoot .



If this prints:



FULL\_GREEN\_OK: CONTRIBUTION\_LEDGER\_V1



then the standalone accounting surface is healthy.



Quick Freeze Check



From repo root:



powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\\_scratch\\\_RUN\_contribution\_ledger\_tier0\_freeze\_v1.ps1 -RepoRoot .



If this prints:



CONTRIBUTION\_LEDGER\_TIER0\_FREEZE\_OK



then the freeze/evidence pack is healthy.



Manual Build Run



Run the deterministic build surface directly against the positive vector:



powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\build\_contribution\_ledger\_v1.ps1 -RepoRoot . -TvRoot .\\test\_vectors\\minimal\_valid



Expected success token:



BUILD\_OK: added=0 tv=C:\\dev\\contribution-ledger\\test\_vectors\\minimal\_valid

Manual Verify Run



Run deterministic verification directly against the positive vector:



powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\verify\_contribution\_ledger\_v1.ps1 -RepoRoot . -TvRoot .\\test\_vectors\\minimal\_valid



Expected success token:



VERIFY\_OK: C:\\dev\\contribution-ledger\\test\_vectors\\minimal\_valid

Manual Negative Verify Runs

Duplicate event reference

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\verify\_contribution\_ledger\_v1.ps1 -RepoRoot . -TvRoot .\\test\_vectors\\neg\_dup\_event\_ref



Expected primary token:



DUP\_EVENT\_REF

Ruleset hash mismatch

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\verify\_contribution\_ledger\_v1.ps1 -RepoRoot . -TvRoot .\\test\_vectors\\neg\_ruleset\_hash\_mismatch



Expected primary token:



RULESET\_HASH\_MISMATCH

Credit mismatch

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\verify\_contribution\_ledger\_v1.ps1 -RepoRoot . -TvRoot .\\test\_vectors\\neg\_credit\_mismatch



Expected primary token:



CREDIT\_MISMATCH

Useful Files During Debug



Positive surface:



test\_vectors\\minimal\_valid\\inputs\\receipts.ndjson

test\_vectors\\minimal\_valid\\inputs\\ruleset.json

test\_vectors\\minimal\_valid\\ledger.ndjson

test\_vectors\\minimal\_valid\\build\_result.json

test\_vectors\\minimal\_valid\\verify\_result.json

test\_vectors\\minimal\_valid\\golden\\ledger.ndjson

test\_vectors\\minimal\_valid\\golden\\expected\_verify.json



Negative surfaces:



test\_vectors\\neg\_dup\_event\_ref\\verify\_result.json

test\_vectors\\neg\_ruleset\_hash\_mismatch\\verify\_result.json

test\_vectors\\neg\_credit\_mismatch\\verify\_result.json



Receipts:



proofs\\receipts\\contribution\_ledger.ndjson



Freeze bundle:



proofs\\freeze\\contribution\_ledger\_tier0\_green\_20260308

Parse-Gate Debug Workflow



If a script stops parse-gating, use this PowerShell pattern:



$t=$null

$e=$null

\[void]\[System.Management.Automation.Language.Parser]::ParseFile("C:\\dev\\contribution-ledger\\scripts\\<SCRIPT\_NAME>.ps1",\[ref]$t,\[ref]$e)

$e



If parse errors exist, repair the script before running anything else.



Deterministic Debug Order



When debugging, use this order:



parse-gate the changed script

run manual build or verify against a specific vector

run the full green runner

run the freeze runner only after full green is restored



Do not skip straight to freeze if the full runner is not green.



Current Frozen State



Current proven standalone state:



full validation surface passes

freeze bundle exists

public repo surface exists

GitHub main is updated

tag exists:

contribution-ledger-v1



Freeze directory:



proofs\\freeze\\contribution\_ledger\_tier0\_green\_20260308

Canonical Meaning



Contribution Ledger is the deterministic accounting nucleus of the economic layer.



It converts verified receipts into canonical contribution ledger entries and contribution credit.



It does not perform:



token issuance

pricing

payments

identity authority

policy authority



Its role is deterministic accounting over already verified events.


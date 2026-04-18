# Contribution Ledger CLI v1 Release

This bundle is the standalone CLI release surface for Contribution Ledger.

Included:
- canonical CLI runners
- docs for usage and ship status
- schemas
- minimal positive and negative test vectors

Primary command:
powershell -File scripts\RUN_CONTRIBUTION_LEDGER.ps1 -RepoRoot . -WorkspaceName my_run

Validation command:
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1 -RepoRoot .

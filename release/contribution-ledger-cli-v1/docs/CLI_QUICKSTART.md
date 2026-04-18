\# CLI Quickstart



\## 1. Validate engine



```

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\scripts\\FULL\_GREEN\_RUNNER\_CONTRIBUTION\_LEDGER\_v1.ps1 -RepoRoot .

```



\---



\## 2. Create workspace



```

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\START\_contributing\_phase\_v2.ps1 -RepoRoot . -TvRoot .\\workspaces\\demo\_phase

```



\---



\## 3. Add or modify receipts



Edit:



```

workspaces/demo\_phase/inputs/receipts.ndjson

```



\---



\## 4. Re-run



```

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\START\_contributing\_phase\_v2.ps1 -RepoRoot . -TvRoot .\\workspaces\\demo\_phase

```



\---



\## 5. Inspect results



```

workspaces/demo\_phase/ledger.ndjson

```



\---



\## Notes



\* If receipts change, delete:



&#x20; \* ledger.ndjson

&#x20; \* build\_result.json

&#x20; \* verify\_result.json



Then rerun.




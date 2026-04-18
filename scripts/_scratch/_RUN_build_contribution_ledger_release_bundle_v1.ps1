param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Utf8NoBomLf {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Text)
    $dir = Split-Path -Parent $Path
    if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
    if(-not $t.EndsWith("`n")){ $t += "`n" }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path,$t,$enc)
}

function Ensure-Dir {
    param([Parameter(Mandatory=$true)][string]$Path)
    if(-not (Test-Path -LiteralPath $Path -PathType Container)){
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Copy-RequiredFile {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Dest
    )
    if(-not (Test-Path -LiteralPath $Source -PathType Leaf)){
        throw ('MISSING_REQUIRED_FILE: ' + $Source)
    }
    $destDir = Split-Path -Parent $Dest
    if($destDir){ Ensure-Dir $destDir }
    Copy-Item -LiteralPath $Source -Destination $Dest -Force
}

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ReleaseRoot = Join-Path $RepoRoot 'release'
$BundleRoot  = Join-Path $ReleaseRoot 'contribution-ledger-cli-v1'

if(Test-Path -LiteralPath $BundleRoot){
    Remove-Item -LiteralPath $BundleRoot -Recurse -Force
}

Ensure-Dir $ReleaseRoot
Ensure-Dir $BundleRoot
Ensure-Dir (Join-Path $BundleRoot 'scripts')
Ensure-Dir (Join-Path $BundleRoot 'docs')
Ensure-Dir (Join-Path $BundleRoot 'schemas')
Ensure-Dir (Join-Path $BundleRoot 'test_vectors')

# Canonical CLI surface
Copy-RequiredFile (Join-Path $RepoRoot 'README.md')                                           (Join-Path $BundleRoot 'README.md')
Copy-RequiredFile (Join-Path $RepoRoot 'scripts\RUN_CONTRIBUTION_LEDGER.ps1')                 (Join-Path $BundleRoot 'scripts\RUN_CONTRIBUTION_LEDGER.ps1')
Copy-RequiredFile (Join-Path $RepoRoot 'scripts\START_contributing_phase_v2.ps1')             (Join-Path $BundleRoot 'scripts\START_contributing_phase_v2.ps1')
Copy-RequiredFile (Join-Path $RepoRoot 'scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1')(Join-Path $BundleRoot 'scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1')
Copy-RequiredFile (Join-Path $RepoRoot 'scripts\build_contribution_ledger_v1.ps1')            (Join-Path $BundleRoot 'scripts\build_contribution_ledger_v1.ps1')
Copy-RequiredFile (Join-Path $RepoRoot 'scripts\verify_contribution_ledger_v1.ps1')           (Join-Path $BundleRoot 'scripts\verify_contribution_ledger_v1.ps1')
Copy-RequiredFile (Join-Path $RepoRoot 'scripts\_SELFTEST_contribution_ledger_v1.ps1')        (Join-Path $BundleRoot 'scripts\_SELFTEST_contribution_ledger_v1.ps1')
Copy-RequiredFile (Join-Path $RepoRoot 'scripts\_lib_contribution_ledger_v1.ps1')             (Join-Path $BundleRoot 'scripts\_lib_contribution_ledger_v1.ps1')
Copy-RequiredFile (Join-Path $RepoRoot 'docs\CLI_USAGE.md')                                    (Join-Path $BundleRoot 'docs\CLI_USAGE.md')
Copy-RequiredFile (Join-Path $RepoRoot 'docs\SHIP_STATUS.md')                                  (Join-Path $BundleRoot 'docs\SHIP_STATUS.md')
Copy-RequiredFile (Join-Path $RepoRoot 'docs\CLI_QUICKSTART.md')                               (Join-Path $BundleRoot 'docs\CLI_QUICKSTART.md')
Copy-RequiredFile (Join-Path $RepoRoot 'docs\CONTRIBUTION_LEDGER_RUN_AND_DEBUG.md')            (Join-Path $BundleRoot 'docs\CONTRIBUTION_LEDGER_RUN_AND_DEBUG.md')
Copy-RequiredFile (Join-Path $RepoRoot 'docs\SPEC_contribution_ledger_v1.md')                  (Join-Path $BundleRoot 'docs\SPEC_contribution_ledger_v1.md')
Copy-RequiredFile (Join-Path $RepoRoot 'schemas\contrib.event.v1.json')                        (Join-Path $BundleRoot 'schemas\contrib.event.v1.json')
Copy-RequiredFile (Join-Path $RepoRoot 'schemas\contrib.ledger.line.v1.json')                  (Join-Path $BundleRoot 'schemas\contrib.ledger.line.v1.json')
Copy-RequiredFile (Join-Path $RepoRoot 'schemas\contrib.rule.v1.json')                         (Join-Path $BundleRoot 'schemas\contrib.rule.v1.json')
Copy-RequiredFile (Join-Path $RepoRoot 'schemas\contrib.verify.result.v1.json')                (Join-Path $BundleRoot 'schemas\contrib.verify.result.v1.json')

# Minimal vectors for verification and examples
Copy-Item -LiteralPath (Join-Path $RepoRoot 'test_vectors\minimal_valid') -Destination (Join-Path $BundleRoot 'test_vectors\minimal_valid') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'test_vectors\neg_dup_event_ref') -Destination (Join-Path $BundleRoot 'test_vectors\neg_dup_event_ref') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'test_vectors\neg_ruleset_hash_mismatch') -Destination (Join-Path $BundleRoot 'test_vectors\neg_ruleset_hash_mismatch') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'test_vectors\neg_credit_mismatch') -Destination (Join-Path $BundleRoot 'test_vectors\neg_credit_mismatch') -Recurse -Force

# Release note
$releaseNote = @(
'# Contribution Ledger CLI v1 Release',
'',
'This bundle is the standalone CLI release surface for Contribution Ledger.',
'',
'Included:',
'- canonical CLI runners',
'- docs for usage and ship status',
'- schemas',
'- minimal positive and negative test vectors',
'',
'Primary command:',
'powershell -File scripts\RUN_CONTRIBUTION_LEDGER.ps1 -RepoRoot . -WorkspaceName my_run',
'',
'Validation command:',
'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\FULL_GREEN_RUNNER_CONTRIBUTION_LEDGER_v1.ps1 -RepoRoot .'
) -join "`n"
Write-Utf8NoBomLf (Join-Path $BundleRoot 'RELEASE.md') $releaseNote

# sha256sums.txt over all files in bundle except sha256sums.txt itself
$shaPath = Join-Path $BundleRoot 'sha256sums.txt'
$lines = New-Object System.Collections.Generic.List[string]
$files = Get-ChildItem -LiteralPath $BundleRoot -Recurse -File | Sort-Object FullName
foreach($f in $files){
    if($f.FullName -eq $shaPath){ continue }
    $hash = Get-Sha256Hex $f.FullName
    $rel  = $f.FullName.Substring($BundleRoot.Length).TrimStart('\') -replace '\\','/'
    [void]$lines.Add($hash + '  ' + $rel)
}
Write-Utf8NoBomLf $shaPath (($lines.ToArray()) -join "`n")

Write-Host ('RELEASE_BUNDLE_OK: ' + $BundleRoot) -ForegroundColor Green
Write-Host ('SHA256SUMS: ' + $shaPath) -ForegroundColor Green
Get-ChildItem -LiteralPath $BundleRoot -Recurse | Select-Object FullName | Out-Host

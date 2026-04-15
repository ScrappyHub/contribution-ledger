Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$PhaseScript = Join-Path $RepoRoot "scripts\START_contributing_phase_v2.ps1"
$AdapterScript = Join-Path $RepoRoot "scripts\adapters\adapter_synthetic_v1.ps1"

if(-not (Test-Path -LiteralPath $PhaseScript -PathType Leaf)){
  Die ("MISSING_PHASE_SCRIPT: " + $PhaseScript)
}
if(-not (Test-Path -LiteralPath $AdapterScript -PathType Leaf)){
  Die ("MISSING_ADAPTER_SCRIPT: " + $AdapterScript)
}

function Resolve-WorkspacePath([string]$Repo,[string]$WsText){
  if([string]::IsNullOrWhiteSpace($WsText)){ return $null }
  if([System.IO.Path]::IsPathRooted($WsText)){ return $WsText }
  return (Join-Path $Repo $WsText)
}

function Set-Output([System.Windows.Forms.TextBox]$Box,[string]$Text){
  $Box.Text = $Text
  $Box.SelectionStart = $Box.TextLength
  $Box.ScrollToCaret()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Contribution Ledger Workbench"
$form.StartPosition = "CenterScreen"
$form.Width = 780
$form.Height = 560
$form.MinimumSize = New-Object System.Drawing.Size(780,560)

$lblRepo = New-Object System.Windows.Forms.Label
$lblRepo.Text = "Repo Root"
$lblRepo.Left = 20
$lblRepo.Top = 20
$lblRepo.Width = 120

$txtRepo = New-Object System.Windows.Forms.TextBox
$txtRepo.Left = 20
$txtRepo.Top = 42
$txtRepo.Width = 720
$txtRepo.ReadOnly = $true
$txtRepo.Text = $RepoRoot

$lblWs = New-Object System.Windows.Forms.Label
$lblWs.Text = "Workspace"
$lblWs.Left = 20
$lblWs.Top = 80
$lblWs.Width = 120

$txtWs = New-Object System.Windows.Forms.TextBox
$txtWs.Left = 20
$txtWs.Top = 102
$txtWs.Width = 720
$txtWs.Text = ".\workspaces\new_phase"

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run / Bootstrap Contribution Phase"
$btnRun.Left = 20
$btnRun.Top = 145
$btnRun.Width = 230
$btnRun.Height = 36

$btnOpenWs = New-Object System.Windows.Forms.Button
$btnOpenWs.Text = "Open Workspace Folder"
$btnOpenWs.Left = 265
$btnOpenWs.Top = 145
$btnOpenWs.Width = 165
$btnOpenWs.Height = 36

$btnGen = New-Object System.Windows.Forms.Button
$btnGen.Text = "Generate Synthetic Receipts"
$btnGen.Left = 445
$btnGen.Top = 145
$btnGen.Width = 180
$btnGen.Height = 36

$btnOpenLedger = New-Object System.Windows.Forms.Button
$btnOpenLedger.Text = "Open Ledger"
$btnOpenLedger.Left = 640
$btnOpenLedger.Top = 145
$btnOpenLedger.Width = 100
$btnOpenLedger.Height = 36

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear Output"
$btnClear.Left = 20
$btnClear.Top = 190
$btnClear.Width = 120
$btnClear.Height = 34

$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text = "Output"
$lblOut.Left = 20
$lblOut.Top = 235
$lblOut.Width = 120

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Left = 20
$txtOut.Top = 257
$txtOut.Width = 720
$txtOut.Height = 245
$txtOut.Multiline = $true
$txtOut.ScrollBars = "Vertical"
$txtOut.ReadOnly = $true
$txtOut.Font = New-Object System.Drawing.Font("Consolas",10)

$btnRun.Add_Click({
  try{
    $wsText = $txtWs.Text
    if([string]::IsNullOrWhiteSpace($wsText)){ throw "WORKSPACE_PATH_EMPTY" }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command powershell.exe -ErrorAction Stop).Source
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -RepoRoot "{1}" -TvRoot "{2}"' -f $PhaseScript,$RepoRoot,$wsText)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add("=== RUN RESULT ===")
    [void]$parts.Add("exit_code=" + [string]$proc.ExitCode)
    [void]$parts.Add("")
    [void]$parts.Add("=== STDOUT ===")
    if($stdout.Length -gt 0){ [void]$parts.Add($stdout.TrimEnd("`r","`n")) }
    [void]$parts.Add("")
    [void]$parts.Add("=== STDERR ===")
    if($stderr.Length -gt 0){ [void]$parts.Add($stderr.TrimEnd("`r","`n")) }

    Set-Output $txtOut ((@($parts.ToArray()) -join "`r`n"))

    if($proc.ExitCode -eq 0){
      $resolvedWs = Resolve-WorkspacePath $RepoRoot $wsText
      if($resolvedWs -and (Test-Path -LiteralPath $resolvedWs -PathType Container)){
        $txtWs.Text = $resolvedWs
      }
    }
  }
  catch{
    Set-Output $txtOut ("UI_RUN_EXCEPTION`r`n" + $_.Exception.Message)
  }
})

$btnOpenWs.Add_Click({
  try{
    $resolvedWs = Resolve-WorkspacePath $RepoRoot $txtWs.Text
    if([string]::IsNullOrWhiteSpace($resolvedWs)){ throw "WORKSPACE_PATH_EMPTY" }
    if(-not (Test-Path -LiteralPath $resolvedWs -PathType Container)){
      throw ("WORKSPACE_MISSING: " + $resolvedWs)
    }
    Start-Process explorer.exe -ArgumentList ('"{0}"' -f $resolvedWs) | Out-Null
  }
  catch{
    Set-Output $txtOut ("OPEN_WORKSPACE_EXCEPTION`r`n" + $_.Exception.Message)
  }
})

$btnGen.Add_Click({
  try{
    $resolvedWs = Resolve-WorkspacePath $RepoRoot $txtWs.Text
    if([string]::IsNullOrWhiteSpace($resolvedWs)){ throw "WORKSPACE_PATH_EMPTY" }

    $inputsDir = Join-Path $resolvedWs "inputs"
    $receiptsPath = Join-Path $inputsDir "receipts.ndjson"

    $derived = @(
      (Join-Path $resolvedWs "ledger.ndjson")
      (Join-Path $resolvedWs "build_result.json")
      (Join-Path $resolvedWs "verify_result.json")
    )

    foreach($p in @($derived)){
      if(Test-Path -LiteralPath $p -PathType Leaf){
        Remove-Item -LiteralPath $p -Force
      }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command powershell.exe -ErrorAction Stop).Source
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -OutPath "{1}"' -f $AdapterScript,$receiptsPath)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add("=== GENERATE SYNTHETIC RECEIPTS ===")
    [void]$parts.Add("exit_code=" + [string]$proc.ExitCode)
    [void]$parts.Add("")
    [void]$parts.Add("workspace=" + $resolvedWs)
    [void]$parts.Add("receipts=" + $receiptsPath)
    [void]$parts.Add("reset=ledger.ndjson|build_result.json|verify_result.json")
    [void]$parts.Add("")
    [void]$parts.Add("=== STDOUT ===")
    if($stdout.Length -gt 0){ [void]$parts.Add($stdout.TrimEnd("`r","`n")) }
    [void]$parts.Add("")
    [void]$parts.Add("=== STDERR ===")
    if($stderr.Length -gt 0){ [void]$parts.Add($stderr.TrimEnd("`r","`n")) }

    Set-Output $txtOut ((@($parts.ToArray()) -join "`r`n"))

    if($proc.ExitCode -eq 0){
      if(Test-Path -LiteralPath $resolvedWs -PathType Container){
        $txtWs.Text = $resolvedWs
      }
    }
  }
  catch{
    Set-Output $txtOut ("GENERATE_SYNTHETIC_EXCEPTION`r`n" + $_.Exception.Message)
  }
})

$btnOpenLedger.Add_Click({
  try{
    $resolvedWs = Resolve-WorkspacePath $RepoRoot $txtWs.Text
    if([string]::IsNullOrWhiteSpace($resolvedWs)){ throw "WORKSPACE_PATH_EMPTY" }
    $ledger = Join-Path $resolvedWs "ledger.ndjson"
    if(-not (Test-Path -LiteralPath $ledger -PathType Leaf)){
      throw ("LEDGER_MISSING: " + $ledger)
    }
    Start-Process notepad.exe -ArgumentList ('"{0}"' -f $ledger) | Out-Null
  }
  catch{
    Set-Output $txtOut ("OPEN_LEDGER_EXCEPTION`r`n" + $_.Exception.Message)
  }
})

$btnClear.Add_Click({
  $txtOut.Text = ""
})

$form.Controls.Add($lblRepo)
$form.Controls.Add($txtRepo)
$form.Controls.Add($lblWs)
$form.Controls.Add($txtWs)
$form.Controls.Add($btnRun)
$form.Controls.Add($btnOpenWs)
$form.Controls.Add($btnGen)
$form.Controls.Add($btnOpenLedger)
$form.Controls.Add($btnClear)
$form.Controls.Add($lblOut)
$form.Controls.Add($txtOut)

[void]$form.ShowDialog()

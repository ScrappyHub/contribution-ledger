Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PhaseScript = Join-Path $RepoRoot "scripts\START_contributing_phase_v2.ps1"

if(-not (Test-Path -LiteralPath $PhaseScript -PathType Leaf)){
  Die ("MISSING_PHASE_SCRIPT: " + $PhaseScript)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Contribution Ledger Workbench"
$form.StartPosition = "CenterScreen"
$form.Width = 760
$form.Height = 520
$form.MinimumSize = New-Object System.Drawing.Size(760,520)

$lblRepo = New-Object System.Windows.Forms.Label
$lblRepo.Text = "Repo Root"
$lblRepo.Left = 20
$lblRepo.Top = 20
$lblRepo.Width = 100

$txtRepo = New-Object System.Windows.Forms.TextBox
$txtRepo.Left = 20
$txtRepo.Top = 42
$txtRepo.Width = 700
$txtRepo.ReadOnly = $true
$txtRepo.Text = $RepoRoot

$lblWs = New-Object System.Windows.Forms.Label
$lblWs.Text = "Workspace"
$lblWs.Left = 20
$lblWs.Top = 80
$lblWs.Width = 100

$txtWs = New-Object System.Windows.Forms.TextBox
$txtWs.Left = 20
$txtWs.Top = 102
$txtWs.Width = 700
$txtWs.Text = ".\workspaces\new_phase"

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run / Bootstrap Contribution Phase"
$btnRun.Left = 20
$btnRun.Top = 145
$btnRun.Width = 240
$btnRun.Height = 36

$btnOpenWs = New-Object System.Windows.Forms.Button
$btnOpenWs.Text = "Open Workspace Folder"
$btnOpenWs.Left = 275
$btnOpenWs.Top = 145
$btnOpenWs.Width = 170
$btnOpenWs.Height = 36

$btnOpenLedger = New-Object System.Windows.Forms.Button
$btnOpenLedger.Text = "Open Ledger"
$btnOpenLedger.Left = 460
$btnOpenLedger.Top = 145
$btnOpenLedger.Width = 120
$btnOpenLedger.Height = 36

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear Output"
$btnClear.Left = 595
$btnClear.Top = 145
$btnClear.Width = 125
$btnClear.Height = 36

$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text = "Output"
$lblOut.Left = 20
$lblOut.Top = 195
$lblOut.Width = 100

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Left = 20
$txtOut.Top = 217
$txtOut.Width = 700
$txtOut.Height = 230
$txtOut.Multiline = $true
$txtOut.ScrollBars = "Vertical"
$txtOut.ReadOnly = $true
$txtOut.Font = New-Object System.Drawing.Font("Consolas",10)

function Resolve-WorkspacePath([string]$Repo,[string]$WsText){
  if([string]::IsNullOrWhiteSpace($WsText)){ return $null }
  if([System.IO.Path]::IsPathRooted($WsText)){
    return $WsText
  }
  return (Join-Path $Repo $WsText)
}

function Set-Output([string]$Text){
  $txtOut.Text = $Text
  $txtOut.SelectionStart = $txtOut.TextLength
  $txtOut.ScrollToCaret()
}

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
    if($stdout.Length -gt 0){
      [void]$parts.Add($stdout.TrimEnd("`r","`n"))
    }
    [void]$parts.Add("")
    [void]$parts.Add("=== STDERR ===")
    if($stderr.Length -gt 0){
      [void]$parts.Add($stderr.TrimEnd("`r","`n"))
    }

    Set-Output ((@($parts.ToArray()) -join "`r`n"))

    if($proc.ExitCode -eq 0){
      $resolvedWs = Resolve-WorkspacePath $RepoRoot $wsText
      if($resolvedWs -and (Test-Path -LiteralPath $resolvedWs -PathType Container)){
        $txtWs.Text = $resolvedWs
      }
    }
  }
  catch{
    Set-Output ("UI_RUN_EXCEPTION`r`n" + $_.Exception.Message)
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
    Set-Output ("OPEN_WORKSPACE_EXCEPTION`r`n" + $_.Exception.Message)
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
    Set-Output ("OPEN_LEDGER_EXCEPTION`r`n" + $_.Exception.Message)
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
$form.Controls.Add($btnOpenLedger)
$form.Controls.Add($btnClear)
$form.Controls.Add($lblOut)
$form.Controls.Add($txtOut)

[void]$form.ShowDialog()
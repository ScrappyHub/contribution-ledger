Add-Type -AssemblyName System.Windows.Forms

$form = New-Object Windows.Forms.Form
$form.Text = "Contribution Ledger"
$form.Width = 500
$form.Height = 300

$btn = New-Object Windows.Forms.Button
$btn.Text = "Run Contribution Phase"
$btn.Width = 200
$btn.Height = 40
$btn.Top = 50
$btn.Left = 140

$output = New-Object Windows.Forms.TextBox
$output.Multiline = $true
$output.Width = 440
$output.Height = 120
$output.Top = 120
$output.Left = 20

$btn.Add_Click({
    $proc = Start-Process powershell `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File .\scripts\START_contributing_phase_v1.ps1 -RepoRoot ." `
        -NoNewWindow -PassThru -Wait -RedirectStandardOutput "out.txt"

    $output.Text = Get-Content "out.txt" -Raw
})

$form.Controls.Add($btn)
$form.Controls.Add($output)

$form.ShowDialog()
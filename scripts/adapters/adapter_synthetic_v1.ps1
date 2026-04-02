param(
  [Parameter(Mandatory=$true)][string]$OutPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }

function EnsureDir([string]$Path){
  if([string]::IsNullOrWhiteSpace($Path)){ Die "ENSUREDIR_EMPTY_PATH" }
  if(-not (Test-Path -LiteralPath $Path -PathType Container)){
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  if([string]::IsNullOrWhiteSpace($Path)){ Die "WRITE_EMPTY_PATH" }
  $dir = Split-Path -Parent $Path
  if($dir){ EnsureDir $dir }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}

$lines = @(
  '{"schema":"contrib.receipt.v1","receipt_hash":"synthetic_r1","event_type":"watchtower.verify","units":1}'
  '{"schema":"contrib.receipt.v1","receipt_hash":"synthetic_r2","event_type":"device.uptime","units":60}'
)

WriteUtf8NoBomLf $OutPath (@($lines) -join "`n")

Write-Host ("ADAPTER_SYNTHETIC_OK: " + $OutPath) -ForegroundColor Green
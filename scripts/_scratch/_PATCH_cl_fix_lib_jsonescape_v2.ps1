param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "EMPTY_PATH" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir){ EnsureDir $dir }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}
function ParseGate([string]$Path){
  $t=$null; $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and @($e).Count -gt 0){ $x=$e[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message) }
}

$Scripts = Join-Path $RepoRoot "scripts"
$TV = Join-Path $RepoRoot "test_vectors\minimal_valid"
$InDir = Join-Path $TV "inputs"
$Gold = Join-Path $TV "golden"
EnsureDir $Scripts; EnsureDir $TV; EnsureDir $InDir; EnsureDir $Gold

$LibPath   = Join-Path $Scripts "_lib_contribution_ledger_v1.ps1"
$BuildPath = Join-Path $Scripts "build_contribution_ledger_v1.ps1"
$VerifyPath= Join-Path $Scripts "verify_contribution_ledger_v1.ps1"
$SelfPath  = Join-Path $Scripts "_SELFTEST_contribution_ledger_v1.ps1"

$Lib = New-Object System.Collections.Generic.List[string]
[void]$Lib.Add('param()')
[void]$Lib.Add('$ErrorActionPreference="Stop"')
[void]$Lib.Add('Set-StrictMode -Version Latest')
[void]$Lib.Add('function CL-Die([string]$m){ throw $m }')
[void]$Lib.Add('function CL-EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ CL-Die "EMPTY_PATH" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }')
[void]$Lib.Add('function CL-WriteUtf8NoBomLf([string]$Path,[string]$Text){ $dir=Split-Path -Parent $Path; if($dir){ CL-EnsureDir $dir }; $t=$Text.Replace("`r`n","`n").Replace("`r","`n"); if(-not $t.EndsWith("`n")){ $t += "`n" }; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$t,$enc) }')
[void]$Lib.Add('function CL-BytesUtf8NoBomLf([string]$Text){ $t=$Text.Replace("`r`n","`n").Replace("`r","`n"); if(-not $t.EndsWith("`n")){ $t += "`n" }; $enc=New-Object System.Text.UTF8Encoding($false); return $enc.GetBytes($t) }')
[void]$Lib.Add('function CL-Sha256HexBytes([byte[]]$b){ $sha=[System.Security.Cryptography.SHA256]::Create(); try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }; return ([BitConverter]::ToString($h).Replace("-","").ToLowerInvariant()) }')
[void]$Lib.Add('function CL-Sha256HexFile([string]$Path){ return (CL-Sha256HexBytes ([System.IO.File]::ReadAllBytes($Path))) }')
[void]$Lib.Add('function CL-JsonEscape([string]$s){')
[void]$Lib.Add('  if($null -eq $s){ return "" }')
[void]$Lib.Add('  $sb = New-Object System.Text.StringBuilder')
[void]$Lib.Add('  foreach($ch in $s.ToCharArray()){')
[void]$Lib.Add('    $c = [int][char]$ch')
[void]$Lib.Add('    if($c -eq 34){ [void]$sb.Append([char]92); [void]$sb.Append([char]34) }' )
[void]$Lib.Add('    elseif($c -eq 92){ [void]$sb.Append([char]92); [void]$sb.Append([char]92) }' )
[void]$Lib.Add('    elseif($c -eq 8){  [void]$sb.Append([char]92); [void]$sb.Append("b") }' )
[void]$Lib.Add('    elseif($c -eq 9){  [void]$sb.Append([char]92); [void]$sb.Append("t") }' )
[void]$Lib.Add('    elseif($c -eq 10){ [void]$sb.Append([char]92); [void]$sb.Append("n") }' )
[void]$Lib.Add('    elseif($c -eq 12){ [void]$sb.Append([char]92); [void]$sb.Append("f") }' )
[void]$Lib.Add('    elseif($c -eq 13){ [void]$sb.Append([char]92); [void]$sb.Append("r") }' )
[void]$Lib.Add('    elseif($c -lt 32){ [void]$sb.Append([char]92); [void]$sb.Append("u"); [void]$sb.Append(($c.ToString("x4"))) }' )
[void]$Lib.Add('    else { [void]$sb.Append($ch) }')
[void]$Lib.Add('  }')
[void]$Lib.Add('  return $sb.ToString()')
[void]$Lib.Add('}')
[void]$Lib.Add('function CL-ToCanonJson($v){')
[void]$Lib.Add('  if($null -eq $v){ return "null" }')
[void]$Lib.Add('  if($v -is [bool]){ return ($(if($v){"true"}else{"false"})) }')
[void]$Lib.Add('  if($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]){ return ([string]$v) }')
[void]$Lib.Add('  if($v -is [string]){ return ([char]34 + (CL-JsonEscape $v) + [char]34) }')
[void]$Lib.Add('  if($v -is [System.Collections.IDictionary]){ $keys=@($v.Keys | ForEach-Object { [string]$_ } | Sort-Object); $pairs=New-Object System.Collections.Generic.List[string]; foreach($k in @($keys)){ [void]$pairs.Add(([char]34 + (CL-JsonEscape $k) + [char]34 + ":" + (CL-ToCanonJson $v[$k]))) }; return ("{" + (@($pairs.ToArray()) -join ",") + "}") }')
[void]$Lib.Add('  if($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])){ $items=New-Object System.Collections.Generic.List[string]; foreach($x in @($v)){ [void]$items.Add((CL-ToCanonJson $x)) }; return ("[" + (@($items.ToArray()) -join ",") + "]") }')
[void]$Lib.Add('  $props=@($v.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" -or $_.MemberType -eq "Property" }); $d=@{}; foreach($p in @($props)){ $d[$p.Name]=$p.Value }; return (CL-ToCanonJson $d)')
[void]$Lib.Add('}')
[void]$Lib.Add('function CL-CanonJsonBytes($obj){ return (CL-BytesUtf8NoBomLf (CL-ToCanonJson $obj)) }')
[void]$Lib.Add('function CL-EventRef([string]$ReceiptHash,[string]$RuleHash,[string]$EventType,[int]$Units){ $s=("receipt="+$ReceiptHash+"|rule="+$RuleHash+"|type="+$EventType+"|units="+$Units); return (CL-Sha256HexBytes (CL-BytesUtf8NoBomLf $s)) }')
[void]$Lib.Add('function CL-ReadLinesUtf8([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return @() }; $enc=New-Object System.Text.UTF8Encoding($false); $txt=[System.IO.File]::ReadAllText($Path,$enc); $t=$txt.Replace("`r`n","`n").Replace("`r","`n"); $lines=@($t -split "`n"); $out=New-Object System.Collections.Generic.List[string]; foreach($ln in @($lines)){ if($ln -ne $null -and $ln.Trim().Length -gt 0){ [void]$out.Add($ln) } }; return @($out.ToArray()) }')
[void]$Lib.Add('function CL-AppendNdjsonUniqueByEventRef([string]$LedgerPath,[string[]]$NewLines){ $existing=CL-ReadLinesUtf8 $LedgerPath; $seen=@{}; foreach($ln in @($existing)){ try{ $o=$ln | ConvertFrom-Json -ErrorAction Stop } catch { continue }; if($o -ne $null -and ($o.PSObject.Properties.Name -contains "event_ref")){ $seen[[string]$o.event_ref]=$true } }; $toAdd=New-Object System.Collections.Generic.List[string]; foreach($ln in @($NewLines)){ $o=$ln | ConvertFrom-Json -ErrorAction Stop; $er=[string]$o.event_ref; if(-not $seen.ContainsKey($er)){ $seen[$er]=$true; [void]$toAdd.Add($ln) } }; if(@($toAdd.ToArray()).Count -gt 0){ $txt=((@($toAdd.ToArray()) -join "`n") + "`n"); $enc=New-Object System.Text.UTF8Encoding($false); $dir=Split-Path -Parent $LedgerPath; if($dir){ CL-EnsureDir $dir }; [System.IO.File]::AppendAllText($LedgerPath,$txt,$enc) }; return @($toAdd.ToArray()) }')

$LibText = (@($Lib.ToArray()) -join "`n") + "`n"
WriteUtf8NoBomLf $LibPath $LibText
Write-Host ("WROTE: " + $LibPath) -ForegroundColor Green
ParseGate $LibPath
Write-Host "PARSE_OK: lib" -ForegroundColor Green

# Re-run original apply flow by calling the existing build/verify/selftest writers if present;
# For v2: just signal lib fixed; you will rerun APPLY to generate the rest cleanly.
Write-Host "PATCH_V2_OK: lib generator fixed; now rerun APPLY file" -ForegroundColor Green

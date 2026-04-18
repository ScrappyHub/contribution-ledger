param()
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function CL-Die([string]$m){ throw $m }
function CL-EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ CL-Die "EMPTY_PATH" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function CL-WriteUtf8NoBomLf([string]$Path,[string]$Text){ $dir=Split-Path -Parent $Path; if($dir){ CL-EnsureDir $dir }; $t=$Text.Replace("`r`n","`n").Replace("`r","`n"); if(-not $t.EndsWith("`n")){ $t += "`n" }; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$t,$enc) }
function CL-BytesUtf8NoBomLf([string]$Text){ $t=$Text.Replace("`r`n","`n").Replace("`r","`n"); if(-not $t.EndsWith("`n")){ $t += "`n" }; $enc=New-Object System.Text.UTF8Encoding($false); return $enc.GetBytes($t) }
function CL-Sha256HexBytes([byte[]]$b){ $sha=[System.Security.Cryptography.SHA256]::Create(); try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }; return ([BitConverter]::ToString($h).Replace("-","").ToLowerInvariant()) }
function CL-Sha256HexFile([string]$Path){ return (CL-Sha256HexBytes ([System.IO.File]::ReadAllBytes($Path))) }
function CL-JsonEscape([string]$s){
  if($null -eq $s){ return "" }
  $sb = New-Object System.Text.StringBuilder
  foreach($ch in $s.ToCharArray()){
    $c = [int][char]$ch
    if($c -eq 34){ [void]$sb.Append([char]92); [void]$sb.Append([char]34) }
    elseif($c -eq 92){ [void]$sb.Append([char]92); [void]$sb.Append([char]92) }
    elseif($c -eq 8){  [void]$sb.Append([char]92); [void]$sb.Append("b") }
    elseif($c -eq 9){  [void]$sb.Append([char]92); [void]$sb.Append("t") }
    elseif($c -eq 10){ [void]$sb.Append([char]92); [void]$sb.Append("n") }
    elseif($c -eq 12){ [void]$sb.Append([char]92); [void]$sb.Append("f") }
    elseif($c -eq 13){ [void]$sb.Append([char]92); [void]$sb.Append("r") }
    elseif($c -lt 32){ [void]$sb.Append([char]92); [void]$sb.Append("u"); [void]$sb.Append(($c.ToString("x4"))) }
    else { [void]$sb.Append($ch) }
  }
  return $sb.ToString()
}
function CL-ToCanonJson($v){
  if($null -eq $v){ return "null" }
  if($v -is [bool]){ return ($(if($v){"true"}else{"false"})) }
  if($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]){ return ([string]$v) }
  if($v -is [string]){ return ([char]34 + (CL-JsonEscape $v) + [char]34) }
  if($v -is [System.Collections.IDictionary]){
    $keys = @($v.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach($k in @($keys)){ [void]$pairs.Add(([char]34 + (CL-JsonEscape $k) + [char]34 + ":" + (CL-ToCanonJson $v[$k]))) }
    return ("{" + (@($pairs.ToArray()) -join ",") + "}")
  }
  if($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])){
    $items = New-Object System.Collections.Generic.List[string]
    foreach($x in @($v)){ [void]$items.Add((CL-ToCanonJson $x)) }
    return ("[" + (@($items.ToArray()) -join ",") + "]")
  }
  $props=@($v.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" -or $_.MemberType -eq "Property" })
  $d=@{}; foreach($p in @($props)){ $d[$p.Name]=$p.Value }
  return (CL-ToCanonJson $d)
}
function CL-CanonJsonBytes($obj){ return (CL-BytesUtf8NoBomLf (CL-ToCanonJson $obj)) }
function CL-EventRef([string]$ReceiptHash,[string]$RuleHash,[string]$EventType,[int]$Units){ $s=("receipt="+$ReceiptHash+"|rule="+$RuleHash+"|type="+$EventType+"|units="+$Units); return (CL-Sha256HexBytes (CL-BytesUtf8NoBomLf $s)) }
function CL-ReadLinesUtf8([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return @() }; $enc=New-Object System.Text.UTF8Encoding($false); $txt=[System.IO.File]::ReadAllText($Path,$enc); $t=$txt.Replace("`r`n","`n").Replace("`r","`n"); $lines=@($t -split "`n"); $out=New-Object System.Collections.Generic.List[string]; foreach($ln in @($lines)){ if($ln -ne $null -and $ln.Trim().Length -gt 0){ [void]$out.Add($ln) } }; return @($out.ToArray()) }
function CL-AppendNdjsonUniqueByEventRef([string]$LedgerPath,[string[]]$NewLines){ $existing=CL-ReadLinesUtf8 $LedgerPath; $seen=@{}; foreach($ln in @($existing)){ try{ $o=$ln | ConvertFrom-Json -ErrorAction Stop } catch { continue }; if($o -ne $null -and ($o.PSObject.Properties.Name -contains "event_ref")){ $seen[[string]$o.event_ref]=$true } }; $toAdd=New-Object System.Collections.Generic.List[string]; foreach($ln in @($NewLines)){ $o=$ln | ConvertFrom-Json -ErrorAction Stop; $er=[string]$o.event_ref; if(-not $seen.ContainsKey($er)){ $seen[$er]=$true; [void]$toAdd.Add($ln) } }; if(@($toAdd.ToArray()).Count -gt 0){ $txt=((@($toAdd.ToArray()) -join "`n") + "`n"); $enc=New-Object System.Text.UTF8Encoding($false); $dir=Split-Path -Parent $LedgerPath; if($dir){ CL-EnsureDir $dir }; [System.IO.File]::AppendAllText($LedgerPath,$txt,$enc) }; return @($toAdd.ToArray()) }

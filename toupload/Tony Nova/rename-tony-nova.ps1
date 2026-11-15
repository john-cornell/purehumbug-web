param(
    [string]$Parent = "C:\Code\purehumbug-web\toupload\Tony Nova",
    [string]$RemoteBase = "/u48851151/purehumbug/ovhlinks/Tony Nova",
    [string]$Password = "YOURPASSWORD",
    [switch]$Remote,
    [switch]$DryRun
)

if ($Remote -and $Password -eq "YOURPASSWORD") { Write-Host "Pass -Password when using -Remote"; exit 1 }

$map = @{ jan=1; feb=2; mar=3; apr=4; may=5; jun=6; jul=7; aug=8; sep=9; oct=10; nov=11; dec=12 }
$dateRe    = '(?i)^(?<m>(jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|jun(e)?|jul(y)?|aug(ust)?|sep(t(ember)?)?|oct(ober)?|nov(ember)?|dec(ember)?))[_ ,](?<d>\d{1,2})[_ ,](?<y>\d{4})(?<rest>.*)$'
$dateNoYr  = '(?i)^(?<m>(jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|jun(e)?|jul(y)?|aug(ust)?|sep(t(ember)?)?|oct(ober)?|nov(ember)?|dec(ember)?))[_ ,](?<d>\d{1,2})(?<rest>[_ ,](?!_?\d{4}).*|\..+)?$'

$done = 0; $skipped = 0
$remoteCmds = @()
$problems = @()

Get-ChildItem -LiteralPath $Parent -Directory | Sort-Object Name | ForEach-Object {
    $yf = $_
    $fyr = if ($yf.Name -match '(\d{4})$') { [int]$Matches[1] } else { 0 }
    Get-ChildItem -LiteralPath $yf.FullName -Recurse -File | Sort-Object Name | ForEach-Object {
        $f = $_
        if ($f.Name -match '^\d{8}') { $skipped++; return }
        $m = [regex]::Match($f.Name, $dateRe)
        if (-not $m.Success) {
            $m = [regex]::Match($f.Name, $dateNoYr)
            if ($m.Success) {
                Write-Host ("{0}\{1}" -f $yf.Name, $f.Name)
                Write-Host "  (no year in filename - using folder year $fyr)"
            }
        }
        if (-not $m.Success) { $problems += "NO DATE:  $($yf.Name)\$($f.Name)"; return }
        $mon = $map[$m.Groups['m'].Value.Substring(0,3).ToLower()]
        if (-not $mon) { $problems += "BAD MONTH:  $($yf.Name)\$($f.Name)"; return }
        $yr = if ($m.Groups['y'].Success) { [int]$m.Groups['y'].Value } else { $fyr }
        if (-not $yr) { $problems += "NO YEAR:  $($yf.Name)\$($f.Name)"; return }
        $new = '{0:d2}{1:d2}{2:d4}{3}' -f [int]$m.Groups['d'].Value, $mon, $yr, $m.Groups['rest'].Value
        $rel = $f.FullName.Substring($yf.FullName.Length + 1)
        $newRel = $rel.Substring(0, $rel.Length - $f.Name.Length) + $new
        if (Test-Path -LiteralPath (Join-Path $f.DirectoryName $new)) { $problems += "COLLISION:  $($yf.Name)\$($f.Name) -> $new"; return }
        Write-Host ("{0}\{1}" -f $yf.Name, $f.Name)
        Write-Host ("  -> {0}" -f $new)
        if (-not $DryRun) {
            try {
                Rename-Item -LiteralPath $f.FullName -NewName $new -ErrorAction Stop
                $done++
                $remoteCmds += "mv `"$RemoteBase/$($yf.Name)/$rel`" `"$RemoteBase/$($yf.Name)/$newRel`""
            } catch {
                $problems += "RENAME FAILED:  $($yf.Name)\$($f.Name)  ($($_.Exception.Message))"
            }
        } else {
            $remoteCmds += "mv `"$RemoteBase/$($yf.Name)/$rel`" `"$RemoteBase/$($yf.Name)/$newRel`""
        }
    }
}

Write-Host ""
if (-not $DryRun) { Write-Host "Renamed locally: $done   Already prefixed: $skipped" }
else              { Write-Host "Dry run. Would rename: $($remoteCmds.Count)   Already prefixed: $skipped" }
if ($problems.Count) { Write-Host ""; Write-Host "PROBLEMS:"; $problems | ForEach-Object { Write-Host "  $_" } }

if ($Remote) {
    Write-Host ""
    Write-Host "Renaming $($remoteCmds.Count) files on IONOS..."
    $cmds = @("open ftps://u48851151:$Password@home240859957.1and1-data.host/",
              "option batch continue") + $remoteCmds + @("exit")
    $cmds | Set-Content -Encoding UTF8 "$env:TEMP\opencode\winscp-rename.txt"
    & "C:\Program Files (x86)\WinSCP\WinSCP.com" /script="$env:TEMP\opencode\winscp-rename.txt" /ini=nul
}

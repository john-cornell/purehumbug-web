param(
    [string]$Parent = "C:\Code\purehumbug-web\toupload\Tony Nova",
    [string]$Dest = "/u48851151/purehumbug/ovhlinks/Tony Nova",
    [string]$Password = "YOURPASSWORD"
)

if ($Password -eq "YOURPASSWORD") { Write-Host "Edit the script or pass -Password"; exit 1 }

$winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com"
$site = "ftps://u48851151:$Password@home240859957.1and1-data.host/"

# one WinSCP session, one put per top-level folder
$cmds = @(
    "open $site",
    "option batch continue",
    "cd `"$Dest`""
)
Get-ChildItem -LiteralPath $Parent -Directory | ForEach-Object {
    $cmds += "put -resume `"$($_.FullName)\*`" `"$Dest/$($_.Name)/`""
}
$cmds += "exit"

$cmds | Set-Content -Encoding Ascii "$env:TEMP\opencode\winscp-cmds.txt"
& $winscp /script="$env:TEMP\opencode\winscp-cmds.txt" /ini=nul

# Tony Nova site builder - surveys IONOS, generates tony-nova/index.html + tony-nova.xml
# Spec: TONY-NOVA-SPEC.md. Run from repo root. Regenerate + redeploy when files change.

$ErrorActionPreference = 'Stop'
$ionosHost   = '74.208.236.107'          # IONOS web cluster (FTP host is different)
$ionosHname  = 'purehumbug.com'          # Host header that routes to this webspace
$ionosRoot   = '/ovhlinks/Tony%20Nova'   # URL path, relative to webspace root
$siteBase    = 'https://purehumbug.com/tony-nova'
$repo        = Split-Path -Parent $PSScriptRoot

function Fetch-Ionos([string]$path) {
    $url = "http://$ionosHost$ionosRoot$path"
    $html = (curl.exe -s -m 30 -H "Host: $ionosHname" $url) -join "`n"
    if (-not $html) { throw "empty response from $url" }
    if ($html -match 'Error 404') { throw "IONOS 404 (returns 200 w/ error page): $url" }
    return $html
}

# IIS autoindex entry: date, size (or <dir>), <A HREF="url">name</A>
$entryRe = '(?s)<A HREF="(?<href>[^"]+)">(?<name>[^<]+)</A>'

# --- 1. survey ---
$years = @()
$rootHtml = Fetch-Ionos '/'
foreach ($m in [regex]::Matches($rootHtml, $entryRe)) {
    if ($m.Groups['href'].Value -match '/TONY%20MARTIN%20(\d{4})/$') {
        $years += [pscustomobject]@{ Year = [int]$Matches[1]; Href = $m.Groups['href'].Value }
    }
}
$years = $years | Sort-Object Year
if (-not $years) { throw "no TONY MARTIN <year> folders found on IONOS" }

$files = @()
foreach ($y in $years) {
    $html = Fetch-Ionos ($y.Href.Substring($ionosRoot.Length))
    foreach ($m in [regex]::Matches($html, $entryRe)) {
        $href = $m.Groups['href'].Value
        $name = $m.Groups['name'].Value
        if ($name -match '\.mp3$') {
            # size: the number on the same listing line (IIS puts date + size before the link)
            # note: the HREF is url-encoded (spaces -> %20) while the link text is not
            $linePat = [regex]::Escape($name.Replace(' ', '%20'))
            $sz = 0
            if ($html -match "\d{1,2}/\d{1,2}/\d{4}[^<]*?(\d{6,})\s*<A HREF=""[^""]*$linePat""") { $sz = [long]$Matches[1] }
            $files += [pscustomobject]@{ Year = $y.Year; Name = $name; Href = $href; Size = $sz }
        }
    }
}
if ($files.Count -eq 0) { throw "no mp3 files found" }
Write-Host "Surveyed $($years.Count) years, $($files.Count) files, $([math]::Round(($files | Measure-Object Size -Sum).Sum/1GB,2)) GB"

# --- 2. helpers: filename -> date + display title ---
$mons = 'January February March April May June July August September October November December'.Split(' ')
function Get-Episode([string]$name, [int]$year) {
    # DDMMYYYY prefix (243/245 files); two undated bonus files fall back to "Bonus"
    $d = 0; $mo = 0; $yr = 0; $rest = ''
    if ($name -match '^(\d{2})(\d{2})(\d{4})(.*)\.mp3$') {
        $d = [int]$Matches[1]; $mo = [int]$Matches[2]; $yr = [int]$Matches[3]; $rest = $Matches[4]
    } else {
        return [pscustomobject]@{ Date = $null; Title = ('Bonus - ' + (Clean-Title ($name -replace '\.mp3$',''))); Rest = $null }
    }
    if ($mo -lt 1 -or $mo -gt 12 -or $d -lt 1 -or $d -gt 31) { throw "bad date in $name" }
    $clean = Clean-Title $rest
    $title = '{0} {1} {2}' -f $d, $mons[$mo-1], $yr
    if ($clean) { $title = "$title - $clean" }
    return [pscustomobject]@{ Date = Get-Date -Year $yr -Month $mo -Day $d; Title = $title; Rest = $clean }
}
function Clean-Title([string]$s) {
    $t = $s -replace '^[-_ ]+',''
    if (-not $t) { return '' }
    $t = $t -replace '(?i)(?<=\w)_s_', "'s "                                    # It_s, Deano_s
    $t = $t -replace '(?i)\b(Don|Can|Won|Isn|Aren|Wasn|Doesn|Didn|Shouldn|Wouldn|Couldn|Hasn|Haven)_t_', ('$1' + [char]39 + 't ')
    $t = $t -replace '(?i)\b(We|You|They|It)_re_', ('$1' + [char]39 + 're ')
    $t = $t -replace '(?i)\b(You|We|They)_ve_',  ('$1' + [char]39 + 've ')
    $t = $t -replace '(?i)\b(I|It|You|We|They|There)_ll_', ('$1' + [char]39 + 'll ')
    $t = $t -replace '(?i)\b(I|You|They|He|She|Who)_d_', ('$1' + [char]39 + 'd ')
    $t = $t -replace '(?i)\bI_m_', "I'm "
    $t = $t -replace '__',' - '               # BEST_OF_2018__Get_Browny__A_Tony_Martin_Production
    $t = $t -replace '_',' '
    $t = $t -replace '\s{2,}',' '
    $t = $t -replace '\s*_?\d{4,6}$',''       # strip trailing Nova episode ID
    return $t.Trim(' -')
}
function Html-Esc([string]$s) {
    return [System.Net.WebUtility]::HtmlEncode($s)
}

# --- 3. listing page ---
function Public-Url([pscustomobject]$f) {
    # public path through the nginx proxy: /tony-nova/<year>/<filename>
    return "$siteBase/$($f.Year)/$([uri]::EscapeDataString($f.Name))"
}
$sb = New-Object System.Text.StringBuilder
foreach ($y in $years) {
    [void]$sb.AppendLine('    <h2>' + $y.Year + '</h2>')
    [void]$sb.AppendLine('    <ul>')
    $yAll = $files | Where-Object Year -eq $y.Year
    $yf = @($yAll | Where-Object { (Get-Episode $_.Name $_.Year).Date -ne $null } |
            Sort-Object { (Get-Episode $_.Name $_.Year).Date })
    $yf += @($yAll | Where-Object { (Get-Episode $_.Name $_.Year).Date -eq $null } | Sort-Object Name)
    foreach ($f in $yf) {
        $ep = Get-Episode $f.Name $y.Year
        $mb = if ($f.Size) { [math]::Round($f.Size / 1MB, 1).ToString() + ' MB' } else { '' }
        $line = '<a href="' + (Public-Url $f) + '">' + (Html-Esc $ep.Title) + '</a>'
        if ($mb) { $line += ' <span class="size">' + $mb + '</span>' }
        [void]$sb.AppendLine('        <li>' + $line + '</li>')
    }
    [void]$sb.AppendLine('    </ul>')
}
$listing = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tony on Nova FM 2016-2022 - Pure Humbug</title>
<style>
  body { margin: 0; background: #eef0f3; color: #1d2733;
         font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
  .card { max-width: 780px; margin: 24px auto 40px; padding: 22px 26px;
          background: #fff; border: 1px solid #dfe3e8; border-radius: 10px;
          line-height: 1.55; }
  h1 { margin: 0 0 4px; font-size: 28px; letter-spacing: 1px;
       font-family: "Courier New", Courier, monospace; }
  h2 { font-size: 20px; border-bottom: 1px solid #dfe3e8; padding-bottom: 6px; }
  ul { padding-left: 1.2em; }
  li { margin: 0.45em 0; }
  a { color: #0a328c; text-decoration: none; border-bottom: 1px dotted #0a328c; }
  a:hover { text-decoration: underline; border-bottom: none; }
  .credit { color: #5a6a7a; font-style: italic; }
  .size { color: #5a6a7a; font-size: 13px; }
  .home a { font-size: 14px; color: #5a6a7a; }
</style>
</head>
<body>
  <div class="card">
    <div class="home"><a href="/">Back to the front page</a></div>
    <h1>Tony on Nova FM 2016-2022</h1>
    <p class="credit">Tony Martin's Nova podcasts with Chrissie, Sam &amp; Browny.
       <b>Thanks Stephanie Cairns for the uploads!</b></p>
    <p>Click any episode to stream or download it (or right-click / long-press to save).
       These are also available as a <a href="https://purehumbug.com/podcasts/">podcast feed</a>.</p>
$($sb.ToString())
    <p class="credit">Episodes are dated by filename (DDMMYYYY prefix) so they stay in chronological order.
       Two bonus episodes couldn't be dated and are listed at the end of their year.</p>
  </div>
</body>
</html>
"@
$dir = Join-Path $repo 'tony-nova'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $dir 'index.html'), $listing, [System.Text.UTF8Encoding]::new($false))

# --- 4. podcast feed (newest first, undated bonus items last) ---
$feedItems = @()
$dated   = @($files | Where-Object { (Get-Episode $_.Name $_.Year).Date -ne $null } |
             Sort-Object { (Get-Episode $_.Name $_.Year).Date } -Descending)
$undated = @($files | Where-Object { (Get-Episode $_.Name $_.Year).Date -eq $null } | Sort-Object Name)
foreach ($f in ($dated + $undated)) {
    $ep = Get-Episode $f.Name $f.Year
    $url = Public-Url $f
    $guid = $url                                                       # never change once published (see spec)
    $pub = if ($ep.Date) { $ep.Date.ToString('ddd, dd MMM yyyy') + ' 12:00:00 +0000' }
           else { 'Sun, 15 Nov 2026 12:00:00 +0000' }
    $t = Html-Esc $ep.Title
    $feedItems += @"
    <item>
      <title>$t</title>
      <description>$t</description>
      <enclosure url="$url" length="$($f.Size)" type="audio/mpeg"/>
      <guid>$guid</guid>
      <pubDate>$pub</pubDate>
    </item>
"@
}
$feed = @"
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Tony on Nova FM 2016-2022</title>
    <link>https://purehumbug.com/tony-nova/</link>
    <description>Tony Martin's Nova podcasts with Chrissie, Sam &amp; Browny (2016-2022). Archive of the now unavailable show, thanks to Stephanie Cairns.</description>
    <language>en-au</language>
    <itunes:author>Tony Martin</itunes:author>
    <itunes:explicit>false</itunes:explicit>
    <itunes:category text="Comedy"/>
    <itunes:image href="https://purehumbug.com/images/3goonsS.png"/>
    <itunes:block>Yes</itunes:block>
$(($feedItems -join "`n"))
  </channel>
</rss>
"@
[System.IO.File]::WriteAllText((Join-Path $repo 'tony-nova.xml'), $feed, [System.Text.UTF8Encoding]::new($false))

# --- 5. playlist manifest (root-relative paths, one per line; chronological, bonus last) ---
$manDir = Join-Path $repo 'playlists\manifests'
New-Item -ItemType Directory -Force -Path $manDir | Out-Null
$chron = @($files | Where-Object { (Get-Episode $_.Name $_.Year).Date -ne $null } |
           Sort-Object { (Get-Episode $_.Name $_.Year).Date }) +
         @($files | Where-Object { (Get-Episode $_.Name $_.Year).Date -eq $null } | Sort-Object Name)
$manifest = ($chron | ForEach-Object { "tony-nova/$($_.Year)/$($_.Name)" }) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $manDir 'Tony on Nova.txt'), $manifest + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Host "Wrote tony-nova/index.html ($($files.Count) links), tony-nova.xml ($($feedItems.Count) items), playlists/manifests/Tony on Nova.txt ($($chron.Count) tracks)"

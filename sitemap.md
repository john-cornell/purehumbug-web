# Pure Humbug — Site Map

All sites and services hosted on this VPS (`15.204.120.81`, nginx on ports 80/443, routed by `server_name`).

## Pure Humbug
- **URL:** https://purehumbug.com (also purehumbug.monkeyskin.au, www.purehumbug.com)
- **Type:** static archive (no backend), nginx autoindex for directory listings
- **Files:** /var/www/purehumbug (this web root)
- **Podcast feeds:** https://purehumbug.com/feed.xml (Get This, 358 episodes), https://purehumbug.com/martin-molloy.xml (Martin/Molloy, 156 episodes)
- **Code:** https://github.com/john-cornell/purehumbug-web

## Other sites on this box

| Site | URL | Type | Backend port | Files |
|---|---|---|---|---|
| clipt | https://clipt.monkeyskin.au | app (nginx proxy) | 127.0.0.1:8100 | clipt-sync-server |
| holdem | https://holdem.monkeyskin.au | static | none | /var/www/holdem |
| monkeybarrel | https://monkeybarrel.monkeyskin.au | app (nginx proxy + static dist) | 127.0.0.1:3001 | /srv/monkeybarrel/apps/web/dist |
| tax receipts | https://tax.monkeyskin.au | app (nginx proxy) | 127.0.0.1:5080 | taxreceipts |
| underpressure | https://underpressure.monkeyskin.au | app (nginx proxy) | underpressure_backend (docker/localhost) | — |
| wordbridge | https://wordbridge.monkeyskin.au | app (nginx proxy) | 127.0.0.1:8000 | wordbridge |

## DNS
- `*.monkeyskin.au` → A records at Instra (nameservers ui-dns/IONOS) → 15.204.120.81
- `purehumbug.com` + `www` → A records at IONOS → 15.204.120.81

## Deploy
- Pure Humbug: `C:\Code\purehumbug-web\deploy.ps1` (scp index.html, playlists, favicon, feeds) or `git pull` + `scp`
- Other sites: check their own project repos/scripts (clipt, tax, etc. have their own deploy flows)

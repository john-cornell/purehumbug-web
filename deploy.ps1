# Pure Humbug site deploy: copy local web files to the VPS
scp C:\Code\purehumbug-web\index.html ubuntu@15.204.120.81:/var/www/purehumbug/index.html
scp C:\Code\purehumbug-web\playlists\index.html ubuntu@15.204.120.81:/var/www/purehumbug/playlists/index.html
scp C:\Code\purehumbug-web\favicon.png ubuntu@15.204.120.81:/var/www/purehumbug/favicon.png
scp C:\Code\purehumbug-web\feed.xml ubuntu@15.204.120.81:/var/www/purehumbug/feed.xml
scp C:\Code\purehumbug-web\martin-molloy.xml ubuntu@15.204.120.81:/var/www/purehumbug/martin-molloy.xml
Write-Host "deployed"

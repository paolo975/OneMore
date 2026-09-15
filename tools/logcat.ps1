param([int]$Seconds = 25)
# Cattura il log del telefono collegato via USB (debug USB attivo) mentre il gioco gira,
# tenendo solo le righe che servono a capire un crash: Godot, AdMob, e la traccia dell'errore.
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $env:LOCALAPPDATA 'AncoraUnoTools\Android\platform-tools\adb.exe'
if (!(Test-Path -LiteralPath $adb)) { throw 'adb non trovato. Vedi README.md.' }
$outPath = Join-Path $projectPath 'artifacts\logcat.txt'
New-Item -ItemType Directory -Force (Join-Path $projectPath 'artifacts') | Out-Null
$devices = & $adb devices | Select-String -Pattern '\tdevice$'
if (-not $devices) { throw 'Nessun telefono collegato o debug USB non autorizzato: guarda lo schermo del telefono.' }
& $adb logcat -c
& $adb shell am force-stop com.neomobile.onemore
& $adb shell monkey -p com.neomobile.onemore -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Output "Gioco avviato, registro $Seconds secondi di log..."
Start-Sleep -Seconds $Seconds
& $adb logcat -d -v time | Select-String -Pattern 'godot|Godot|AdMob|Ads|PoingGodot|FATAL|AndroidRuntime|DEBUG   |signal |backtrace|ancorauno' | ForEach-Object { $_.Line } | Set-Content -LiteralPath $outPath -Encoding utf8
Write-Output "Salvato in $outPath ($((Get-Content -LiteralPath $outPath | Measure-Object -Line).Lines) righe). Le righe FATAL/AndroidRuntime sono il punto del crash."

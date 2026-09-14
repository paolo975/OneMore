$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$godotPath = Join-Path $env:LOCALAPPDATA 'AncoraUnoTools\Godot\Godot_v4.6-stable_win64.exe'
if (!(Test-Path -LiteralPath $godotPath)) { throw 'Godot non trovato. Vedi README.md.' }
$logPath = Join-Path $projectPath 'artifacts\store.log'
New-Item -ItemType Directory -Force (Join-Path $projectPath 'artifacts') | Out-Null
# Windowed on purpose: the headless renderer cannot read a viewport back. "--test" keeps the game silent.
$launchArgs = '--path "' + $projectPath + '" --script res://tools/store_assets.gd --log-file "' + $logPath + '" -- --test'
$process = Start-Process -FilePath $godotPath -ArgumentList $launchArgs -Wait -PassThru
Get-Content -LiteralPath $logPath | Select-String -Pattern 'scritto|ERROR|Impossibile'
if ($process.ExitCode -ne 0) { throw "Generazione fallita: $($process.ExitCode)" }
# The new icon is a fresh resource: import it so the editor and the export see it.
$importArgs = '--headless --path "' + $projectPath + '" --import'
Start-Process -FilePath $godotPath -ArgumentList $importArgs -WindowStyle Hidden -Wait | Out-Null
$count = (Get-ChildItem (Join-Path $projectPath 'artifacts\store') -Recurse -File -Filter *.png | Measure-Object).Count
Write-Output "$count immagini in artifacts\store"

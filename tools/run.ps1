param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$godotPath = Join-Path $env:LOCALAPPDATA 'AncoraUnoTools\Godot\Godot_v4.6-stable_win64.exe'
if (!(Test-Path -LiteralPath $godotPath)) { throw 'Godot non trovato. Vedi README.md.' }
$launchArgs = '--path "' + $projectPath + '"'
if ($Editor) { $launchArgs += ' --editor' }
Start-Process -FilePath $godotPath -ArgumentList $launchArgs

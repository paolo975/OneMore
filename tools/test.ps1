$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$godotPath = Join-Path $env:LOCALAPPDATA 'AncoraUnoTools\Godot\Godot_v4.6-stable_win64.exe'
$logPath = Join-Path $projectPath 'artifacts\tests.log'
# The AdMob addon registers global classes; --script alone does not rebuild that cache.
$importArgs = '--headless --path "' + $projectPath + '" --import'
Start-Process -FilePath $godotPath -ArgumentList $importArgs -WindowStyle Hidden -Wait | Out-Null
$launchArgs = '--headless --path "' + $projectPath + '" --script res://tests/game_test.gd --log-file "' + $logPath + '" -- --test'
$process = Start-Process -FilePath $godotPath -ArgumentList $launchArgs -WindowStyle Hidden -Wait -PassThru
Get-Content -LiteralPath $logPath
if ($process.ExitCode -ne 0) { throw "Test falliti: $($process.ExitCode)" }

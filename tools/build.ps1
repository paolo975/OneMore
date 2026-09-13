param([ValidateSet('Android','Windows','All')][string]$Target = 'All')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$toolRoot = Join-Path $env:LOCALAPPDATA 'AncoraUnoTools'
$godotPath = Join-Path $toolRoot 'Godot\Godot_v4.6-stable_win64.exe'
$env:JAVA_HOME = (Get-ChildItem (Join-Path $toolRoot 'Java') -Directory | Select-Object -First 1).FullName
$targets = if ($Target -eq 'All') { @('Android','Windows') } else { @($Target) }
New-Item -ItemType Directory -Force (Join-Path $projectPath 'artifacts') | Out-Null
# The AdMob 5.x aars require compileSdk 36; the Godot 4.6 template ships 35 and is regenerated
# by "Install Android Build Template", so patch it every time, idempotently.
$configGradle = Join-Path $projectPath 'android\build\config.gradle'
$gradleProps = Join-Path $projectPath 'android\build\gradle.properties'
if (Test-Path -LiteralPath $configGradle) {
    $noBom = New-Object System.Text.UTF8Encoding($false)
    $cfg = [System.IO.File]::ReadAllText($configGradle)
    $patched = [regex]::Replace($cfg, '(?m)^(\s*compileSdk\s*:\s*)35,', '${1}36,')
    if ($patched -ne $cfg) { [System.IO.File]::WriteAllText($configGradle, $patched, $noBom) }
    $props = [System.IO.File]::ReadAllText($gradleProps)
    if ($props -notmatch 'suppressUnsupportedCompileSdk') {
        [System.IO.File]::WriteAllText($gradleProps, $props + "`nandroid.suppressUnsupportedCompileSdk=36`n", $noBom)
    }
}
foreach ($buildTarget in $targets) {
    $logPath = Join-Path $projectPath ('artifacts\export-' + $buildTarget.ToLower() + '.log')
    $launchArgs = '--headless --path "' + $projectPath + '" --export-debug ' + $buildTarget + ' --log-file "' + $logPath + '"'
    $process = Start-Process -FilePath $godotPath -ArgumentList $launchArgs -WindowStyle Hidden -Wait -PassThru
    Get-Content -LiteralPath $logPath -Tail 8
    if ($process.ExitCode -ne 0) { throw "Export $buildTarget fallito; vedi $logPath" }
}

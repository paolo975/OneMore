param([ValidateSet('Android','Windows','Bundle','All')][string]$Target = 'All', [switch]$Release)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
# Bundle is the AAB Play wants; the APK stays for testing on a phone. A debug bundle would carry
# the Google test ad ids under a file named "release", so refuse it rather than hand it to Play.
if ($Target -eq 'Bundle' -and !$Release) { throw "Il bundle per Play va firmato: usa -Target Bundle -Release." }
if ($Release) {
    # Release signing: keystore/ is outside Git; Godot reads these variables when the preset's
    # keystore fields are empty, so the password never enters export_presets.cfg.
    $propsPath = Join-Path $projectPath 'keystore\release.properties'
    if (!(Test-Path -LiteralPath $propsPath)) { throw "Manca $propsPath (vedi README.md)." }
    $keystore = @{}
    foreach ($line in Get-Content -LiteralPath $propsPath) {
        if ($line -match '^\s*([^=#]+?)\s*=\s*(.*?)\s*$') { $keystore[$Matches[1]] = $Matches[2] }
    }
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = Join-Path $projectPath $keystore['path']
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $keystore['alias']
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $keystore['password']
}
$toolRoot = Join-Path $env:LOCALAPPDATA 'AncoraUnoTools'
$godotPath = Join-Path $toolRoot 'Godot\Godot_v4.6-stable_win64.exe'
$env:JAVA_HOME = (Get-ChildItem (Join-Path $toolRoot 'Java') -Directory | Select-Object -First 1).FullName
# "All" stays the everyday pair; the bundle is only ever built on purpose, for a Play upload.
$targets = if ($Target -eq 'All') { @('Android','Windows') } else { @($Target) }
$presetOf = @{ 'Android' = 'Android'; 'Windows' = 'Windows'; 'Bundle' = 'Android AAB' }
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
    $mode = if ($Release) { '--export-release' } else { '--export-debug' }
    # The Android preset's export_path is the debug APK; a release build gets its own file next to
    # it. The bundle preset already points at the .aab, so it needs no override.
    $outArg = if ($Release -and $buildTarget -eq 'Android') { ' "' + (Join-Path $projectPath 'artifacts\AncoraUno-release.apk') + '"' } else { '' }
    $launchArgs = '--headless --path "' + $projectPath + '" ' + $mode + ' "' + $presetOf[$buildTarget] + '"' + $outArg + ' --log-file "' + $logPath + '"'
    # Not -Wait: that also waits for every descendant, and the Gradle daemon Godot spawns
    # outlives the export by hours. WaitForExit returns as soon as Godot itself is done.
    $process = Start-Process -FilePath $godotPath -ArgumentList $launchArgs -WindowStyle Hidden -PassThru
    $process.WaitForExit()
    Get-Content -LiteralPath $logPath -Tail 8
    if ($process.ExitCode -ne 0) { throw "Export $buildTarget fallito; vedi $logPath" }
}

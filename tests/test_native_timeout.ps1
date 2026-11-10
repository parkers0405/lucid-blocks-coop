param([Parameter(Mandatory)][string] $Godot)
$ErrorActionPreference = 'Stop'
$fixture = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../work/native-timeout-check'))
[IO.Directory]::CreateDirectory($fixture) | Out-Null
$source = Get-Content (Join-Path $PSScriptRoot 'native_collision.gd') -Raw
$body = [regex]::Match($source, '(?ms)^func _abort_incomplete_load\(\) -> void:.*\z').Value
if (-not $body) { throw 'Native abort function missing.' }
[IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), '[application]')
[IO.File]::WriteAllText((Join-Path $fixture 'check.gd'), "extends SceneTree`nfunc _initialize() -> void:`n    _abort_incomplete_load()`n    print(`"NATIVE_ABORT_RETURNED`")`n    quit(1)`n" + $body)
$savedProfile = $env:APPDATA
try {
    $env:APPDATA = Join-Path $fixture 'profile'
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    $stdout = Join-Path $fixture 'stdout.log'
    $stderr = Join-Path $fixture 'stderr.log'
    $job = Start-Process -FilePath (Resolve-Path $Godot).Path -ArgumentList @('--headless', '--path', ('"' + $fixture + '"'), '--script', 'res://check.gd') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $job.WaitForExit(12000)) { $job.Kill(); $job.WaitForExit(); throw 'Native abort test timed out.' }
    $lines = (Get-Content $stdout -Raw) + (Get-Content $stderr -Raw)
    # Windows OS.kill(self) exits zero; prove termination by the unreachable marker instead.
    if ($lines -notmatch 'terminating disposable process' -or $lines -match 'NATIVE_ABORT_RETURNED|SCRIPT ERROR:|ERROR:') { throw "Native abort test failed: $lines" }
    'NATIVE_TIMEOUT_CHECK_OK'
} finally { $env:APPDATA = $savedProfile }

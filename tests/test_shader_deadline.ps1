param([Parameter(Mandatory)][string] $Godot)
$ErrorActionPreference = 'Stop'
$fixture = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../work/shader-deadline-check'))
[IO.Directory]::CreateDirectory($fixture) | Out-Null
$launcher = Get-Content (Join-Path $PSScriptRoot '../scripts/build_raw_mod.ps1') -Raw
$body = [regex]::Match($launcher, '(?ms)^func _shader_wait_deadline\(\) -> void:\r?\n.*?(?=^func )').Value
if (-not $body) { throw 'Production deadline function missing.' }
[IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), '[application]')
[IO.File]::WriteAllText((Join-Path $fixture 'probe.gd'), "extends Node`nvar shader_isolation_done: bool = false`n" + $body)
@'
extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var probe = load("res://probe.gd").new()
    root.add_child(probe)
    probe.shader_isolation_done = "complete" in OS.get_cmdline_user_args()
    probe._shader_wait_deadline()
    if probe.shader_isolation_done:
        quit(0)
'@ | Set-Content (Join-Path $fixture 'check.gd') -Encoding UTF8
$savedProfile = $env:APPDATA
try {
    $env:APPDATA = Join-Path $fixture 'profile'
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    foreach ($state in @('missing', 'complete')) {
        $stdout = Join-Path $fixture "$state.stdout.log"
        $stderr = Join-Path $fixture "$state.stderr.log"
        $job = Start-Process -FilePath (Resolve-Path $Godot).Path -ArgumentList @('--headless', '--path', ('"' + $fixture + '"'), '--script', 'res://check.gd', '--', $state) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if (-not $job.WaitForExit(12000)) { $job.Kill(); $job.WaitForExit(); throw "Deadline selfcheck $state timed out." }
        $lines = (Get-Content $stdout -Raw) + (Get-Content $stderr -Raw)
        $expected = if ($state -eq 'missing') { 1 } else { 0 }
        if ($job.ExitCode -ne $expected -or $lines -match 'SCRIPT ERROR:|ERROR:|Parse Error' -or (($lines -match 'COOP_BUILD_CHECK_FAILED shader completion deadline') -ne ($state -eq 'missing'))) { throw "Deadline selfcheck $state failed: $lines" }
    }
    'SHADER_DEADLINE_CHECKS_OK 2'
} finally { $env:APPDATA = $savedProfile }

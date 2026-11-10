$ErrorActionPreference = 'Stop'
$builder = Join-Path $PSScriptRoot '../scripts/build_mod.ps1'
foreach ($testSwitch in @('CombatTests', 'RegionTests', 'AdmissionTests')) {
    $arguments = @{ Godot = 'missing-editor'; $testSwitch = $true }
    $rejected = $false
    try { & $builder @arguments } catch {
        if ($_.Exception.Message -ne 'Runtime test switches require both Gdre and GameExe.') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw "$testSwitch silently skipped." }
}
'BUILD_SWITCH_CHECKS_OK 3'

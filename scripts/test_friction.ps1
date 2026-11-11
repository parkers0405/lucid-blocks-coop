[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ModPack,
    [string] $BatchId = (Get-Date -Format 'yyyyMMdd-HHmmss'),
    # scenario:profile:disk cells; every cell runs -Repeats times, plus one solo baseline set per scenario.
    [string[]] $Cells = @('mine_tunnel:clean:fast', 'mine_tunnel:typical:slow', 'shared_loot:clean:fast', 'handoff_motion:clean:fast', 'handoff_motion:typical:slow'),
    [int] $Repeats = 3,
    [switch] $SkipControls,
    [int] $Blocks = 20
)
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '../work/friction'
$batch = [IO.Path]::GetFullPath((Join-Path $root $BatchId))
$runs = Join-Path $batch 'runs'
[IO.Directory]::CreateDirectory($runs) | Out-Null
$driver = Join-Path $PSScriptRoot 'test_local_coop.ps1'
$log = Join-Path $batch 'batch.log'
function Invoke-Run([hashtable] $Arguments) {
    $started = Get-Date
    $output = & $driver -ModPack $ModPack -RunRoot $runs -Blocks $Blocks @Arguments 2>&1 | Out-String
    "[{0:s}] {1} ({2:N0}s)`n{3}" -f $started, ($Arguments.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ', ((Get-Date) - $started).TotalSeconds, ($output -split "`n" | Select-Object -Last 3 | Out-String) | Add-Content -LiteralPath $log
}
$scenarios = $Cells | ForEach-Object { ($_ -split ':')[0] } | Select-Object -Unique
if (-not $SkipControls) {
    foreach ($control in @('original', 'offline')) { Invoke-Run @{ WorldControl = $control } }
}
foreach ($scenario in $scenarios) {
    for ($i = 0; $i -lt $Repeats; $i++) { Invoke-Run @{ Scenario = $scenario; Solo = $true; TimeoutSeconds = 400 } }
}
foreach ($cell in $Cells) {
    $scenario, $profile, $disk = $cell -split ':'
    for ($i = 0; $i -lt $Repeats; $i++) { Invoke-Run @{ Scenario = $scenario; Profile = $profile; Disk = $disk; TimeoutSeconds = 600 } }
}
& (Join-Path $PSScriptRoot '../tests/lan/summarize.ps1') -Batch $runs

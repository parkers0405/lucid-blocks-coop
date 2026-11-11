[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ModPack,
    [string] $BatchId = (Get-Date -Format 'yyyyMMdd-HHmmss'),
    # scenario:profile:disk[:killpoint] cells; every cell runs -Repeats times, plus one solo baseline set per scenario.
    [string[]] $Cells = @('mine_tunnel:clean:fast', 'mine_tunnel:typical:slow', 'shared_loot:clean:fast', 'handoff_motion:clean:fast', 'handoff_motion:typical:slow'),
    [int] $Repeats = 3,
    [switch] $SkipControls,
    [switch] $SkipSolo,
    [int] $Blocks = 20,
    [int] $Trips = 1,
    # Hard cap for the whole batch; remaining cells are listed as not run.
    [int] $MaxMinutes = 120
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
    $output = try { & $driver -ModPack $ModPack -RunRoot $runs -Blocks $Blocks -Trips $Trips @Arguments 2>&1 | Out-String } catch { "DRIVER_EXCEPTION $_" }
    $label = ($Arguments.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
    $tail = ($output -split "`n" | Select-Object -Last 4) -join "`n"
    Add-Content -LiteralPath $log -Value ("[{0:s}] {1} ({2:N0}s)`n{3}" -f $started, $label, ((Get-Date) - $started).TotalSeconds, $tail)
}
$batchEnd = (Get-Date).AddMinutes($MaxMinutes)
$notRun = [Collections.Generic.List[string]]::new()
function Stop-Strays { Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'local-coop-godot.exe' -or ($_.Name -like 'godot*.exe' -and $_.CommandLine -match 'udp_relay\.gd') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } }
Stop-Strays
$scenarios = $Cells | ForEach-Object { ($_ -split ':')[0] } | Select-Object -Unique
if (-not $SkipControls) {
    foreach ($control in @('original', 'offline')) { foreach ($enters in @(2, 3)) { Invoke-Run @{ WorldControl = $control; ControlEnters = $enters } } }
}
foreach ($scenario in $(if ($SkipSolo) { @() } else { $scenarios })) {
    for ($i = 0; $i -lt $Repeats; $i++) { Invoke-Run @{ Scenario = $scenario; Solo = $true; TimeoutSeconds = 400 } }
}
try {
    foreach ($cell in $Cells) {
        $scenario, $profile, $disk, $kill = $cell -split ':'
        for ($i = 0; $i -lt $Repeats; $i++) {
            if ((Get-Date) -ge $batchEnd) { $notRun.Add("$cell #$($i + 1)"); continue }
            $arguments = @{ Scenario = $scenario; Profile = $profile; Disk = $disk; TimeoutSeconds = 600 }
            if ($kill) { $arguments.KillGuestAt = $kill }
            Invoke-Run $arguments
        }
    }
}
finally { Stop-Strays }
if ($notRun.Count) { Add-Content -LiteralPath $log -Value ("NOT RUN (batch time cap): " + ($notRun -join ', ')) }
& (Join-Path $PSScriptRoot '../tests/lan/summarize.ps1') -Batch $runs

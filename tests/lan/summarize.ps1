[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Batch,      # folder holding run folders (each has config.json, <role>_telemetry.jsonl, run-summary.json)
    [string] $Pck = '',                          # release PCK to audit for G8
    [int] $RequiredRepeats = 3
)
$ErrorActionPreference = 'Stop'
$LoadingFlags = @('reconnect_pending', 'client_restore_in_progress', 'receiving_host_world')
$HandoffFlags = @('lease_preparing', 'lease_frozen')

function Get-Percentile([double[]] $Values, [double] $P) {
    if ($Values.Count -eq 0) { return $null }
    $sorted = $Values | Sort-Object
    $sorted[[Math]::Min($sorted.Count - 1, [Math]::Max(0, [int][Math]::Ceiling($P * $sorted.Count) - 1))]
}
function Get-Runs([int[]] $Times, [bool[]] $Flags) {
    # Durations in ms of contiguous true runs (end timestamp is the first false frame).
    $runs = @(); $start = -1
    for ($i = 0; $i -lt $Flags.Count; $i++) {
        if ($Flags[$i] -and $start -lt 0) { $start = $Times[$i] }
        if (-not $Flags[$i] -and $start -ge 0) { $runs += ($Times[$i] - $start); $start = -1 }
    }
    if ($start -ge 0) { $runs += ($Times[-1] - $start) }
    , $runs
}
function Normalize-Error([string] $Line) {
    ($Line -replace '0x[0-9a-fA-F]+', '0xN' -replace '\d+', 'N' -replace '\s+', ' ').Trim()
}

$rows = @()
foreach ($dir in Get-ChildItem -LiteralPath $Batch -Directory) {
    $configPath = Join-Path $dir.FullName 'config.json'
    if (-not (Test-Path $configPath)) { continue }
    $config = Get-Content -Raw $configPath | ConvertFrom-Json
    $summaryPath = Join-Path $dir.FullName 'run-summary.json'
    $summary = if (Test-Path $summaryPath) { Get-Content -Raw $summaryPath | ConvertFrom-Json } else { $null }
    foreach ($role in @('host', 'guest', 'solo')) {
        $telemetryPath = Join-Path $dir.FullName "${role}_telemetry.jsonl"
        if (-not (Test-Path $telemetryPath)) { continue }
        $frames = @(); $events = @()
        foreach ($line in [IO.File]::ReadLines($telemetryPath)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json
            if ($obj.PSObject.Properties.Name -contains 'ev') { $events += $obj } else { $frames += $obj }
        }
        $start = ($events | Where-Object ev -eq 'scenario_start' | Select-Object -First 1).t
        $done = $events | Where-Object ev -eq 'scenario_done' | Select-Object -First 1
        $win = @($frames | Where-Object { $_.t -ge $start -and (-not $done -or $_.t -le $done.t) })
        $times = [int[]]@($win | ForEach-Object { $_.t })
        $flagsOf = { param($f) @(([string]$f.f) -split ',' | Where-Object { $_ }) }
        $handoffLock = [bool[]]@($win | ForEach-Object { $_.lk -eq 1 -and (& $flagsOf $_ | Where-Object { $_ -in $HandoffFlags }) })
        $loading = [bool[]]@($win | ForEach-Object { [bool](& $flagsOf $_ | Where-Object { $_ -in $LoadingFlags }) })
        $otherLock = [bool[]]@(for ($i = 0; $i -lt $win.Count; $i++) { $win[$i].lk -eq 1 -and -not $handoffLock[$i] -and -not $loading[$i] -and -not [bool](& $flagsOf $win[$i] | Where-Object { $_ -eq 'chest_lock_active' -and $win[$i].lk -eq 1 -and $false }) })
        $handoffRuns = Get-Runs $times $handoffLock
        $otherRuns = Get-Runs $times $otherLock
        $freezeFlags = [bool[]]@(for ($i = 0; $i -lt $win.Count; $i++) { ($win[$i].sim -eq 0 -or $win[$i].ent -eq 0) -and -not $loading[$i] })
        $freezeRuns = Get-Runs $times $freezeFlags
        $reconnectRuns = Get-Runs $times ([bool[]]@($win | ForEach-Object { [bool](& $flagsOf $_ | Where-Object { $_ -eq 'reconnect_pending' }) }))
        $ignored = @($win | Where-Object { $_.mi -eq 1 -and $_.mv -lt 0.001 -and ($_.dis -eq 1 -or $_.lk -eq 1) -and -not (& $flagsOf $_ | Where-Object { $_ -in $LoadingFlags }) }).Count
        $dts = [double[]]@($win | ForEach-Object { $_.dt / 1000.0 })
        $over50 = @($win | Where-Object { $_.dt -gt 50000 -and $_.ld -eq 0 -and -not (& $flagsOf $_ | Where-Object { $_ -in $LoadingFlags }) }).Count
        $pickups = $null
        $pickupPath = Join-Path $dir.FullName "${role}_pickups.json"
        if (Test-Path $pickupPath) { $pickups = Get-Content -Raw $pickupPath | ConvertFrom-Json }
        $windowMs = if ($times.Count -gt 1) { $times[-1] - $times[0] } else { 0 }
        $rows += [pscustomobject]@{
            run = $dir.Name; scenario = $config.scenario; profile = $(if ($config.solo) { 'solo' } else { $config.profile }); disk = $config.disk; role = $role
            elapsed_ms = $done.elapsed_ms; window_ms = $windowMs; frames = $win.Count
            handoff_lock_runs_ms = $handoffRuns; other_lock_ms = $otherRuns; lock_total_ms = (($handoffRuns | Measure-Object -Sum).Sum + ($otherRuns | Measure-Object -Sum).Sum)
            freeze_runs_ms = $freezeRuns; reconnects = $reconnectRuns.Count; movement_ignored_frames = $ignored
            break_resets = [int](($win | Measure-Object -Property rst -Sum).Sum)
            frame_p99_ms = (Get-Percentile $dts 0.99); frames_over_50ms = $over50
            pickup_p95_ms = $(if ($pickups -and $pickups.pickup_ms.Count) { Get-Percentile ([double[]]$pickups.pickup_ms) 0.95 } else { $null })
            items_delta = $(if ($pickups) { $pickups.items - $pickups.items0 } else { $null }); drops_left = $(if ($pickups) { $pickups.drops_left } else { $null })
            probe_ok = $(if ($summary -and $summary.$role) { [bool]$summary.$role.valid } else { $false })
            errors = $(if ($summary -and $summary.$role) { @($summary.$role.errors) } else { @() })
        }
    }
}

# Group repeats into cells and evaluate gates.
$netDelay = @{ clean = 0; typical = 60; bad = 150; spike = 60; cut = 0; solo = 0 }
$ioMs = @{ fast = 0; slow = 250; failing = 250 }
$cells = @()
foreach ($group in ($rows | Group-Object scenario, profile, disk, role)) {
    $r = @($group.Group)
    $first = $r[0]
    $repeatRuns = @($r | Select-Object -ExpandProperty run -Unique).Count
    $solo = @($rows | Where-Object { $_.profile -eq 'solo' -and $_.scenario -eq $first.scenario })
    $soloElapsed = if ($solo.Count) { ($solo | Measure-Object -Property elapsed_ms -Average).Average } else { $null }
    $soloP99 = if ($solo.Count) { ($solo | Measure-Object -Property frame_p99_ms -Average).Average } else { $null }
    $g = [ordered]@{}
    $allHandoff = @($r | ForEach-Object { $_.handoff_lock_runs_ms } | Where-Object { $_ -ne $null })
    $allOther = @($r | ForEach-Object { $_.other_lock_ms } | Where-Object { $_ -ne $null })
    $g.G3 = if (@($r | Where-Object { $_.movement_ignored_frames -gt 0 }).Count) { 'FAIL' } else { 'PASS' }
    $maxHandoff = ($allHandoff | Measure-Object -Maximum).Maximum
    $lockFraction = if (($r | Measure-Object -Property window_ms -Sum).Sum) { ($r | Measure-Object -Property lock_total_ms -Sum).Sum / ($r | Measure-Object -Property window_ms -Sum).Sum } else { 0 }
    $g.G4 = if (($maxHandoff -gt 150) -or ($allOther.Count -gt 0 -and ($allOther | Measure-Object -Maximum).Maximum -gt 0) -or ($lockFraction -gt 0.01) -or (@($r | Where-Object { $_.break_resets -gt 0 }).Count)) { 'FAIL' } else { 'PASS' }
    if ($first.profile -eq 'solo') { $g.G5 = 'baseline' }
    elseif ($null -eq $soloElapsed) { $g.G5 = 'BLOCKED (no solo baseline)' }
    else {
        $limit = if ($first.profile -eq 'bad') { 1.25 } else { 1.10 }
        $ratio = (($r | Measure-Object -Property elapsed_ms -Average).Average) / $soloElapsed
        $pick = @($r | Where-Object { $null -ne $_.pickup_p95_ms } | ForEach-Object { $_.pickup_p95_ms })
        $pickLimit = 2 * $netDelay[$first.profile] + $ioMs[$first.disk] + 150
        $frameBad = @($r | Where-Object { $_.frame_p99_ms -gt $soloP99 + 4 -or $_.frames_over_50ms -gt 0 }).Count
        $timeGate = if ($first.profile -in @('typical', 'bad')) { $ratio -le $limit } else { $true }
        $g.G5 = if ($timeGate -and ($pick.Count -eq 0 -or ($pick | Measure-Object -Maximum).Maximum -le $pickLimit) -and -not $frameBad) { 'PASS' } else { 'FAIL' }
        $g.G5_detail = 'time ratio {0:N2} (limit {1}), pickup p95 max {2} (limit {3}), frames>50ms {4}' -f $ratio, $limit, (($pick | Measure-Object -Maximum).Maximum), $pickLimit, (($r | Measure-Object -Property frames_over_50ms -Sum).Sum)
    }
    $freezeAll = [double[]]@($r | ForEach-Object { $_.freeze_runs_ms } | Where-Object { $_ -ne $null })
    $p95 = Get-Percentile $freezeAll 0.95
    $maxFreeze = ($freezeAll | Measure-Object -Maximum).Maximum
    $reconnects = ($r | Measure-Object -Property reconnects -Sum).Sum
    $g.G6 = if (($p95 -gt 500) -or ($maxFreeze -gt 1500) -or ($reconnects -gt 0 -and $first.profile -ne 'cut')) { 'FAIL (partial: handoff freeze only; portal/quit not measured here)' } else { 'PASS (partial: handoff freeze only; portal/quit not measured here)' }
    if ($first.scenario -eq 'shared_loot' -and $first.role -ne 'solo') { $g.G7 = 'see conservation' } else { $g.G7 = 'BLOCKED (no oracle for this scenario)' }
    $cells += [pscustomobject]@{
        scenario = $first.scenario; profile = $first.profile; disk = $first.disk; role = $first.role; repeats = $repeatRuns
        complete = ($repeatRuns -ge $RequiredRepeats); probe_ok = (-not @($r | Where-Object { -not $_.probe_ok }).Count)
        max_handoff_lock_ms = $maxHandoff; handoff_count = $allHandoff.Count; freeze_p95_ms = $p95; freeze_max_ms = $maxFreeze; lock_fraction = [Math]::Round($lockFraction, 4)
        elapsed_ms_avg = (($r | Measure-Object -Property elapsed_ms -Average).Average); movement_ignored = ($r | Measure-Object -Property movement_ignored_frames -Sum).Sum
        break_resets = ($r | Measure-Object -Property break_resets -Sum).Sum; gates = $g
    }
}

# Conservation for shared_loot: items gained by both players plus drops left equals the 30 spawned.
$conservation = @()
foreach ($run in ($rows | Where-Object scenario -eq 'shared_loot' | Group-Object run)) {
    $players = @($run.Group | Where-Object { $_.items_delta -ne $null })
    $drops = ($run.Group | Where-Object role -eq 'host' | Select-Object -First 1).drops_left
    $gained = ($players | Measure-Object -Property items_delta -Sum).Sum
    $conservation += [pscustomobject]@{ run = $run.Name; gained = $gained; drops_left_host = $drops; expected = 30; ok = ($gained + [int]$drops -eq 30) }
}

# G8 release purity.
$g8 = 'BLOCKED (no -Pck given)'
if ($Pck) {
    $text = [Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($Pck))
    $hits = @('friction', 'udp_relay', 'FaultQueue', 'local_coop', 'zz-local', 'world_startup', 'probe') | Where-Object { $text.Contains($_) }
    $g8 = if ($hits) { "FAIL ($($hits -join ', '))" } else { 'PASS (no harness, probe, relay or injection names in PCK; SHA256 ' + (Get-FileHash -LiteralPath $Pck -Algorithm SHA256).Hash + ')' }
}

# G9 native error categories versus controls (runs whose scenario is control-original / control-offline).
$errorCats = @{}
foreach ($dir in Get-ChildItem -LiteralPath $Batch -Directory) {
    $configPath = Join-Path $dir.FullName 'config.json'; $summaryPath = Join-Path $dir.FullName 'run-summary.json'
    if (-not (Test-Path $configPath) -or -not (Test-Path $summaryPath)) { continue }
    $config = Get-Content -Raw $configPath | ConvertFrom-Json
    $summary = Get-Content -Raw $summaryPath | ConvertFrom-Json
    $bucket = if ($config.control) { "control-$($config.control)" } else { 'mod' }
    foreach ($role in $summary.PSObject.Properties.Name) {
        foreach ($e in @($summary.$role.errors)) {
            $key = "$bucket|$(Normalize-Error $e)"
            $errorCats[$key] = 1 + $(if ($errorCats.ContainsKey($key)) { $errorCats[$key] } else { 0 })
        }
    }
}
$modScript = @($errorCats.Keys | Where-Object { $_ -like 'mod|*' -and $_ -match 'SCRIPT ERROR|Parse Error|Compile Error|unknown peer' })

$report = [ordered]@{ batch = $Batch; generated = (Get-Date).ToString('s'); cells = $cells; conservation = $conservation; G8 = $g8; G9_mod_script_errors = $modScript; G9_error_counts = $errorCats }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Batch 'friction-report.json') -Encoding UTF8
$md = @("# Friction report ($Batch)", '', '| scenario | profile | disk | role | repeats | max handoff lock ms | freeze p95/max ms | lock frac | resets | G3 | G4 | G5 | G6 | G7 |', '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
foreach ($c in $cells) {
    $md += "| $($c.scenario) | $($c.profile) | $($c.disk) | $($c.role) | $($c.repeats)$(if (-not $c.complete) { ' (INCOMPLETE)' }) | $($c.max_handoff_lock_ms) | $($c.freeze_p95_ms)/$($c.freeze_max_ms) | $($c.lock_fraction) | $($c.break_resets) | $($c.gates.G3) | $($c.gates.G4) | $($c.gates.G5) | $($c.gates.G6) | $($c.gates.G7) |"
}
$md += ''; $md += "G8: $g8"; $md += ''; $md += 'Conservation (shared_loot):'
foreach ($c in $conservation) { $md += "- $($c.run): gained $($c.gained) + drops left $($c.drops_left_host) vs expected $($c.expected): $(if ($c.ok) { 'PASS' } else { 'FAIL' })" }
$md += ''; $md += 'G9 error categories (normalised; mod = mod runs, control-* = controls):'
foreach ($k in ($errorCats.Keys | Sort-Object)) { $md += "- $k = $($errorCats[$k])" }
$md | Set-Content -LiteralPath (Join-Path $Batch 'friction-report.md') -Encoding UTF8
Write-Output "FRICTION_REPORT $(Join-Path $Batch 'friction-report.md')"

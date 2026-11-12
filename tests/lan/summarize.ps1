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
# H0/D2: pause of objects that change owner. An object is "simulated" while at least one process has it processing; a pause is a gap with
# none, between two processing spans, that did not end in a despawn. Works for any protocol (global freeze or per-object transit).
function Get-TransitPauses($NodeEvents, [double] $From, [double] $To) {
    $all = @()
    foreach ($role in $NodeEvents.Keys) { foreach ($e in $NodeEvents[$role]) { $all += [pscustomobject]@{ u = [double]$e.u; id = $e.id; role = $role; on = [int]$e.on } } }
    $pauses = @()
    foreach ($g in ($all | Group-Object id)) {
        $state = @{}; $zeroAt = $null; $had = $false
        foreach ($e in ($g.Group | Sort-Object u)) {
            $state[$e.role] = ($e.on -eq 1)
            $count = @($state.Values | Where-Object { $_ }).Count
            if ($count -gt 0) {
                if ($null -ne $zeroAt -and $e.u -ge $From -and $e.u -le $To) { $pauses += ($e.u - $zeroAt) }
                $zeroAt = $null; $had = $true
            }
            elseif ($had -and $null -eq $zeroAt -and $e.on -eq 0) { $zeroAt = $e.u }
            elseif ($e.on -eq -1) { $zeroAt = $null }
        }
    }
    , $pauses
}
function Normalize-Error([string] $Line) {
    ($Line -replace '0x[0-9a-fA-F]+', '0xN' -replace '\d+', 'N' -replace '\s+', ' ').Trim()
}

$rows = @()
foreach ($dir in Get-ChildItem -LiteralPath $Batch -Directory) {
    $nodeEvents = @{}; $uWin = @{}
    $firstRow = $rows.Count
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
        # Allowed G4 exception (logged): the open chest modal. A pickup lock (pickup_inventory_lock) is not an exception.
        $chestOpen = [bool[]]@($win | ForEach-Object { $f = & $flagsOf $_; ($f -contains 'chest_lock_active') -and -not ($f -contains 'pickup_inventory_lock') })
        $otherLock = [bool[]]@(for ($i = 0; $i -lt $win.Count; $i++) { $win[$i].lk -eq 1 -and -not $handoffLock[$i] -and -not $loading[$i] -and -not $chestOpen[$i] })
        $chestOpenFrames = @($chestOpen | Where-Object { $_ }).Count
        $handoffRuns = Get-Runs $times $handoffLock
        $otherRuns = Get-Runs $times $otherLock
        $freezeFlags = [bool[]]@(for ($i = 0; $i -lt $win.Count; $i++) { ($win[$i].sim -eq 0 -or $win[$i].ent -eq 0) -and -not $loading[$i] })
        $freezeRuns = Get-Runs $times $freezeFlags
        $editRuns = Get-Runs $times ([bool[]]@($win | ForEach-Object { $_.ed -gt 0 }))
        $nodeEvents[$role] = @($events | Where-Object ev -eq 'node')
        # Host: time from the SWITCH being sent (phase "switching") to the epoch change, per handoff that completed; rejected switches are counted.
        $switchMs = @(); $switchRejected = 0; $switchAt = $null; $idleAt = $null
        foreach ($e in @($events | Where-Object { $_.ev -in 'phase', 'epoch' })) {
            if ($null -ne $idleAt) {
                # The idle phase and the epoch change are logged in the same frame; an epoch event right after it means the switch completed.
                if ($e.ev -eq 'epoch' -and ($e.t - $idleAt) -le 50) { $switchMs += ($idleAt - $switchAt) } else { $switchRejected++ }
                $idleAt = $null; $switchAt = $null
            }
            if ($e.ev -eq 'phase' -and ([string]$e.p).StartsWith('switching')) { $switchAt = $e.t }
            elseif ($e.ev -eq 'phase' -and $null -ne $switchAt -and ([string]$e.p).StartsWith('|0')) { $idleAt = $e.t }
        }
        if ($start -ne $null -and $role -ne 'solo') { $uWin[$role] = @(($events | Where-Object ev -eq 'scenario_start' | Select-Object -First 1).u, $(if ($done) { $done.u } else { [double]::MaxValue })) }
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
            switch_ms = $switchMs; switch_rejected = $switchRejected; chest_modal_frames = $chestOpenFrames; freeze_runs_ms = $freezeRuns; edit_delay_runs_ms = $editRuns; reconnects = $reconnectRuns.Count; movement_ignored_frames = $ignored
            break_resets = [int](($win | Measure-Object -Property rst -Sum).Sum)
            frame_p99_ms = (Get-Percentile $dts 0.99); frames_over_50ms = $over50
            pickup_p95_ms = $(if ($pickups -and $pickups.pickup_ms.Count) { Get-Percentile ([double[]]$pickups.pickup_ms) 0.95 } else { $null })
            terrain_oracle = $(if ($pickups -and $pickups.terrain_oracle -and $pickups.terrain_oracle.host) { $pickups.terrain_oracle } else { $null })
            items_delta = $(if ($pickups) { $pickups.items - $pickups.items0 } else { $null }); drops_left = $(if ($pickups) { $pickups.drops_left } else { $null })
            probe_ok = $(if ($summary -and $summary.$role) { [bool]$summary.$role.valid } else { $false })
            errors = $(if ($summary -and $summary.$role) { @($summary.$role.errors) } else { @() })
        }
    }
    $pauses = @()
    if ($uWin.Count) { $pauses = Get-TransitPauses $nodeEvents (($uWin.Values | ForEach-Object { $_[0] } | Measure-Object -Minimum).Minimum) (($uWin.Values | ForEach-Object { $_[1] } | Measure-Object -Maximum).Maximum) }
    foreach ($row in @($rows | Select-Object -Skip $firstRow)) { $row | Add-Member -NotePropertyName transit_pause_ms -NotePropertyValue $pauses }
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
    $allHandoff = @($r | ForEach-Object { @($_.handoff_lock_runs_ms) + @($_.edit_delay_runs_ms) } | Where-Object { $_ -ne $null })
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
    # D2: the global freeze signal stays; the object-pause signal is added (union, so a protocol without a global freeze cannot read 0 by construction).
    $pauseOnly = [double[]]@($r | Select-Object -ExpandProperty run -Unique | ForEach-Object { $name = $_; ($r | Where-Object run -eq $name | Select-Object -First 1).transit_pause_ms } | Where-Object { $_ -ne $null })
    $oldOnly = [double[]]@($r | ForEach-Object { $_.freeze_runs_ms } | Where-Object { $_ -ne $null })
    $freezeAll = [double[]]@($oldOnly + $pauseOnly)
    $p95 = Get-Percentile $freezeAll 0.95
    $maxFreeze = ($freezeAll | Measure-Object -Maximum).Maximum
    $reconnects = ($r | Measure-Object -Property reconnects -Sum).Sum
    $g.G6 = if (($p95 -gt 500) -or ($maxFreeze -gt 1500) -or ($reconnects -gt 0 -and $first.profile -ne 'cut')) { 'FAIL (partial: handoff freeze only; portal/quit not measured here)' } else { 'PASS (partial: handoff freeze only; portal/quit not measured here)' }
    $oracleRows = @($r | Where-Object { $_.terrain_oracle -and ($_.terrain_oracle.host.expected + $_.terrain_oracle.guest.expected) -gt 0 })
    if ($first.scenario -eq 'shared_loot' -and $first.role -ne 'solo') { $g.G7 = 'see conservation' }
    elseif ($oracleRows.Count -gt 0) {
        $bad = @($oracleRows | Where-Object { $_.terrain_oracle.host.matched -ne $_.terrain_oracle.host.expected -or $_.terrain_oracle.guest.matched -ne $_.terrain_oracle.guest.expected -or -not $_.terrain_oracle.host.checked })
        $g.G7 = if ($bad.Count) { 'FAIL (terrain oracle: ' + (($bad | ForEach-Object { 'host ' + $_.terrain_oracle.host.matched + '/' + $_.terrain_oracle.host.expected + ' guest ' + $_.terrain_oracle.guest.matched + '/' + $_.terrain_oracle.guest.expected }) -join '; ') + ')' } else { 'PASS (terrain oracle on host disk, all repeats)' }
    }
    else { $g.G7 = 'BLOCKED (no oracle for this scenario)' }
    $cells += [pscustomobject]@{
        scenario = $first.scenario; profile = $first.profile; disk = $first.disk; role = $first.role; repeats = $repeatRuns
        complete = ($repeatRuns -ge $RequiredRepeats); probe_ok = (-not @($r | Where-Object { -not $_.probe_ok }).Count)
        max_handoff_lock_ms = $maxHandoff; handoff_count = $allHandoff.Count; freeze_p95_ms = $p95; freeze_max_ms = $maxFreeze; old_freeze_p95_ms = (Get-Percentile $oldOnly 0.95); old_freeze_max_ms = ($oldOnly | Measure-Object -Maximum).Maximum; pause_p95_ms = (Get-Percentile $pauseOnly 0.95); pause_max_ms = ($pauseOnly | Measure-Object -Maximum).Maximum; pause_count = $pauseOnly.Count; switch_p95_ms = (Get-Percentile ([double[]]@($r | ForEach-Object { $_.switch_ms } | Where-Object { $_ -ne $null })) 0.95); switch_max_ms = (@($r | ForEach-Object { $_.switch_ms } | Where-Object { $_ -ne $null }) | Measure-Object -Maximum).Maximum; switch_count = @($r | ForEach-Object { $_.switch_ms } | Where-Object { $_ -ne $null }).Count; switch_rejected = ($r | Measure-Object -Property switch_rejected -Sum).Sum; lock_fraction = [Math]::Round($lockFraction, 4)
        elapsed_ms_avg = (($r | Measure-Object -Property elapsed_ms -Average).Average); movement_ignored = ($r | Measure-Object -Property movement_ignored_frames -Sum).Sum
        break_resets = ($r | Measure-Object -Property break_resets -Sum).Sum; gates = $g
    }
}

# Conservation for shared_loot: items gained by both players plus drops left equals the 30 spawned.
$conservation = @()
foreach ($run in ($rows | Where-Object scenario -eq 'shared_loot' | Group-Object run)) {
    $players = @($run.Group | Where-Object { $_.items_delta -ne $null })
    $drops = ($run.Group | Where-Object { $_.role -in 'host', 'solo' } | Select-Object -First 1).drops_left
    $gained = ($players | Measure-Object -Property items_delta -Sum).Sum
    $conservation += [pscustomobject]@{ run = $run.Name; gained = $gained; drops_left_host = $drops; expected = 30; ok = ($gained + [int]$drops -eq 30) }
}

# G7 kill tests: the recovered guest's inventory (plus chest for chest kills) and the host's inventory and leftover drops must equal what was spawned/granted.
foreach ($dir in (Get-ChildItem -LiteralPath $Batch -Directory)) {
    $cfgPath = Join-Path $dir.FullName 'config.json'
    $recPath = Join-Path $dir.FullName 'guest_recovered.json'
    if (-not (Test-Path $cfgPath) -or -not (Test-Path $recPath)) { continue }
    $cfg = Get-Content -Raw $cfgPath | ConvertFrom-Json
    $rec = Get-Content -Raw $recPath | ConvertFrom-Json
    $hostPick = Join-Path $dir.FullName 'host_pickups.json'
    if (-not (Test-Path $hostPick)) { $conservation += [pscustomobject]@{ run = $dir.Name; kill = $cfg.kill_guest_at; ok = $false; note = 'host did not finish' }; continue }
    $h = Get-Content -Raw $hostPick | ConvertFrom-Json
    if ($cfg.kill_guest_at -eq 'chest') { $total = [int]$rec.items + [int]$rec.chest_items; $expected = 5 } else { $total = [int]$rec.items + [int]$h.items + [int]$h.drops_left; $expected = 30 }
    $conservation += [pscustomobject]@{ run = $dir.Name; kill = $cfg.kill_guest_at; gained = $total; expected = $expected; ok = ($total -eq $expected) }
}

# G8 release purity.
$g8 = 'BLOCKED (no -Pck given)'
if ($Pck) {
    $text = [Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($Pck))
    $hits = @('friction.gd', 'udp_relay', 'FaultQueue', 'local_coop', 'zz-local', 'world_startup', 'summarize.ps1', 'mods/local') | Where-Object { $text.Contains($_) }
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
$md = @("# Friction report ($Batch)", '', '| scenario | profile | disk | role | repeats | max handoff lock ms | freeze p95/max ms | old freeze p95/max | object pause p95/max (n) | switch p95/max (n, rejected) | lock frac | resets | G3 | G4 | G5 | G6 | G7 |', '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
foreach ($c in $cells) {
    $md += "| $($c.scenario) | $($c.profile) | $($c.disk) | $($c.role) | $($c.repeats)$(if (-not $c.complete) { ' (INCOMPLETE)' }) | $($c.max_handoff_lock_ms) | $($c.freeze_p95_ms)/$($c.freeze_max_ms) | $($c.old_freeze_p95_ms)/$($c.old_freeze_max_ms) | $($c.pause_p95_ms)/$($c.pause_max_ms) ($($c.pause_count)) | $($c.switch_p95_ms)/$($c.switch_max_ms) ($($c.switch_count), $($c.switch_rejected)) | $($c.lock_fraction) | $($c.break_resets) | $($c.gates.G3) | $($c.gates.G4) | $($c.gates.G5) | $($c.gates.G6) | $($c.gates.G7) |"
}
$md += ''; $md += "G8: $g8"; $md += ''; $md += 'Conservation (shared_loot):'
foreach ($c in $conservation) { $md += "- $($c.run)$(if ($c.kill) { ' kill=' + $c.kill }): total $($c.gained) (drops left $($c.drops_left_host)) vs expected $($c.expected): $(if ($c.ok) { 'PASS' } else { 'FAIL' })" }
$md += ''; $md += 'G9 error categories (normalised; mod = mod runs, control-* = controls):'
foreach ($k in ($errorCats.Keys | Sort-Object)) { $md += "- $k = $($errorCats[$k])" }
$md | Set-Content -LiteralPath (Join-Path $Batch 'friction-report.md') -Encoding UTF8
Write-Output "FRICTION_REPORT $(Join-Path $Batch 'friction-report.md')"

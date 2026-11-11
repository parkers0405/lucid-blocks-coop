[CmdletBinding()]
param(
    [string] $Godot = "$PSScriptRoot/../work/tools/godot.windows.editor.double.x86_64.exe",
    [string] $Gdre = "$PSScriptRoot/../work/tools/gdre-2.7.4/gdre_tools.exe",
    [string] $GameExe = 'C:/Program Files (x86)/Steam/steamapps/common/lucid-blocks/lucid-blocks.exe',
    [Parameter(Mandatory)][string] $ModPack,
    [ValidateSet('original', 'offline', 'host')][string] $WorldControl,
    # smoke = the original 19-assertion LAN fixture; anything else runs tests/lan/friction.gd with that scenario.
    [string] $Scenario = 'smoke',
    [ValidateSet('clean', 'typical', 'bad', 'spike', 'cut')][string] $Profile = 'clean',
    [ValidateSet('fast', 'slow', 'failing')][string] $Disk = 'fast',
    # One process with the mod and no peer (baseline).
    [switch] $Solo,
    [string] $RunRoot = "$PSScriptRoot/../work/friction/runs",
    [string] $KillGuestAt = '',
    [int] $TimeoutSeconds = 420,
    [int] $Blocks = 40,
    [switch] $Diag,
    [int] $ControlEnters = 1,
    [int] $Trips = 2
)
$ErrorActionPreference = 'Stop'
# Only one host+guest pair at a time: a named mutex held for the whole run; stray test processes from a killed runner are removed first.
$gate = [Threading.Mutex]::new($false, 'Global\lucid-blocks-coop-friction')
if (-not $gate.WaitOne(0)) { throw 'Another friction run is active; refusing to start a second pair.' }
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'local-coop-godot.exe' -or ($_.Name -like 'godot*.exe' -and $_.CommandLine -match 'udp_relay\.gd') } | ForEach-Object { Write-Output "LOCAL_COOP_STRAY_KILLED $($_.ProcessId) $($_.Name)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$game = (Resolve-Path -LiteralPath $GameExe).Path
$editor = (Resolve-Path -LiteralPath $Godot).Path
$gdreTool = (Resolve-Path -LiteralPath $Gdre).Path
$pack = (Resolve-Path -LiteralPath $ModPack).Path
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($game).FileVersion -ne '5.2.0.0') { throw 'Original game must be 5.2.0.0.' }
$run = [IO.Path]::GetFullPath((Join-Path $RunRoot ([guid]::NewGuid().ToString('N'))))
[IO.Directory]::CreateDirectory($run) | Out-Null
[IO.File]::WriteAllText((Join-Path $run '.local-coop-scenario'), 'disposable')
Write-Output "LOCAL_COOP_RUN $run"
$probe = Join-Path $run 'probe/mods/local_coop'
[IO.Directory]::CreateDirectory($probe) | Out-Null
$fixture = if ($WorldControl) { 'world_startup.gd' } elseif ($Scenario -eq 'smoke') { 'local_coop.gd' } else { 'friction.gd' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "../tests/lan/$fixture") -Destination (Join-Path $probe 'mod_init.gd')
$probePack = Join-Path $run 'zz-local-coop.pck'
$oldProfile = $env:APPDATA
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
try {
    foreach ($directory in @('tool-profile', 'tool-temp')) { [IO.Directory]::CreateDirectory((Join-Path $run $directory)) | Out-Null }
    $env:APPDATA = Join-Path $run 'tool-profile'
    $env:TEMP = Join-Path $run 'tool-temp'
    $env:TMP = $env:TEMP
    $packArguments = @(
        '--headless', ('"--pck-create=' + (Join-Path $run 'probe') + '"'),
        '--pck-version=2', '--pck-engine-version=4.6.0', ('"--output=' + $probePack + '"')
    )
    $packProcess = Start-Process -FilePath $gdreTool -ArgumentList $packArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'pack.stdout.log') -RedirectStandardError (Join-Path $run 'pack.stderr.log')
    if (-not $packProcess.WaitForExit(45000)) { $packProcess.Kill(); $packProcess.WaitForExit(); throw 'Fixture pack deadline.' }
}
finally {
    $env:APPDATA = $oldProfile
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
}
if ($packProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $probePack)) { throw "Fixture pack failed: $run" }
$port = Get-Random -Minimum 26000 -Maximum 45000
$relayPort = $port + 1
$roles = if ($WorldControl) { @($WorldControl) } elseif ($Solo) { @('solo') } else { @('host', 'guest') }
$processes = @{}
$useRelay = (-not $WorldControl) -and (-not $Solo) -and $Profile -ne 'clean'
[IO.File]::WriteAllText((Join-Path $run 'config.json'), (@{ scenario = $Scenario; disk = $Disk; profile = $Profile; solo = [bool]$Solo; host_port = $port; kill_guest_at = $KillGuestAt; control = [string]$WorldControl; control_enters = $ControlEnters; blocks = $Blocks; trips = $Trips; diag = [int][bool]$Diag } | ConvertTo-Json))
$relay = $null
$relayStop = Join-Path $run 'relay.stop'
try {
    if ($useRelay) {
        $relayInfo = [Diagnostics.ProcessStartInfo]::new()
        $relayInfo.FileName = $editor
        $relayInfo.WorkingDirectory = $run
        $relayInfo.UseShellExecute = $false
        $relayInfo.CreateNoWindow = $true
        $relayInfo.RedirectStandardOutput = $true
        $relayInfo.Environment['APPDATA'] = Join-Path $run 'tool-profile'
        $relayInfo.Environment['TEMP'] = Join-Path $run 'tool-temp'
        $relayInfo.Environment['TMP'] = $relayInfo.Environment['TEMP']
        $relayScript = (Resolve-Path (Join-Path $PSScriptRoot '../tests/lan/udp_relay.gd')).Path
        foreach ($argument in @('--headless', '--script', $relayScript, '--', "$relayPort", "$port", $Profile, '12345', (Join-Path $run 'relay.json'), $relayStop)) { $relayInfo.ArgumentList.Add($argument) }
        $relay = [Diagnostics.Process]::Start($relayInfo)
        $relayOut = $relay.StandardOutput.ReadToEndAsync()
        Start-Sleep -Milliseconds 1500
    }
    foreach ($role in $roles) {
        $runtime = Join-Path $run $role
        [IO.Directory]::CreateDirectory((Join-Path $runtime 'mods')) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $runtime 'profile')) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $runtime 'temp')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $runtime '.coop-test-runtime'), 'disposable')
        if ($WorldControl -ne 'original') {
            Copy-Item -LiteralPath $pack -Destination (Join-Path $runtime 'mods/lucid-blocks-coop.pck')
        }
        Copy-Item -LiteralPath $probePack -Destination (Join-Path $runtime 'mods/zz-local-coop.pck')
        $gameDirectory = Split-Path -Parent $game
        foreach ($library in @('libgdblocks.windows.template_release.double.x86_64.dll', 'libgodotsteam.windows.template_release.double.x86_64.dll', 'steam_api64.dll')) {
            Copy-Item -LiteralPath (Join-Path $gameDirectory $library) -Destination (Join-Path $runtime $library)
        }
        foreach ($entry in @(@('libgdblocks.windows.template_release.double.x86_64.dll', 'bin'), @('libgodotsteam.windows.template_release.double.x86_64.dll', 'addons/godotsteam/win64'))) {
            $folder = Join-Path $runtime $entry[1]
            [IO.Directory]::CreateDirectory($folder) | Out-Null
            Copy-Item -LiteralPath (Join-Path $runtime $entry[0]) -Destination (Join-Path $folder $entry[0])
            Copy-Item -LiteralPath (Join-Path $runtime $entry[0]) -Destination (Join-Path $folder $entry[0].Replace('template_release', 'template_debug'))
        }
        Copy-Item -LiteralPath (Join-Path $runtime 'steam_api64.dll') -Destination (Join-Path $runtime 'addons/godotsteam/win64/steam_api64.dll')
        $runtimeEditor = Join-Path $runtime 'local-coop-godot.exe'
        Copy-Item -LiteralPath $editor -Destination $runtimeEditor
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $runtimeEditor
        $info.WorkingDirectory = $runtime
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.Environment['APPDATA'] = Join-Path $runtime 'profile'
        $info.Environment['TEMP'] = Join-Path $runtime 'temp'
        $info.Environment['TMP'] = $info.Environment['TEMP']
        foreach ($argument in @('--headless', '--max-fps', '60', '--path', $runtime, '--main-pack', $game, '--', $role, $run, $(if ($role -eq 'guest' -and $useRelay) { "$relayPort" } else { "$port" }))) { $info.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::Start($info)
        $processes[$role] = @{
            Process = $process
            StandardOutput = $process.StandardOutput.ReadToEndAsync()
            StandardError = $process.StandardError.ReadToEndAsync()
        }
        [IO.File]::WriteAllText((Join-Path $runtime 'owned-pid.txt'), "$($process.Id)")
        Write-Output "LOCAL_COOP_STARTED $role $($process.Id)"
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (@($processes.Values | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
        foreach ($role in $roles) {
            if ($Scenario -eq 'smoke' -and (Test-Path -LiteralPath (Join-Path $run ($role + '_failed.json')))) { throw "Local co-op role failed: $run" }
        }
        if ([DateTime]::UtcNow -ge $deadline) { throw "Local co-op overall deadline: $run" }
        Start-Sleep -Milliseconds 500
    }
}
finally {
    if ($relay) {
        [IO.File]::WriteAllText($relayStop, 'stop')
        if (-not $relay.WaitForExit(5000)) { $relay.Kill($true) }
    }
    foreach ($role in $processes.Keys) {
        $entry = $processes[$role]
        if (-not $entry.Process.HasExited) { $entry.Process.Kill($true); $entry.Process.WaitForExit() }
        [IO.File]::WriteAllText((Join-Path $run "$role.stdout.log"), $entry.StandardOutput.GetAwaiter().GetResult())
        [IO.File]::WriteAllText((Join-Path $run "$role.stderr.log"), $entry.StandardError.GetAwaiter().GetResult())
    }
}
$failed = $false
$summary = @{}
foreach ($role in $roles) {
    $lines = (Get-Content -LiteralPath (Join-Path $run "$role.stdout.log") -Raw) + (Get-Content -LiteralPath (Join-Path $run "$role.stderr.log") -Raw)
    $errors = [regex]::Matches($lines, '(?im)^.*(?:SCRIPT ERROR:|ERROR:|Parse Error|Compile Error|CrashHandlerException|LOCAL_COOP_CHECK .* FAIL|WORLD_STARTUP_CHECK .* FAIL).*$')
    $result = Join-Path $run ($role + '_complete.json')
    $complete = Test-Path -LiteralPath $result
    $data = if ($complete) { Get-Content -LiteralPath $result -Raw | ConvertFrom-Json } else { $null }
    Write-Output "LOCAL_COOP_PROCESS $role exit=$($processes[$role].Process.ExitCode) completed=$complete errors=$($errors.Count) checks=$($data.checks) failures=$($data.failures)"
    $resultPrefix = if ($WorldControl) { 'WORLD_STARTUP_RESULT' } else { 'LOCAL_COOP_RESULT' }
    $validResult = $complete -and $data.failures -eq 0 -and $lines -match "$resultPrefix $role \d+ checks 0 failures"
    $summary[$role] = @{ exit = $processes[$role].Process.ExitCode; completed = $complete; errors = @($errors | ForEach-Object { $_.Value.Trim() }); checks = $data.checks; failures = $data.failures; valid = $validResult }
    if ($processes[$role].Process.ExitCode -ne 0 -or $errors.Count -gt 0 -or -not $validResult) { $failed = $true }
}
$gate.ReleaseMutex()
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $run 'run-summary.json') -Encoding UTF8
if ($Scenario -ne 'smoke' -or $Solo) { Write-Output "FRICTION_RUN $run failed=$failed"; return }
if ($failed) { throw "Local co-op strict validation failed: $run" }
if ($WorldControl) { "WORLD_STARTUP_CONTROL_PASS $WorldControl" } else { 'LOCAL_COOP_SMOKE_PASS' }

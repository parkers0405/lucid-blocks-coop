[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Godot,
    [Parameter(Mandatory)][string] $Gdre,
    [Parameter(Mandatory)][string] $GameExe,
    [Parameter(Mandatory)][string] $ProjectDir,
    [Parameter(Mandatory)][string] $OutputDir,
    [switch] $CombatTests,
    [switch] $RendererControl,
    [switch] $OriginalControl,
    [switch] $StartupDiagnostic,
    [switch] $NativeBaseline,
    [switch] $CollisionTests,
    [switch] $RegionTests,
    [switch] $AdmissionTests
)
if ($StartupDiagnostic -and ($CombatTests -or $RegionTests -or $AdmissionTests)) { throw 'StartupDiagnostic must run alone.' }
if ($NativeBaseline -and (-not $RegionTests -or $CombatTests -or $StartupDiagnostic -or $AdmissionTests)) { throw 'NativeBaseline requires RegionTests alone.' }
if ($RendererControl -and -not $CombatTests) { throw 'RendererControl requires CombatTests.' }
if ($OriginalControl -and -not $RendererControl) { throw 'OriginalControl requires RendererControl.' }
if ($CollisionTests -and (-not $RegionTests -or $CombatTests -or $StartupDiagnostic -or $AdmissionTests)) { throw 'CollisionTests requires RegionTests alone.' }
. (Join-Path $PSScriptRoot 'mod_files.ps1')
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$gdrePath = (Resolve-Path -LiteralPath $Gdre).Path
$gamePath = (Resolve-Path -LiteralPath $GameExe).Path
$project = (Resolve-Path -LiteralPath $ProjectDir).Path
$output = [IO.Path]::GetFullPath($OutputDir)
foreach ($path in @($godotPath, $gdrePath, $gamePath, $project, $output)) { Assert-PlainPath $path }
if ($output -eq $project -or $output.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputDir must be outside the mod source.' }
$buildId = [guid]::NewGuid().ToString('N')
$logs = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../work/build-logs/$buildId"))
[IO.Directory]::CreateDirectory($logs) | Out-Null
[IO.Directory]::CreateDirectory($output) | Out-Null
function Invoke-RawTool([string] $Executable, [string[]] $ToolArguments, [string] $Label) {
    $stdout = Join-Path $logs ($Label + '.stdout.log')
    $stderr = Join-Path $logs ($Label + '.stderr.log')
    if ([IO.Path]::GetExtension($Executable) -eq '.ps1') {
        $global:LASTEXITCODE = 0
        $lines = @(& $Executable @ToolArguments 2>&1)
        $code = $LASTEXITCODE
        $lines | Set-Content -LiteralPath $stdout -Encoding UTF8
        return @{ Code = $code; Lines = $lines }
    }
    $quoted = ($ToolArguments | ForEach-Object { '"' + ($_ -replace '(\\+)$', '$1$1') + '"' }) -join ' '
    $process = Start-Process -FilePath $Executable -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timeout = if ($Label -eq 'runtime' -and $CombatTests) { 180000 } elseif ($Label -eq 'runtime') { 90000 } else { 45000 }
    if (-not $process.WaitForExit($timeout)) { $process.Kill(); $process.WaitForExit(); throw "$Label exceeded $($timeout / 1000) seconds. Logs: $logs" }
    @{ Code = $process.ExitCode; Lines = @(Get-Content -LiteralPath $stdout) + @(Get-Content -LiteralPath $stderr) }
}
$version = Invoke-RawTool $godotPath @('--headless', '--version') 'version'
if ($version.Code -ne 0 -or ($version.Lines | Out-String).Trim() -notmatch '^4\.6[.\-].*\bdouble\b') { throw "Matching Godot 4.6 double editor required. Logs: $logs" }
$target = Join-Path $output $ModName
Assert-PlainPath $target
$buildDir = Join-Path $output ('.build-' + $buildId)
$source = Join-Path $buildDir 'source'
$runtime = Join-Path $logs 'runtime'
$staging = Join-Path $runtime ('mods/' + $ModName)
$oldProfile = $env:APPDATA
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
try {
    [IO.Directory]::CreateDirectory($source) | Out-Null
    foreach ($directory in @('profile', 'temp')) { [IO.Directory]::CreateDirectory((Join-Path $buildDir $directory)) | Out-Null }
    $env:APPDATA = Join-Path $buildDir 'profile'
    $env:TEMP = Join-Path $buildDir 'temp'
    $env:TMP = $env:TEMP
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "../tests") -Destination (Join-Path $buildDir "tests") -Recurse
    foreach ($entry in Get-ChildItem -LiteralPath $project -Force) {
        if ($entry.Name -in @('.godot', '.git', 'project.godot', 'export_presets.cfg')) { continue }
        foreach ($child in @($entry) + @(Get-ChildItem -LiteralPath $entry.FullName -Recurse -Force -ErrorAction Stop)) {
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Links are not supported: $($child.FullName)" }
        }
        Copy-Item -LiteralPath $entry.FullName -Destination $source -Recurse -Force
    }
    $imported = Join-Path $project '.godot/imported'
    if (Test-Path -LiteralPath $imported) {
        Assert-PlainPath $imported
        foreach ($child in Get-ChildItem -LiteralPath $imported -Recurse -Force) {
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Links are not supported: $($child.FullName)" }
        }
        [IO.Directory]::CreateDirectory((Join-Path $source '.godot')) | Out-Null
        Copy-Item -LiteralPath $imported -Destination (Join-Path $source '.godot') -Recurse -Force
    }
    # Mod imports are cached build inputs; reject missing or stale asset imports.
    foreach ($import in Get-ChildItem -LiteralPath $source -Filter '*.import' -Recurse -File) {
        if ((Get-Content -LiteralPath $import.FullName -Raw) -match '(?m)^path="res://(\.godot/imported/[^"\r\n]+)"') {
            $destination = Join-Path $source $Matches[1]
            $checksum = [IO.Path]::ChangeExtension($destination, '.md5')
            $asset = $import.FullName.Substring(0, $import.FullName.Length - 7)
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or -not (Test-Path -LiteralPath $checksum -PathType Leaf)) { throw "Missing mod import: $asset" }
            $hash = (Get-FileHash -LiteralPath $asset -Algorithm MD5).Hash
            if ((Get-Content -LiteralPath $checksum -Raw) -notmatch ('source_md5="' + $hash + '"')) { throw "Stale mod import: $asset" }
        }
    }
    $scriptPaths = @()
    foreach ($script in Get-ChildItem -LiteralPath $source -Filter '*.gd' -Recurse -File) {
        $relative = $script.FullName.Substring($source.Length + 1).Replace('\', '/')
        $resource = 'res://' + $relative
        [IO.File]::WriteAllText(($script.FullName + '.remap'), "[remap]`npath=`"$resource`"`n")
        if ($relative -match '^(main|coop_mod)/' -and $relative -notmatch '^coop_mod/animation_workflow/') { $scriptPaths += $resource }
    }
    [IO.Directory]::CreateDirectory((Join-Path $runtime 'mods')) | Out-Null
    $pack = Invoke-RawTool $gdrePath @('--headless', "--pck-create=$source", '--pck-version=2', '--pck-engine-version=4.6.0', "--output=$staging") 'pack'
    if ($pack.Code -ne 0 -or $pack.Lines -match '(?i)(SCRIPT ERROR:|ERROR:|Parse Error|Failed)') { throw "Pack creation failed. Logs: $logs" }
    Assert-ModPack $staging
    if ($OriginalControl) { Remove-Item -LiteralPath $staging }
    $runtimeEditor = Join-Path $runtime ('godot' + [IO.Path]::GetExtension($godotPath))
    Copy-Item -LiteralPath $godotPath -Destination $runtimeEditor
    $gameDir = Split-Path -Parent $gamePath
    foreach ($library in @('libgdblocks.windows.template_release.double.x86_64.dll', 'libgodotsteam.windows.template_release.double.x86_64.dll', 'steam_api64.dll')) {
        Copy-Item -LiteralPath (Join-Path $gameDir $library) -Destination (Join-Path $runtime $library)
    }
    if ($NativeBaseline) {
        $baseline = Join-Path $PSScriptRoot '../work/native-baseline-output/libgdblocks.windows.template_release.double.x86_64.dll'
        if ((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash -ne '4F66CFFE038960E624773F8363452CC811A5B91156EA1CB2201BEA132C0B1FB9') { throw 'Native baseline fingerprint mismatch.' }
        Copy-Item -LiteralPath $baseline -Destination (Join-Path $runtime 'libgdblocks.windows.template_release.double.x86_64.dll') -Force
    }
    foreach ($entry in @(@('libgdblocks.windows.template_release.double.x86_64.dll', 'bin'), @('libgodotsteam.windows.template_release.double.x86_64.dll', 'addons/godotsteam/win64'))) {
        $folder = Join-Path $runtime $entry[1]
        [IO.Directory]::CreateDirectory($folder) | Out-Null
        Copy-Item -LiteralPath (Join-Path $runtime $entry[0]) -Destination (Join-Path $folder $entry[0])
        Copy-Item -LiteralPath (Join-Path $runtime $entry[0]) -Destination (Join-Path $folder $entry[0].Replace('template_release', 'template_debug'))
    }
    Copy-Item -LiteralPath (Join-Path $runtime 'steam_api64.dll') -Destination (Join-Path $runtime 'addons/godotsteam/win64/steam_api64.dll')
    $probeSource = Join-Path $buildDir 'probe'
    $probeFolder = Join-Path $probeSource 'mods/coop_build_check'
    [IO.Directory]::CreateDirectory($probeFolder) | Out-Null
    $listPath = Join-Path $probeFolder 'scripts.json'
    ConvertTo-Json -InputObject @($scriptPaths) | Set-Content -LiteralPath $listPath -Encoding UTF8
    $probe = Join-Path $probeFolder 'mod_init.gd'
    @'
extends Node
signal shader_isolation_finished
var shader_profile_seeded: bool = false
var shader_isolation_done: bool = false
func _enter_tree() -> void:
    var args = OS.get_cmdline_user_args()
    if args.size() > 1 and args[1] == "combat":
        get_tree().node_added.connect(_watch_combat_startup)
        _scan_combat_startup(get_tree().root)
        get_tree().create_timer(10.0, true, false, true).timeout.connect(_isolation_deadline)
func _ready() -> void:
    call_deferred("_check")
func _scan_combat_startup(node: Node) -> void:
    _watch_combat_startup(node)
    for child in node.get_children():
        _scan_combat_startup(child)
func _isolation_deadline() -> void:
    if not shader_profile_seeded:
        print("COOP_BUILD_CHECK_FAILED shader isolation deadline")
        get_tree().quit(1)
func _start_shader_wait_deadline() -> void:
    print("COMBAT_SHADER_WAIT_STARTED")
    # Cold original UI shader compilation can exceed ten seconds on this Intel GPU.
    get_tree().create_timer(60.0, true, false, true).timeout.connect(_shader_wait_deadline)
func _shader_wait_deadline() -> void:
    if not shader_isolation_done:
        print("COOP_BUILD_CHECK_FAILED shader completion deadline")
        get_tree().quit(1)
func _watch_combat_startup(node: Node) -> void:
    if node.get_script() == null:
        return
    var path: String = node.get_script().resource_path
    if path == "res://main/save_file/save_file_manager.gd":
        if node.is_node_ready():
            _seed_combat_profile(node)
        elif not node.ready.is_connected(_seed_combat_profile.bind(node)):
            node.ready.connect(_seed_combat_profile.bind(node), CONNECT_ONE_SHOT)
    elif path == "res://main/shader_compilation/shader_loader.gd":
        if not node.shaders_compiled.is_connected(_shader_isolation_finished):
            node.shaders_compiled.connect(_shader_isolation_finished, CONNECT_ONE_SHOT)
    elif path == "res://main/world/world.gd":
        if not node.start_up_done.is_connected(_start_shader_wait_deadline):
            node.start_up_done.connect(_start_shader_wait_deadline, CONNECT_ONE_SHOT)
func _seed_combat_profile(manager: Node) -> void:
    # Seed after device initialization, before the parent Main starts up.
    manager.device_file.set_data("save_version", ProjectSettings.get_setting("application/config/version"))
    manager.device_file.set_data("shaders_baked", true)
    shader_profile_seeded = true
    print("COMBAT_SHADER_PROFILE_SEEDED")
func _shader_isolation_finished() -> void:
    shader_isolation_done = true
    shader_isolation_finished.emit()
func _check() -> void:
    print("COOP_BUILD_CHECK_START")
    await get_tree().process_frame
    await get_tree().process_frame
    print("COOP_BUILD_CHECK_FRAMES")
    var isolation_args = OS.get_cmdline_user_args()
    if isolation_args.size() > 1 and isolation_args[1] == "combat":
        if not shader_isolation_done:
            await shader_isolation_finished
        if not shader_profile_seeded:
            print("COOP_BUILD_CHECK_FAILED shader isolation setup")
            get_tree().quit(1)
            return
        get_tree().node_added.disconnect(_watch_combat_startup)
        print("COMBAT_SHADER_ISOLATION_OK")
    if isolation_args.size() > 3 and isolation_args[3] == "startup-only":
        print("COOP_RENDER_CONTROL_OK")
        print("COOP_BUILD_CHECK_OK 0")
        call_deferred("_finish", 0)
        return
    if not OS.has_feature("double") or not ClassDB.class_exists("World") or not ClassDB.class_exists("SteamMultiplayerPeer"):
        print("COOP_BUILD_CHECK_FAILED native interfaces")
        get_tree().quit(1)
        return
    var paths = JSON.parse_string(FileAccess.get_file_as_string("res://mods/coop_build_check/scripts.json"))
    var failures := 0
    for path in paths:
        var script = load(path) as GDScript
        if script == null or not script.can_instantiate():
            print("COOP_BUILD_CHECK_FAILED ", path)
            failures += 1
    print("COOP_BUILD_CHECK_SCRIPTS")
    if failures:
        print("COOP_BUILD_CHECK_FAILED script validation ", failures)
        call_deferred("_finish", failures)
        return
    var world_script = load("res://main/world/world.gd") as GDScript
    var entity_script = load("res://main/entity/entity.gd") as GDScript
    var dimensions = world_script.get_script_constant_map().get("Dimension", {})
    if dimensions.get("LUCY", -1) != 8 or dimensions.get("TORUS", -1) != 9 or not entity_script.has_method("get_water_flow"):
        print("COOP_BUILD_CHECK_FAILED current interfaces")
        failures += 1
    var fixture = entity_script.new()
    if fixture.get("dexterity") != 0:
        print("COOP_BUILD_CHECK_FAILED dexterity default")
        failures += 1
    fixture.free()
    if entity_script.call("get_water_flow", Vector3(10000000, 10000000, 10000000)) != Vector3.ZERO:
        print("COOP_BUILD_CHECK_FAILED unloaded water flow")
        failures += 1
    print("COOP_BUILD_CHECK_NATIVE_CALLS")
    var manager = get_node("/root/Ref").coop_manager
    if manager == null or manager.has_connected_remote_peers():
        print("COOP_BUILD_CHECK_FAILED offline peers")
        failures += 1
    var test_args = OS.get_cmdline_user_args()
    if not test_args.is_empty():
        # Parse the retained LAN fixture without starting its exhausted gameplay test.
        var local_coop_script = load(test_args[0].path_join("local_coop.gd")) as GDScript
        if local_coop_script == null or not local_coop_script.can_instantiate():
            print("COOP_BUILD_CHECK_FAILED local co-op fixture parse")
            call_deferred("_finish", failures + 1)
            return
        print("COOP_LOCAL_COOP_FIXTURE_PARSE_OK")
        if test_args.size() > 1 and test_args[1] == "region":
            var region_suite = load(test_args[0].path_join("region_runtime.gd")).new()
            add_child(region_suite)
            failures += await region_suite.run()
            region_suite.free()
            if test_args.size() > 2 and test_args[2] == "collision":
                var collision_suite = load(test_args[0].path_join("native_collision.gd")).new()
                add_child(collision_suite)
                failures += await collision_suite.run()
                collision_suite.free()
        elif test_args.size() > 1 and test_args[1] == "combat":
            var combat_suite = load(test_args[0].path_join("combat.gd")).new()
            add_child(combat_suite)
            failures += await combat_suite.run()
            combat_suite.free()
        if test_args.size() == 1 or test_args.has("admission"):
            print("COOP_ADMISSION_SUITE_LOADING")
            var suite = load(test_args[0].path_join("admission.gd")).new()
            add_child(suite)
            print("COOP_ADMISSION_SUITE_RUNNING")
            failures += await suite.run()
            suite.queue_free()
            failures += load(test_args[0].path_join("native_guard.gd")).run()
            var personal_suite = load(test_args[0].path_join("personal_store.gd")).new()
            add_child(personal_suite)
            failures += personal_suite.run()
            personal_suite.free()
            var chunk_suite = load(test_args[0].path_join("chunk_authority.gd")).new()
            add_child(chunk_suite)
            failures += chunk_suite.run()
            chunk_suite.free()
            var profile_suite = load(test_args[0].path_join("profile_runtime.gd")).new()
            add_child(profile_suite)
            failures += await profile_suite.run()
            profile_suite.free()
            var canonical_suite = load(test_args[0].path_join("canonical_runtime.gd")).new()
            add_child(canonical_suite)
            failures += await canonical_suite.run()
            canonical_suite.free()
            var instance_suite = load(test_args[0].path_join("instance_entities.gd")).new()
            add_child(instance_suite)
            failures += instance_suite.run()
            instance_suite.free()
            var lease_store_suite = load(test_args[0].path_join("runtime_lease.gd")).new()
            add_child(lease_store_suite)
            failures += lease_store_suite.run()
            lease_store_suite.free()
            var lease_runtime_suite = load(test_args[0].path_join("lease_runtime.gd")).new()
            add_child(lease_runtime_suite)
            failures += await lease_runtime_suite.run()
            lease_runtime_suite.free()
            var respawn_store_suite = load(test_args[0].path_join("private_respawns.gd")).new()
            add_child(respawn_store_suite)
            failures += respawn_store_suite.run()
            respawn_store_suite.free()
            var respawn_runtime_suite = load(test_args[0].path_join("respawn_runtime.gd")).new()
            add_child(respawn_runtime_suite)
            failures += respawn_runtime_suite.run()
            respawn_runtime_suite.free()
    print("COOP_BUILD_CHECK_OK ", paths.size())
    call_deferred("_finish", failures)
func _cleanup_keyboard() -> void:
    # The original keyboard owns an unattached helper; release it for this short probe.
    var keyboard = get_node_or_null("/root/Main/UI/OnscreenKeyboard")
    if keyboard != null:
        var helper = keyboard.get("KeyListHandler")
        if is_instance_valid(helper) and helper is Node and not helper.is_inside_tree() and helper.get_script().resource_path == "res://addons/onscreenkeyboard/keylist.gd":
            helper.free()
            keyboard.set("KeyListHandler", null)
            print("COOP_BUILD_CHECK_CLEANUP keyboard helper")
func _finish(failures: int) -> void:
    var args = OS.get_cmdline_user_args()
    var original_control: bool = args.size() > 4 and args[4] == "original"
    if not original_control:
        _cleanup_keyboard()
    if args.size() > 1 and args[1] == "combat" and not original_control:
        # Preloaded item scenes can retain their own items through exported resources.
        for item in ItemMap.id_to_resource.values():
            item.held_item_scene = null
            if item is Block:
                item.living_block_scene = null
            if item is Spawner:
                item.entity_scene = null
    if args.size() > 1 and args[1] == "combat":
        await RenderingServer.frame_post_draw
    await get_tree().process_frame
    get_tree().quit(1 if failures else 0)
'@ | Set-Content -LiteralPath $probe -Encoding UTF8
    if ($StartupDiagnostic) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../tests/startup_diagnostic.gd') -Destination $probe -Force
    }
    $probePack = Join-Path $runtime 'mods/zz-coop-build-check.pck'
    $probeBuild = Invoke-RawTool $gdrePath @('--headless', "--pck-create=$probeSource", '--pck-version=2', '--pck-engine-version=4.6.0', "--output=$probePack") 'probe-pack'
    if ($probeBuild.Code -ne 0 -or $probeBuild.Lines -match '(?i)(SCRIPT ERROR:|ERROR:|Parse Error|Failed)') { throw "Probe pack creation failed. Logs: $logs" }
    Assert-ModPack $probePack
    foreach ($directory in @('profile', 'temp')) { [IO.Directory]::CreateDirectory((Join-Path $buildDir $directory)) | Out-Null }
    $env:APPDATA = Join-Path $buildDir 'profile'
    $env:TEMP = Join-Path $buildDir 'temp'
    $env:TMP = $env:TEMP
    $runtimeArgs = @('--headless')
    if ($CombatTests) {
        $runtimeArgs = @('--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--windowed', '--resolution', '640x480', '--position', '-32000,-32000', '--audio-driver', 'Dummy', '--max-fps', '60')
    }
    if ($PSBoundParameters['Verbose']) { $runtimeArgs += '--verbose' }
    # The shipped executable already embeds the game pack and forbids path overrides.
    if ($godotPath -ne $gamePath) { $runtimeArgs += @('--path', $runtime, '--main-pack', $gamePath) }
    if ($AdmissionTests -or $RegionTests -or $CombatTests) {
        [IO.File]::WriteAllText((Join-Path $runtime '.coop-test-runtime'), '')
        $runtimeArgs += @('--', [IO.Path]::GetFullPath((Join-Path $buildDir 'tests')))
        if ($RegionTests) {
            $runtimeArgs += 'region'
            if ($AdmissionTests) { $runtimeArgs += 'admission' }
            if ($CollisionTests) { $runtimeArgs += 'collision' }
        }
        elseif ($CombatTests) {
            $runtimeArgs += @('combat', $logs)
            if ($RendererControl) { $runtimeArgs += 'startup-only' }
            if ($OriginalControl) { $runtimeArgs += 'original' }
        }
    }
    $check = Invoke-RawTool $runtimeEditor $runtimeArgs 'runtime'
    $errors = @($check.Lines | Where-Object { "$_" -match '(?i)(SCRIPT ERROR:|ERROR:|Parse Error|Compile Error)' })
    if ($StartupDiagnostic) {
        if ($check.Code -ne 0 -or $errors.Count -gt 0 -or
            -not ($check.Lines -match '^STARTUP_DIAGNOSTIC_SETUP ') -or
            -not ($check.Lines -match '^STARTUP_DIAGNOSTIC_RESULT nodes=[1-9]\d* ')) {
            throw "Startup diagnostic failed; do not retry unchanged. Logs: $logs"
        }
        Write-Output "Startup identities captured; hook isolation and gameplay unverified. Logs: $logs"
        return
    }
    if ($CombatTests -and (
        -not ($check.Lines -match '^COMBAT_SHADER_PROFILE_SEEDED$') -or
        -not ($check.Lines -match '^Shader baking skipped\.$') -or
        $check.Lines -match '^Baking shaders\.\.\.' -or
        -not ($check.Lines -match '^COMBAT_SHADER_ISOLATION_OK$') -or
        (-not $RendererControl -and (
            -not ($check.Lines -match '^COMBAT_RESULT \d+ checks 0 failures$') -or
            @($check.Lines | Where-Object { "$_" -match '^COMBAT_RENDER .* method=forward_plus .* center_hits=[1-9]\d* ' }).Count -ne 2
        )) -or
        ($RendererControl -and (-not ($check.Lines -match '^COOP_RENDER_CONTROL_OK$') -or $check.Lines -match '^COMBAT_(RESULT|RENDER|SUITE_START)( |$)'))
    )) { throw "Isolated combat renderer gate failed. Logs: $logs" }
    if ($check.Code -ne 0 -or $errors.Count -gt 0 -or -not ($check.Lines -match '^COOP_BUILD_CHECK_OK ') -or $check.Lines -match '^COOP_BUILD_CHECK_FAILED ') {
        $errors | Select-Object -First 8 | ForEach-Object { Write-Output "$_" }
        throw "Runtime script check failed (exit $($check.Code)). Logs: $logs"
    }
    if ($NativeBaseline) {
        if (-not ($check.Lines -match '^REGION_RUNTIME_RESULT \d+ checks 0 failures$')) { throw "Native baseline region result missing. Logs: $logs" }
        if ($CollisionTests -and -not ($check.Lines -match '^NATIVE_COLLISION_RESULT 3 checks 0 failures$')) { throw "Native collision result missing. Logs: $logs" }
        Write-Output "Native baseline runtime/region probe passed; collision checked=$([bool]$CollisionTests), gameplay unverified. Logs: $logs"
        return
    }
    if ($CollisionTests) {
        if (-not ($check.Lines -match '^NATIVE_COLLISION_RESULT 3 checks 0 failures$')) { throw "Native collision result missing. Logs: $logs" }
        Write-Output "Original native collision control passed; gameplay unverified. Logs: $logs"
        return
    }
    if ($RendererControl) {
        Write-Output "Rendered startup control passed; combat not run. Logs: $logs"
        return
    }
    $publish = Join-Path $output ('.publish-' + $buildId + '.pck')
    try {
        Copy-Item -LiteralPath $staging -Destination $publish
        if ((Get-ModHash $publish) -ne (Get-ModHash $staging)) { throw 'Publish copy hash mismatch.' }
        Set-AtomicFile $publish $target
    } finally {
        if (Test-Path -LiteralPath $publish) { Remove-Item -LiteralPath $publish }
    }
    Write-Output "Built $target (SHA256 $(Get-ModHash $target)); script check passed, gameplay unverified. Logs: $logs"
} catch {
    if (Test-Path -LiteralPath $staging -PathType Leaf) { Copy-Item -LiteralPath $staging -Destination (Join-Path $logs 'failed-mod.pck') }
    throw
} finally {
    $env:APPDATA = $oldProfile
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
    if (Test-Path -LiteralPath $runtime) {
        if ([IO.Path]::GetFullPath($runtime) -ne (Join-Path $logs 'runtime')) { throw 'Unsafe runtime cleanup path.' }
        try { Remove-Item -LiteralPath $runtime -Recurse -Force }
        catch { Write-Warning "Could not remove runtime directory ${runtime}: $_" }
    }
    if (Test-Path -LiteralPath $buildDir) {
        $resolvedBuild = [IO.Path]::GetFullPath($buildDir)
        if (-not $resolvedBuild.StartsWith($output.TrimEnd('\') + '\.build-', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe build cleanup path.' }
        try { Remove-Item -LiteralPath $resolvedBuild -Recurse -Force }
        catch { Write-Warning "Could not remove staging directory ${resolvedBuild}: $_" }
    }
}

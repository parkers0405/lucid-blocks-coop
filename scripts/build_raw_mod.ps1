[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Godot,
    [Parameter(Mandatory)][string] $Gdre,
    [Parameter(Mandatory)][string] $GameExe,
    [Parameter(Mandatory)][string] $ProjectDir,
    [Parameter(Mandatory)][string] $OutputDir,
    [switch] $AdmissionTests
)
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
    $timeout = if ($Label -eq 'runtime') { 90000 } else { 45000 }
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
    $runtimeEditor = Join-Path $runtime ('godot' + [IO.Path]::GetExtension($godotPath))
    Copy-Item -LiteralPath $godotPath -Destination $runtimeEditor
    $gameDir = Split-Path -Parent $gamePath
    foreach ($library in @('libgdblocks.windows.template_release.double.x86_64.dll', 'libgodotsteam.windows.template_release.double.x86_64.dll', 'steam_api64.dll')) {
        Copy-Item -LiteralPath (Join-Path $gameDir $library) -Destination (Join-Path $runtime $library)
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
func _ready() -> void:
    call_deferred("_check")
func _check() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
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
    var manager = get_node("/root/Ref").coop_manager
    if manager == null or manager.has_connected_remote_peers():
        print("COOP_BUILD_CHECK_FAILED offline peers")
        failures += 1
    var test_args = OS.get_cmdline_user_args()
    if not test_args.is_empty():
        print("COOP_ADMISSION_SUITE_LOADING")
        var suite = load(test_args[0].path_join("admission.gd")).new()
        add_child(suite)
        print("COOP_ADMISSION_SUITE_RUNNING")
        failures += await suite.run()
        suite.queue_free()
        failures += load(test_args[0].path_join("native_guard.gd")).run()
    print("COOP_BUILD_CHECK_OK ", paths.size())
    # The original keyboard owns an unattached helper; release it for this short probe.
    var keyboard = get_node_or_null("/root/Main/UI/OnscreenKeyboard")
    if keyboard != null:
        var helper = keyboard.get("KeyListHandler")
        if is_instance_valid(helper) and helper is Node and not helper.is_inside_tree() and helper.get_script().resource_path == "res://addons/onscreenkeyboard/keylist.gd":
            helper.free()
            keyboard.set("KeyListHandler", null)
            print("COOP_BUILD_CHECK_CLEANUP keyboard helper")
    call_deferred("_finish", failures)
func _finish(failures: int) -> void:
    await get_tree().process_frame
    get_tree().quit(1 if failures else 0)
'@ | Set-Content -LiteralPath $probe -Encoding UTF8
    $probePack = Join-Path $runtime 'mods/zz-coop-build-check.pck'
    $probeBuild = Invoke-RawTool $gdrePath @('--headless', "--pck-create=$probeSource", '--pck-version=2', '--pck-engine-version=4.6.0', "--output=$probePack") 'probe-pack'
    if ($probeBuild.Code -ne 0 -or $probeBuild.Lines -match '(?i)(SCRIPT ERROR:|ERROR:|Parse Error|Failed)') { throw "Probe pack creation failed. Logs: $logs" }
    Assert-ModPack $probePack
    foreach ($directory in @('profile', 'temp')) { [IO.Directory]::CreateDirectory((Join-Path $buildDir $directory)) | Out-Null }
    $env:APPDATA = Join-Path $buildDir 'profile'
    $env:TEMP = Join-Path $buildDir 'temp'
    $env:TMP = $env:TEMP
    $runtimeArgs = @('--headless', '--path', $runtime, '--main-pack', $gamePath)
    if ($AdmissionTests) {
        [IO.File]::WriteAllText((Join-Path $runtime '.coop-test-runtime'), '')
        $runtimeArgs += @('--', [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../tests')))
    }
    $check = Invoke-RawTool $runtimeEditor $runtimeArgs 'runtime'
    $errors = @($check.Lines | Where-Object { "$_" -match '(?i)(SCRIPT ERROR:|ERROR:|Parse Error|Compile Error)' })
    if ($check.Code -ne 0 -or $errors.Count -gt 0 -or -not ($check.Lines -match '^COOP_BUILD_CHECK_OK ') -or $check.Lines -match '^COOP_BUILD_CHECK_FAILED ') {
        $errors | Select-Object -First 8 | ForEach-Object { Write-Output "$_" }
        throw "Runtime script check failed (exit $($check.Code)). Logs: $logs"
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

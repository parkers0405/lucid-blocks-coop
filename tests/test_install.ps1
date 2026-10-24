param([string] $FixtureRoot = (Join-Path $PSScriptRoot '../work/test-temp'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scripts = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../scripts'))
$fixture = Join-Path ([IO.Path]::GetFullPath($FixtureRoot)) ('coop installer tests ' + [guid]::NewGuid().ToString('N'))
$checks = 0
function Assert([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
function Expect-Failure([scriptblock] $Action, [string] $Message) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Assert $failed $Message
}
function Write-Pack([string] $Path, [byte] $Marker) {
    # Synthetic header fixtures exercise file operations, not Godot pack loading.
    $bytes = [byte[]]::new(128)
    [BitConverter]::GetBytes([uint32]0x43504447).CopyTo($bytes, 0)
    [BitConverter]::GetBytes([uint32]2).CopyTo($bytes, 4)
    [BitConverter]::GetBytes([uint32]4).CopyTo($bytes, 8)
    [BitConverter]::GetBytes([uint32]6).CopyTo($bytes, 12)
    $bytes[127] = $Marker
    [IO.File]::WriteAllBytes($Path, $bytes)
}
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
try {
    [IO.Directory]::CreateDirectory($fixture) | Out-Null
    $game = Join-Path $fixture 'game with spaces'
    $mods = Join-Path $game 'mods'
    [IO.Directory]::CreateDirectory($mods) | Out-Null
    [IO.File]::WriteAllText((Join-Path $game 'lucid-blocks.exe'), 'fixture')
    $unrelated = Join-Path $mods 'another-mod.pck'
    [IO.File]::WriteAllText($unrelated, 'do not touch')
    $target = Join-Path $mods 'lucid-blocks-coop.pck'
    $pack = Join-Path $fixture 'new mod.pck'
    $update = Join-Path $fixture 'updated mod.pck'
    $invalid = Join-Path $fixture 'invalid.pck'
    Write-Pack $pack 1
    Write-Pack $update 2
    [IO.File]::WriteAllText($invalid, 'not a PCK')
    & "$scripts/install_mod.ps1" -GameDir $game -Pack $pack
    Assert ((Hash $target) -eq (Hash $pack)) 'fresh install'
    & "$scripts/install_mod.ps1" -GameDir $game -Pack $pack
    $manifestPath = Join-Path $mods '.lucid-blocks-coop-install/manifest.json'
    $lockedManifest = [IO.File]::Open($manifestPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        Expect-Failure { & "$scripts/install_mod.ps1" -GameDir $game -Pack $update } 'locked manifest aborts update'
        Assert ((Hash $target) -eq (Hash $pack)) 'failed update restores prior installed pack'
    } finally { $lockedManifest.Dispose() }
    & "$scripts/install_mod.ps1" -GameDir $game -Pack $update
    Assert ((Hash $target) -eq (Hash $update)) 'update install'
    Expect-Failure { & "$scripts/install_mod.ps1" -GameDir $game -Pack $invalid } 'invalid pack rejected'
    Assert ((Hash $target) -eq (Hash $update)) 'invalid pack preserves install'
    & "$scripts/uninstall_mod.ps1" -GameDir $game
    & "$scripts/uninstall_mod.ps1" -GameDir $game
    Assert (-not (Test-Path -LiteralPath $target)) 'fresh install rollback removes only own pack'
    [IO.File]::WriteAllText($target, 'original mod bytes')
    $originalHash = Hash $target
    & "$scripts/install_mod.ps1" -GameDir $game -Pack $pack
    & "$scripts/install_mod.ps1" -GameDir $game -Pack $update
    [IO.File]::WriteAllText($target, 'external modification')
    Expect-Failure { & "$scripts/install_mod.ps1" -GameDir $game -Pack $pack } 'changed target blocks install'
    Expect-Failure { & "$scripts/uninstall_mod.ps1" -GameDir $game } 'changed target blocks uninstall'
    Assert (([IO.File]::ReadAllText($target)) -eq 'external modification') 'changed target preserved'
    Copy-Item -LiteralPath $update -Destination $target
    $backup = Join-Path $mods '.lucid-blocks-coop-install/original.pck'
    $backupBytes = [IO.File]::ReadAllBytes($backup)
    [IO.File]::WriteAllText($backup, 'bad backup')
    Expect-Failure { & "$scripts/uninstall_mod.ps1" -GameDir $game } 'damaged backup blocks uninstall'
    Assert ((Hash $target) -eq (Hash $update)) 'damaged backup preserves install'
    [IO.File]::WriteAllBytes($backup, $backupBytes)
    & "$scripts/uninstall_mod.ps1" -GameDir $game
    & "$scripts/uninstall_mod.ps1" -GameDir $game
    Assert ((Hash $target) -eq $originalHash) 'original restored after multiple updates'
    Assert (([IO.File]::ReadAllText($unrelated)) -eq 'do not touch') 'unrelated pack preserved'
    Assert (-not (Test-Path -LiteralPath (Join-Path $game 'coop-native-patch'))) 'native patch untouched'

    $project = Join-Path $fixture 'export project'
    $dist = Join-Path $fixture 'dist with spaces'
    [IO.Directory]::CreateDirectory($project) | Out-Null
    [IO.Directory]::CreateDirectory($dist) | Out-Null
    [IO.File]::WriteAllText((Join-Path $project 'project.godot'), 'fixture')
    [IO.File]::WriteAllText((Join-Path $project 'export_presets.cfg'), 'fixture')
    $artifact = Join-Path $dist 'lucid-blocks-coop.pck'
    Copy-Item -LiteralPath $pack -Destination $artifact
    $mock = Join-Path $fixture 'mock editor.ps1'
    @'
if ($args -contains '--version') {
    $global:LASTEXITCODE = 0
    if ($env:COOP_TEST_MODE -eq 'version') { '4.7.2.stable'; return }
    '4.6.stable.double'; return
}
if ($env:COOP_TEST_MODE -eq 'exit') { $global:LASTEXITCODE = 1; return }
$global:LASTEXITCODE = 0
[IO.File]::WriteAllText((Join-Path $args[2] 'project.godot'), 'editor changed its disposable copy')
if ($env:COOP_TEST_MODE -eq 'missing') { return }
if ($env:COOP_TEST_MODE -eq 'invalid') { [IO.File]::WriteAllText($args[-1], 'invalid'); return }
Copy-Item -LiteralPath $env:COOP_TEST_PACK -Destination $args[-1]
if ($env:COOP_TEST_MODE -eq 'error') { 'SCRIPT ERROR: simulated failure' }
'@ | Set-Content -LiteralPath $mock -Encoding UTF8
    $env:COOP_TEST_PACK = $update
    foreach ($mode in @('version', 'exit', 'missing', 'invalid', 'error')) {
        $env:COOP_TEST_MODE = $mode
        Expect-Failure { & "$scripts/build_mod.ps1" -Godot $mock -ProjectDir $project -OutputDir $dist } "build rejects $mode"
        Assert ((Hash $artifact) -eq (Hash $pack)) "build $mode retains old artifact"
        Assert ((Hash $target) -eq $originalHash) "build $mode leaves installation unchanged"
    }
    $env:COOP_TEST_MODE = 'success'
    & "$scripts/build_mod.ps1" -Godot $mock -ProjectDir $project -OutputDir $dist
    Assert ((Hash $artifact) -eq (Hash $update)) 'successful mock build replaces artifact'
    Assert ((Hash $target) -eq $originalHash) 'successful mock build leaves installation unchanged'
    Assert (([IO.File]::ReadAllText((Join-Path $project 'project.godot'))) -eq 'fixture') 'editor only changes staged project'
    Assert (@(Get-ChildItem -LiteralPath $dist -Force).Count -eq 1) 'no build staging files remain'
    $rawMock = Join-Path $fixture 'raw tools.ps1'
    @'
$global:LASTEXITCODE = 0
if ($args -contains '--version') { '4.6.stable.double'; return }
$create = @($args | Where-Object { $_ -like '--pck-create=*' })
if ($create.Count) {
    $source = $create[0].Substring(13)
    if (Test-Path -LiteralPath (Join-Path $source 'project.godot')) { throw 'Pack includes project settings.' }
    if (-not (Test-Path -LiteralPath (Join-Path $source 'coop_mod/fixture.gd.remap')) -and
        -not (Test-Path -LiteralPath (Join-Path $source 'mods/coop_build_check/mod_init.gd'))) { throw 'Script remap or isolated probe missing.' }
    $destination = @($args | Where-Object { $_ -like '--output=*' })[0].Substring(9)
    Copy-Item -LiteralPath $env:COOP_TEST_PACK -Destination $destination
    return
}
if ($env:COOP_TEST_MODE -eq 'rawexit') { $global:LASTEXITCODE = 1; return }
if ($env:COOP_TEST_MODE -eq 'rawmissing') { return }
'COOP_BUILD_CHECK_OK 1'
if ($env:COOP_TEST_MODE -eq 'rawerror') { 'SCRIPT ERROR: Compile Error: simulated dependency mismatch' }
'@ | Set-Content -LiteralPath $rawMock -Encoding UTF8
    New-Item -ItemType Directory -Path (Join-Path $project 'coop_mod') | Out-Null
    [IO.File]::WriteAllText((Join-Path $project 'coop_mod/fixture.gd'), "extends Node`n")
    foreach ($library in @('libgdblocks.windows.template_release.double.x86_64.dll', 'libgodotsteam.windows.template_release.double.x86_64.dll', 'steam_api64.dll')) {
        [IO.File]::WriteAllText((Join-Path $game $library), 'fixture library')
    }
    Copy-Item -LiteralPath $pack -Destination $artifact
    foreach ($mode in @('rawerror', 'rawexit', 'rawmissing')) {
        $env:COOP_TEST_MODE = $mode
        Expect-Failure { & "$scripts/build_mod.ps1" -Godot $rawMock -Gdre $rawMock -GameExe (Join-Path $game 'lucid-blocks.exe') -ProjectDir $project -OutputDir $dist } "raw check rejects $mode"
        Assert ((Hash $artifact) -eq (Hash $pack)) "raw $mode retains old artifact"
    }
    $env:COOP_TEST_MODE = 'rawsuccess'
    & "$scripts/build_mod.ps1" -Godot $rawMock -Gdre $rawMock -GameExe (Join-Path $game 'lucid-blocks.exe') -ProjectDir $project -OutputDir $dist
    Assert ((Hash $artifact) -eq (Hash $update)) 'raw successful check publishes artifact'
    Assert ((Hash $target) -eq $originalHash) 'raw builder leaves install unchanged'
    Write-Output "PASS: $checks assertions (synthetic fixtures; no game or engine execution)."
} finally {
    Remove-Item Env:COOP_TEST_PACK, Env:COOP_TEST_MODE -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $fixture) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        $tempRoot = [IO.Path]::GetFullPath($FixtureRoot).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ModName = 'lucid-blocks-coop.pck'

function Assert-PlainPath([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Links are not supported: $current"
            }
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}

function Assert-ModPack([string] $Path) {
    Assert-PlainPath $Path
    $stream = [IO.File]::OpenRead($Path)
    try {
        $reader = [IO.BinaryReader]::new($stream)
        if ($stream.Length -lt 100 -or $reader.ReadUInt32() -ne 0x43504447 -or
            $reader.ReadUInt32() -ne 2 -or $reader.ReadUInt32() -ne 4 -or $reader.ReadUInt32() -ne 6) {
            throw "Expected a Godot 4.6 version-2 PCK header: $Path"
        }
    } finally { $stream.Dispose() }
}

function Get-ModHash([string] $Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Set-AtomicFile([string] $Source, [string] $Destination) {
    if (Test-Path -LiteralPath $Destination) {
        [IO.File]::Replace($Source, $Destination, [System.Management.Automation.Language.NullString]::Value)
    } else {
        [IO.File]::Move($Source, $Destination)
    }
}

function Get-InstallPaths([string] $GameDir) {
    $game = (Resolve-Path -LiteralPath $GameDir).Path
    Assert-PlainPath $game
    if (-not (Test-Path -LiteralPath (Join-Path $game 'lucid-blocks.exe') -PathType Leaf)) {
        throw "Game directory must contain lucid-blocks.exe: $game"
    }
    $mods = Join-Path $game 'mods'
    Assert-PlainPath $mods
    $state = Join-Path $mods '.lucid-blocks-coop-install'
    Assert-PlainPath $state
    $target = Join-Path $mods $ModName
    Assert-PlainPath $target
    @{
        Mods = $mods; State = $state; Target = $target
        Manifest = Join-Path $state 'manifest.json'
        Backup = Join-Path $state 'original.pck'
    }
}

function Read-InstallState($Paths) {
    foreach ($path in @($Paths.Manifest, $Paths.Backup)) { Assert-PlainPath $path }
    $manifest = Get-Content -LiteralPath $Paths.Manifest -Raw | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.mod -ne $ModName -or
        $manifest.installedHash -notmatch '^[A-Fa-f0-9]{64}$' -or
        $manifest.hadOriginal -isnot [bool]) { throw 'Invalid install manifest.' }
    if ($manifest.hadOriginal -and (
        $manifest.originalHash -notmatch '^[A-Fa-f0-9]{64}$' -or
        -not (Test-Path -LiteralPath $Paths.Backup -PathType Leaf) -or
        (Get-ModHash $Paths.Backup) -ne $manifest.originalHash)) { throw 'Original backup is missing or changed.' }
    $manifest
}

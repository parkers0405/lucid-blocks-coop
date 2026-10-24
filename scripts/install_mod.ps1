[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $GameDir,
    [string] $Pack = (Join-Path $PSScriptRoot '../dist/lucid-blocks-coop.pck')
)
. (Join-Path $PSScriptRoot 'mod_files.ps1')
Assert-ModPack $Pack
$packHash = Get-ModHash $Pack
$paths = Get-InstallPaths $GameDir
$existingState = Test-Path -LiteralPath $paths.State
if ($existingState) {
    $manifest = Read-InstallState $paths
    if (-not (Test-Path -LiteralPath $paths.Target -PathType Leaf) -or
        (Get-ModHash $paths.Target) -ne $manifest.installedHash) {
        throw 'Installed pack changed or is missing; refusing to overwrite it.'
    }
    if ($packHash -eq $manifest.installedHash) { Write-Output 'Already installed.'; return }
} else {
    $hadOriginal = Test-Path -LiteralPath $paths.Target -PathType Leaf
    $originalHash = $null
    if ($hadOriginal) { $originalHash = Get-ModHash $paths.Target }
    $manifest = [pscustomobject]@{
        schema = 1; mod = $ModName; installedHash = $packHash
        hadOriginal = [bool]$hadOriginal; originalHash = $originalHash
    }
}
[IO.Directory]::CreateDirectory($paths.State) | Out-Null
$staging = Join-Path $paths.State ('pack-' + [guid]::NewGuid().ToString('N') + '.tmp')
$pendingManifest = Join-Path $paths.State ('manifest-' + [guid]::NewGuid().ToString('N') + '.tmp')
$previous = Join-Path $paths.State ('previous-' + [guid]::NewGuid().ToString('N') + '.tmp')
$replaced = $false
try {
    Copy-Item -LiteralPath $Pack -Destination $staging
    Assert-ModPack $staging
    if ((Get-ModHash $staging) -ne $packHash) { throw 'Staged pack hash mismatch.' }
    if (Test-Path -LiteralPath $paths.Target) { Copy-Item -LiteralPath $paths.Target -Destination $previous }
    if (-not $existingState -and $manifest.hadOriginal) {
        Copy-Item -LiteralPath $previous -Destination $paths.Backup
        if ((Get-ModHash $paths.Backup) -ne $manifest.originalHash) { throw 'Backup hash mismatch.' }
    }
    $manifest.installedHash = $packHash
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $pendingManifest -Encoding UTF8
    Set-AtomicFile $staging $paths.Target
    $replaced = $true
    Set-AtomicFile $pendingManifest $paths.Manifest
    Write-Output "Installed $($paths.Target) (SHA256 $packHash)"
} catch {
    if ($replaced) {
        if (Test-Path -LiteralPath $previous) { Set-AtomicFile $previous $paths.Target }
        else { Remove-Item -LiteralPath $paths.Target }
    }
    if (-not $existingState) {
        if (Test-Path -LiteralPath $paths.Backup) { Remove-Item -LiteralPath $paths.Backup }
    }
    throw
} finally {
    foreach ($path in @($staging, $pendingManifest, $previous)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    if (-not $existingState -and -not (Test-Path -LiteralPath $paths.Manifest)) {
        [IO.Directory]::Delete($paths.State)
    }
}

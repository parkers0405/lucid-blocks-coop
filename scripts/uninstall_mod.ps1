[CmdletBinding()]
param([Parameter(Mandatory)][string] $GameDir)
. (Join-Path $PSScriptRoot 'mod_files.ps1')
$paths = Get-InstallPaths $GameDir
if (-not (Test-Path -LiteralPath $paths.State)) { Write-Output 'Nothing installed by this installer.'; return }
$manifest = Read-InstallState $paths
$targetExists = Test-Path -LiteralPath $paths.Target -PathType Leaf
# A completed restore may leave its manifest behind if cleanup was interrupted.
$alreadyRestored = if ($manifest.hadOriginal) {
    $targetExists -and (Get-ModHash $paths.Target) -eq $manifest.originalHash
} else { -not $targetExists }
if (-not $alreadyRestored) {
    if (-not $targetExists -or (Get-ModHash $paths.Target) -ne $manifest.installedHash) {
        throw 'Installed pack changed or is missing; refusing to remove it.'
    }
    if ($manifest.hadOriginal) {
        $staging = Join-Path $paths.State ('restore-' + [guid]::NewGuid().ToString('N') + '.tmp')
        try {
            Copy-Item -LiteralPath $paths.Backup -Destination $staging
            if ((Get-ModHash $staging) -ne $manifest.originalHash) { throw 'Restore hash mismatch.' }
            Set-AtomicFile $staging $paths.Target
        } finally {
            if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging }
        }
    } else { Remove-Item -LiteralPath $paths.Target }
}
if (Test-Path -LiteralPath $paths.Backup) { Remove-Item -LiteralPath $paths.Backup }
Remove-Item -LiteralPath $paths.Manifest
[IO.Directory]::Delete($paths.State)
Write-Output 'Uninstalled; original pack restored when present.'

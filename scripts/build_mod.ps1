[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Godot,
    [string] $Gdre,
    [string] $GameExe,
    [switch] $RegionTests,
    [switch] $AdmissionTests,
    [string] $ProjectDir = (Join-Path $PSScriptRoot '../mod/overrides'),
    [string] $OutputDir = (Join-Path $PSScriptRoot '../dist')
)
. (Join-Path $PSScriptRoot 'mod_files.ps1')
if ($Gdre -or $GameExe) {
    if (-not $Gdre -or -not $GameExe) { throw 'Raw packaging requires both Gdre and GameExe.' }
    & (Join-Path $PSScriptRoot 'build_raw_mod.ps1') -Godot $Godot -Gdre $Gdre -GameExe $GameExe -ProjectDir $ProjectDir -OutputDir $OutputDir -AdmissionTests:$AdmissionTests -RegionTests:$RegionTests
    return
}
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$project = (Resolve-Path -LiteralPath $ProjectDir).Path
Assert-PlainPath $project
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $project 'export_presets.cfg') -PathType Leaf)) {
    throw 'The export project and export_presets.cfg are required.'
}
$output = [IO.Path]::GetFullPath($OutputDir)
Assert-PlainPath $output
if ($output -eq $project -or $output.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDir must be outside the export project.'
}
[IO.Directory]::CreateDirectory($output) | Out-Null
function Invoke-Editor([string[]] $EditorArguments) {
    if ([IO.Path]::GetExtension($godotPath) -eq '.ps1') {
        $global:LASTEXITCODE = 0
        $lines = @(& $godotPath @EditorArguments 2>&1)
        return @{ Code = $LASTEXITCODE; Lines = $lines }
    }
    $stdout = Join-Path $output ([guid]::NewGuid().ToString('N') + '.stdout.log')
    $stderr = Join-Path $output ([guid]::NewGuid().ToString('N') + '.stderr.log')
    try {
        # Windows GUI editors otherwise return before their export finishes.
        $quoted = ($EditorArguments | ForEach-Object { '"' + ($_ -replace '(\\+)$', '$1$1') + '"' }) -join ' '
        $process = Start-Process -FilePath $godotPath -ArgumentList $quoted -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        return @{ Code = $process.ExitCode; Lines = @(Get-Content -LiteralPath $stdout) + @(Get-Content -LiteralPath $stderr) }
    } finally {
        foreach ($log in @($stdout, $stderr)) {
            if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log }
        }
    }
}
$versionResult = Invoke-Editor @('--headless', '--version')
$version = ($versionResult.Lines | Out-String).Trim()
if ($versionResult.Code -ne 0 -or $version -notmatch '^4\.6[.\-]' -or $version -notmatch '\bdouble\b') {
    throw "Use the matching Godot 4.6 double-precision editor. Reported: $version"
}
$target = Join-Path $output $ModName
Assert-PlainPath $target
$buildDir = Join-Path $output ('.build-' + [guid]::NewGuid().ToString('N'))
$stagedProject = Join-Path $buildDir 'project'
$staging = Join-Path $buildDir $ModName
try {
    [IO.Directory]::CreateDirectory($stagedProject) | Out-Null
    # Imports and export may modify sidecars; only the disposable copy reaches the editor.
    foreach ($entry in Get-ChildItem -LiteralPath $project -Force) {
        if ($entry.Name -in @('.godot', '.git')) { continue }
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Links are not supported: $($entry.FullName)" }
        if ($entry.PSIsContainer) {
            foreach ($child in Get-ChildItem -LiteralPath $entry.FullName -Recurse -Force) {
                if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Links are not supported: $($child.FullName)" }
            }
        }
        Copy-Item -LiteralPath $entry.FullName -Destination $stagedProject -Recurse -Force
    }
    $export = Invoke-Editor @('--headless', '--path', $stagedProject, '--export-pack', 'Linux/X11', $staging)
    $lines = $export.Lines
    $exportCode = $export.Code
    $lines | ForEach-Object { Write-Output "$_" }
    if ($exportCode -ne 0 -or ($lines -match '(?i)(SCRIPT ERROR:|ERROR:|Parse Error|Failed to export)')) {
        throw "Godot export failed (exit $exportCode); previous artifact retained."
    }
    Assert-ModPack $staging
    Set-AtomicFile $staging $target
    Write-Output "Built $target (SHA256 $(Get-ModHash $target))"
} finally {
    if (Test-Path -LiteralPath $buildDir) {
        $resolvedBuild = [IO.Path]::GetFullPath($buildDir)
        if (-not $resolvedBuild.StartsWith($output.TrimEnd('\') + '\.build-', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unsafe build cleanup path.'
        }
        try { Remove-Item -LiteralPath $resolvedBuild -Recurse -Force }
        catch { Write-Warning "Could not remove staging directory ${resolvedBuild}: $_" }
    }
}

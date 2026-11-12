# Retention for test-run folders (C:\Work\AGENTS.md "Disk and harnesses"): finished runs keep logs/results, lose binaries and copied inputs.
# The $KeepFailed most recent failed (or unfinished) runs stay in full. -CheckOnly deletes nothing and exits 1 if a prunable run still holds an .exe/.pck/.dll.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Runs,
    [int] $KeepFailed = 5,
    [switch] $CheckOnly
)
$ErrorActionPreference = 'Stop'
function Test-Failed($dir) {
    $summary = Join-Path $dir.FullName 'run-summary.json'
    if (-not (Test-Path -LiteralPath $summary)) { return $true }
    $data = Get-Content -LiteralPath $summary -Raw | ConvertFrom-Json
    foreach ($role in $data.PSObject.Properties) { if ($role.Value.valid -ne $true) { return $true } }
    return $false
}
$dirs = @(Get-ChildItem -LiteralPath $Runs -Directory | Sort-Object LastWriteTime -Descending)
$kept = @($dirs | Where-Object { Test-Failed $_ } | Select-Object -First $KeepFailed).FullName
$left = [Collections.Generic.List[string]]::new()
foreach ($dir in $dirs | Where-Object { $kept -notcontains $_.FullName }) {
    # Copied inputs: binaries and the probe source copy. Files only, one at a time.
    $files = @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File | Where-Object { $_.Extension -in '.exe', '.pck', '.dll' -or $_.FullName -like (Join-Path $dir.FullName 'probe\*') })
    foreach ($file in $files) {
        if ($CheckOnly) { if ($file.Extension -in '.exe', '.pck', '.dll') { $left.Add($file.FullName) } }
        else { Remove-Item -LiteralPath $file.FullName -Force }
    }
}
if ($left.Count) { $left | ForEach-Object { Write-Output "RUN_RETENTION_LEFTOVER $_" }; exit 1 }
Write-Output "RUN_RETENTION_OK runs=$($dirs.Count) kept_failed=$($kept.Count)"

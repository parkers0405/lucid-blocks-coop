# Regression check: prune_runs.ps1 leaves no .exe/.pck in finished runs, keeps the newest failed runs in full and keeps logs.
$ErrorActionPreference = 'Stop'
$prune = Join-Path $PSScriptRoot '../../scripts/prune_runs.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('retention-' + [guid]::NewGuid().ToString('N'))
try {
    foreach ($i in 1..8) {
        $run = Join-Path $root "run$i"
        [IO.Directory]::CreateDirectory((Join-Path $run 'probe/mods')) | Out-Null
        'x' | Set-Content (Join-Path $run 'zz-local-coop.pck'); 'x' | Set-Content (Join-Path $run 'a.exe'); 'log' | Set-Content (Join-Path $run 'host.stdout.log')
        $valid = $i -le 2   # run1-2 pass, run3-8 fail
        (@{ host = @{ valid = $valid } } | ConvertTo-Json -Depth 3) | Set-Content (Join-Path $run 'run-summary.json')
        (Get-Item $run).LastWriteTime = (Get-Date).AddMinutes($i)
    }
    & $prune -Runs $root -CheckOnly *> $null
    if ($LASTEXITCODE -ne 1) { throw 'Check did not flag unpruned runs.' }
    & $prune -Runs $root *> $null
    & $prune -Runs $root -CheckOnly | Out-Null
    $survivors = @(Get-ChildItem $root -Recurse -File | Where-Object Extension -in '.exe', '.pck')
    # failed run3..8, newest = run8..run4 kept in full (2 files each); run3 and passed runs 1-2 pruned
    if ($survivors.Count -ne 10) { throw "Expected 10 binaries in the 5 kept failed runs, got $($survivors.Count)." }
    if (@(Get-ChildItem $root -Recurse -File -Filter host.stdout.log).Count -ne 8) { throw 'Logs must survive pruning.' }
    Write-Output 'RUN_RETENTION_CHECK_PASS'
}
finally { Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue | Remove-Item -Force; Get-ChildItem $root -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Remove-Item -Force; Remove-Item $root -Force -ErrorAction SilentlyContinue }

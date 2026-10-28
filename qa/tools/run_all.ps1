# Runs every QA scenario sequentially, captures logs, checks them.
# Usage: powershell -ExecutionPolicy Bypass -File qa/tools/run_all.ps1 [-Godot <exe>] [-Python <exe>]
param(
    [string]$Godot  = "W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Python = "python",
    # Milestone label for the before_set scenario (b0..b4); PNGs land in qa/evidence/before_set/<tag>/.
    [ValidateSet("b0", "b1", "b2", "b3", "b4")]
    [string]$BeforeTag = "b0"
)
$ErrorActionPreference = "Continue"
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    Write-Host "Godot not found: $Godot (pass -Godot <path to Godot console exe>)"
    exit 1
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    $cmd = Get-Command $Python -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Write-Host "Python not found: $Python (pass -Python <path to python.exe>)"
        exit 1
    }
    $Python = $cmd.Source
}
$Project = (Resolve-Path "$PSScriptRoot\..\..").Path
$Logs    = Join-Path $Project "qa\evidence\_logs"
New-Item -ItemType Directory -Force -Path $Logs | Out-Null

# scenario -> --quit-after frame safety limit (scenarios quit themselves earlier)
# Limits are frames, and uncapped FPS runs at ~500, so they must be generous: a scenario cut off
# by --quit-after exits 0 without metrics.json, which the metrics check below reports as a failure.
$Scenarios = [ordered]@{
    smoke = 20000; load_all = 20000; animation_gallery = 40000; traversal_bot = 100000
    city_flythrough = 200000; combat_bot = 100000; perf_sweep = 200000
    gadget_bot = 60000; progression_bot = 20000; stealth_bot = 60000; base_waves = 200000
    menu_bot = 40000; damage_bot = 60000; world_stream_bot = 60000; facing_bot = 40000; car_model_bot = 40000
    ko_bot = 600000; street_bot = 300000; park_bot = 600000; prop_gallery = 100000; material_bot = 40000
    before_set = 100000; building_gallery = 400000; facade_bot = 600000
    regression = 600000; soak10 = 900000
}
# Iteration 3: extra user args per scenario (before_set needs the milestone tag).
$ExtraArgs = @{ before_set = @("--tag=$BeforeTag") }
$Results = @()
foreach ($s in $Scenarios.Keys) {
    $log = Join-Path $Logs "$s.log"
    $metrics = Join-Path $Project "qa\evidence\$s\metrics.json"
    if (Test-Path -LiteralPath $metrics) { Remove-Item -LiteralPath $metrics -Force }
    Write-Host "=== $s ==="
    $userArgs = @("--qa=$s")
    if ($ExtraArgs.ContainsKey($s)) { $userArgs += $ExtraArgs[$s] }
    # PS 5.1 `*>` writes UTF-16 LE; pipe through Out-String and write UTF-8 explicitly.
    $out = & $Godot --path $Project --quit-after $Scenarios[$s] -- @userArgs 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    [System.IO.File]::WriteAllLines($log, [string[]]$out, (New-Object System.Text.UTF8Encoding($false)))
    & $Python (Join-Path $Project "qa\tools\check_log.py") $log
    $logCode = $LASTEXITCODE
    $passed = $false
    if (Test-Path -LiteralPath $metrics) {
        try { $passed = [bool]((Get-Content -Raw -LiteralPath $metrics | ConvertFrom-Json).pass) } catch { $passed = $false }
    }
    $Results += [pscustomobject]@{ scenario = $s; exit = $code; log_clean = ($logCode -eq 0); metrics_pass = $passed }
}
$Results | Format-Table -AutoSize
& $Python (Join-Path $Project "qa\tools\summarize_evidence.py")
$sumCode = $LASTEXITCODE
# Iteration 3 building gates (density, shimmer, texture memory, FPS, draw calls).
& $Python (Join-Path $Project "qa\tools\check_building_metrics.py") `
    (Join-Path $Project "qa\evidence\facade_bot\metrics.json") `
    (Join-Path $Project "qa\evidence\building_gallery\metrics.json") `
    (Join-Path $Project "qa\evidence\before_set\metrics.json")
$bldCode = $LASTEXITCODE
if ($sumCode -ne 0 -or $bldCode -ne 0 -or ($Results | Where-Object { $_.exit -ne 0 -or -not $_.log_clean -or -not $_.metrics_pass })) { exit 1 } else { exit 0 }

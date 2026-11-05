param(
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$SkipBenchmark,
    [string]$ResultsDir = '.godot-test-results'
)
. (Join-Path $PSScriptRoot 'godot_helpers.ps1')
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
try { $godot = Resolve-GodotBinary $GodotBin } catch { Write-Error $_; exit 1 }

$checks = @(
    @{Name='import'; Args=@('--editor', '--import', '--quit')},
    @{Name='resources'; Args=@('--script', 'res://tests/test_resource_loading.gd')},
    @{Name='unit'; Args=@('res://tests/test_dungeon_generator_unit.tscn')},
    @{Name='properties'; Args=@('res://tests/test_dungeon_properties.tscn')},
    @{Name='combat'; Args=@('res://tests/test_orc_battle.tscn')},
    @{Name='reviewer'; Args=@('res://tests/test_reviewer_concurrency.tscn')},
    @{Name='mechanics'; Args=@('res://tests/test_new_mechanics.tscn')},
    @{Name='backdrop'; Args=@('res://tests/test_visual_backdrop.tscn')},
    @{Name='skeleton_king'; Args=@('res://tests/test_skeleton_king.tscn')},
    @{Name='doraemon'; Args=@('res://tests/test_doraemon.tscn')},
    @{Name='yugi'; Args=@('res://tests/test_yugi.tscn')},
    @{Name='werewolf'; Args=@('res://tests/test_werewolf.tscn')},
    @{Name='hud_inventory'; Args=@('res://tests/test_moba_hud_and_inventory.tscn')},
    @{Name='replay_security'; Args=@('res://tests/test_replay_security.tscn')}
)
if (-not $SkipBenchmark) {
    $checks += @{Name='benchmark'; Args=@('res://benchmarks/benchmark_dungeon_generator.tscn')}
}
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force -Path $ResultsDir -ErrorAction Stop | Out-Null
    $testEnvironment = @{}
    foreach ($entry in @{'APPDATA'='appdata'; 'LOCALAPPDATA'='localappdata'; 'TEMP'='tmp'; 'TMP'='tmp'}.GetEnumerator()) {
        $directory = Join-Path ([System.IO.Path]::GetFullPath($ResultsDir)) "userdata/$($entry.Value)"
        New-Item -ItemType Directory -Force -Path $directory -ErrorAction Stop | Out-Null
        $testEnvironment[$entry.Key] = $directory
    }
    foreach ($check in $checks) {
        Write-Host "Running $($check.Name)..."
        $argsForCheck = @('--headless', '--path', $projectRoot) + $check.Args
        # A cold cache can report a project font before the importer creates it.
        # Retry only import, once, retaining both logs. Tests are never retried.
        $attempts = if ($check.Name -eq 'import') { 2 } else { 1 }
        for ($attempt = 1; $attempt -le $attempts; $attempt++) {
            # Capture both native streams explicitly, including Windows console launchers.
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = $godot
            $startInfo.Arguments = ($argsForCheck | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
            $startInfo.WorkingDirectory = $projectRoot
            $startInfo.UseShellExecute = $false
            $startInfo.CreateNoWindow = $true
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            # Keep GameManager user:// writes and engine caches out of the real player profile.
            foreach ($key in $testEnvironment.Keys) {
                $startInfo.EnvironmentVariables[$key] = $testEnvironment[$key]
            }
            $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $startInfo
            try {
                [void]$process.Start()
                $stdout = $process.StandardOutput.ReadToEndAsync()
                $stderr = $process.StandardError.ReadToEndAsync()
                $process.WaitForExit()
                $code = $process.ExitCode
                $output = ($stdout.Result + $stderr.Result) -split '\r?\n'
            } finally { $process.Dispose() }
            $logName = if ($attempt -eq 1) { "$($check.Name).log" } else { "$($check.Name)_retry.log" }
            @("# engine: $godot", "# args: $($argsForCheck -join ' ')", "# exit code: $code") + $output |
                Set-Content -LiteralPath (Join-Path $ResultsDir $logName) -Encoding UTF8
            $output | ForEach-Object { Write-Host $_ }
            # Godot can exit 0 after a script parse error; also inspect diagnostics.
            $errors = @($output | Where-Object {
                $_ -match '^(SCRIPT ERROR:|ERROR:)|\[FAIL\]|^FAIL[!:]' -and
                $_ -notmatch '^ERROR: Failed to read the root certificate store\.$'
            })
            if ($code -eq 0 -and $errors.Count -eq 0) { break }
            if ($attempt -lt $attempts) {
                Write-Warning "Import reported errors; retrying once. First attempt saved in $logName."
            } else {
                Write-Error "$($check.Name) failed (exit $code). See $ResultsDir."
                exit 1
            }
        }
    }
    Write-Host "All $($checks.Count) checks completed. Logs: $ResultsDir"
} finally { Pop-Location }

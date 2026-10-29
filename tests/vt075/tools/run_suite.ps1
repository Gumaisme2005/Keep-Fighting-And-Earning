# VT-075 - chay mot bo test cua Godot va ghi evidence (commit, lenh, output, exit code).
# Vi du:
#   powershell -File tests/vt075/tools/run_suite.ps1 -Out docs/vt075/evidence/01_red_v0.log
#   powershell -File tests/vt075/tools/run_suite.ps1 -Out x.log -Scene res://tests/test_dungeon_generator_unit.tscn
#   powershell -File tests/vt075/tools/run_suite.ps1 -Out x.log -EnvVars "VT075_ORDER=reverse;VT075_PERSIST_US=0"
param(
	[Parameter(Mandatory = $true)][string]$Out,
	[string]$Scene = "res://tests/test_reviewer_concurrency.tscn",
	[string]$EnvVars = "",
	[switch]$Quiet
)
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe" }
$saved = @{}
foreach ($pair in ($EnvVars -split ";" | Where-Object { $_ -ne "" })) {
	$k, $v = $pair -split "=", 2
	$saved[$k] = [Environment]::GetEnvironmentVariable($k)
	[Environment]::SetEnvironmentVariable($k, $v)
}
$commit = (git rev-parse HEAD).Trim()
$dirty = if ((git status --porcelain)) { "dirty" } else { "clean" }
$branch = (git branch --show-current).Trim()
$lines = @()
$lines += "# commit: $commit ($dirty) branch: $branch"
$lines += "# date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
$lines += "# godot: $((& $godot --version).Trim())"
$lines += "# cmd: godot --headless $Scene   env: $EnvVars"
$output = & $godot --headless $Scene 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$lines += $output
$lines += "# exit code: $code"
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$lines | Set-Content -Path $Out -Encoding UTF8
foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
if (-not $Quiet) { $lines }
exit $code

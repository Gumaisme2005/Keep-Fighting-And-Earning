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
. (Join-Path $PSScriptRoot '../../../tools/godot_helpers.ps1')
$godot = Resolve-GodotBinary
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$saved = @{}
foreach ($pair in ($EnvVars -split ";" | Where-Object { $_ -ne "" })) {
	$k, $v = $pair -split "=", 2
	$saved[$k] = [Environment]::GetEnvironmentVariable($k)
	[Environment]::SetEnvironmentVariable($k, $v)
}
$commit = 'unavailable (no Git metadata or Git CLI)'
$dirty = 'unknown'
$branch = 'unknown'
if ((Test-Path (Join-Path $projectRoot '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
	$commit = (git -C $projectRoot rev-parse HEAD).Trim()
	$dirty = if ((git -C $projectRoot status --porcelain)) { 'dirty' } else { 'clean' }
	$branch = (git -C $projectRoot branch --show-current).Trim()
}
$lines = @()
$lines += "# commit: $commit ($dirty) branch: $branch"
$lines += "# date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
$lines += "# godot: $((& $godot --version).Trim())"
$lines += "# cmd: godot --headless --path `"$projectRoot`" $Scene   env: $EnvVars"
$output = & $godot --headless --path $projectRoot $Scene 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$lines += $output
$lines += "# exit code: $code"
$outDir = Split-Path $Out
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$lines | Set-Content -Path $Out -Encoding UTF8
foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
if (-not $Quiet) { $lines }
exit $code


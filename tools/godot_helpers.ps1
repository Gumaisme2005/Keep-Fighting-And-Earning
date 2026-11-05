# Shared CLI discovery for local test tools. Dot-source this file.
function Resolve-GodotBinary {
    param([string]$GodotBin = $env:GODOT_BIN)
    if ($GodotBin) {
        if (Test-Path -LiteralPath $GodotBin -PathType Leaf) {
            return (Resolve-Path -LiteralPath $GodotBin).Path
        }
        $command = Get-Command $GodotBin -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
        throw "GODOT_BIN does not point to an executable: $GodotBin"
    }
    foreach ($name in @('godot', 'godot4')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    throw 'Godot not found. Set GODOT_BIN to your Godot 4.7.2 executable, or add it to PATH.'
}

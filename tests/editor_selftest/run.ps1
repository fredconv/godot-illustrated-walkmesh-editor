# Runs the editor self-test: the real Godot editor (headless) with the IWE plugin enabled, the dock
# instantiated inside the editor, and the test walk exercised. Prints the SELFTEST lines.
# It works on a temporary copy of the project, so the real project and its .godot cache stay untouched.
# Usage: pwsh tests/editor_selftest/run.ps1 -Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe"
param([Parameter(Mandatory = $true)][string]$Godot)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("iwe_editor_selftest_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path "$work\addons\iwe_selftest" | Out-Null
Copy-Item "$root\addons\illustrated_walkmesh_editor" "$work\addons\illustrated_walkmesh_editor" -Recurse
Copy-Item "$root\assets", "$root\tests", "$root\icon.svg", "$root\icon.svg.import" $work -Recurse
Copy-Item "$PSScriptRoot\plugin.cfg", "$PSScriptRoot\plugin.gd" "$work\addons\iwe_selftest"
@'
config_version=5

[application]

config/name="IWE editor selftest"
config/features=PackedStringArray("4.7", "GL Compatibility")

[editor_plugins]

enabled=PackedStringArray("res://addons/illustrated_walkmesh_editor/plugin.cfg", "res://addons/iwe_selftest/plugin.cfg")

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

renderer/rendering_method="gl_compatibility"
'@ | Set-Content "$work\project.godot"
& $Godot --headless --path $work --import | Out-Null
& $Godot --headless --editor --path $work 2>&1 | Select-String "SELFTEST|SCRIPT ERROR|Parse Error"
Remove-Item $work -Recurse -Force

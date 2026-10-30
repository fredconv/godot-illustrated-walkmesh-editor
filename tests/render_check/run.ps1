# Renders the village stage on a real GPU window and checks the fountain hides the character.
# Works on a temporary copy of the project. Set IWE_RENDER_OUT to a folder to keep the screenshots.
# Usage: pwsh tests/render_check/run.ps1 -Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe"
param([Parameter(Mandatory = $true)][string]$Godot)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("iwe_render_check_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path "$work\addons" | Out-Null
Copy-Item "$root\addons\illustrated_walkmesh_editor" "$work\addons\illustrated_walkmesh_editor" -Recurse
Copy-Item "$root\assets", "$root\tests", "$root\examples", "$root\icon.svg", "$root\icon.svg.import" $work -Recurse
Copy-Item "$PSScriptRoot\render.gd" $work
@'
config_version=5

[application]

config/name="IWE render check"
config/features=PackedStringArray("4.7", "GL Compatibility")

[rendering]

renderer/rendering_method="gl_compatibility"

[physics]

3d/physics_engine="Jolt Physics"
'@ | Set-Content "$work\project.godot"
& $Godot --headless --path $work --import | Out-Null
& $Godot --path $work --resolution 1280x720 --script render.gd 2>&1 | Select-String "RENDER|SCRIPT ERROR"
$code = $LASTEXITCODE
Remove-Item $work -Recurse -Force
exit $code

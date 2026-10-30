# Renders the README screenshots from the real plugin on a real GPU window. Works on a temporary copy of
# the project (the real project and its .godot cache stay untouched). Only the Godot window is captured.
# Usage: pwsh tests/render_check/readme_shots.ps1 -Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe" -Out assets\screenshots
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$Out = "assets\screenshots"
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$outFolder = if ([System.IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $root $Out }
New-Item -ItemType Directory -Force $outFolder | Out-Null
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("iwe_readme_shots_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path "$work\addons" | Out-Null
Copy-Item "$root\addons\illustrated_walkmesh_editor" "$work\addons\illustrated_walkmesh_editor" -Recurse
Copy-Item "$root\assets", "$root\tests", "$root\examples", "$root\icon.svg", "$root\icon.svg.import" $work -Recurse
@'
config_version=5

[application]

config/name="IWE screenshots"
config/features=PackedStringArray("4.7", "GL Compatibility")

[rendering]

renderer/rendering_method="gl_compatibility"

[physics]

3d/physics_engine="Jolt Physics"
'@ | Set-Content "$work\project.godot"
& $Godot --headless --path $work --import | Out-Null
$env:IWE_SHOT_OUT = $outFolder
& $Godot --path $work --resolution 1400x900 --script tests/render_check/readme_shots.gd 2>&1 | Select-String "SHOT|SCRIPT ERROR|Parse Error|ERROR"
$code = $LASTEXITCODE
# The occlusion renders of the stage, from the existing render check.
$env:IWE_RENDER_OUT = $outFolder
& $Godot --path $work --resolution 1280x720 --script tests/render_check/render.gd 2>&1 | Select-String "RENDER|SCRIPT ERROR"
Remove-Item $work -Recurse -Force
exit $code

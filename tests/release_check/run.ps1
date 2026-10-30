# Packages the addon exactly as a release would (git archive of the committed files), unpacks it into an
# EMPTY Godot project that contains nothing else, enables it, starts the real editor headless and runs the
# smoke plugin. Prints the editor errors (there must be none) and the SMOKE lines.
# Usage: pwsh tests/release_check/run.ps1 -Godot "C:\path\to\Godot_v4.7.1-stable_win64_console.exe" [-Zip out.zip]
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$Zip = ""
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("iwe_release_check_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
$archive = if ($Zip -ne "") { $Zip } else { Join-Path $work "addon.zip" }
git -C $root archive --format=zip --output=$archive HEAD addons/illustrated_walkmesh_editor LICENSE
if ($LASTEXITCODE -ne 0) { throw "git archive failed" }

$project = Join-Path $work "blank_project"
New-Item -ItemType Directory -Path $project | Out-Null
Expand-Archive -Path $archive -DestinationPath $project
New-Item -ItemType Directory -Path "$project\addons\iwe_release_smoke" | Out-Null
Copy-Item "$PSScriptRoot\smoke_plugin.gd" "$project\addons\iwe_release_smoke\plugin.gd"
@'
[plugin]

name="IWE release smoke"
description="Smoke test."
author="test"
version="1.0"
script="plugin.gd"
'@ | Set-Content "$project\addons\iwe_release_smoke\plugin.cfg"
@'
config_version=5

[application]

config/name="Blank project"
config/features=PackedStringArray("4.7", "GL Compatibility")

[editor_plugins]

enabled=PackedStringArray("res://addons/illustrated_walkmesh_editor/plugin.cfg", "res://addons/iwe_release_smoke/plugin.cfg")

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

renderer/rendering_method="gl_compatibility"
'@ | Set-Content "$project\project.godot"

Write-Output "Files in the package:"
Get-ChildItem "$project\addons\illustrated_walkmesh_editor" -Recurse -File | Measure-Object | ForEach-Object { "  $($_.Count) files" }
& $Godot --headless --path $project --import 2>&1 | Out-Null
$log = & $Godot --headless --editor --path $project 2>&1
$log | Select-String "SMOKE|SCRIPT ERROR|Parse Error|ERROR|WARNING" | ForEach-Object { $_.Line }
$exit = $LASTEXITCODE
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
if ($Zip -ne "") { Write-Output "Package kept at $Zip" }
exit $exit

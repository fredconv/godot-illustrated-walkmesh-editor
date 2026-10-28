# Development Guide

## Requirements

- **Godot 4.7.1** (the validation target). Other 4.x versions are untested.
- **GdUnit4 6.2.2** for the test suite (installed locally or by CI, see below).
- Git.

## Optional development tools

None of these are needed to use or test the plugin.

| Tool | Used for | Notes |
|---|---|---|
| UniBuilder | Level geometry modelling in the viewport | Commercial licence (end-user licence agreement). It is **not** part of this repository and must not be redistributed. |
| Godot MCP Pro | AI-assisted control of the editor during development | Local development only. Not part of the plugin. |
| Phantom Camera | Camera experiments | Not used by IWE. |

If you enable any of these in your own project, the project still opens without them: IWE does not depend on them.

## Set up the project

1. Clone the repository and open the folder as a Godot 4.7 project.
2. The repository's `project.godot` enables no plugins. Enable **Illustrated Walkmesh Editor** under *Project → Project Settings → Plugins*.
3. Restart the editor after changing dock scripts or the dock scene (`ui/iwe_dock.tscn`). Godot caches scripts and scenes, so disabling and re-enabling the plugin is not always enough.

## Install GdUnit4 locally

The test addon is excluded from Git. Install the pinned version once:

1. Download the source archive of the tag `v6.2.2`:
   `https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v6.2.2.zip`
2. Extract it and copy its `addons/gdUnit4` folder into this project's `addons/` folder.
3. Enable **GdUnit4** in *Project Settings → Plugins*, then open the editor once so Godot builds its class cache.

Do not commit `addons/gdUnit4/`. It is listed in `.gitignore`.

## Run the tests (headless)

From the project root, with the Godot 4.7.1 executable on your path or referenced by its full path:

```powershell
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add "res://tests" --ignoreHeadlessMode
```

A successful run prints `Exit code: 0` and reports the number of test cases (currently 28). Reports are written to `reports/`, which is ignored by Git.

The same command runs in continuous integration (`.github/workflows/tests.yml`), which downloads the pinned versions of Godot and GdUnit4.

The suite covers:

- Document serialization, including regions, cutouts, groups, templates, calibration, and the schema version.
- Polygon editing: vertex movement, insertion, removal, and undo/redo.
- Subtractive cutouts and their derived contours.
- Perspective projection and floor intersections.
- Scale templates: placement, movement, resizing, and undo.
- Scene exports (2D, 3D, perspective) with reload checks.
- Walking across connected walkable zones, and walls on outer edges.
- Floating illustration window and the save/open workflow.

### What headless tests cannot cover

Clicking inside the real editor, drawing polygons with the mouse, and visual layout are not tested automatically. Check these by hand before a release:

1. Open `examples/perspective_calibration_demo.tscn`.
2. Import an illustration, draw two touching zones, and run the scene. Walk across the shared edge.
3. Open the illustration window, place templates, save, close the project, and reopen.

## Regenerating the demo scene: stale editor state

`examples/perspective_calibration_demo.tscn` is written by `examples/generate_perspective_demo.gd`. Regenerating it on disk while the same scene is open in the editor is unsafe:

- The editor keeps its own copy of an open scene. **Saving that tab overwrites the regenerated file** with the editor's older copy, without a warning.
- Verified on 2026-10-29 with a copy of the demo: after an external change on disk, a save from the editor restored the previous value (`snap_tolerance` 0.5 became 0.864 again).
- Headless save and reload preserve every value checked (`snap_tolerance`, anchor IDs), so Godot's serialization is not the cause.

**Procedure**

1. Close the demo tab, or make sure it has no unsaved changes.
2. Run the generator headless (command in `prototypes/occlusion/README.md`, with `generate_perspective_demo.gd` instead).
3. Reopen the demo scene in the editor. Do not save it before reopening.
4. Check `Player → snap_tolerance` (expected `0.864`) before saving anything.

Generated anchor IDs are random on each run, so regenerating the demo produces a noisy diff even when nothing else changed. A deterministic ID scheme for the demo generator is a planned improvement.

## Versioning

- The plugin version is `version` in `addons/illustrated_walkmesh_editor/plugin.cfg`. It is currently `0.1.0-dev`.
- The saved document format is versioned separately (`schema_version`, see `DATA_FORMAT.md`).
- Changes are recorded in `CHANGELOG.md` under `[Unreleased]`.

## Project layout

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the real folder layout and the target structure.

## Coding notes

- Keep geometry and data code free of editor APIs so it can run headless.
- All user-visible strings are in English.
- Saved data changes must follow [`DATA_FORMAT.md`](DATA_FORMAT.md).

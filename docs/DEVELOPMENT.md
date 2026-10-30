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

A successful run prints `Exit code: 0` and reports the number of test cases (currently 297). Reports are written to `reports/`, which is ignored by Git.

The same command runs in continuous integration (`.github/workflows/tests.yml`), which downloads the pinned versions of Godot and GdUnit4.

The suite covers:

- Document serialization, including regions, cutouts, groups, templates, calibration, and the schema version.
- Polygon editing: vertex movement, insertion, removal, and undo/redo on Godot's real `UndoRedo` (no test doubles).
- Per-document history: opening or creating a document never replays the previous document's actions.
- Unsaved-change state (`IWEDocumentHistory`): clean, modified, undo back to the saved state, redo, and the case where a new action after an undo makes the saved state unreachable.
- The prompts for New and Open (Save, Discard Changes, Cancel), failed saves, documents without a path, and the dock methods behind `_get_unsaved_status` and `_save_external_data`.
- Subtractive cutouts and their derived contours.
- Perspective projection and floor intersections.
- Scale templates: placement, movement, resizing, and undo.
- Scene exports (2D, 3D, perspective) with reload checks.
- Walking across connected walkable zones, and walls on outer edges.
- Floating illustration window and the save/open workflow.

### Render check

`tests/render_check/run.ps1` renders the village stage with its foreground fountain in a real window (it needs a GPU, so it is not part of CI) and counts the pixels of the test character behind and in front of the fountain. See `docs/DECISIONS.md` for what it proves. Set `IWE_RENDER_OUT` to keep the screenshots.

### Editor self-test

`tests/editor_selftest/run.ps1` runs the dock inside the real Godot editor (headless editor mode, on a temporary copy of the project) and exercises the test walk there. See its README. It uses no mouse.

### What headless tests cannot cover

`EditorPlugin` cannot be instantiated outside the editor, so the tests exercise the dock methods that the plugin hooks forward to, not the hooks themselves.

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

## Manual check: unsaved-change protection

Run this in the real editor after any change to saving, loading, or the history. Use a scratch project or a document you do not need.

1. Enable the plugin. The toolbar shows `Untitled` with no `*`.
2. Import an illustration and draw a region. The label becomes `Untitled *`.
3. Close Godot. The *Save before closing?* dialog must show the IWE message. Choose **Cancel**: the editor stays open and the document is unchanged.
4. Close a Godot scene tab. No IWE message appears.
5. Click `Save`, choose a folder, and accept the copy of the image. The label shows the file name without `*`.
6. Draw another region (`name *`), press `Undo` (`name`), `Redo` (`name *`), `Undo` (`name`).
7. Choose `New` while the label has a `*`: the Save / Discard Changes / Cancel question appears. `Cancel` keeps the document.
8. Close Godot with the label clean. No IWE message appears and Godot closes.
9. Never-saved document: draw a region, close Godot, choose **Save & Quit** or run `Save All`. A file appears in the project's `user://iwe_recovery/` folder, and the label keeps its `*`.

Checked in the editor for Godot 4.7.1 on 2026-10-29: steps 1 to 6 and step 8. The buttons were driven through their signals by script, not with the mouse. Steps 7 and 9 are covered by automated tests only; they have not been run by hand in the editor.

### Manual check: perspective stability

1. Import an illustration, switch to `Perspective`, and note the status line and a template's position in the preview.
2. Drag the split between the canvas and the side panel, and open and close the `Window`. The preview keeps the reference aspect ratio, the projection does not move, and the label does not gain a `*`.
3. Change `Reference frame` width: the projection changes, the label gains a `*`, and `Undo` restores it.

Checked in the editor for Godot 4.7.1 on 2026-10-29 by script (split offset 170 to 650, and window detach and reattach): reference frame unchanged, floor point identical, document not modified. Not driven with the mouse.

### Manual check: replacing the illustration

1. Draw a region, place a height reference, and fit the camera. Note the camera values.
2. Import another picture of the same size. The regions and the camera values must not change, and the label gains a `*`. `Undo` restores the first picture.
3. Import a picture of another size. A confirmation asks first. `Cancel` changes nothing; `Replace illustration` swaps the picture and `Undo` restores it.

Checked headless only (`tests/test_illustration_reimport.gd`, `tests/e2e/`); the dialog was not clicked in the real editor.

### End-to-end scenario

`tests/e2e/README.md` describes the village and fountain scenario, its four suites, and its pinned known defects.

## Versioning

- The plugin version is `version` in `addons/illustrated_walkmesh_editor/plugin.cfg`. It is currently `0.1.0-alpha.4`.
- The saved document format is versioned separately (`schema_version`, see `DATA_FORMAT.md`).
- Changes are recorded in `CHANGELOG.md` under `[Unreleased]`.

## Project layout

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the real folder layout and the target structure.

## Coding notes

- Keep geometry and data code free of editor APIs so it can run headless.
- All user-visible strings are in English.
- Saved data changes must follow [`DATA_FORMAT.md`](DATA_FORMAT.md).

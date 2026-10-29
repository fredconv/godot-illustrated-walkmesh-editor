# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/). While the version is `0.x`, the API and the document format may still change between releases; each change that affects saved documents is called out explicitly.

## [Unreleased]

### Added
- The perspective export warns about a doorway narrower than the character's diameter, naming the zone and where it is. The planner still cannot route around it, so this is a report, not a fix. Tests also pin that a cutout stays an obstacle when another zone overlaps its zone elsewhere, and that ground covered by a second zone is walkable under the union rule.
- Portable documents (audit P1-7). Saving always copies the picture beside the document and stores a path relative to it, so moving the project folder keeps it working. The extra folder prompt is gone. Fixes Save As, which kept pointing at the first folder's picture and left the new folder without one.
- Small exports (audit P1-8). An exported scene references a picture inside the project instead of embedding its pixels (126 KB instead of 6.4 MB on the village scene). A picture that is not imported yet is imported by the editor at export time.
- Document format version (audit P1-9). Every saved file names its `schema_version`. A file from a newer version is refused with both version numbers and is not touched. Files from before the field still open.
- Stable cutout identifiers, region and cutout identifiers on exported nodes (`iwe_region_id`, `iwe_cutout_id`), and a reference validator that warns about broken references when a document is opened.
- Click-to-move keeps a clearance from corners (audit N-2). The planner's paths touched obstacle and doorway corners, which a character with a radius could not round. `IWEWalkmeshCharacter.path_clearance` (default 0, set to the character radius by the export) moves each corner of a planned path away from the edge while it stays walkable.
- Perspective export warnings (audit P1-3). A zone or template that lies at or above the horizon of the calibrated camera used to disappear from the export without a word. Each one is now named in the Output panel, the dock status shows the count, and `IWESceneGenerator.take_warnings(root)` returns them for scripts.
- Overlapping zones are walkable as one (audit P1-2). Click-to-move crosses from one zone to another where they overlap, in both directions and across chains of three. The zone drawn first keeps the shared ground; a later zone's navigation mesh stops on its outline.
- End-to-end validation scenario on new assets (`tests/e2e/`): the village background and the fountain foreground, authored from an empty document. 31 tests cover import, polygons, cutout union, undo and redo, save and reopen, calibration, perspective export, and walking around the fountain at several speeds. Known defects found by it are pinned by tests that say so. `docs/PRE_RELEASE_AUDIT.md` is the pre-release inventory and the proposed plan to the first release.
- Testing speed for the test character: `set_speed_multiplier` (x0.1 to x10, presets x1, x2, x5, x10), `get_effective_speed`, `pause`, `resume`, `reset_position`. The multiplier is never saved or exported, and no depth-based scaling is added: perspective comes from the camera. Controls in the dock are not part of this change.
- Protection against losing unsaved work (audit P1-6). The dock shows the document name with a `*` when it has changes that are not saved, and the mark follows Undo and Redo: returning to the saved state clears it. Creating a new document or opening another one asks `Save`, `Discard Changes`, or `Cancel` first. Godot's own quit dialog now lists an unsaved IWE document, `Save All` writes it in place when it has a path, and a document that was never saved gets a recovery copy in `user://iwe_recovery/` instead of being lost. A failed save is reported, keeps the document modified, and does not run the action that was waiting.
- Floating illustration window (`Window` button) that gives the whole illustration room on screen; closing it returns the canvas to the dock.
- Document `schema_version` field (value `1`), so future format changes can be detected and migrated.
- Headless regression tests: full workflow (regions, cutouts, templates, 2D/3D/perspective exports, save and reopen), window toggling, save-folder creation, and connected walkable zones.
- Project documentation: `docs/SPECIFICATION.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- User guide with installation steps, `docs/USER_GUIDE.md`; development guide, `docs/DEVELOPMENT.md`; data format and compatibility rules, `docs/DATA_FORMAT.md`.
- Repository governance: `CONTRIBUTING.md` (including the policy for AI-assisted contributions), `CODE_OF_CONDUCT.md`, `SECURITY.md`.
- GitHub issue and pull request templates.
- Headless test workflow `.github/workflows/tests.yml`. It installs GdUnit4 6.2.2 and the Godot 4.7.1 console build at pinned versions, and runs on every push and pull request.
- Layer Manager design proposal, `docs/LAYER_MANAGER_DESIGN.md`: architecture, schema version 2 migration guarantees, asset handling, and the transparency-technique study. Design only; no layer feature is implemented.

### Changed
- Perspective calibration no longer depends on the dock (audit P1-4). The preview panel is locked to the calibration's own reference frame, so resizing the dock, detaching the window, zooming, or changing the editor resolution cannot move the projection, and the preview never writes to the document or marks it modified. New documents take their reference frame from the project's game window instead of the panel size. Two new `Reference frame` inputs in the perspective panel change it deliberately. Each committed change is one undo entry, and a run of arrow-button steps undoes in one go. Saved documents keep their stored reference frame; no migration and no format change.
- The perspective preview no longer asks Godot to resize a stretched SubViewport (it logged a warning on every layout).
- The undo history is now `IWEDocumentHistory`, a thin class around Godot's `UndoRedo` that also remembers which state was saved. Closing a Godot scene never prompts about the IWE document.
- Creating a new document is no longer an undoable action; it starts an empty history, like opening a document.
- `Ctrl+Z`, `Ctrl+Shift+Z`, and `Ctrl+Y` undo and redo IWE edits while the illustration has focus. IWE edits no longer go into the editor's global history.
- Documentation no longer claims that overlapping zones are connected: only zones sharing an exact edge are (audit P1-2 remains open).
- Walls are no longer generated along edges shared with another walkable zone. Touching zones form a continuous walkable network without being merged.
- Save dialog opens inside the project and creates the target folder when it does not exist.
- User-facing labels in the window are in English.
- README restructured after a MIT-licensed reference project: what the plugin does, a screenshot, documentation links, a numbered installation section, and credits. New FAQ in `docs/FAQ.md`.

### Removed
- Test doubles `tests/dock_undo_stub.gd` and `tests/undo_history_stub.gd`. They implemented `undo()` and `redo()`, which the real editor API does not have, and hid audit P0-1. Tests now use Godot's `UndoRedo`.

### Fixed
- Replacing the illustration of a document rebuilt the calibration and overwrote the document silently (audit P1-5). Replacing now swaps the picture only, keeps regions, templates and calibration, and is one undo entry. A picture of another size asks first.
- A picture copied beside a saved document could not be loaded until the editor had imported it, so reopening a document right after saving could show no picture. The dock now reads the file directly when the engine cannot load it.
- The last waypoint of a click-to-move path is reached with a partial step, so the character stops on the target at every walking speed.
- The perspective calibration stored the size of the preview panel as its reference viewport and rewrote it whenever the dock was resized, so the same document projected the floor and the templates differently depending on the layout, and the change was silent (audit P1-4). Only the aspect ratio of the reference frame matters to the projection; it is now explicit and stable.
- The save button opened an *Open* dialog instead of a *Save* dialog (wrong `file_mode`).
- The dock's `Undo` and `Redo` buttons called methods that `EditorUndoRedoManager` does not have, so they failed in the real editor (audit P0-1).
- Overlapping cutouts were subtracted one after another, so their intersection was counted twice: the walkable area and contours were wrong, and navigation and collision received overlapping holes (audit P1-1). The cutouts are now merged into disjoint pieces first. Source cutouts are not modified and the save format is unchanged.
- The undo history was shared across documents: after opening another document, undo or redo could add regions of the previous document to it (audit P0-2). Each document now has its own Godot `UndoRedo`, freed when the document changes.
- Selecting a cutout in the region tree could abort the engine: the tree was rebuilt inside its own selection callback. Selection no longer rebuilds the tree, and interaction signals are deferred. See `docs/REGION_TREE_FIX.md`.

## [0.1.0-dev] — development snapshot

### Added
- Illustration import with pan and zoom.
- Polygon regions: create, select, move, vertex insert/remove/move, rename, duplicate, hide, delete, undo and redo.
- Flat region groups.
- Named subtractive cutouts per region (derived with Godot's clipping API).
- Scale templates in image space, persisted and exported as 3D capsules.
- Perspective calibration: camera field of view and transform, virtual floor height, known character height, and camera fit from two or more height references.
- 2D, flat 3D, and perspective scene exports with optional cameras.
- Save and reopen of IWE documents (`.tres`), copying the illustration beside the document.
- Test character with mouse and keyboard movement, walls, and path following.

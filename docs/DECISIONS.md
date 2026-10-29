# Architecture Decision Records

## 2026-10-22 — Keep image-space geometry authoritative

**Decision:** Store authored points in native source-image coordinates and treat viewport pan/zoom as presentation state.

**Reason:** Editing must not change geometry when the editor viewport changes. This also gives screen-space 2.5D a stable basis without pretending that a painted image determines unique physical depth.

## 2026-10-22 — Preserve source geometry and separate derived output

**Decision:** Treat regions and modifier inputs as editable source resources; keep evaluated geometry and generated runtime nodes derived and regenerable.

**Reason:** Non-destructive editing and deterministic regeneration are core requirements.

## 2026-10-22 — Do not publish bundled starter addons before audit

**Decision:** Exclude the local test, MCP, and camera addons from the initial IWE distribution until their provenance, license compatibility, and need are verified.

**Reason:** The current project contains complete third-party addon trees, and no audit has yet established that redistribution is permitted or desirable.

## 2026-10-22 — Keep exported scene placement separate from template scale

**Decision:** Export an editable root node for scene placement and a child `Template` node for the image-pixel-to-world scale. Export flat 3D navigation by converting the same evaluated 2D contours used for 2D navigation.

**Reason:** The root remains convenient to move and rotate in the host scene, scale does not disappear when Godot packs the root scene, and both outputs share one tested source of truth for Boolean holes. Flat 3D stays explicit until perspective calibration and height authoring exist.

## 2026-10-28 — Touching zones are passages, not merged polygons

**Decision:** Keep polygons separate. A shared edge between two walkable zones produces no wall; outer edges and cutouts keep their walls. Zones that only touch at a point are not connected.

**Reason:** The author draws zones one after another (left path, bridge, right path). Merging polygons would destroy the separate names and editing handles, and would make the layer system harder. The walkable network is derived from the geometry instead.

**Consequence:** The passage rule currently lives in `iwe_scene_generator.gd`. It moves to a pure geometry module in step 3 of the roadmap.

## 2026-10-28 — Three separate systems: layers, geometry and navigation, rendering and depth

**Decision:** Layer organization, geometry and navigation, and rendering and depth are separate data domains. Layer order never affects whether a zone is walkable. Visual elements never create navigation or collision automatically.

**Reason:** A character can pass behind a house while the path continues behind it. Tying navigation to draw order would force the author to contort the layers to fix walkability, and would make occluders block the character by accident.

## 2026-10-28 — Layers are a separate resource tree, not a field on regions

**Decision:** `IWELayer` and `IWEVisualElement` are separate resources referenced by id. Regions keep their geometry and may reference a layer id.

**Reason:** Geometry stays stable when layers are reorganized, and the navigation rules never need to read layer data.

## 2026-10-28 — Add a schema version before new document fields

**Decision:** `IWEDocument` gets a `schema_version` field. Version 1 documents (the current format) load with defaults: every region walkable, no layers, no connections.

**Reason:** The document format has no version today. New fields (region types, connections, layers) would otherwise break old files silently.

## 2026-10-28 — Interface in English, project name provisional

**Decision:** User-facing labels and tooltips are in English. The working name stays IWE until the final public name is chosen.

**Reason:** The public documentation and the GitHub presentation are in English.

## 2026-10-29 — Track unsaved changes with the document's own history

**Decision:** `IWEDocumentHistory` wraps `UndoRedo` and stores the version at the last successful save. A document is modified when the current version differs, when a change happened outside the history, or when the saved state became unreachable. The dock asks before New and Open, and the plugin implements `_get_unsaved_status` and `_save_external_data`.

**Reason:** `UndoRedo.get_version()` goes up on commit and redo and down on undo, so equality with the saved version means "back at the saved state". That fails after an undo followed by a different action. A recovery copy is written for a document without a path, because `_save_external_data` runs while the editor may be closing and must not show a dialog.

**Consequences:** Creating or opening a document starts clean. Importing an illustration is not undoable, so it keeps the document modified until saved. The preview no longer writes to the document (see the 2026-10-29 reference-frame decision), so resizing the dock never changes the modified state.

## 2026-10-29 — A per-document UndoRedo instead of the editor's history

**Decision:** The dock owns a Godot `UndoRedo` for the open document. It is freed and recreated when a document is created or opened. IWE no longer uses `EditorUndoRedoManager`.

**Reason:** The audit confirmed that `EditorUndoRedoManager` has no `undo()`/`redo()` methods, so the dock buttons failed, and that IWE actions went into the editor's global history, where they survived a document change and could inject regions of one document into another. Clearing the global history would also erase other tools' actions.

**Consequences:** Undo is available from the dock buttons and from `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y` while the illustration has focus, but not from Godot's main `Ctrl+Z` elsewhere. Creating or opening a document is not undoable. Tests drive the real `UndoRedo`; no test double reimplements the history.

## 2026-10-29 — The perspective projection uses an explicit reference frame, not the panel size

**Decision:** Three things are kept apart. (1) The persistent calibration, including `reference_viewport_size`, is saved with the document. (2) The projection frame is that reference viewport; only its aspect ratio affects the projection. (3) The editor display transform (`panel_fit`, `panel_to_reference`, `reference_to_panel` in `IWEPerspectiveProjector`) maps the preview panel to the frame with a centred contain-fit and is never saved. The preview panel sits in an `AspectRatioContainer` set to the frame's ratio, and the preview does not write to the document. New documents take the reference from the project's game window; the author can edit it explicitly.

**Reason:** The dock used to copy its own size into the calibration, so the layout changed the projection silently. Verified numerically that the projection depends on the reference aspect only, so a stable aspect gives a stable projection at any panel size.

**Consequences:** Old documents keep the reference they stored, so their projection is unchanged; no migration, no schema change. A document whose stored reference was an accident of the old dock layout keeps that shape; the author can correct it with the `Reference frame` inputs. A fixture of an old document (`tests/fixtures/iwe_document_old_panel_reference.tres`) checks that it loads and projects identically and that its file is not modified.


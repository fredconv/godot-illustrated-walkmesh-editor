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

## 2026-10-29 — Overlapping zones: the earlier zone owns the shared ground

**Decision.** Overlap is supported. When zones overlap, the zone that comes first in the document keeps the shared ground; each later zone's navigation mesh is its walkable area minus the walkable area of every earlier visible zone. Authored outlines, cutouts, guides and walls are not changed.

**Why.** Navigation regions are linked by Godot only where their mesh edges coincide, so two meshes that overlap were never connected. Cutting the later mesh along the earlier outline turns an overlap into a shared border, which is the case that already works (touching zones, partly shared edges). Alternatives rejected: navigation links (their ends snap to the nearest polygon of either region, which is ambiguous inside an overlap) and refusing overlaps (an artist draws a bridge over a path without thinking about edges).

**Consequences.** Region order matters for the mesh split, not for what is walkable: the union is the same in any order (tested). The floor collision of a later zone also covers only its own part. Hidden zones and zones with fewer than three points cover nothing.

## 2026-10-29 — The dock preview's test character moves without physics

**Decision.** `Test walk` in the dock preview puts an `IWEWalkmeshCharacter` in the preview world with `editor_preview` and `kinematic` set: it follows the navigation path by changing its position, with no `move_and_slide`. The class is a tool script that stays still in the editor unless `editor_preview` is set, so a scene containing it never moves while someone edits that scene. Speed settings live in the preview and the dock, never in the document or an export.

**Why.** The editor does not step the physics of a preview world, and the walls only matter for keyboard walking, which the preview does not offer. The navigation path already stays on the walkable area, with the corner clearance. The path request is also repeated for up to 120 frames while the navigation server has not synchronized its regions: its iteration counter can look settled before the regions are in the map, which an editor run showed once.

**Consequences.** A click in test walk never tests the walls; the game build (physics, walls) is what the headless suite and F5 cover.

## 2026-10-29 — Track unsaved changes with the document's own history

**Decision:** `IWEDocumentHistory` wraps `UndoRedo` and stores the version at the last successful save. A document is modified when the current version differs, when a change happened outside the history, or when the saved state became unreachable. The dock asks before New and Open, and the plugin implements `_get_unsaved_status` and `_save_external_data`.

**Reason:** `UndoRedo.get_version()` goes up on commit and redo and down on undo, so equality with the saved version means "back at the saved state". That fails after an undo followed by a different action. A recovery copy is written for a document without a path, because `_save_external_data` runs while the editor may be closing and must not show a dialog.

**Consequences:** Creating or opening a document starts clean. Importing an illustration is not undoable, so it keeps the document modified until saved. The preview no longer writes to the document (see the 2026-10-29 reference-frame decision), so resizing the dock never changes the modified state.

## 2026-10-29 — A per-document UndoRedo instead of the editor's history

**Decision:** The dock owns a Godot `UndoRedo` for the open document. It is freed and recreated when a document is created or opened. IWE no longer uses `EditorUndoRedoManager`.

**Reason:** The audit confirmed that `EditorUndoRedoManager` has no `undo()`/`redo()` methods, so the dock buttons failed, and that IWE actions went into the editor's global history, where they survived a document change and could inject regions of one document into another. Clearing the global history would also erase other tools' actions.

**Consequences:** Undo is available from the dock buttons and from `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y` while the illustration has focus, but not from Godot's main `Ctrl+Z` elsewhere. Creating or opening a document is not undoable. Tests drive the real `UndoRedo`; no test double reimplements the history.

## 2026-10-29 — Replacing the illustration swaps the picture only

**Decision:** Importing into a document that already has an illustration replaces the picture and nothing else. It is one undoable action. A picture of another size asks for confirmation first. The first import still creates a calibration for the new image.

**Reason:** The old code rebuilt the calibration on every import (all six calibration fields were reset, measured against the previous commit). Regions and templates are authored in image pixels, so they cannot be moved or scaled for the author without guessing.

**Consequences:** A different-size picture can leave shapes misaligned until the author adjusts them; the dialog says so and Undo restores everything. Resizing or re-anchoring shapes automatically is left for later.

## 2026-10-29 — The testing speed lives on the character, not in the document

**Decision:** `IWEWalkmeshCharacter` gets `set_speed_multiplier` (x0.1 to x10, presets x1/x2/x5/x10), `get_effective_speed`, `pause`, `resume`, and `reset_position`. Base speed is the existing `move_speed`. The multiplier is a plain variable, not an exported or saved property. No depth-based speed scaling exists: the walk is in world space and the camera produces the apparent speed. Dock controls are scheduled with an in-editor test character (M3), where the multiplier becomes an editor preference and the base speed stays a character property.

**Reason:** The dock preview is a static render with no character, so only the runtime character can walk. A document-level or exported speed would change authored data for a testing convenience.

**Consequences:** The last waypoint is reached with a partial step so the stopping error does not grow with speed. Corner-cutting at x10 is bounded by one step per frame, and walls still stop the character.

## 2026-10-29 — The perspective projection uses an explicit reference frame, not the panel size

**Decision:** Three things are kept apart. (1) The persistent calibration, including `reference_viewport_size`, is saved with the document. (2) The projection frame is that reference viewport; only its aspect ratio affects the projection. (3) The editor display transform (`panel_fit`, `panel_to_reference`, `reference_to_panel` in `IWEPerspectiveProjector`) maps the preview panel to the frame with a centred contain-fit and is never saved. The preview panel sits in an `AspectRatioContainer` set to the frame's ratio, and the preview does not write to the document. New documents take the reference from the project's game window; the author can edit it explicitly.

**Reason:** The dock used to copy its own size into the calibration, so the layout changed the projection silently. Verified numerically that the projection depends on the reference aspect only, so a stable aspect gives a stable projection at any panel size.

**Consequences:** Old documents keep the reference they stored, so their projection is unchanged; no migration, no schema change. A document whose stored reference was an accident of the old dock layout keeps that shape; the author can correct it with the `Reference frame` inputs. A fixture of an old document (`tests/fixtures/iwe_document_old_panel_reference.tres`) checks that it loads and projects identically and that its file is not modified.


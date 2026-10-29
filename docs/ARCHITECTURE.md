# IWE Architecture

This document has two parts: the **current code** as audited on 2026-10-28, and the **target architecture** that the Layer Manager work moves toward. Earlier drafts described folders (`editor/`, `geometry/`, `boolean/`, `scale/`) that do not exist; the layout below is the real one.

## 1. Current layout (audited)

```
addons/illustrated_walkmesh_editor/
├── plugin.gd                      EditorPlugin entry point: adds and removes the dock
├── data/
│   ├── iwe_document.gd            IWEDocument (Resource): image ref, groups, regions, anchors, calibration
│   ├── iwe_region.gd              IWERegion (Resource): id, group_id, name, points, cutouts, color, visible, locked
│   ├── iwe_region_group.gd        IWERegionGroup (Resource): id, name (flat)
│   ├── iwe_scale_anchor.gd        IWEScaleAnchor (Resource): id, name, image position, apparent height px
│   ├── iwe_perspective_calibration.gd  IWEPerspectiveCalibration (Resource): FOV, camera, floor, character height
│   ├── iwe_perspective_projector.gd    Static pure functions: image ↔ viewport ↔ floor mapping
│   └── iwe_scene_generator.gd     Static builders: 2D, 3D, perspective scenes; navigation; walls
├── ui/
│   ├── iwe_dock.tscn / iwe_dock.gd  Dock UI and all document mutations (≈1,400 lines)
│   ├── iwe_canvas.gd              Image canvas: drawing, vertex/region/template hit-testing (≈600 lines)
│   ├── iwe_region_list.gd         Region tree helper
│   └── iwe_perspective_preview.gd SubViewport preview of the calibration
└── runtime/
    └── iwe_walkmesh_character.gd  IWEWalkmeshCharacter (CharacterBody3D): click and keyboard movement
```

Perspective keeps three layers apart: the persistent calibration (saved), the projection frame (the calibration's reference viewport, aspect ratio only), and the editor display transform (panel fit in `IWEPerspectiveProjector`, never saved).

Tests live in the project-level `tests/` folder (GdUnit4), not inside the addon. Current suite: 92 headless tests, all passing.

### 1.1 Data model facts

- The document is a single flat list of regions. Each region points to a group by `group_id`. There is no nesting, no type field, no layer, and no connection or occluder resource.
- Serialization is the Godot default for `Resource`. **There is no schema version field.**
- Stable IDs (`region_…`, `group_…`, `scale_…`) identify items. Names are display-only.
- Cutouts are stored as `subtraction_polygons` with a parallel `subtraction_names` array. Walkable contours are derived on demand by `IWERegion.get_walkable_contours()`.
- `locked` is read by the canvas and dock logic, but **no UI control sets it**.

### 1.2 Where logic currently lives

- **Navigation and connections** are computed in `iwe_scene_generator.gd`. Shared edges between touching zones are detected while building walls (`_edge_is_covered_by_other_zone`). This is correct but misplaced: the rule belongs to the Geometry & Navigation domain, not to scene building, and the 2D export does not yet use it.
- **Undo/redo** uses a Godot `UndoRedo` owned by the dock, one per document (`_history`). It is freed and recreated when a document is created or opened, so actions never apply to another document, and the editor's own histories are not used. The canvas receives the same history. Every mutation goes through `_history.add_do_method(Callable)`.
- **Modified state.** The history is an `IWEDocumentHistory` (`data/iwe_document_history.gd`), a wrapper around `UndoRedo`. It records the undo version at the last successful save. The document is modified when the version differs, or when a change was made outside the history (`note_untracked_change`, used for importing an illustration). A new action committed while a redo is pending makes the saved state unreachable, because `UndoRedo.get_version()` would otherwise return to the saved number with different content.
- **Godot hooks.** `plugin.gd` implements `_get_unsaved_status(for_scene)` and `_save_external_data()` and forwards both to the dock. They are not used for any scene: a non-empty `for_scene` always answers "".
- **The dock** holds UI widgets, document mutations, export, calibration, and file dialogs in one class. It is the main maintenance risk.

## 2. Target architecture

Three systems with separate data, as required by the specification (section 4 of `SPECIFICATION.md`):

| System | Owns | Must not depend on |
|---|---|---|
| **Layer Manager** (`data/layers/`) | Layer tree, order, visibility, lock, opacity, transforms of visual elements, draw order | Navigation results |
| **Geometry & Navigation** (`geometry/`) | Regions and their types, cutouts, connections, collision-only regions, contour derivation, passage rules | Layer order, rendering |
| **Rendering & Depth** (`rendering/`) | Visual elements' depth, occlusion mode, parallax, perspective projection, camera | Writes to geometry (read-only) |

Shared infrastructure stays where it is: `iwe_perspective_projector.gd` is the single source for image ↔ floor mapping and is read by both Geometry (floor points) and Rendering (depth).

### 2.1 Target data additions

- `IWERegion.kind`: walkable, connection, collision_only, special. Default walkable, so existing documents stay valid.
- `IWEConnection` (Resource): ids of two regions, optional width, direction, allowed flag. Only explicit connections bridge zones that do not share an edge.
- `IWELayer` (Resource): id, name, kind (regions or visual), parent id, order, visible, locked, opacity. Regions and visual elements reference a layer id. Layer order is consumed only by drawing and the Rendering system.
- `IWEVisualElement` (Resource): id, layer id, texture path, transform (position, scale, rotation, pivot, flip), opacity, depth mode (background, foreground, occlusion, parallax), depth value, ground anchor.
- `IWEDocument.schema_version`: integer, starts at 2 once added. Loading a version 1 document applies defaults (every region walkable, no layers, no connections).

### 2.2 Target module boundaries

- Geometry & Navigation exposes one pure function set: derive walkable contours, derive passages between regions, derive wall edges. Tests call it without the editor, as today's `test_iwe_document.gd` does.
- The scene generator consumes these results. It stops deciding passages itself.
- The dock delegates to controllers as features are added (region controller, layer controller, calibration controller). New features go into new files; existing dock methods are moved only when touched.

## 3. Proposed adaptations (for approval)

1. **Move passage logic out of the scene generator** into a pure `geometry/` module first. Behaviour stays identical; the existing headless tests guard it. This is the first non-feature change.
2. **Add `schema_version`** before adding any new field, with a loader that fills defaults for version 1 documents.
3. **Add the Layer Manager as a separate resource tree**, not as a field on regions. Regions keep their geometry; layers only reference them by id. This satisfies "layer order must not drive navigation" structurally.
4. **Keep rendering out of navigation code.** Visual elements are exported as sibling nodes, never as navigation or collision bodies, so an occluder cannot block the character by accident.
5. **Split the dock incrementally.** New controllers are added beside the existing dock; old methods move only when a feature touches them.
6. **Keep the window (floating canvas) and the status bar as UI-only concerns** in `ui/`.

Nothing in this list changes the public behaviour of the current tools. Each step ships with regression tests before the next starts.

## 4. Coordinates and determinism

- All authored geometry is in source-image pixels. The viewport owns zoom and pan.
- Collections serialize in creation order. Stable IDs, not display names, link objects.
- Derived output (navigation, collision, scenes) is regenerated from source data and is never the source of truth.

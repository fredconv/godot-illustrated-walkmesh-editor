# IWE Roadmap

Status labels reflect verified implementation, not planned work. Each step ships with regression tests before the next one starts. Feature details are in `SPECIFICATION.md`; module boundaries are in `ARCHITECTURE.md`.

The pre-release inventory, the revised plan to the first release, and the decisions waiting for approval are in [`PRE_RELEASE_AUDIT.md`](PRE_RELEASE_AUDIT.md). This file keeps the status labels.

Legend: **Done** — implemented and tested · **Partial** — exists but incomplete · **Todo** — not started.

## Step 1 — Finish polygon features

| Item | Status | Notes |
|---|---|---|
| Create, select, move, vertex insert/remove/move | Done | Minimum three vertices enforced |
| Move whole region | Done | |
| Duplicate, rename, hide, delete | Done | Duplicate moves the outline but not its cutouts (audit P1-10, open) |
| Unsaved-change protection (modified mark, prompts, Godot quit dialog) | Done | Audit P1-6; recovery copy for a never-saved document |
| Replace the illustration without losing the calibration | Done | Audit P1-5; another size asks first; undoable |
| Overlapping cutouts remove their union once | Done | Merged before subtraction; enclosed islands are still blocked (known limitation) |
| Undo / redo for polygon edits | Done | Per-document `UndoRedo`; reset on new or open (audit P0 fix) |
| Lock a region | Partial | Model and canvas respect `locked`; no UI button |
| Region type field (walkable, connection, collision only, special) | Todo | Required before step 2 |
| Region properties panel (type, name, colour) | Todo | |

## Step 2 — Connections and independent collision regions

| Item | Status | Notes |
|---|---|---|
| Touching zones on one floor are walkable | Done | Exact, full shared edges only; tested headlessly and end to end. A partly shared edge is connected for navigation but keeps its wall (found by the village scenario) |
| Overlapping zones are connected for navigation | Done | The earlier zone keeps the shared ground, the later mesh stops on its outline (audit P1-2). Tested headlessly: areas, chains of three, gaps stay closed |
| Click-to-move keeps clearance from obstacle corners | Done | `path_clearance` on the test character (set to its radius by the export): each planned corner moves away from the edge while it stays walkable. Doorways wider than the character's diameter are crossed; narrower ones are still not checked |
| Warnings when export drops a zone or wall above the horizon | Done | Audit P1-3. Each dropped zone or template is named in the Output panel and counted in the dock status; a zone that crosses the horizon is dropped whole and reported |
| Explicit manual connection (bridge between two regions) | Todo | Width, allowed flag, optional direction |
| Connection only between regions that touch or are explicitly linked | Todo | Single-point contact is never a passage |
| Collision-only region (no navigation effect) | Todo | |
| Passage narrower than character radius is blocked | Partial | Reported by the export (warning with the zone and position); the planner does not avoid it yet |
| Connections exported in 2D and 3D | Todo | |

## Step 3 — Layer Manager architecture

| Item | Status | Notes |
|---|---|---|
| Schema version on `IWEDocument` | Done | Written in every file, a newer or invalid version is refused with a message and the file untouched, files without the field load as version 1 (audit P1-9). No migration exists yet because only version 1 exists |
| Portable picture reference | Done | Saving always copies the picture beside the document and stores `assets/...`; a moved folder reopens; Save As brings its own copy (audit P1-7) |
| Cutout identifiers, region identifier on exported nodes, reference validator | Done | `subtraction_ids`, `iwe_region_id` and `iwe_cutout_id` metadata, `validate_references()` reports on open |
| Layer tree resource (`IWELayer`), create/rename/delete/reorder | Todo | |
| Nested groups | Todo | Currently flat |
| Regions reference a layer id, not replaced by it | Todo | Navigation never reads layer order |
| Move geometry between layers | Todo | |
| Pure geometry module (passage and wall derivation) | Todo | Moved out of `iwe_scene_generator.gd`; behaviour unchanged |

## Step 4 — Visual layers and PNG elements

| Item | Status | Notes |
|---|---|---|
| Import transparent PNG / WebP | Done | Copied once to `assets/elements/<hash>` at save; missing files are kept and reported |
| Position, scale, opacity, layer, exact coordinates | Done | Typed in the layer panel, undoable. Rotation, pivot, flip and mouse dragging are not done |
| Background and foreground layer kinds | Done | Two default layers; more can be added |
| Visual elements exported as sibling nodes | Done | 2D sprites; camera-facing quads in the perspective stage; never navigation or collision |
| Layer visibility, lock, and opacity | Done | A locked layer refuses edits |

## Step 5 — Occlusion, depth and parallax

| Item | Status | Notes |
|---|---|---|
| Always-in-front mode (e.g. bridge railing) | Done | Quad just past the camera near plane |
| Depth occlusion from 3D depth (house, tree) | Done | Quad at the camera distance of the ground point. Verified on rendered pixels: hidden behind the fountain, shown in front |
| Parallax depth coefficient | Not in the first release | |
| Preview of occlusion during test movement | Done | The dock preview builds the same stage, so the test walk shows it |
| Walkable path remains walkable behind occluders | Done | A picture adds no navigation or collision; tested with a walk behind it |

## Step 6 — Calibration and exports

| Item | Status | Notes |
|---|---|---|
| Manual calibration of camera and floor | Done | |
| Fit camera from two or more height references | Done | |
| Multi-position presets (Near / Middle / Far) | Partial | Templates exist; no preset workflow |
| Calibration quality diagnostic | Done | Per-reference miss in the perspective panel, a warning above 5%, the horizon row, and the zones on or above it (M4). The steep village scene shows -10.6% / +10.6% with a warning. Assisted calibration itself (suggesting better references) is still to develop |
| 2D, flat 3D, and perspective exports | Done | Saved and reloaded in tests. A picture inside the project is referenced, not embedded (audit P1-8); only a picture Godot has not imported and cannot import is embedded, with a warning |
| Test character speed: base speed, x0.1 to x10 multiplier, pause, reset | Done (character) | `IWEWalkmeshCharacter`; never saved or exported |
| Speed controls in the dock preview | Done | `Test walk` in the perspective panel: character on the preview floor, base speed, x1/x2/x5/x10, pause/resume, reset; settings are preview-only. Verified headless (13 tests) and in the real editor runtime by `tests/editor_selftest` (no mouse) |
| Environment-only and navigation-only exports | Todo | |
| Exports include layers and connections | Todo | After steps 2–5 |

## Already completed (earlier phases)

- Illustration import, pan, zoom, and floating large window.
- Scale templates in image space, persisted, exported in 3D.
- Subtractive cutouts with names, derived through Godot's clipping API.
- Perspective projection and camera views; known-height template placement.
- Save and reopen of IWE documents, including the copy of the image beside the document.
- Test character with mouse and keyboard, walls, and path following.
- Automated suite: 293 headless GdUnit4 tests, including 31 end-to-end tests (`tests/e2e/`).

## Open technical debts

- Schema version is written and enforced, but no migration has been exercised because version 2 does not exist yet.
- The dock is about 1,640 lines and mixes UI with document logic.
- Manual GUI verification is still needed for most interactions; headless tests cover data and generation.
- Pre-existing Phantom Camera icon errors remain in the starter project.

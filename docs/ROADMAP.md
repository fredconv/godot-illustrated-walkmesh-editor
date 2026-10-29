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
| Click-to-move keeps clearance from obstacle corners | Todo | Paths hug corners, so the character can stall at a narrow doorway |
| Warnings when export drops a zone or wall above the horizon | Todo | Audit P1-3 |
| Explicit manual connection (bridge between two regions) | Todo | Width, allowed flag, optional direction |
| Connection only between regions that touch or are explicitly linked | Todo | Single-point contact is never a passage |
| Collision-only region (no navigation effect) | Todo | |
| Passage narrower than character radius is blocked | Todo | Needs physical radius setting |
| Connections exported in 2D and 3D | Todo | |

## Step 3 — Layer Manager architecture

| Item | Status | Notes |
|---|---|---|
| Schema version on `IWEDocument` | Partial | The field exists (default 1, omitted from files). No explicit write, no refusal of a newer version, no migration (audit P1-9) |
| Layer tree resource (`IWELayer`), create/rename/delete/reorder | Todo | |
| Nested groups | Todo | Currently flat |
| Regions reference a layer id, not replaced by it | Todo | Navigation never reads layer order |
| Move geometry between layers | Todo | |
| Pure geometry module (passage and wall derivation) | Todo | Moved out of `iwe_scene_generator.gd`; behaviour unchanged |

## Step 4 — Visual layers and PNG elements

| Item | Status | Notes |
|---|---|---|
| Import transparent PNG / WebP | Todo | |
| Move, scale, rotate, pivot, flip, opacity, exact coordinates | Todo | |
| Background and foreground layer kinds | Todo | |
| Visual elements exported as sibling nodes | Todo | Never navigation or collision |
| Layer visibility, lock, and opacity | Todo | |

## Step 5 — Occlusion, depth and parallax

| Item | Status | Notes |
|---|---|---|
| Always-in-front mode (e.g. bridge railing) | Todo | |
| Depth occlusion from 3D depth (house, tree) | Todo | Uses calibrated floor depth |
| Parallax depth coefficient | Todo | |
| Preview of occlusion during test movement | Todo | |
| Walkable path remains walkable behind occluders | Todo | Required by the specification |

## Step 6 — Calibration and exports

| Item | Status | Notes |
|---|---|---|
| Manual calibration of camera and floor | Done | |
| Fit camera from two or more height references | Done | |
| Multi-position presets (Near / Middle / Far) | Partial | Templates exist; no preset workflow |
| Assisted calibration with quality diagnostic | Todo | The fit residual is not shown; 10.6% on the steep village scene |
| 2D, flat 3D, and perspective exports | Done | Saved and reloaded in tests. An export from a picture outside the project embeds about 6 MB (audit P1-8) |
| Test character speed: base speed, x0.1 to x10 multiplier, pause, reset | Done (character) | `IWEWalkmeshCharacter`; never saved or exported |
| Speed controls in the dock preview | Todo | Needs an in-editor test character; the dock preview is a static render (milestone M3) |
| Environment-only and navigation-only exports | Todo | |
| Exports include layers and connections | Todo | After steps 2–5 |

## Already completed (earlier phases)

- Illustration import, pan, zoom, and floating large window.
- Scale templates in image space, persisted, exported in 3D.
- Subtractive cutouts with names, derived through Godot's clipping API.
- Perspective projection and camera views; known-height template placement.
- Save and reopen of IWE documents, including the copy of the image beside the document.
- Test character with mouse and keyboard, walls, and path following.
- Automated suite: 141 headless GdUnit4 tests, including 31 end-to-end tests (`tests/e2e/`).

## Open technical debts

- Schema version field exists but is not written, enforced, or migrated.
- The dock is about 1,640 lines and mixes UI with document logic.
- Manual GUI verification is still needed for most interactions; headless tests cover data and generation.
- Pre-existing Phantom Camera icon errors remain in the starter project.

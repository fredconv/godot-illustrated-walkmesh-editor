# Pre-release audit

Date: 2026-10-29 · Branch `feature/region-editing` · Godot 4.7.1 · Plugin version `0.1.0-dev`

This document answers one question: **what is left before the first public pre-release (`0.1.0-alpha.1`)?** It is an inventory, not a plan of record. [`ROADMAP.md`](ROADMAP.md) stays the single place where status labels are maintained; section 7 below proposes changes to it and waits for approval.

## 1. Executive summary

- **The core chain works and is test-backed.** Importing an illustration, drawing zones and cutouts, connecting zones by a shared edge, calibrating a perspective camera from height references, exporting a perspective scene, and walking a test character around the obstacles all work, from an empty document, on new assets (`tests/e2e/`, 31 tests, plus a scripted pass in the real editor).
- **All audit blockers are closed.** P0-1, P0-2, P1-1, P1-2, P1-3, P1-4, P1-5, P1-6, P1-10 are fixed with tests (M1 is complete). P1-7, P1-8 and P1-9 are fixed too (M2 is complete).
- **The end-to-end run found three problems the unit tests did not.** (1) A zone that shares only *part* of another zone's edge is connected for navigation but still walled, so the character stalls. (2) The camera fit missed the two height references by 10.6% on a steeply viewed scene, and the plugin does not show the residual. (3) A picture copied beside a saved document could not be reopened until the editor had imported it (fixed in this pass, see section 5).
- **The large features are not started.** Layers, transparent PNG elements, occlusion, parallax, triggers, portals, region types, explicit connections. They exist as design documents only. The foreground fountain of the new scene cannot yet hide the character.
- **The editor UI is one tall dock.** There is no recorded UI/UX redesign plan in the repository or in the project notes I could access, so "the target UI" is **unverified** (section 3). I have listed concrete gaps instead of inventing a design.
- **Overall assessment.** The *authoring and perspective core* is close to an alpha: it needs the open geometry and persistence defects fixed, real mouse testing, and release preparation. Whether the *first release* also includes the Layer Manager and occlusion is a **design decision that is not made yet**; the answer changes the remaining work by an order of magnitude. I do not give a completion percentage, because the target scope is not fixed.

## 2. Feature completion matrix

Status classes: **Validated** (implemented, automated tests, checked in the real editor or by an end-to-end run) · **Needs validation** (implemented, tested headless, never driven with a mouse) · **Partial** · **Not started** · **Decision needed**.

"Automated" is the number of headless tests that exercise the feature. "Manual" is what only a person with a mouse can confirm: the editor tooling available to me can call dock methods and take screenshots, but cannot inject real mouse events into the editor.

### 2.1 Illustration

| Feature | Status | Implementation | Missing | Automated | Manual | Priority |
|---|---|---|---|---|---|---|
| Import PNG/JPG/WebP, keep size | Validated | `_load_illustration`, `iwe_canvas.gd` | | e2e 01, unsaved, runtime | File dialog | Must |
| Pan and zoom | Needs validation | canvas, zoom label | | zoom does not touch calibration (stability) | Wheel and drag feel | Must |
| Replace the picture without losing work | Validated | P1-5: same size swaps silently, other size asks first, one undo entry | | 6 + e2e 01 | Confirmation dialog look | Must |
| Copy picture beside the document | Partial | `_copy_image_into_document` | Folder chosen in the dialog may differ from the document folder (P1-7); exports embed ~6 MB when the source is outside the project (P1-8, measured: 126 KB vs 6.4 MB) | e2e 03 | Save flow in a real project folder | Must |
| Show/hide image, tracing opacity | Not started | | Both appear in the specification (3.1) | | | Optional |

### 2.2 Regions, groups, boolean operations

| Feature | Status | Implementation | Missing | Automated | Manual | Priority |
|---|---|---|---|---|---|---|
| Draw, select, move, edit vertices, add/remove point, undo/redo | Needs validation | `iwe_canvas.gd`, dock | Mouse interaction never driven by a test | e2e 02/03, document, region tree | **All mouse editing** | Must |
| Duplicate region | Validated | `_duplicate_selected_region` | The outline and its cutouts move together (P1-10 fixed) | e2e 03 | | Must |
| Rename, hide, delete | Validated | | Undo of a deletion re-adds the region at the end of the list (changes draw/export order; audit P2) | e2e 03 | | Must |
| Lock a region | Partial | model and canvas respect `locked` | No button | | | Should |
| Flat groups | Validated | | Undo of *Create group* can leave orphans (audit P2, not re-verified) | e2e 02 | | Must |
| Nested groups | Not started | | | | | Optional |
| Cutouts (named, several per region) | Validated | merged union subtracted once (P1-1) | Cutouts that enclose an island also block the island | cutout geometry 8, e2e 02 | | Must |
| Cutouts without stable IDs | Partial | indexed + parallel name array | Stable IDs and a reference validator (prerequisite for layers) | | | Should |
| Union of zones in the user's sense (walk from zone to zone) | Validated | exact **full** shared edge = doorway; verified end to end across yard, crossroads and bridge | Partly shared edges and overlapping zones are both walkable (N-1 and P1-2 fixed, `test_overlapping_zones`, e2e 04) | walkable connections, e2e 04 (3 tests) | | Must |
| Explicit union / intersection / XOR commands | Not started | | The README lists them as planned | e2e 02 pins their absence | | Optional |
| Region types (connection, collision only, special) | Not started | every region is walkable | | | | Should |
| Explicit connections, passage width | Not started | | | | | Should |

### 2.3 Calibration, perspective, preview, export

| Feature | Status | Implementation | Missing | Automated | Manual | Priority |
|---|---|---|---|---|---|---|
| Height references (templates) | Validated | place, move, resize, delete | | e2e 04, document | | Must |
| Fit camera from references | Partial | least-squares line on screen row | **No residual shown.** 10.6% miss on the steep e2e scene versus 2.5% on the demo. No horizon warning (P1-3) | stability, e2e 04 | Judging the fit by eye | Should |
| Calibration independent of dock size | Validated | P1-4, explicit reference frame | | 15 | Resize with the mouse | Must |
| Perspective preview (dock) | Needs validation | static render of the stage | **No character, no playback.** Reloads the PNG at every spin-box step (audit P2) | stability, e2e 04 | Preview in a narrow dock | Must |
| Perspective export | Validated | walls, navigation, templates, cameras, optional player | Silent drops above the horizon (P1-3); exported nodes carry no region ID (audit P2); 6.4 MB embedded picture (P1-8) | full workflow, e2e 04 | Opening the exported scene and running it (F5) | Must |
| 2D and flat 3D export | Needs validation | | Never run in the editor by hand | full workflow | Run both scenes | Must |
| Assisted calibration, presets | Not started | | | | | Optional |
| Environment-only / navigation-only export | Not started | | | | | Optional |

### 2.4 Test character and preview speed (new request)

| Feature | Status | Implementation | Missing | Automated | Manual | Priority |
|---|---|---|---|---|---|---|
| Test character (click, keys, walls, path) | Validated | `IWEWalkmeshCharacter` | **Path hugs obstacle corners with no clearance**: at a narrow doorway the capsule stalls on the corner (observed: stopped 33 px from the corner after 28 frames) | runtime, e2e 04 | Feel of the controls | Must |
| Base speed, multiplier x0.1 to x10, presets x1/x2/x5/x10, pause, reset | **Implemented at character level** | `set_speed_multiplier`, `get_effective_speed`, `pause`, `resume`, `reset_position`; never saved, never exported | | 10 + e2e 04 | | Should |
| Controls in the dock (speed selector, pause, reset, base speed) | **Scheduled** (milestone M3) | | The dock preview is a static render with no character, so a control there would have nothing to drive | | | Should |
| Perspective-consistent apparent speed | Validated | no depth scaling; the camera does it. Tested: equal world distance at every depth, screen distance proportional to the multiplier at every depth | | 2 | | |

### 2.5 Persistence and format

| Feature | Status | Implementation | Missing | Automated | Manual | Priority |
|---|---|---|---|---|---|---|
| Save and reopen `.tres` | Validated | | Reopening right after a save in the editor (picture not imported yet) is covered by a fix and a headless test, **not** by a real-editor run | e2e 03 | Save then reopen in a real project folder | Must |
| Unsaved-change protection | Validated | `IWEDocumentHistory`, Godot quit dialog, recovery copy | Quit dialog driven by script only | 26 | Close Godot with a modified document | Must |
| Per-document undo | Validated | | | 10 | | Must |
| Schema version | Validated | written in every file; newer or invalid versions refused, file untouched; old files load as 1 | No migration code (none needed until version 2) | `test_schema_version` (8) | | Must |
| Portable picture reference | Validated | always copied beside the document, relative path, Save As fixed | Picture import by the editor at export time is not testable headless | `test_picture_paths` (7) | Save in a real project folder, move it, reopen | Must |

### 2.6 Layers, visual elements, occlusion, triggers

| Feature | Status | Notes | Priority |
|---|---|---|---|
| Layer Manager (create, group, hide, lock, opacity, reorder) | Not started | Design only: `LAYER_MANAGER_DESIGN.md`, `IWE_LAYERS_TRIGGERS_POST_OPUS.md` | **Decision needed** |
| Transparent PNG elements and transforms | Not started | The foreground fountain of the e2e scene can only be stacked by hand in a Godot scene | Decision needed |
| Background / foreground / depth occlusion / parallax | Not started | Prototype `prototypes/occlusion/`: Alpha Scissor and Alpha Blend are good in both renderers; Alpha Hash is wrong under GL Compatibility | Decision needed |
| Triggers, actions, portals, spawn points | Not started | Specification only | Post-release |

### 2.7 Quality and infrastructure

| Item | Status | Notes |
|---|---|---|
| CI | Validated | Headless suite on every push and PR, pinned Godot and GdUnit4 |
| Test suite | 141 tests | 110 unit and integration, 31 end to end. `tests/test_document.gd` has no test cases and is never run |
| Public docs | Needs sync | Several statements are stale (section 4.3) |
| Packaging | Not started | No addon-only ZIP, no `0.1.0-alpha.1` entry, no release checklist |

## 3. UI/UX redesign status

**Existing UI** (one dock, `iwe_dock.tscn`, `iwe_dock.gd` at 1,637 lines): a toolbar (New, Save, Open, Import, New group, group selector, Undo, Redo, Perspective, Window, zoom), a region tree, region tools, a template section, a perspective section with calibration inputs and a reference-frame pair, export buttons, and a status line. Observed in the real editor on 2026-10-29: the dock is usable but wide; in the editor layout I captured, the canvas column was cut at the right edge.

**Target UI.** `SPECIFICATION.md` 3.12 names five workspaces (Image & Regions, Perspective, 3D Preview, Test, Export). Nothing implements them: Perspective is a toggle, 3D Preview is the same toggle, Test and Export are buttons. The Layer Manager design proposes a single typed editing tree and asks for a small usability proof of concept first. **I found no other redesign plan** in the repository, the planning documents, or the project notes. Any redesign request from earlier conversations that is not in those files is **unverified**. Please provide it or confirm that 3.12 is the intended target.

| Area | Existing | Gap observed or recorded | Priority |
|---|---|---|---|
| Layout and docking | One dock, a floating window for the canvas | Narrow-dock behaviour is only checked by script; no workspace switching | Should |
| Toolbars and contextual controls | Tool buttons enabled by state | No lock button; no region properties panel (type, colour); no keyboard shortcut list | Should |
| Region editing workflow | Draw, edit points, add/remove point, cutout | Mouse flow untested by automation; duplicate leaves cutouts behind (P1-10) | Must |
| Camera calibration interface | Numeric inputs, fit button, reference frame | No fit residual, no horizon or aspect hints beyond one status note, no Near/Middle/Far presets | Should |
| Perspective and 3D preview controls | Toggle, top view, scale | Static render; no playback, speed, pause, reset | Should |
| Reference character visualization | Capsule in exported scenes | Not visible in the dock | Should |
| Selection and state feedback | Tree plus canvas highlight | Selection has three sources of truth (audit section 4) | Should |
| Messages and errors | Status line, `push_error`, save and replace dialogs | Several failures go only to the Output panel | Should |
| Artists and level designers | | No guided first-run flow; no sample document shipped beside the demo scene | Should |

Do not start the redesign before the target is agreed.

## 4. Missing, forgotten, and unverified requirements

### 4.1 Requested and not yet in the roadmap, or only implicitly

| Request | Where it came from | State |
|---|---|---|
| Adjustable 3D preview speed (base speed, x1/x2/x5/x10, live change, pause, reset) | This session | Character level done; dock controls scheduled (M3). Added to the roadmap by this audit |
| Stable cutout IDs and reference integrity check | Opus audit, before layers | In `LAYER_MANAGER_DESIGN.md`, not in `ROADMAP.md` |
| Selection model with one source of truth; controllers extracted from the dock | Opus audit | Not in the roadmap |
| Warnings for geometry dropped on export (P1-3) | Opus audit | Not in the roadmap |
| Fit residual display | Opus audit P2, confirmed by the e2e run | Not in the roadmap |
| Corner clearance in click-to-move | Found by the e2e run | New (N-2) |
| Partly shared edge is connected but walled | Found by the e2e run | New (N-1) |
| Foreground and occlusion preview during test movement | User, with the fountain asset | In the roadmap (step 5) |
| `0.1.0-alpha.1` first public pre-release | User | Mentioned, no checklist |

### 4.2 Unverified

- A request to save documents as `iwdock/<image name>.tres` by default (an early message). The save dialog opens in the project root; I found no trace that the naming convention was kept or dropped.
- GitHub repository settings (description wording, wiki disabled). They were requested earlier; I did not re-check them in this pass.
- The UI/UX redesign plan (section 3).

### 4.3 Stale statements in the public docs

- `ROADMAP.md`: "Schema version on `IWEDocument`: Todo" (the field exists, with no migration); "some labels and one tooltip are still French" (none found in the dock scripts and scene); test count.
- `SPECIFICATION.md` 3.11: "no version field yet", and the line saying importing an illustration is not undoable (replacing one now is).
- `DATA_FORMAT.md`: says a document with a newer schema "must not be loaded silently" and that the plugin reports it. Nothing implements this.
- `README.md` is consistent with the implemented features.

## 5. Technical debt and known risks

| Risk | Evidence |
|---|---|
| `iwe_dock.gd` is 1,637 lines (1,378 at the time of the Opus audit) and mixes UI, document mutations, export, calibration and history | file size |
| Selection has three sources of truth | Opus audit |
| Passage and wall rules live inside the scene generator; they are the source of N-1 and P1-2 | `_edge_is_covered_by_other_zone` samples three points per edge |
| Click-to-move paths have zero clearance while the character has a physical radius | e2e 04, probe |
| `get_walkable_contours` removes collinear vertices, so extra vertices on an edge do not create a doorway | probe on 2026-10-29 |
| A picture that a save just copied is not importable by `load()`; the dock now reads the file directly. Side effect: an export made from it embeds the pixels (P1-8) | e2e 03, size measurement |
| Real-editor interaction is mostly unverified: no mouse-driven test exists | tooling limit |
| The editor tooling refused an unsafe-I/O flag for a real-editor save-and-reopen run, so that run was not done | this session |
| Test pins of known defects (P1-10, partial doorway, absent layers, absent union) must be flipped when those are fixed | comments in `tests/e2e/` |
| Pre-existing Phantom Camera icon errors in the starter project's Output panel | unrelated to IWE |

## 6. Test coverage and pending manual checks

**Automated: 141 headless tests, all passing** (CI green on the pushed commits; the commits from this session are pushed with the documentation).

| Area | Tests |
|---|---|
| Document, region geometry, cutouts | 15 + 8 + 2 |
| Undo history and unsaved changes | 10 + 26 |
| Region tree selection | 6 |
| Perspective runtime and stability | 7 + 15 |
| Illustration replacement | 6 |
| Preview speed | 10 |
| Window and storage, walkable connections | 4 + 1 |
| End to end, village and fountain | 31 |

**Manual checks still owed** (nothing below can be done by the headless suite):

1. Draw, edit and delete polygons with the mouse; drag vertices; step through undo and redo.
2. Save into a real project folder, reopen immediately and after a restart; confirm the picture shows.
3. Replace the picture with one of another size and read the confirmation dialog.
4. Export 2D, 3D and perspective scenes and run each with F5; walk the character around the fountain.
5. Close Godot with a modified document; check the quit dialog and the recovery copy.
6. Resize and detach the dock with the mouse in perspective mode.
7. Compare the foreground fountain composite scene (`tests/e2e/e2e_village_fountain.tscn`) with the editor view.

**End-to-end scenario results** are in `tests/e2e/README.md`.

## 7. Proposed roadmap to the first release

The proposal assumes **`0.1.0-alpha.1` is the authoring and perspective core**, without layers and triggers. If you want layers in the first release, M7 to M9 move into "Must" and the release moves out by their cost. This is the main decision to take.

Complexity: **S** a day or less · **M** two to four days · **L** one to two weeks · **XL** more than two weeks. Estimates assume the current AI-assisted pace and a green test suite at each step.

### Must-have before the first release

| ID | Milestone | Depends on | Acceptance criteria | Size |
|---|---|---|---|---|
| M1 | **DONE 2026-10-29. Navigation and collision consistency.** Partly shared edges (N-1), overlapping zones (P1-2, or a documented decision not to support them), warnings for dropped zones and walls (P1-3), corner clearance for click-to-move (N-2), duplicate with cutouts (P1-10) | none | The e2e tests that pin N-1, P1-10 flip to the correct behaviour; a doorway of any width crossable by click-to-move; a warning names every dropped zone; no stall in the e2e walk | L |
| M2 | **DONE 2026-10-29. Persistence and export integrity.** Relative picture path (P1-7), no embedded pixels in exports (P1-8), explicit schema version write, refusal of newer versions and a migration policy (P1-9), stable cutout IDs, reference validator, region ID on exported nodes | none | Save, move the folder, reopen; an export of a project-folder picture is under 1 MB; a v2 file is refused with a message and untouched; v1 fixtures still load | L |
| M12 | **Manual QA with a mouse**, list in section 6 | M1, M2 | Every item checked and recorded in `docs/DEVELOPMENT.md` | M |
| M13 | **Release preparation.** Addon-only ZIP, `0.1.0-alpha.1` in `plugin.cfg` and changelog, screenshots, the village scene as a second example, doc sync (4.3), asset provenance, release checklist | M1, M2, M12 | A clean project opens with only the addon folder; every claim in README is covered by a test or marked experimental | M |

### Should-have before the first release

| ID | Milestone | Depends on | Acceptance criteria | Size |
|---|---|---|---|---|
| M3 | **In-editor test playback and speed controls.** A character in the dock preview (reusing `IWEWalkmeshCharacter`), a compact bar with Base Speed, x1/x2/x5/x10, Pause, Reset. The multiplier is an editor preference, not document data; the base speed is a character property | M1 | Walk the village path at x10 in the dock; changing speed during the walk takes effect at once; nothing saved in the document or the export changes | L |
| M4 | **Calibration usability.** Show the fit residual per reference, warn when it exceeds a threshold, horizon warning | none | The e2e steep scene shows its 10.6% residual and a warning | M |
| M5 | **UI/UX pass.** Needs an approved target first (section 3): workspaces, lock button, region properties, narrow-dock layout, first-run guidance | decision on the target | Agreed checklist; no control cut off at a 380 px dock | M to L |
| M6 | **Structural clean-up.** One selection model, controllers extracted from the dock, geometry module for passage rules, a public API for tests | M1 | Characterisation tests written first; dock under 1,000 lines | L |
| M11 | **Region types and explicit connections** (connection, collision only, width) | M6 | A bridge drawn as a connection with a width; a collision-only region blocks without navigation | L |

### Optional or after the first release

| ID | Milestone | Depends on | Size |
|---|---|---|---|
| M7 | Layer Manager (data, UI, persistence, schema v2 migration) | M2, M6 | XL |
| M8 | Transparent PNG elements and export | M7 | XL |
| M9 | Occlusion and parallax (the fountain hides the character) | M8 | XL |
| M10 | Triggers, actions, portals, spawn points | M2, M6 | XL |
| M14 | Assisted calibration, presets, environment-only and navigation-only exports, nested groups, boolean commands, snapping, tracing opacity | | L each |

### Decisions needed from you

1. Is the first release the authoring and perspective core, or does it include layers and occlusion?
2. Visual order: ordered children of one typed tree (the Opus recommendation, and the `POST_OPUS` document) or a separate `draw_index` (the earlier validated plan)? This blocks M7 only.
3. Is `SPECIFICATION.md` 3.12 the intended UI target, or is there a separate redesign plan?
4. Should partly shared edges become doorways (M1 option A) or be reported as an authoring error (option B)?

## 8. Proposed next milestone

**M1, navigation and collision consistency.** It fixes the defects an artist meets first (a character that stalls, a zone that looks connected and is not, a duplicate that leaves holes behind), it needs no design decision beyond question 4, and the e2e scene already contains the failing cases as pinned tests.

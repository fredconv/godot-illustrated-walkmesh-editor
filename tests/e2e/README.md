# End-to-end scenario: village and fountain

A reusable validation case for IWE. It is meant to answer one question after any milestone: **does the whole workflow still work from an empty document, on assets that no earlier test used?**

## Assets

| File | Role |
|---|---|
| `assets/img/background_template.png` | The illustration (1672 x 941, opaque): a village with a house, crossroads, bridge and river |
| `assets/img/foreground_template.png` | A fountain on a transparent canvas of the same size, used as the foreground object |
| `tests/e2e/e2e_village_fountain.tscn` | A plain Godot scene that stacks the two images (foreground above background). Open it to see the composite |

Both images are AI-generated and free to use (see `assets/README.md`).

## What the scenario authors

Everything is created from an empty document through the signals the canvas emits when a person draws. Nothing is loaded from a saved sample. The shapes are in `village_scenario.gd`.

| Shape | Purpose |
|---|---|
| `Region 1` yard | Left zone; shares the full edge `x = 500` with the crossroads |
| `Region 2` crossroads | Main zone with a short tab on its right side |
| `Region 3` bridge | Shares the tab's far edge in full: the only kind of shared edge that is a doorway |
| `Region 4` patch | Overlaps the yard and the crossroads without a shared edge |
| Cutout 1 | Footprint of the fountain (16-sided ellipse) |
| Cutout 2 | A bench-sized rectangle overlapping the fountain footprint, to test the union of cutouts |
| Two height templates | 230 px at (300, 880) and 105 px at (1000, 330) |

## The four suites

| Suite | Covers |
|---|---|
| `test_e2e_01_assets_and_import.gd` | Asset set, composite scene, empty start, first import, two documents in a row, replacing the picture |
| `test_e2e_02_polygons_and_operations.gd` | Drawing from scratch, shared-edge union, overlapping cutouts subtracted once, a refused cutout, undo and redo of cutouts, the merge command |
| `test_e2e_03_editing_and_persistence.gd` | Selection, vertex move, add and remove point, delete and undo, rename and hide, undoing a whole session, duplicate (known defect), save and reopen in a fresh dock |
| `test_e2e_04_perspective_layers_and_walk.gd` | Camera fit, preview independent of the dock, perspective export, absence of a foreground layer, footprint against the foreground picture, walking around the fountain at x1, x5 and x10, the doorway, the partial-edge limitation |

Run them like any other test (see `docs/DEVELOPMENT.md`). Temporary output goes to `tests/e2e/_output/` (ignored by Git) or `user://` and is removed after each test.

## Results on 2026-10-29

31 tests, all passing. Behaviour they document:

- **Works:** import, polygons, cutout union, undo and redo, save and reopen, calibration, perspective export, walking around the fountain at every test speed, the doorway through a fully shared edge.
- **Pinned known defects** (a test passes while the defect exists and must be flipped when it is fixed):
  - Duplicating a region moves its outline 16 px but not its cutouts (P1-10).
  - A bridge that touches only part of an edge is connected for navigation but the wall stays, so the character stops at the wall. Related to P1-2 and P1-3.
  - (Fixed since: layers, foreground occlusion and the union command now exist. See `tests/test_layers.gd`, `tests/render_check/` and `tests/test_merge_regions.gd`.)
- **Measured:** the camera fit misses the two templates by 10.6% on this steeply viewed scene (bound `FIT_BOUND = 0.12` in suite 04).
- **Found and fixed during this run:** a picture copied beside a saved document could not be reopened until the editor imported it.

## Manual validation done in the real editor

The dock of the running editor (Godot 4.7.1) was driven by script with this scenario: import of `background_template.png`, four regions with two cutouts, two templates, camera fit, and perspective mode. The tree showed *Region 2 (2 cutouts)*, the overlays showed the zones and the fountain cutout, and the dock stayed unmodified after the dock was reset. Save and reopen in a real project folder was **not** run in the editor.

## Reusing it

Import `village_scenario.gd` in a new suite and call `new_dock`, `import_background`, `author_regions`, `author_templates`, and `start_stage`. Add new shapes there, not in the tests.

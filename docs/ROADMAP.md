# IWE Roadmap

Status labels reflect verified implementation, not planned work.

## Phase 0 — Reconnaissance and reuse audit

- Verify Godot version and editor APIs.
- Test available Godot MCP integration.
- Inspect candidate projects, source, maintenance, compatibility, and licenses.
- Record decisions and choose a compatible test framework.

## Phase 1 — Minimal editor plugin

- Add plugin manifest and GDScript `EditorPlugin` entry point.
- Add dock with image import/display, pan, and zoom.
- Persist/reload image-space document state.
- Verify clean activation/deactivation in Godot.

Status: image import/display, zoom and pan, `.tres` save/open, image copy beside the document, polygon creation/selection, vertex insertion/removal/movement, region rename/visibility/delete/duplicate, and editor undo/redo exist. Manual GUI verification remains recommended.

## Phase 2 — Polygon editing and groups

- Region resources, polygon editing, validation, selection, and undo/redo.
- Group hierarchy and variable-width path authoring.

Status: polygon editing, selection, undo/redo, and flat region groups exist. Nested groups and variable-width paths remain planned.

## Phase 3 — Boolean geometry

- Non-destructive scoped modifiers, holes, disconnected results, and triangulation.
- Focused geometry tests before integration into the editor.

Status: a selected region can now hold multiple editable subtraction polygons. Godot's clipping API derives contours with hole winding; union/intersection/XOR, robust overlapping cutout merging, and triangulation remain planned.

## Phase 4 — Scale calibration

- Scale anchors, interpolation, visualization, and character preview.

Initial slice implemented: place and drag image-space scale templates, adjust their artist-chosen apparent height in pixels, save them in the IWE document, and export upright 3D capsules at the same image position and apparent height. The perspective workflow also places known-height 3D capsules using floor-projected image coordinates. Reference sprites, interpolation across walkable surfaces, and heatmap visualization remain follow-up work.

## Phase 5 — Runtime navigation

- [x] Export a reusable 2D scene with the illustration and one `NavigationRegion2D` per visible region.
- [x] Export a flat 3D stage with the image on a horizontal plane and `NavigationRegion3D` meshes.
- [x] Let the author choose world units per source-image pixel and optionally add a framing camera.
- [ ] Add generated collision, explicit links and levels, and a demo character/controller.
- [x] Add a perspective-calibrated 3D workflow that projects image-space navigation onto a flat virtual floor, warps the image plane, preserves cutouts, and includes perspective/top cameras.
- [x] Add a reusable perspective calibration demo with two walkable regions, cutouts, camera views, and near/far height references.
- [ ] Add automatic depth interpolation and terrain-height reconstruction; calibrated output currently remains on one plane.

## Phase 6 — Occlusion and alpha release

- Occluder editing, usability pass, regression coverage, packaging, and release documentation.

## Current verified progress

- The local starter folder is a Godot project declaring Godot 4.7.
- Godot 4.7 is installed locally at a non-PATH location and is used for headless validation.
- The repository and `main`/`develop` branches exist on GitHub; initial source publication is complete.
- IWE document, polygon editing, and subtractive cutouts are implemented on `feature/region-editing`; GdUnit4 headless validation is run for the active feature branch.
- 2D and flat 3D scene export now exist; scene save/reload, scale settings, optional cameras, hidden regions, and cutout holes are covered by GdUnit4 tests.
- Scale templates persist in IWE documents and export to the 3D stage; automated coverage checks their position, apparent height, and save/reload.
- Perspective projection, floor intersections, cutout preservation, camera views, known-height template placement, and demo-scene serialization pass in the GdUnit4 suite.
- Enabling the plugin in a headless editor completed without IWE script errors. Pre-existing Phantom Camera missing-icon errors remain in this starter project.

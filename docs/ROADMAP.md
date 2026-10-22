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

## Phase 5 — Runtime navigation

- Walkable surface and collision generation, explicit links and levels, demo character.

## Phase 6 — Occlusion and alpha release

- Occluder editing, usability pass, regression coverage, packaging, and release documentation.

## Current verified progress

- The local starter folder is a Godot project declaring Godot 4.7.
- Godot 4.7 is installed locally at a non-PATH location and is used for headless validation.
- The repository and `main`/`develop` branches exist on GitHub; initial source publication is complete.
- IWE document, polygon editing, and subtractive cutouts are implemented on `feature/region-editing`; GdUnit4 headless validation is run for the active feature branch.
- Enabling the plugin in a headless editor completed without IWE script errors. Pre-existing Phantom Camera missing-icon errors remain in this starter project.

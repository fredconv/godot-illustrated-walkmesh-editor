# IWE Roadmap

Status labels reflect verified implementation, not planned work. At repository initialization, every feature below is planned.

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

## Phase 2 — Polygon editing and groups

- Region resources, polygon editing, validation, selection, and undo/redo.
- Group hierarchy and variable-width path authoring.

## Phase 3 — Boolean geometry

- Non-destructive scoped modifiers, holes, disconnected results, and triangulation.
- Focused geometry tests before integration into the editor.

## Phase 4 — Scale calibration

- Scale anchors, interpolation, visualization, and character preview.

## Phase 5 — Runtime navigation

- Walkable surface and collision generation, explicit links and levels, demo character.

## Phase 6 — Occlusion and alpha release

- Occluder editing, usability pass, regression coverage, packaging, and release documentation.

## Current verified progress

- The local starter folder is a Godot project declaring Godot 4.7.
- No Godot executable is currently discoverable through PATH or the checked common install folders, so engine validation is pending.
- An IWE plugin has not yet been implemented.

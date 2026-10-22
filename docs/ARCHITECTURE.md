# IWE Architecture

## Status

This is the proposed modular architecture. Godot API compatibility and class boundaries must be validated in the installed engine before implementation is considered stable.

## Layers

- `addons/illustrated_walkmesh_editor/plugin.gd`: `@tool` entry point; registers and removes editor UI only.
- `editor/`: dock, image viewport, selection state, tool dispatch, and editor-facing undo/redo commands.
- `data/`: serializable Godot `Resource` types for documents, groups, regions, anchors, modifiers, connections, and occluders.
- `geometry/`: polygon validation, triangulation, and coordinate utilities without UI dependencies.
- `boolean/`: modifier evaluation with explicit scope and source preservation.
- `scale/`: anchor interpolation and visualization data.
- `runtime/`: generated scene/runtime components, independent of editor widgets.
- `tests/`: geometry, serialization, modifier, scale, and plugin lifecycle tests.
- `examples/`: self-contained scenes and local assets.

## Data and coordinate model

All authored geometry is stored in source-image pixel coordinates. The viewport owns a view transform for pan and zoom and converts pointer positions back into that coordinate space. Serialized collection ordering must be deterministic. Stable resource IDs, rather than display names, identify groups and regions.

Source resources are authoritative. Modifier results and generated runtime nodes are derived and may be regenerated. Modifier target scope and level compatibility must be explicit to prevent operations from affecting unrelated bridges or overlapping floors.

## Test seams

Pure geometry and interpolation code should avoid editor APIs so it can run headlessly. Godot editor integration tests should separately verify plugin activation/deactivation, resource loading, dock cleanup, and project serialization. The chosen framework will be the existing compatible test addon only after its version and redistribution terms are verified.

# IWE Architecture

## Status

This describes the current development architecture. Godot API compatibility is validated against the local Godot 4.7.1 editor and automated regression suite; editor interaction still needs manual review.

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

All authored geometry is stored in source-image pixel coordinates. The viewport owns a view transform for pan and zoom and converts pointer positions back into that coordinate space. Serialized collection ordering must be deterministic. Stable resource IDs, rather than display names, identify groups and regions. Cutout names are serialized alongside their polygons by index so they remain editor labels without changing the generated navigation geometry.

Source resources are authoritative. Modifier results and generated runtime nodes are derived and may be regenerated. Modifier target scope and level compatibility must be explicit to prevent operations from affecting unrelated bridges or overlapping floors.

## Current scene export

`data/iwe_scene_generator.gd` builds self-contained `Node2D` or `Node3D` scenes. The root remains the user's placement/rotation handle; a child named `Template` stores the chosen world-units-per-pixel scale so it survives PackedScene serialization. The illustration texture and visible-region navigation resources are serialized with the scene. In 3D, named groups are scene parents and each region contains a translucent rendered navigation surface plus line guides for its exact authored outer contour and each named cutout. The illustration plane sits just below those overlays. These source guides remain distinguishable from Godot's convex-partitioned navigation cells. Boolean subtraction contours are converted into holes in each generated navigation surface. Navigation baking uses a zero agent radius so it does not silently erode the authored polygons; runtime agents control their own clearance. The 3D result is a horizontal plane with planar navigation; it is not a perspective reconstruction or heightfield. Its orthographic top-view camera is included by default, locks framing to image width, and looks down the Y axis with the image's top edge at screen top.

## Perspective calibration stage

`data/iwe_perspective_calibration.gd` persists the perspective camera field of view, transform, virtual floor height, reference viewport, and known character height. `data/iwe_perspective_projector.gd` maps image pixels into the contain-fitted viewport and intersects camera rays with the floor. The scene generator uses the same mapping for authored region vertices, named cutouts, anchors, and a subdivided illustration mesh. The generated stage includes perspective and orthographic top cameras. Its geometry remains on one flat plane; calibration does not infer terrain elevation or hidden depth. Re-export after changing calibration values.

Pure geometry and interpolation code should avoid editor APIs so it can run headlessly. Godot editor integration tests should separately verify plugin activation/deactivation, resource loading, dock cleanup, and project serialization. The chosen framework will be the existing compatible test addon only after its version and redistribution terms are verified.

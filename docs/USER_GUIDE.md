# User Guide

This guide describes what the plugin does today. Features that are planned are listed at the end and are not available yet.

## Requirements

- Godot 4.7 (the version the plugin is validated with).
- No other addon is required.

## Install

1. Copy the `addons/illustrated_walkmesh_editor/` folder into the `addons/` folder of your Godot project.
2. Open the project in Godot.
3. Enable the plugin under *Project → Project Settings → Plugins*. Tick **Illustrated Walkmesh Editor**.

The plugin was verified by enabling it alone in an empty Godot 4.7.1 project: the editor starts without errors. The examples folder can be copied the same way.

## Open the dock

The **IWE** dock appears in the right-hand dock area once the plugin is enabled.

## Workflow

1. **Import an illustration.** Click `Import image` and choose a PNG, JPG, or WebP file. The image is shown on the canvas.
2. **Create a group.** Click `New group` and name it. Groups organize regions; you need one before drawing.
3. **Draw a walkable zone.** Click `Draw polygon`, click to place points, and close the polygon by clicking the first point. The region is added to the active group.
4. **Edit the zone.** Use `Select / move region` to move a zone, and `Edit points` to move, add (`Add point to edge`), or remove (`Remove selected point`) vertices.
5. **Cut holes.** Click `Boolean − (cutout)`, select the region, and draw the hole. The cutout must overlap the region. Each cutout can be renamed.
6. **Place height templates.** Click `Place / move height template` and click on the illustration where a character stands. Set its apparent height in pixels in the field below. Use several templates at different depths to calibrate the camera.
7. **Calibrate the perspective.** Open the perspective panel (`Perspective`). Adjust the camera, or click `Fit camera to height references` when you have two or more templates at different depths.
8. **Export a scene.** Use *Scene export*:
   - `Export 2D scene` writes a standalone 2D scene.
   - `Export 3D stage` writes a flat 3D stage.
   - `Export perspective scene` writes the calibrated 3D stage. Re-export after changing the calibration.
9. **Save and reopen.** Click `Save`, choose a `.tres` file, and accept the copy of the illustration if it is proposed. Use `Open` to reopen the document later.

## Undo and redo

`Undo` and `Redo` (or `Ctrl+Z` and `Ctrl+Shift+Z` / `Ctrl+Y` while the illustration has focus) work for polygon edits, cutouts, groups, templates, and calibration changes.

Each document has its own history. Creating a new document or opening another one starts an empty history, so nothing from the previous document can be undone into the new one. Creating or opening a document is itself not undoable. Godot's main `Ctrl+Z` (when the illustration does not have focus) does not undo IWE edits.

## Floating window

The `Window` button moves the illustration area into a large separate window, which is useful for seeing the whole illustration at once. Close the window, or click `Window` again, to return the canvas to the dock.

## Connected zones

Two walkable zones that share an edge are connected: the character walks from one to the other without a wall at the shared edge. Zones that only touch at a corner are not connected. You do not need to merge the polygons.

**Limitation:** zones that overlap without sharing an exact edge are not connected yet. Their walls are removed where they overlap, but the character cannot path from one to the other with click-to-move. Snap the shared border so both zones use the same edge.

## Known limitations

- Locking a region has no button yet. Locked regions are respected when they are locked by data.
- The perspective calibration assumes one flat floor. It does not detect terrain height or hidden depth.
- Scenes must be exported again after changing a region or the calibration.
- Only walkable regions and cutouts exist. Region types (connection, collision-only, special) are not implemented yet.

## Planned features

Union, intersection, and XOR operations, explicit connections, layers, visual elements, occlusion, and parallax are planned. See [`SPECIFICATION.md`](SPECIFICATION.md) and [`ROADMAP.md`](ROADMAP.md).

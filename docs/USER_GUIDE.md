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

The **IWE** dock appears in the right-hand dock area once the plugin is enabled. It has two tabs: **Creation** (layers and pictures, regions, drawing tools, height references, camera) and **Test** (the test character and its speed, export, validation). Each tab is made of sections you can fold with a click on their title.

## Workflow

1. **Import an illustration.** Click `Import image` and choose a PNG, JPG, or WebP file. The image is shown on the canvas.
2. **Create a group.** Click `New group` and name it. Groups organize regions; you need one before drawing.
3. **Draw a walkable zone.** Click `Draw polygon`, click to place points, and close the polygon by clicking the first point. The region is added to the active group.
4. **Edit the zone.** Use `Select / move region` to move a zone, and `Edit points` to move, add (`Add point to edge`), or remove (`Remove selected point`) vertices.
5. **Merge two zones (optional).** Select a region in the list and click `Merge with…`, then choose the other region. They become one polygon (the selected region keeps its name and group), and a cutout of one region stays only where the other region does not cover it. Regions that neither touch nor overlap, or a union that would leave a hole, are refused with a message. Undo gives both regions back. You rarely need this: touching and overlapping zones already walk as one.
6. **Cut holes.** Click `Boolean − (cutout)`, select the region, and draw the hole. The cutout must overlap the region. Each cutout can be renamed.
7. **Add a foreground or background picture.** In the Creation tab, section *Layers and pictures*, select a layer and click `Add image…`; choose a transparent PNG or WebP (the template package has `foreground_template.png`, a fountain the size of the background). Set its position, scale and opacity in the fields under the list. `Drawn` chooses how the character meets it: *Behind* and *In front* are fixed; *By depth* hides the character when it stands farther from the camera than the picture's **ground point** (where it touches the floor, shown as a dot on the canvas; default bottom centre) and draws it in front when nearer. Place the ground point at the base of the object. In V1, prepare the picture beforehand at the resolution and framing you want: the background image fills the camera frame, so give a foreground or background picture the same canvas size as the background (the `foreground_template.png` of the examples does) and add transparent pixels around the object so that it lines up. The position and scale fields are for small corrections; there is no mouse moving or resizing of pictures yet (planned for V2). A layer can be hidden, locked or faded; `Remove` takes the selected picture or layer away (its pictures go to the default layer). Pictures never block walking.
8. **Place height templates.** Click `Place / move height template` and click on the illustration where a character stands. Set its apparent height in pixels in the field below. Use several templates at different depths to calibrate the camera.
9. **Calibrate the perspective.** Open the perspective panel (`Perspective`). Adjust the camera, or click `Fit camera to height references` when you have two or more templates at different depths. Under the button, each template shows how far the camera is from it (`+4.0%` means the character looks 4% taller than the template). Above 5% a warning asks you to check the heights. The panel also gives the horizon row, and lists zones on or above it: the floor cannot be projected there, so they are not exported.
10. **Try the stage with a test character.** In the Test tab, turn on `Test walk`. A character appears on the floor; click the preview to send it there (clicks no longer place height references while this is on). `Base speed` is its walking speed in world units per second; `×1`, `×2`, `×5` and `×10` multiply it, and you can change them while it walks. `Pause` freezes it and `Resume` continues, `Reset position` puts it back at its start. The speed is the same at every depth, so it looks slower far away: that is the perspective, not a setting. None of this is saved in the document or written to an export.
11. **Export a scene.** In the Test tab, section *Export*. `Check the perspective export` in section *Validation* first lists what an export would drop or change, without writing a file:
   - `Export 2D scene` writes a standalone 2D scene.
   - `Export 3D stage` writes a flat 3D stage.
   - `Export perspective scene` writes the calibrated 3D stage. Re-export after changing the calibration.
12. **Save and reopen.** Click `Save` and choose a `.tres` file. The illustration is copied next to it in an `assets` folder, and the project can then be moved. Use `Open` to reopen the document later.

## Undo and redo

`Undo` and `Redo` (or `Ctrl+Z` and `Ctrl+Shift+Z` / `Ctrl+Y` while the illustration has focus) work for polygon edits, cutouts, groups, templates, and calibration changes.

Each document has its own history. Creating a new document or opening another one starts an empty history, so nothing from the previous document can be undone into the new one. Creating or opening a document is itself not undoable. Godot's main `Ctrl+Z` (when the illustration does not have focus) does not undo IWE edits.

## Unsaved changes

The name of the document is shown at the right of the toolbar. A `*` after the name means there are changes that are not saved (`Untitled *` for a document that has never been saved). The mark follows Undo and Redo: if you undo back to the state you last saved, the `*` disappears, and it returns if you redo.

IWE asks before it would drop unsaved work:

- **New** and **Open** ask `Save`, `Discard Changes`, or `Cancel`. `Cancel` leaves the current document and its undo history exactly as they were. `Save` saves first and continues only if the save worked; a document that has no file yet asks where to save it.
- **Closing Godot** lists the IWE document in Godot's own *Save before closing?* dialog.
- **Closing a scene** in Godot does not mention the IWE document, because it is not part of any scene.
- **Save All** (and `Save` in the quit dialog) writes a document that already has a file, in place. A document that was never saved cannot be written silently, so IWE writes a **recovery copy** to `user://iwe_recovery/` and keeps the document marked as modified. Open the IWE `Save` button to choose a real location.
- If a save fails, a message appears in the status bar and the Output panel, the document stays marked as modified, and whatever was waiting (for example opening another document) does not happen.

The first import of an illustration cannot be undone, so it keeps the document marked as modified until you save.

## Replacing the illustration

Import another picture into a document that already has one and only the picture changes: regions, cutouts, height references and the calibration keep their values. The change can be undone. If the new picture has another size, IWE asks first, because your shapes are placed in the pixels of the current picture and may no longer line up.

## Floating window

The `Window` button moves the illustration area into a large separate window, which is useful for seeing the whole illustration at once. Close the window, or click `Window` again, to return the canvas to the dock.

## Connected zones

Two walkable zones that share an edge are connected: the character walks from one to the other without a wall at the shared edge. Zones that only touch at a corner are not connected. You do not need to merge the polygons.

**Limitation:** zones that overlap without sharing an exact edge are not connected yet. Their walls are removed where they overlap, but the character cannot path from one to the other with click-to-move. Snap the shared border so both zones use the same edge.

## Known limitations

- Duplicating a region moves its outline but not its cutouts (audit P1-10).
- A doorway needs a full shared edge. A zone that touches only part of another zone's edge is connected for navigation but keeps its wall, so the character stops at it.
- The camera fit does not show how far it misses your height references. On a steeply viewed scene it can miss by about 10%.
- The test character follows the shortest path, which hugs obstacle corners. It can stall at a very narrow doorway.

- The perspective projection depends on the shape (aspect ratio) of the reference frame, not on the dock. Changing the reference frame width or height changes where every image point lands on the floor; it is undoable and marks the document modified. A frame that differs in shape from the game window is reported in the status line.
- Locking a region has no button yet. Locked regions are respected when they are locked by data.
- The perspective calibration assumes one flat floor. It does not detect terrain height or hidden depth.
- Scenes must be exported again after changing a region or the calibration.
- Cutouts that together enclose a walkable island also block the island. Draw the island as its own region instead.
- Only walkable regions and cutouts exist. Region types (connection, collision-only, special) are not implemented yet.

## Planned features

Intersection and XOR operations, explicit connections, nested layers, picture rotation, and parallax are planned. Selecting, moving and resizing layer pictures with the mouse (handles, undo and redo, numeric fields, an optional lock) is planned for V2. See [`SPECIFICATION.md`](SPECIFICATION.md) and [`ROADMAP.md`](ROADMAP.md).

# Illustrated Walkmesh Editor (IWE)

Illustrated Walkmesh Editor is an open-source Godot editor plugin intended to help level designers turn a painted background into an authored, playable 2.5D space. The local development build supports image-backed polygon authoring and multiple subtractive cutouts per region.

## Planned capabilities

- Import and view a background illustration while authoring image-space regions.
- Edit walkable polygons and create subtractive cutouts within a selected region.
- Organize regions into flat groups; nested groups and path authoring are planned.
- Calibrate apparent character scale with artist-placed anchors.
- Preview and eventually generate runtime navigation and collision data.

Union/intersection/XOR, perspective calibration, occlusion, and runtime generation are not implemented yet.

## Compatibility

The local starter project declares Godot 4.7. Plugin compatibility will be confirmed against an installed Godot executable before the first functional release.

## Current status

The current development dock supports illustration import, flat groups, polygon creation and selection, vertex editing, region management, undo/redo, saving/reopening, and non-destructive subtraction cutouts. Runtime navigation generation is not implemented yet.

## Repository layout

- `addons/illustrated_walkmesh_editor/`: IWE editor plugin.
- `docs/`: specification, architecture, roadmap, reuse audit, and decisions.
- `examples/`: self-contained demonstrations (planned).
- `tests/`: automated tests (planned).

Third-party addons currently present in the local starter project are not part of the distributable IWE plugin and are excluded from the initial repository until individually audited.

## Installation

For development, copy `addons/illustrated_walkmesh_editor` into the `addons/` directory of a Godot 4.7 project, then enable **Illustrated Walkmesh Editor** under **Project > Project Settings > Plugins**.

### Editor controls

- **Select** is the default mode. Click a filled region or its entry in the list. Click near a vertex to select it; **− Point** removes that vertex when the polygon has more than three points.
- **Points** enables vertex handles and drag-to-move. **+ Point** enters a one-click mode: click an edge to insert a vertex. Press Escape to cancel.
- **Import image** enables **New group**. Choose or create a group before **Polygon** becomes available; each new region belongs to the active group. Click to add vertices, click near the first point or press Enter to finish, and Escape to cancel.
- **Boolean −** requires a selected, unlocked region. Draw one or more polygons inside it; the red areas are cutouts. Each cutout can be undone, is saved with its region, and contributes hole contours to the derived walkable geometry. Select another tool to finish adding cutouts.
- **Delete**, **Duplicate**, **Rename selected region**, and **Hide/Show region** act on the selected region. Region changes can be undone/redone.
- Use the middle mouse button to pan and the wheel or zoom buttons to zoom.
- **Save** writes an IWE `.tres` document. If needed, choose the folder where IWE should save a copy of the background; the image is stored beside the document under `assets/` and referenced relatively. **Open** restores the image and regions together.

The document stores polygon vertices in the source image's pixel coordinates, independently of viewport zoom. Groups currently provide a flat organizational level; nested groups, group renaming/reordering, union/intersection/XOR, self-intersection validation, and runtime navigation generation remain future work.

## License

IWE is distributed under the MIT License. See [LICENSE](LICENSE).

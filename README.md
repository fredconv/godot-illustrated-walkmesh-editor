# Illustrated Walkmesh Editor (IWE)

Illustrated Walkmesh Editor is an open-source Godot editor plugin intended to help level designers turn a painted background into an authored, playable 2.5D space. The project is at the initialization and research stage; the features below describe goals, not implemented functionality.

## Planned capabilities

- Import and view a background illustration while authoring image-space regions.
- Edit walkable polygons, blocked areas, groups, and paths.
- Calibrate apparent character scale with artist-placed anchors.
- Preview and eventually generate runtime navigation and collision data.

Boolean region operations, perspective calibration, occlusion, and runtime generation are research items and are not available yet.

## Compatibility

The local starter project declares Godot 4.7. Plugin compatibility will be confirmed against an installed Godot executable before the first functional release.

## Current status

The current development dock supports illustration import, polygon creation and selection, vertex editing, region management, undo/redo, and saving/reopening a document. Runtime navigation generation and boolean operations are not implemented yet.

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
- **Polygon** starts a new region. Click to add vertices, click near the first point or press Enter to finish, and Escape to cancel.
- **Delete**, **Duplicate**, **Rename selected region**, and **Hide/Show region** act on the selected region. Region changes can be undone/redone.
- Use the middle mouse button to pan and the wheel or zoom buttons to zoom.
- **Save** writes an IWE `.tres` document. If needed, choose the folder where IWE should save a copy of the background; the image is stored beside the document under `assets/` and referenced relatively. **Open** restores the image and regions together.

The document stores polygon vertices in the source image's pixel coordinates, independently of viewport zoom. Self-intersecting polygon validation, boolean operations, groups, and runtime navigation generation are future work.

## License

IWE is distributed under the MIT License. See [LICENSE](LICENSE).

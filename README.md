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

The first development dock is implemented: it can select and display a local illustration, and provides zoom controls and middle-button panning. Document data stores the image path and native dimensions. Polygon editing, document persistence through the UI, and runtime generation are not implemented yet.

## Repository layout

- `addons/illustrated_walkmesh_editor/`: IWE editor plugin.
- `docs/`: specification, architecture, roadmap, reuse audit, and decisions.
- `examples/`: self-contained demonstrations (planned).
- `tests/`: automated tests (planned).

Third-party addons currently present in the local starter project are not part of the distributable IWE plugin and are excluded from the initial repository until individually audited.

## Installation

For development, copy `addons/illustrated_walkmesh_editor` into the `addons/` directory of a Godot 4.7 project, then enable **Illustrated Walkmesh Editor** under **Project > Project Settings > Plugins**. The current dock is an early development build and does not yet save authored regions.

## License

IWE is distributed under the MIT License. See [LICENSE](LICENSE).

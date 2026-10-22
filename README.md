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

No IWE editor plugin has been implemented yet. This repository currently contains the Godot project shell and project documentation.

## Repository layout

- `addons/illustrated_walkmesh_editor/`: IWE editor plugin (planned).
- `docs/`: specification, architecture, roadmap, reuse audit, and decisions.
- `examples/`: self-contained demonstrations (planned).
- `tests/`: automated tests (planned).

Third-party addons currently present in the local starter project are not part of the distributable IWE plugin and are excluded from the initial repository until individually audited.

## Installation

Once a release is available, copy `addons/illustrated_walkmesh_editor` into the `addons/` directory of a Godot 4.7 project, then enable **Illustrated Walkmesh Editor** under **Project > Project Settings > Plugins**. The plugin is not yet available for installation.

## License

IWE is distributed under the MIT License. See [LICENSE](LICENSE).

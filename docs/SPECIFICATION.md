# IWE Specification

## Purpose and status

Illustrated Walkmesh Editor (IWE) is intended to let an artist author playable navigation over a painted illustration. The immediate product target is an image-space 2.5D workflow; the art remains the visual source of truth and the plugin does not claim to recover real 3D geometry automatically.

This is a starting specification. No IWE functionality is implemented as of the initial repository setup.

## Core concepts

- **Illustration:** source image with native pixel coordinates. Pan and zoom must not alter stored geometry.
- **Region:** polygonal source geometry with a stable identifier, name, color, level, and editability state.
- **Path:** optional authoring aid that can produce a region; polygonal regions remain the canonical model.
- **Group:** hierarchical organizational node with visibility and lock state.
- **Modifier:** ordered, non-destructive operation over explicitly scoped geometry. Boolean operations must preserve original inputs.
- **Scale anchor:** image-space point with a desired apparent character height. It encodes artistic scale, not unique physical depth.
- **Blocked region, connection, and occluder:** separate concepts from walkable area and generated collision.
- **Generated output:** derived navigation/collision/runtime data, kept separate from editable source data.

## Functional goals

1. Import, display, lock, pan, and zoom an illustration with optional grid and guides.
2. Author, select, validate, and edit independent convex or concave polygons, including regions with holes and multiple levels.
3. Organize regions in stable-ID hierarchical groups.
4. Provide path-based region authoring, including variable width and branches where practical.
5. Support scoped, ordered, non-destructive UNION, SUBTRACT, INTERSECT, and XOR operations.
6. Place and edit scale anchors and preview an interpolated scale field across compatible regions.
7. Author blocked regions, explicit portals/connections, and foreground/background occluders.
8. Generate runtime surfaces and physics separately, with a screen-space 2.5D mode first and an architecture that can later support a calibrated 3D mode.
9. Provide a reproducible countryside demo and automated algorithm/data tests.

## Non-goals and constraints

- Automatic scene reconstruction or unique 3D depth inference from a single image.
- Treating visual scale as equivalent to ground depth or elevation.
- Silently connecting regions that only overlap visually.
- Destructive modifier evaluation that discards source contours.

## Near-term acceptance criteria

The first useful alpha should load and unload cleanly as an editor plugin, display an image in a dock, preserve image-space coordinates through zoom/pan, and save/reload its authored data. Later milestones add polygon authoring and validated geometry operations.

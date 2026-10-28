# Illustrated Walkmesh Editor (IWE)

Illustrated Walkmesh Editor is an open-source Godot editor plugin intended to help level designers turn a painted background into an authored, playable 2.5D space. The local development build supports image-backed polygon authoring and multiple subtractive cutouts per region.

## Planned capabilities

- Import and view a background illustration while authoring image-space regions.
- Edit walkable polygons and create subtractive cutouts within a selected region.
- Organize regions into flat groups; nested groups and path authoring are planned.
- Calibrate apparent character scale with artist-placed anchors.
- Place, drag, and resize standing height templates; include them as scale capsules in exported 3D stages.
- Generate runtime navigation and collision data for the exported scenes (implemented for the perspective stage; see below).

Not implemented yet: union, intersection and XOR operations, the Layer Manager, visual layers and PNG elements, depth occlusion, parallax, and connections as explicit regions. See [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Status

Pre-release (`0.1.0-dev`). Expect breaking changes to the saved document format until a stable version is announced. Do not use it for production data without keeping a backup.

## Compatibility

The local starter project and current validation target Godot 4.7.1.

## Current status

The current development dock supports illustration import, flat groups, polygon creation and selection, vertex editing, region management, undo/redo, saving/reopening, and non-destructive subtraction cutouts. It exports standalone Godot 2D scenes, flat top-down 3D stages, and a perspective-calibrated 3D stage. The perspective workflow projects authored image coordinates onto a configurable flat floor using camera rays, warps the illustration onto that floor, and preserves walkable regions and cutouts. Camera field of view, transform, floor height, and top-down orthographic preview can be adjusted. Image-space scale anchors place known-height 3D capsules on the floor. This calibration does not infer real terrain height or hidden depth.

## About the Project & AI-Assisted Development

This project started from a personal need.

As a developer and digital artist, I wanted a simple and intuitive way to turn 2D illustrations into navigable 2.5D environments in Godot, without having to manually rebuild everything in 3D.

I couldn't find a tool that matched exactly what I had in mind, so I decided to create my own.

While I have a background in development, I'm using AI-assisted coding tools, particularly **Claude Code**, to help design, implement, improve, and maintain this plugin.

I'm not trying to hide the fact that AI is involved in its development. On the contrary, I see it as an opportunity to bring ideas to life, explore technical solutions, and learn along the way.

The original idea, functional requirements, creative direction, and development priorities come from me, while AI helps turn that vision into working code.

### An Open-Source Project

I'm initially building this plugin for my own Godot projects, but I believe it could also be useful to other developers and artists working on similar 2.5D games.

That's why I've decided to share it as an open-source project.

### Feedback & Contributions Welcome

This is an evolving project, and I'm always interested in hearing new ideas.

If you have suggestions, discover bugs, or think of features that could improve the plugin, feel free to open a GitHub Issue or start a discussion.

I'll do my best to review suggestions and, whenever possible, implement improvements with the help of Claude Code and other development tools.

I can't promise that every feature request will be implemented, but constructive feedback is always appreciated.

**The goal is simple: build a useful tool, share it with the community, and keep improving it together.**

## Documentation

- [User guide](docs/USER_GUIDE.md): what works today, step by step.
- [Development guide](docs/DEVELOPMENT.md): setup and headless tests.
- [Data format](docs/DATA_FORMAT.md): saved document versions and compatibility.
- [Specification](docs/SPECIFICATION.md), [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md).
- [Changelog](CHANGELOG.md), [contributing](CONTRIBUTING.md), [security](SECURITY.md).

## Repository layout

- `addons/illustrated_walkmesh_editor/`: IWE editor plugin.
- `docs/`: specification, architecture, roadmap, reuse audit, and decisions.
- `examples/`: perspective demo scene and its repeatable generator.
- `prototypes/`: standalone experiments that are not part of the plugin (transparency modes for occlusion).
- `tests/`: GdUnit4 regression tests.

Third-party addons currently present in the local starter project are not part of the distributable IWE plugin and are excluded from the initial repository until individually audited.

## Installation

For development, copy `addons/illustrated_walkmesh_editor` into the `addons/` directory of a Godot 4.7 project, then enable **Illustrated Walkmesh Editor** under **Project > Project Settings > Plugins**.

### Editor controls

- **Select** is the default mode. Click a filled region or its entry in the list. Click near a vertex to select it; **− Point** removes that vertex when the polygon has more than three points.
- **Points** enables vertex handles and drag-to-move. **+ Point** enters a one-click mode: click an edge to insert a vertex. Press Escape to cancel.
- **Import image** enables **New group**. Choose or create a group before **Polygon** becomes available; each new region belongs to the active group. Click to add vertices, click near the first point or press Enter to finish, and Escape to cancel.
- **Boolean −** requires a selected, unlocked region. Draw one or more polygons inside it; the red areas are cutouts. Each cutout appears as a named child in the region tree, can be renamed, is saved with its region, and contributes hole contours to the derived walkable geometry. Select another tool to finish adding cutouts.
- **Delete**, **Duplicate**, **Rename selected region**, and **Hide/Show region** act on the selected region. Region changes can be undone/redone.
- Use the middle mouse button to pan and the wheel or zoom buttons to zoom.
- **Save** writes an IWE `.tres` document. If needed, choose the folder where IWE should save a copy of the background; the image is stored beside the document under `assets/` and referenced relatively. **Open** restores the image and regions together.
- **Export 2D scene** builds a scene containing the illustration and one `NavigationRegion2D` per visible walkable region. The `2D scale` value is world units per illustration pixel (default `1`). Enable **Add camera** to include a `Camera2D` centered over the illustration.
- **Export 3D stage** builds a horizontal illustration plane and one flat `NavigationRegion3D` mesh per visible walkable region, nested under its named group. A translucent surface and exact authored outer/cutout contour guides are rendered above the image; Godot's convex navigation cells can still add internal partition edges in editor gizmos. Baking uses zero agent radius so exported navigation does not silently shrink the authored area. Its `3D scale` defaults to `0.01` world units per pixel, so a 1920×1080 image spans 19.2×10.8 units. **Add camera** is enabled by default and adds an orthographic top-view camera framed to preserve the full image width, including in a narrow editor preview. Save the generated scene inside the current Godot project so its resources can be loaded portably.
- **Perspective calibration** opens a separate preview with the editable camera, a flat virtual floor, and an orthographic top view. Adjust field of view, camera position and rotation, floor height, and known character height. IWE projects each image-space polygon vertex to the floor using the matching camera ray; cutout loops stay attached to the region. A subdivided image mesh is warped onto the same floor so the camera view and authored regions use the same projection. Export with **Export perspective scene**. Keep the camera aspect ratio aligned with the reference viewport (1280×720 by default) for a direct match.
- **Scale template** mode: click the image to place a standing height marker, drag it to move it, choose its apparent height in illustration pixels, and delete it with the button or Delete key. The exported 3D stage adds an upright capsule at each template's image position under `Template/ScaleTemplates`. The chosen height is an artist-authored apparent-size cue and does not determine true physical depth.
- In perspective calibration, click the preview to place a known-height character template at that image position. The exported stage includes the upright capsule and scales it with the stage's world-units-per-pixel value. Multiple anchors are visual references; they do not yet drive automatic depth interpolation.
- Each generated scene root is a normal Godot `Node2D` or `Node3D`: move it, rotate it, scale it, add a character, or add other nodes in the Scene dock. The flat 3D export keeps the original top-down plane. The perspective export maps the image to a calibrated flat floor; neither mode reconstructs terrain height or hidden depth.

- **Fit camera to height references** (perspective panel) solves the camera pitch and height so that two or more height references at different depths appear at their authored apparent heights. It is one undoable step; field of view and yaw are kept.
- **Add player** adds a `Player` node to the exported perspective stage. It starts on a walkable area, walks where you click on the floor, stays inside walkable polygons and outside cutouts, and is drawn at the size the calibrated camera gives its position. Keyboard control (arrows or WASD) is also available. The runtime script is `addons/illustrated_walkmesh_editor/runtime/iwe_walkmesh_character.gd`.

### Perspective demo

Open `examples/perspective_calibration_demo.tscn` to inspect a ready-made perspective stage with two named walkable polygons, two named cutouts, a perspective camera, a top camera, and near/far known-height templates. It uses `assets/img/background.png`. To regenerate it after changing the builder, run `godot --headless --path . --script res://examples/generate_perspective_demo.gd`.

The document stores polygon vertices in the source image's pixel coordinates, independently of viewport zoom. Groups currently provide a flat organizational level; group and cutout names can be edited in the hierarchy. Nested groups, group reordering, union/intersection/XOR, self-intersection validation, automatic depth inference, and occlusion authoring remain future work.

## License

IWE is distributed under the MIT License. See [LICENSE](LICENSE).

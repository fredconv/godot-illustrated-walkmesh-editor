# IWE Specification

Working name: **IWE (Illustrated Walkmesh Editor)**. The final public name is not chosen yet.

## 1. Vision

IWE is a Godot 4.x editor plugin that turns a 2D illustration (painted background, pixel art, isometric art) into a navigable 2.5D environment that can be reused in a 3D scene.

The product is a complete chain, not just a polygon editor:

> 2D illustration → polygon zones and exclusions → perspective calibration → 3D projection → testable navigation and collision → reusable Godot scene

The illustration stays the visual source of truth. IWE does not recover real 3D geometry from a single image. It produces a perspective-consistent, controllable approximation for gameplay.

## 2. Core principles

1. **Non-destructive editing.** Source polygons, cutouts, anchors, and layers remain editable. Generated navigation, collision, and scenes are derived and can be regenerated.
2. **Image-space authority.** Geometry is stored in source-image pixel coordinates. Pan and zoom are presentation state only.
3. **Three separate concerns.** Layer organization, geometry and navigation, and rendering and depth are distinct systems (section 4). Their data never implies one another.
4. **Native Godot output.** Export uses standard nodes (`NavigationRegion2D/3D`, collision shapes, `Sprite2D/3D`, cameras) so the result is editable in Godot.
5. **Reliable serialization.** A saved project reopens with all authored data intact.

## 3. Functional requirements

### 3.1 Illustration

- Import PNG, JPG, and WebP files supported by Godot; keep the original dimensions.
- Pan, zoom, show or hide the image.
- Copy the image beside the project file so the project stays portable.
- Warn when a replacement image changes dimensions: completed. Replacing the picture keeps regions, templates and calibration, and is undoable.
- Optional opacity control while tracing (planned).

### 3.2 Polygon regions

- Create convex and concave polygons; close them automatically or manually.
- Select, move a vertex, insert a vertex on an edge, remove a vertex (minimum three), move a whole region.
- Duplicate, rename, hide, lock, and delete regions.
- Undo and redo for every edit, with a history that belongs to the open document. Creating or opening a document starts a new, empty history.
- Snapping to vertices and edges (planned).

### 3.3 Region types

Each region has a type that decides how it is used at runtime. The current implementation only has *walkable* regions and *cutouts*.

| Type | Purpose | Status |
|---|---|---|
| Walkable | Surface the character can stand on | Partial (implicit: every region) |
| Exclusion (cutout) | Removes area from a walkable region | Completed |
| Connection | Explicit bridge or link between regions | To develop |
| Collision only | Physical obstacle with no navigation effect | To develop |
| Special | Slowdown, navigation cost, conditional access | To develop |

### 3.4 Groups and Boolean operations

- Flat groups exist. Nested groups are to develop.
- Subtraction (cutouts) is completed: a region keeps several named cutouts, and contours are derived with Godot's clipping API. Overlapping, nested, and edge-touching cutouts are merged before subtraction, so their intersection is removed once. **Known limitation:** two or more cutouts that together enclose a walkable island currently block the island as well; the island is not restored.
- Union, intersection, and XOR are to develop as scoped, non-destructive modifiers. IWE does not need to merge polygons into one shape: touching zones can stay separate and still form one walkable network (section 3.5).

### 3.5 Connected zones

The character must be able to walk from one zone to another when their polygons touch, for example *Left path → Bridge → Right path*, without the zones being merged.

- Shared edges are passages, not walls. Outer edges keep their walls.
- A contact at a single point does not create a passage.
- Zones that overlap are walkable as one. The zone drawn first keeps the shared ground and a later zone's navigation stops on its outline, so each point is covered once and Godot links the meshes along that outline. Walls are removed only where another zone covers the edge. A zone entirely inside an earlier zone adds nothing. Ground inside an earlier zone's cutout stays walkable when a later zone covers it (audit P1-2).
- Zones at different heights are not connected unless an explicit connection exists (to develop).
- A passage narrower than the character's physical diameter is not traversable. The export reports each doorway (a covered run of an edge with a wall on both sides) that is narrower than the diameter, so the author can widen it; the path planner itself does not avoid such a passage yet (the character stops in front of it). A run that reaches a zone corner is not judged.
- A cutout (lake, building, fountain) blocks the ground of its own zone. Under the union rule, ground that another zone also covers stays walkable: draw the second zone around the obstacle, not over it, when the obstacle must stay closed.

Status: **Completed** for zones that share an edge (in full or in part) or overlap, on one floor (tested headlessly and end to end). Explicit connections, width checks, and level handling are to develop.

### 3.6 Calibration

- Scale templates: image-space height references, stored as apparent height in pixels.
- Perspective calibration: camera field of view, transform, virtual floor height, and known character height. The projection frame is an explicit reference viewport stored in the calibration (aspect ratio only); it does not depend on the dock or window size.
- Fit camera to two or more height references: completed (automatic fit from anchors).
- Manual calibration of camera and floor: completed.
- Assisted calibration with explicit constraints and a quality diagnostic: to develop.
- Multi-position calibration presets (Near / Middle / Far): partial (templates exist, presets do not).

The calibration assumes one flat virtual floor. It does not infer terrain elevation or hidden depth.

### 3.7 Layers (new system)

A Photoshop-style layer manager for organizing both regions and visual elements. Full design in section 4 and `ARCHITECTURE.md`.

- Create, delete, rename, duplicate, reorder, group, and nest layers.
- Show, hide, lock, and set opacity per layer.
- Move regions and visual elements between layers.
- Layer order controls drawing only. It never changes navigation.

Status: **To develop.** Current data has no layer model.

### 3.8 Visual elements (new system)

- Import transparent PNG, WebP, and other Godot-compatible textures.
- Move, scale, rotate, pivot, flip, set opacity, and set exact coordinates.
- Ground anchor point for depth placement.
- Depth modes: background, foreground (always in front), depth occlusion (in front or behind the character by 3D depth), parallax (depth coefficient).
- Visual elements never create navigation or physical collision automatically.

Status: **To develop.**

### 3.9 Navigation and collision

- Generate `NavigationRegion2D` (2D export) and `NavigationRegion3D` (3D exports) per walkable region.
- Connections between touching zones come from shared edges (completed for perspective export).
- Generated collision walls on outer boundaries and cutouts (completed for perspective export).
- Separate collision layer masks and configurable navigation parameters: to develop.
- Test character with mouse and keyboard, walls, and path following (completed in the perspective runtime). A testing speed multiplier (x0.1 to x10), pause, and reset are available on the character; they are never saved or exported. Controls in the dock preview are to develop.
- Debug overlays for contours, exclusions, connections, collisions, and templates: partial (contour and template guides exist; connection and collision overlays do not).

The physical character size is a runtime setting, separate from its visual height. Perspective changes apparent size on screen; it must not change physical size.

### 3.10 Export

| Output | Content | Status |
|---|---|---|
| 2D scene | Illustration, camera (optional), walkable navigation regions | Completed |
| 3D stage (flat) | Image plane, navigation regions, guides, top camera | Completed |
| Perspective scene | Calibrated floor, warped image, walkable regions with walls, height templates, optional test character, cameras | Completed |
| Environment only | Geometry and decor without navigation | To develop |
| Navigation only | Navigation and collision data without decor | To develop |

Exported scenes are standard Godot scenes. Templates are placed in a `ScaleTemplates` node in 3D. The 2D export has no templates by design.

### 3.11 Save and reopen

- Save an IWE document (`.tres`) containing image reference, groups, regions, cutouts, templates, and calibration: **completed**, tested.
- Reopen a document and continue editing: **completed**, tested.
- Unsaved-change protection: **completed**. The document shows a modified mark that follows undo and redo; New and Open ask Save, Discard Changes, or Cancel; Godot's quit dialog lists an unsaved document; a failed save keeps the document modified. A document that was never saved gets a recovery copy in `user://iwe_recovery/` when Godot asks to save. The first import of an illustration is not undoable and keeps the document modified until saved; replacing it is undoable.
- Schema version and migration: **partial**. The field exists (default 1, omitted from files). Writing the current version, refusing a newer one, and migrating are to develop.
- Layers, visual elements, connections, region types, and export options in the document: **to develop**.
- Exports never modify the source document.

### 3.12 Editor interface

- Workspace: Image & Regions, Perspective, 3D Preview, Test, Export.
- Floating large window for the illustration (completed).
- Interface in English. Most labels are English; a few remain French (to be cleaned up).
- Undo and redo, status bar messages, and explicit error messages.

## 4. Architecture of the three systems

Responsibilities are split so that layer order never affects navigation.

| System | Responsibility | Depends on |
|---|---|---|
| **Layer Manager** | Organization, visibility, lock, opacity, transforms, hierarchy, draw order | Nothing navigational |
| **Geometry & Navigation** | Polygons, zones, exclusions, connections, collision shapes, navigation data | Image coordinates only |
| **Rendering & Depth** | Display, perspective, occlusion, parallax, camera projection | Layer data and geometry, read-only |

The character's behaviour depends on Geometry & Navigation. Rendering decides what is drawn in front of or behind it. Neither the draw order of a layer nor a visual element's transparency changes whether a zone is walkable.

## 5. Status summary

**Completed**
- Image import, pan and zoom, floating window.
- Polygon creation, vertex edit, move, duplicate, rename, hide, delete, undo and redo.
- Flat groups.
- Subtractive cutouts with names.
- Scale templates (image-space, persisted, exported in 3D).
- Perspective calibration, camera fit from templates, perspective scene export.
- 2D and 3D exports with optional cameras.
- Save and reopen of IWE documents.
- Touching zones are walkable as one network (headless test).
- Test character with mouse and keyboard, walls, path following.
- Automated test suite: 141 headless GdUnit4 tests passing.

**Partially implemented**
- Locked regions: the model and canvas respect the lock, but no button sets it.
- Walkable regions: implicit only, no explicit type field.
- Multi-position calibration: templates exist, no preset workflow.
- Debug overlays: contours and templates only.
- Manual GUI verification: much of the editor is checked only headlessly.

**To develop (in planned order, see `ROADMAP.md`)**
- Region types (connection, collision only, special) and explicit connections.
- Nested groups.
- Union, intersection, XOR modifiers.
- Layer Manager and visual elements.
- Depth occlusion, parallax, and visual export.
- Assisted calibration and quality diagnostics.
- Schema version, migration, and project file extensions.
- Environment-only and navigation-only exports.
- Physical character radius and passage width checks.
- Full English interface pass and project rename.

## 6. Non-goals

- Automatic scene reconstruction or unique 3D depth from a single image.
- Treating visual scale as ground depth or elevation.
- Silently connecting zones that only touch at a point or overlap at different heights.
- Destructive evaluation of modifiers that discards source contours.
- Bundling third-party addons without a provenance and licence check.

## 7. Example

A garden illustration with a main path, a river, and a bridge:

```
Walkable areas
├── Main_Path
├── Garden_Left
└── Garden_Right
Exclusions
├── River_01
└── Rock_01
Connections
└── Wooden_Bridge
Calibration
├── Character_Near   (1.8 m)
├── Character_Middle (1.8 m)
└── Character_Far    (1.8 m)
```

The three references share the same real height but different apparent sizes, according to their distance from the camera.

## 8. Roadmap summary

The detailed phases and their status are in `ROADMAP.md`. The planned order is:

1. Finish polygon features: region types and properties, lock control.
2. Explicit connections and independent collision regions.
3. Layer Manager architecture: hierarchy, serialization, schema version.
4. Visual layers: PNG import and transforms.
5. Occlusion modes, 3D depth, and parallax.
6. Calibration improvements and exports adapted to the layer architecture.

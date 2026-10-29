# Layer Manager — Design Proposal (draft)

Status: **partly implemented on 2026-10-29, in a reduced form** (see the box below). Original status line: **design validated, implementation not started.** The architecture (§3), schema version 2 and its migration (§4), asset handling (§4.3), and the transparency prototype (§5.3) are agreed. The Layer Manager itself is not implemented yet and no step beyond S0–S1 may start without approval.

> **What was built.** `IWELayer` (a flat list, no nesting, no ordering control) with the two default layers, `IWEVisualElement` with three depth modes (behind, in front, by depth) and a ground point, schema version 2 with the in-memory migration, the layer panel in the dock, asset copying to `assets/elements/<hash>`, and the export of pictures (sprites in 2D, camera-facing quads in the perspective stage). **Not built:** nested layers, `kind`/`draw_index` on regions, `layer_id` on regions, the pure geometry module (S3), rotation, pivot, flip, parallax, `render_technique` per element. The decisions of section 8 stand, except that layers are not nested. See `DECISIONS.md`.

## 1. Audit of the current architecture

### 1.1 Regions, groups and cutouts

- `IWEDocument.regions` is a flat `Array[IWERegion]`. Each region carries `group_id` (string) pointing into `IWEDocument.groups` (flat `Array[IWERegionGroup]`).
- Cutouts live inside the region: `subtraction_polygons` and a parallel `subtraction_names`.
- **The array order of `regions` is doing three jobs at once:**
  1. Hit-testing: `IWECanvas._find_region_at` iterates from the last element down, so the last region is the topmost.
  2. Drawing: `IWECanvas._draw` paints in array order.
  3. Export order: `IWESceneGenerator` creates navigation nodes per region in array order inside each group node.
- Groups are used **only** to organise exported navigation nodes (`group_nodes[group.id]`). They are not a visual or authoring layer.

### 1.2 Serialization

- One `.tres` file holding an `IWEDocument` (`Resource`). Nested resources (`IWERegion`, `IWEScaleAnchor`, `IWERegionGroup`, `IWEPerspectiveCalibration`) are saved as sub-resources by Godot's default serializer.
- `schema_version` exists (value 1) but no migration code exists yet.
- The illustration is copied into `assets/` beside the document and referenced by a relative `illustration_path`.

### 1.3 Region management UI

- `ui/iwe_region_list.gd` (a `Tree`) shows groups as parents and regions as children. Its metadata carries `kind` (`group`/`region`) and `id`, so it already distinguishes item types without storing a type on the region.
- All mutations go through `IWEDock` and its per-document `UndoRedo` (`_history`). Until 2026-10-29 they went through `EditorUndoRedoManager`, which mixed documents and had no `undo()` method (audit P0-1, P0-2).
- The dock is ~1,400 lines and mixes UI, document mutation, export, and calibration.

### 1.4 Calibration and projection

- `IWEPerspectiveCalibration` (camera, FOV, floor height, character height) and `IWEPerspectiveProjector` (pure static functions: image ↔ viewport ↔ floor) are already separated from the editor UI.
- `IWEScaleAnchor` stores image-space position and apparent height.

### 1.5 Scene generators and export

- `IWESceneGenerator` has three builders: `build_2d_scene`, `build_3d_scene`, `build_perspective_scene`. Each iterates `document.regions` and `document.scale_anchors`.
- Navigation and wall construction for the perspective stage now consult all regions (`_edge_is_covered_by_other_zone`). This is the first place where cross-region rules live inside the generator — the risk named in `ARCHITECTURE.md` §1.2.

## 2. Problems to solve before adding layers

1. **Array order is overloaded.** If a layer reorders visual content, it must not reorder navigation or hit-testing unintentionally. Draw order and navigation order must become explicit, separate fields.
2. **Groups and layers would be confused.** Today a group is a navigation container. Layers are an authoring/visual container. Both need a hierarchy, and they must not be the same tree.
3. **No place for visual elements.** Nothing stores PNG references, transforms, depth, or occlusion mode.
4. **No migration path.** `schema_version` exists but nothing reads it.
5. **Rules leak into the generator.** Passage and wall rules should live in a pure module before more rules are added.

## 3. Target architecture

Three independent data domains. Each has its own resources, its own tests, and its own export step.

| Domain | Owns | Depends on | Must not depend on |
|---|---|---|---|
| **Layer Manager** | `IWELayer` tree: visibility, lock, opacity, name, hierarchy, draw order of layers | Nothing navigational | Geometry or navigation results |
| **Geometry & Navigation** | `IWERegion` (points, cutouts, `kind`, `group_id`, explicit `draw_index`), `IWERegionGroup` (navigation hierarchy), connections | Image coordinates | Layers, visual elements |
| **Rendering & Depth** | `IWEVisualElement`: texture, transform, depth mode, depth value, parallax factor, ground anchor, draw order within its layer | Layers (for visibility) and the projector (read-only) | Navigation output |

### 3.1 Resources

```
IWELayer (Resource)
  id: String                 stable id, e.g. "layer_xxxxxxxx"
  name: String
  parent_id: String          "" for root
  visible: bool = true
  locked: bool = false
  opacity: float = 1.0       editor preview and visual elements inherit it
  order: int                 position among siblings (draw order between layers)

IWEVisualElement (Resource)
  id, name, layer_id
  texture_path: String       relative to the document, copied into assets/
  position: Vector2          image pixels, pivot point
  scale: Vector2 = (1, 1)
  rotation_degrees: float = 0
  flip_h, flip_v: bool
  opacity: float = 1.0
  depth_mode: int            BACKGROUND | FOREGROUND | DEPTH_OCCLUSION | PARALLAX
  depth_units: float         world depth of the element's ground anchor (perspective export)
  parallax_factor: float = 1.0
  ground_anchor: Vector2     image pixels, usually the base of the element
  draw_index: int            draw order inside its layer

IWERegion (existing, extended)
  + kind: int = WALKABLE     WALKABLE | CONNECTION | COLLISION_ONLY | SPECIAL   (step 2 of the roadmap)
  + layer_id: String = ""    authoring/visibility container only; never read by navigation
  + draw_index: int          explicit position replacing implicit array order

IWEDocument (existing, extended)
  + layers: Array[IWELayer]
  + visual_elements: Array[IWEVisualElement]
  schema_version: int        2 once the new fields are introduced
```

### 3.2 Rules that keep the domains separate

- **Navigation never reads layers or visual elements.** The generator's navigation path only consumes `regions`, `groups`, `kind`, and cutouts. A test asserts that changing a layer's order or opacity leaves navigation output identical.
- **Visual elements never produce collision or navigation.** A test asserts that no `NavigationRegion*` or `CollisionShape*` is created from an element.
- **Draw order is explicit.** `draw_index` replaces the implicit array order. Hit-testing and drawing both use it, so the current behaviour is preserved in migration.
- **Layers are a tree; groups are a tree.** They are separate arrays. A region references both, and each reference has a different meaning.

## 4. Schema version 2 and migration

### 4.1 Version 1 → version 2 (in memory, on load)

- `layers`: empty. A single default layer is created **only in memory** for the editor, and written on the next save.
- `regions[i].layer_id`: default layer id.
- `regions[i].draw_index`: the current array index `i`.
- `regions[i].kind`: `WALKABLE`.
- `visual_elements`: empty.
- `schema_version`: set to 2 after the first save.

Migration must be **idempotent** and must **never reorder regions**. A test loads a version-1 fixture and checks that hit-testing, drawing order, navigation output, and exported node order are identical before and after.

### 4.2 Forward and backward compatibility

- A document with `schema_version` greater than the plugin supports is **refused**, with an explicit error, and not modified.
- Version 2 files are not expected to open in version 1 plugins. This is a breaking format change, so the changelog and `DATA_FORMAT.md` must say so, and the plugin's minor version must indicate it while the project is `0.x`.

### 4.2.1 Migration guarantees (validated)

- **Load without modifying the file.** Opening a version-1 document migrates it **in memory only**. The file on disk is not touched until the author explicitly saves.
- **Automatic default layer.** The migrated document gets one default layer, which every region references.
- **Preserved content.** Polygons, names, positions, cutout names and order, region order, groups, scale templates, and the perspective calibration keep their values exactly. Tests compare every field before and after migration.
- **Clean refusal.** A document whose `schema_version` is newer than the plugin supports is not loaded. The editor shows an explicit message naming both versions, and the file is left unchanged.
- **Non-regression tests.** A version-1 fixture is kept in `tests/fixtures/`. Tests check the migration result, hit-testing order, drawing order, navigation output, and exported node order before and after.

### 4.3 Asset handling

- **Relative, portable paths.** Every asset path stored in a document is relative to the document's folder (`assets/...`). Absolute paths are never written. A test saves a document, moves the folder, and reopens it.
- **Organised assets folder** beside the document:
  ```
  <document folder>/
  ├── background.tres
  └── assets/
      ├── illustration_<hash>.png         the illustration (existing)
      └── elements/<hash>.png             visual elements (new)
  ```
- **Reuse of textures.** Each texture is stored once. Several `IWEVisualElement` can reference the same `texture_path`.
- **Duplicate detection.** The file name contains the first 12 characters of the file's SHA-256. Importing an image whose hash already exists in `assets/` reuses that file and does not copy it again.
- **Explicit missing-asset handling.** When an asset referenced by the document is missing, the element is kept, flagged as *missing* in the layer panel, drawn as a visible placeholder in the editor, and reported in the output panel with its path. The document is never rewritten to remove it.
- **Exported scenes keep valid references.** Exports reference the project's `res://` paths, so the scene stays valid inside the project. An export option copies the referenced assets next to the exported scene (`<scene name>_assets/`) when the scene is meant to be moved to another project. A test loads every exported scene and checks that each texture resource resolves.
- Elements reference `texture_path` (relative), never a `Texture2D` sub-resource, to keep `.tres` files small and diff-friendly.

## 5. Export strategy

| Output | Layers | Visual elements | Navigation |
|---|---|---|---|
| 2D scene | Background and foreground order preserved as sibling `Sprite2D` nodes in `z_index` order | `Sprite2D` with transform and opacity | Unchanged |
| 3D stage (flat) | Not used in the first version | Optional `Sprite3D` planes | Unchanged |
| Perspective scene | Background elements behind the floor plane | `Sprite3D` at `depth_units`, or a textured quad | Unchanged |

### 5.1 Transparency technique is pluggable

The **depth behaviour** (what the element does relative to the character: always in front, occlude by depth, parallax) is separate from the **render technique** (how transparent pixels are drawn). A layer or element stores only the behaviour. Each element also stores a `render_technique`, chosen per element, so no structural change is needed to switch technique:

```
IWEVisualElement.render_technique: int = ALPHA_SCISSOR
    ALPHA_SCISSOR | ALPHA_BLEND | ALPHA_HASH | DEPTH_PRE_PASS
```

A single mapping function turns `(render_technique, depth_mode)` into material settings (`transparency`, `alpha_scissor_threshold`, `depth_draw_mode`). Export and the editor preview both call it, so they cannot disagree. Adding a technique later means adding one enum value and one mapping entry.

### 5.2 Parallax

Parallax moves the element by `camera_offset × (1 − parallax_factor)`, which only makes sense for backgrounds, not for occluders.

### 5.3 Transparency prototype (done, not committed)

Scene: `prototypes/occlusion/occlusion_prototype.tscn`, generated by `build_occlusion_prototype.gd`. One transparent fence texture per column, with a character behind it (red) and a character beside it, in front of the camera side (blue). Each column uses one of Godot's four transparency modes.

| Mode | Behind character | Edges | Assessment |
|---|---|---|---|
| Alpha Scissor | Hidden where the slats are opaque, visible through the gaps | Crisp | Good default for fences, railings, and trees. Writes depth, so occlusion is consistent. |
| Alpha Blend | Visible through the haze band and the gaps | Soft | Best for partial transparency. Sorting issues are possible with several overlapping sprites. |
| Alpha Hash | **Not visible in this view** | Dithered, noisy | Needs investigation before any use. It is not yet explained: the behind character may be hidden by the dithered depth writes. Not recommended until checked. |
| Depth Pre-Pass | Visible through the haze band and the gaps | Soft | Close to Alpha Blend here, with depth written first. A candidate for elements with both soft edges and occlusion. |

**Conclusion of the prototype:** Alpha Scissor is the right first choice for barriers and trees. Soft transparency needs Alpha Blend or Depth Pre-Pass, selected per element through §5.1. Alpha Hash is excluded until its behaviour is understood. The prototype is not committed yet; it is kept for review.

## 6. Risks

1. **Hidden coupling to array order.** Mitigation: explicit `draw_index` plus the characterization tests in §4.1 before changing anything.
2. **Two hierarchies (layers and groups) confuse the author.** Mitigation: separate panels and clear names in the UI ("Layers" for appearance and "Navigation groups" for walkable output).
3. **Alpha blending and depth in Godot.** Occlusion may look wrong with semi-transparent sprites. Mitigation: prototype first (§5).
4. **Migration breaks existing documents.** Mitigation: fixtures of real version-1 files in `tests/`, and the idempotency test.
5. **Dock size.** Adding layers to a 1,400-line dock makes it worse. Mitigation: new `ui/iwe_layer_panel.gd`, and the layer logic in a controller, not in the dock.
6. **Large PNG files.** Mitigation: warn when a texture exceeds a size threshold; keep originals in `assets/`.

## 7. Staged plan

Each step ends with the full headless suite passing, a changelog entry, and documentation of what is implemented.

| Step | Scope | Tests added |
|---|---|---|
| **S0** | Freeze the baseline. | Characterization tests: hit-test order, draw order, navigation node order, export output for the current demo. |
| **S1** | Schema version reader and version-1 fixture. Refuse unknown higher versions. | Load fixture; refuse version 99; idempotent migration. |
| **S2** | `IWERegion.kind` (default walkable) and `draw_index`. Behaviour unchanged. | Characterization tests still pass; kind round-trips. |
| **S3** | Passage and wall rules moved to a pure `geometry/` module, output identical. | Existing walkable-connection tests unchanged. |
| **S4** | `IWELayer` tree with one default layer; regions get `layer_id`. Read-only layer list in the UI. | Layer round-trip; navigation unchanged by layer changes. |
| **S5** | Layer operations: create, rename, delete, reorder, visibility, lock, opacity, with undo/redo. | Each operation undoable; delete moves regions to the parent layer. |
| **S6** | `IWEVisualElement` import (PNG copied to `assets/`), placement, transforms, undo. Editor preview only. | Import copies with hash; transform round-trip; no navigation produced. |
| **S7** | Export of background and foreground elements in 2D and perspective scenes. | Exported nodes exist; no navigation or collision produced from elements. |
| **S8** | Depth occlusion prototype in the perspective scene, then production. | Manual check with the test character behind a railing; automated: depth value exported. |
| **S9** | Parallax. | Exported factor; camera-offset preview. |

Steps S0–S3 change no user-visible behaviour. They are the safe foundation.

## 8. Decisions needed from you

1. **Two separate hierarchies (layers for appearance, groups for navigation).** Recommended: yes.
2. **Visual elements are copied into `assets/`** like the illustration. Recommended: yes.
3. **Occlusion uses alpha-scissor sprites first**, with soft edges as a later improvement. Recommended: yes, after the S8 prototype.
4. **Schema version 2 is a breaking format change** while the project is `0.x`. Recommended: announce it in the changelog and keep the migration.
5. **Maximum nesting depth for layers.** Recommended: unlimited in the data; the UI shows a warning beyond three levels.

## 9. Git strategy (proposal, nothing executed)

Current state, verified read-only:

- `develop` is an ancestor of `feature/region-editing`: `develop..feature` has 10 commits and `feature..develop` has 0. A fast-forward or merge is possible.
- `main` and `develop` have diverged after `9759397`: `main` has 2 commits that `develop` lacks (the GitHub initialisation: LICENSE and README wording), and `develop` has 2 that `main` lacks (the initial dock and the reuse audit). A dry-run merge in both directions completes **without conflicts**.
- `origin/feature/region-editing` is at `d6f97ea`. Five commits are local only.
- `main`'s README still says "no IWE editor plugin has been implemented yet". It must be updated before any public release from `main`.

Proposed sequence:

1. **Push `feature/region-editing`** — **blocked.** The GitHub repository `fredconv/godot-illustrated-walkmesh-editor` is **public**, and `origin/develop` already exposes the initial dock code. Pushing publishes the feature branch. This needs your explicit confirmation. The first CI run happens here, so it is also the first validation of the workflow.
2. **Bring `main` changes into `develop`**: merge `main` into `develop` (`--no-ff`), resolving README wording in favour of the current status. Needs your approval.
3. **Integrate the feature into `develop`**: merge `feature/region-editing` with `--no-ff` once CI is green. This keeps the feature visible in history.
4. **Create `feature/layer-manager` from `develop`** and start with S0–S3 only.
5. **Release later**: merge `develop` into `main`, update the README status, and tag `v0.1.0-alpha.1` only when you decide. Not before.

Each step is a separate, reversible decision. None of them is executed by this proposal.

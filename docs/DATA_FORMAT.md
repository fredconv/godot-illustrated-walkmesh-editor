# Data Format

IWE saves a project as a Godot resource file (`.tres`) that contains an `IWEDocument`. The illustration is copied next to the document in an `assets/` subfolder, so the project folder stays portable.

## Versions

Two versions are tracked separately:

| Version | Where | Meaning |
|---|---|---|
| Plugin version | `addons/illustrated_walkmesh_editor/plugin.cfg` (`version`) | The release of the plugin code. |
| Document schema version | `IWEDocument.schema_version` | The layout of saved documents. |

The current document schema is **2**, written explicitly in every saved file. Documents saved before the field existed, and documents saved as version 1, load as 1 and are migrated in memory when opened (see below).

## Version 2 additions

- `layers`: list of `IWELayer` (`id`, `name`, `kind` background or foreground, `visible`, `locked`, `opacity`). Every document has the layers `layer_background` and `layer_foreground`.
- `visual_elements`: list of `IWEVisualElement` (`id`, `name`, `layer_id`, `texture_path`, `position`, `texture_size`, `scale`, `opacity`, `depth_mode` behind, in front or by depth, `ground_anchor`). `texture_path` is relative to the document (`assets/elements/<first 12 characters of the SHA-256>.<ext>`) once saved. An unset `ground_anchor` is stored as NaN and means the bottom centre of the picture.
- Migration from version 1: add the two default layers. Regions, groups, cutouts, templates and the calibration are not touched or reordered. The migration can be run again without effect. The file on disk is not modified until the author saves.

## Version 1 contents

- `illustration_path`, `image_size`: the picture and its pixel size. After a save the path is relative to the document (`assets/illustration_<hash>.png`).
- `groups`: flat list of `IWERegionGroup` (`id`, `name`).
- `regions`: list of `IWERegion`:
  - `id`, `group_id`, `name`, `color`, `visible`, `locked`
  - `points`: authored outline in image pixels
  - `subtraction_polygons` with parallel `subtraction_names` and `subtraction_ids`: cutouts. Identifiers (`cutout_<hex>`) do not change when a cutout is renamed or moved; a document saved before they existed gets them when opened.
- `scale_anchors`: list of `IWEScaleAnchor` (`id`, `name`, `position`, `apparent_height_px`).
- `default_template_height_px`.
- `perspective_calibration`: `IWEPerspectiveCalibration` (camera position and rotation, field of view, floor height, character height, reference viewport size). The reference viewport is the projection frame; only its aspect ratio affects the projection. The size of the dock panel is never stored. Documents saved before the dock stopped rewriting this value keep the value they stored; no migration is applied.
- `document_path`.

Object identity uses the stable `id` values. Display names may change freely.

`IWEDocument.validate_references()` lists broken references (a region in a missing group, an identifier used twice, a cutout name without a cutout). The dock prints them as warnings when a document is opened. Nothing is repaired or removed.

## Exported scenes

- A picture inside the project is referenced by its path, so an exported scene stays small (under 1 MB in tests). If Godot has not imported the picture yet, the editor imports it at export time. Outside the editor, or for a picture outside the project, the pixels are embedded and a warning says so.
- Exported region nodes carry the metadata `iwe_region_id`, and cutout outlines carry `iwe_cutout_id`, so a game can find the authored region from a node.

## Recovery copies

When Godot asks IWE to save and the document has no file yet, IWE writes an ordinary IWE document to `user://iwe_recovery/recovery_<date-time>.tres`. It uses the same schema as any other document and can be opened with `Open`. There is one file per editor session, overwritten on each save. Its illustration path is the one the document held, which may be an absolute path to the source image.

## Compatibility rules

- Adding an optional field with a default value does not require a new schema version.
- Renaming, removing, or changing the meaning of a field requires a new schema version and a migration.
- A document with a higher schema version than the plugin supports is not loaded. The dock reports both versions and the file is not changed. A version below 1 is refused as invalid.
- Opening a version-1 file migrates it in memory (`migrate_to_current`) and writes nothing until the author saves.
- Exports never modify the source document.

## Design notes for later versions

Version 2 is implemented in the reduced form described above (flat layers and visual elements). The Layer Manager design (`LAYER_MANAGER_DESIGN.md`) also proposes a per-region kind and an explicit draw order; those are not implemented, and the migration rules below stay the policy for them.

### Migration from version 1 to version 2

- **In memory only.** Opening a version-1 document migrates it in memory. The file on disk is not modified until the author saves explicitly.
- **Default layer.** One default layer is created, and every region references it.
- **Preserved content.** Polygons, names, positions, cutout names and order, region order, groups, scale templates, and the perspective calibration keep their values exactly.
- **Explicit draw order.** The current array order of regions becomes an explicit `draw_index`, so hit-testing and drawing do not change.
- **Refusal of newer versions.** A document with a `schema_version` newer than the plugin supports is not loaded. The editor reports both versions, and the file is left unchanged.
- **Regression tests.** A version-1 fixture is kept in `tests/fixtures/`. Tests compare fields, hit-testing order, drawing order, navigation output, and exported node order before and after migration.

### Asset paths

Asset paths are stored relative to the document's folder (done for the illustration). Visual element textures live in `assets/elements/` and are named by the first 12 characters of their SHA-256 hash. Missing assets are kept in the document and reported; they are never removed automatically.

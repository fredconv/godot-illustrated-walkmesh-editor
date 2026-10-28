# Data Format

IWE saves a project as a Godot resource file (`.tres`) that contains an `IWEDocument`. The illustration is copied next to the document in an `assets/` subfolder, so the project folder stays portable.

## Versions

Two versions are tracked separately:

| Version | Where | Meaning |
|---|---|---|
| Plugin version | `addons/illustrated_walkmesh_editor/plugin.cfg` (`version`) | The release of the plugin code. |
| Document schema version | `IWEDocument.schema_version` | The layout of saved documents. |

The current document schema is **1**. Documents saved before the field existed load with the default value, which is also 1.

## Version 1 contents

- `illustration_path`, `image_size`: source image reference and its pixel size.
- `groups`: flat list of `IWERegionGroup` (`id`, `name`).
- `regions`: list of `IWERegion`:
  - `id`, `group_id`, `name`, `color`, `visible`, `locked`
  - `points`: authored outline in image pixels
  - `subtraction_polygons` with parallel `subtraction_names`: cutouts
- `scale_anchors`: list of `IWEScaleAnchor` (`id`, `name`, `position`, `apparent_height_px`).
- `default_template_height_px`.
- `perspective_calibration`: `IWEPerspectiveCalibration` (camera position and rotation, field of view, floor height, character height, reference viewport size).
- `document_path`.

Object identity uses the stable `id` values. Display names may change freely.

## Compatibility rules

- Adding an optional field with a default value does not require a new schema version.
- Renaming, removing, or changing the meaning of a field requires a new schema version and a migration.
- A document with a higher schema version than the plugin supports must not be loaded silently. The plugin reports it as an error and leaves the file unchanged.
- Exports never modify the source document.

## Planned changes (not yet implemented)

Schema version 2 is planned with the Layer Manager and region types. It will add region types, explicit connections, layers, and visual elements. Version 1 documents will be loaded with defaults: every region walkable, no layers, no connections. The migration is not written yet; it will ship with the schema change.

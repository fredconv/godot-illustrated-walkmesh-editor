# Architecture Decision Records

## 2026-10-22 — Keep image-space geometry authoritative

**Decision:** Store authored points in native source-image coordinates and treat viewport pan/zoom as presentation state.

**Reason:** Editing must not change geometry when the editor viewport changes. This also gives screen-space 2.5D a stable basis without pretending that a painted image determines unique physical depth.

## 2026-10-22 — Preserve source geometry and separate derived output

**Decision:** Treat regions and modifier inputs as editable source resources; keep evaluated geometry and generated runtime nodes derived and regenerable.

**Reason:** Non-destructive editing and deterministic regeneration are core requirements.

## 2026-10-22 — Do not publish bundled starter addons before audit

**Decision:** Exclude the local test, MCP, and camera addons from the initial IWE distribution until their provenance, license compatibility, and need are verified.

**Reason:** The current project contains complete third-party addon trees, and no audit has yet established that redistribution is permitted or desirable.

## 2026-10-22 — Keep exported scene placement separate from template scale

**Decision:** Export an editable root node for scene placement and a child `Template` node for the image-pixel-to-world scale. Export flat 3D navigation by converting the same evaluated 2D contours used for 2D navigation.

**Reason:** The root remains convenient to move and rotate in the host scene, scale does not disappear when Godot packs the root scene, and both outputs share one tested source of truth for Boolean holes. Flat 3D stays explicit until perspective calibration and height authoring exist.

## 2026-10-28 — Touching zones are passages, not merged polygons

**Decision:** Keep polygons separate. A shared edge between two walkable zones produces no wall; outer edges and cutouts keep their walls. Zones that only touch at a point are not connected.

**Reason:** The author draws zones one after another (left path, bridge, right path). Merging polygons would destroy the separate names and editing handles, and would make the layer system harder. The walkable network is derived from the geometry instead.

**Consequence:** The passage rule currently lives in `iwe_scene_generator.gd`. It moves to a pure geometry module in step 3 of the roadmap.

## 2026-10-28 — Three separate systems: layers, geometry and navigation, rendering and depth

**Decision:** Layer organization, geometry and navigation, and rendering and depth are separate data domains. Layer order never affects whether a zone is walkable. Visual elements never create navigation or collision automatically.

**Reason:** A character can pass behind a house while the path continues behind it. Tying navigation to draw order would force the author to contort the layers to fix walkability, and would make occluders block the character by accident.

## 2026-10-28 — Layers are a separate resource tree, not a field on regions

**Decision:** `IWELayer` and `IWEVisualElement` are separate resources referenced by id. Regions keep their geometry and may reference a layer id.

**Reason:** Geometry stays stable when layers are reorganized, and the navigation rules never need to read layer data.

## 2026-10-28 — Add a schema version before new document fields

**Decision:** `IWEDocument` gets a `schema_version` field. Version 1 documents (the current format) load with defaults: every region walkable, no layers, no connections.

**Reason:** The document format has no version today. New fields (region types, connections, layers) would otherwise break old files silently.

## 2026-10-28 — Interface in English, project name provisional

**Decision:** User-facing labels and tooltips are in English. The working name stays IWE until the final public name is chosen.

**Reason:** The public documentation and the GitHub presentation are in English.

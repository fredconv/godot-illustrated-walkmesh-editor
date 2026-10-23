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

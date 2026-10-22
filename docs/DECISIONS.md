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

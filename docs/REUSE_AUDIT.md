# Third-party Reuse Audit

## Status and method

This is an initial reuse decision, not approval to copy third-party code. GitHub metadata (stars, SPDX license, default branch, latest commit date, latest release) was checked on 2026-10-22. Candidate source files were checked for project purpose and known native dependencies. No third-party implementation is copied into IWE.

| Candidate | Intended study | License / compatibility / activity | Decision |
|---|---|---|---|
| [SmartShape2D](https://github.com/SirRamEsq/SmartShape2D) | Polygon editing, selection, and control handles | 1,760 stars; MIT; release 3.3.2; latest commit 2026-08-07; not archived. Godot-version support still needs source-level verification. | Study interaction concepts; no code copied |
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) | Curves, widths, surfaces, and road junction workflows | 1,244 stars; MIT; release 0.9.5; latest commit 2026-10-13; not archived. Its domain is 3D roads and traffic, so IWE needs adaptation. | Study path authoring; no code copied |
| [ProtonScatter](https://github.com/HungryProton/scatter) | Modifier and exclusion-zone architecture | 3,017 stars; MIT; release 4.0; latest commit 2026-09-27; not archived. GitHub repository identifies itself as a Codeberg mirror. | Study architecture only; no code copied |
| [PathMesh3D](https://github.com/iiMidknightii/PathMesh3D) | Path extrusion and parametric mesh generation | 147 stars; MIT; release v1.7.0; latest commit 2026-09-10; not archived. C++ GDExtension adds native build and packaging cost. | Do not depend on it for initial screen-space 2.5D; no code copied |
| [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | Automated test framework | 1,274 stars; MIT; release v6.2.2; latest commit 2026-10-18; not archived. Local addon is 6.2.0-rc2. One IWE Resource serialization test passes on Godot 4.7 headless with `--ignoreHeadlessMode`. | Selected for IWE tests; keep only this framework |
| [GUT](https://github.com/bitwes/Gut) | Alternative test framework | 2,764 stars; API reports no SPDX license; release v9.6.1; latest commit 2026-08-18; not archived. Local addon not present. | Not selected until license and need are established |
| [Godot documentation](https://docs.godotengine.org/en/stable/) | Official API reference | Version-specific API checks still required against installed engine | Reference source |

The starter folder also contains `godot_mcp` and `phantom-camera-main`. They are excluded from IWE publication pending separate provenance, license, and necessity checks. Their presence in the local project is not evidence of permission to redistribute.

## Required audit completion

For future reuse, inspect the exact relevant files and version compatibility before copying. Confirm provenance for bundled addons before redistributing. The MCP integration has not yet been live-tested; the bundled addon alone does not prove a connection to an external MCP server.

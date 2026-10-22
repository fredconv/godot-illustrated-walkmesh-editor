# Third-party Reuse Audit

## Status and method

This is an initial triage, not approval to copy code. Public repository pages were checked on 2026-10-22. Release cadence, exact latest commit dates/stars, key source files, full license terms, and Godot 4.7 compatibility have not yet been verified for every candidate. No third-party code is copied into IWE.

| Candidate | Intended study | License / compatibility / activity | Decision |
|---|---|---|---|
| [SmartShape2D](https://github.com/SirRamEsq/SmartShape2D) | Polygon editing, selection, and control handles | Repository describes a 2D terrain tool. Exact license, recent activity, source implementation, and Godot 4.7 support remain unverified. | Study interaction concepts; no code copied |
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) | Curves, widths, surfaces, and road junction workflows | Repository describes a Godot 3D road/traffic plugin. Exact license, supported engine versions, activity, and relevant source files remain unverified. | Study path authoring; likely domain/engine adaptation needed; no code copied |
| [ProtonScatter](https://github.com/HungryProton/scatter) | Modifier and exclusion-zone architecture | GitHub page identifies it as a Godot addon and a mirror of the Codeberg project. Exact license, activity, and current Godot compatibility remain unverified. | Study architecture only; no code copied |
| [PathMesh3D](https://github.com/iiMidknightii/PathMesh3D) | Path extrusion and parametric mesh generation | Repository description identifies C++ GDExtension implementation. Exact supported Godot versions, license, activity, and build matrix remain unverified. Native compilation increases packaging and CI cost. | Do not depend on it for the initial screen-space 2.5D tool; no code copied |
| [GdUnit4](https://github.com/MikeSchulze/gdUnit4) | Automated test framework | Redirects to `godot-gdunit-labs/gdUnit4`; local addon reports version 6.2.0-rc2. Confirm its exact license, release stability, runtime compatibility, and supported engine versions before use. | Preferred local candidate for a compatibility check; keep one framework only |
| [GUT](https://github.com/bitwes/Gut) | Alternative test framework | Public repository exists. Version, latest activity, supported Godot versions, license, and local availability have not yet been inspected in detail. | Alternative only; do not install alongside GdUnit4 without a concrete need |
| [Godot documentation](https://docs.godotengine.org/en/stable/) | Official API reference | Stable docs are not a substitute for checking APIs against the actual installed engine version. No Godot executable was found in PATH or the common locations checked. | Reference source; engine-specific validation pending |

The starter folder also contains `godot_mcp` and `phantom-camera-main`. They are excluded from IWE publication pending separate provenance, license, and necessity checks. Their presence in the local project is not evidence of permission to redistribute.

## Required audit completion

For each code candidate, inspect GitHub API metadata (stars, default branch, recent commits, releases), supported Godot versions, license text, key implementation files, dependencies, and likely maintenance/adaptation cost. Confirm exact local addon provenance before retaining any bundled copy. Any reusable implementation must be copied only with compatible licensing and attribution requirements documented here. No Godot MCP editor action or engine test has yet been run; the bundled addon alone does not prove a live MCP connection.

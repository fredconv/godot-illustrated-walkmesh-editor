# Third-party Reuse Audit

## Status and method

No third-party source is approved for copying into IWE yet. Repository metadata and source inspection are required before reuse. This audit is intentionally marked pending until network and a Godot installation are available for a complete review.

| Candidate | Intended study | License / compatibility / activity | Decision |
|---|---|---|---|
| [SmartShape2D](https://github.com/SirRamEsq/SmartShape2D) | Polygon editing and handles | Pending source, releases, activity, and license review | Study only; no code copied |
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) | Curves, widths, surfaces | Pending source, releases, activity, and license review | Study only; no code copied |
| [ProtonScatter](https://github.com/HungryProton/scatter) | Non-destructive modifier patterns | Pending source, releases, activity, and license review | Study only; no code copied |
| [PathMesh3D](https://github.com/iiMidknightii/PathMesh3D) | Path extrusion and native dependency cost | Pending source, releases, activity, license, and GDExtension review | Study only; no code copied |
| [GdUnit4](https://github.com/MikeSchulze/gdUnit4) | Automated test framework | Local addon reports version 6.2.0-rc2; license and Godot 4.7 compatibility need verification | Candidate; exclude from distribution until approved |
| [GUT](https://github.com/bitwes/Gut) | Alternative test framework | Pending source, releases, activity, compatibility, and license review | Do not add alongside GdUnit4 without justification |
| [Godot documentation](https://docs.godotengine.org/en/stable/) | Official API reference | Version-specific API checks still required against installed engine | Reference source |

The starter folder also contains `godot_mcp` and `phantom-camera-main`. They are excluded from IWE publication pending separate provenance, license, and necessity checks. Their presence in the local project is not evidence of permission to redistribute.

## Required audit completion

For each code candidate, inspect repository metadata, recent commits, releases, supported Godot versions, license text, key implementation files, dependencies, and likely maintenance/adaptation cost. Any reusable implementation must be copied only with compatible licensing and attribution requirements documented here.

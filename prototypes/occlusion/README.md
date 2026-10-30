# Occlusion prototype: transparency modes behind a barrier

## Purpose

This prototype checks how a character standing **behind** a transparent PNG (a fence or railing) is drawn, for each transparency mode Godot offers. It supports the design choice in [`docs/LAYER_MANAGER_DESIGN.md`](../../docs/LAYER_MANAGER_DESIGN.md) §5: the render technique is chosen per visual element, so the right one must be known.

It is standalone: it uses only Godot's built-in nodes. It does not depend on UniBuilder, Godot MCP, or any IWE plugin code.

## Modes compared

Each column uses one of Godot's `StandardMaterial3D` transparency modes:

| Column | Mode | Notes |
|---|---|---|
| Alpha Scissor | `TRANSPARENCY_ALPHA_SCISSOR` | Pixels below a threshold are discarded; the rest are opaque. |
| Alpha Blend | `TRANSPARENCY_ALPHA` | Standard alpha blending, partial transparency. |
| Alpha Hash | `TRANSPARENCY_ALPHA_HASH` | Spatially deterministic dithering. |
| Depth Pre-Pass | `TRANSPARENCY_ALPHA_DEPTH_PRE_PASS` | Depth written first, then blended. |

In each column, a **red** character stands behind the barrier and a **blue** character stands beside it, on the camera side. The barrier texture has opaque wooden slats, transparent gaps, and a semi-transparent haze band at the top.

## Results

Observed in the editor with two renderers. Each run was a separate copy of the prototype, captured from the screen.

| Mode | GL Compatibility (project renderer) | Forward+ |
|---|---|---|
| Alpha Scissor | Red visible through the gaps; crisp edges. | Same. Good default for fences and trees. |
| Alpha Blend | Red visible through the haze band and the gaps; soft edges. | Same. Best for partial transparency. |
| Alpha Hash | **Gaps render black; the red character is not visible at all.** | Red visible through the gaps; the haze band is dithered as expected. |
| Depth Pre-Pass | Red visible through the haze band and the gaps; soft edges. | Same. Candidate for soft edges with occlusion. |

### Conclusion

- **Alpha Scissor** is the default for barriers and trees.
- **Alpha Blend** or **Depth Pre-Pass** for soft transparency, chosen per element.
- **Alpha Hash** is correct under Forward+ but wrong under GL Compatibility. IWE's project uses GL Compatibility, so it stays disabled there. It may be offered later only when the renderer is Forward+.

## Known limitations

- The characters are static. Movement through the barrier is not tested.
- The haze band is a fixed fake, not a real foliage or glass texture.
- No shadows are tested, although all four modes support casting them.
- Only one barrier per column. Overlapping sprites, which need sorting, are not tested.
- Results come from visual inspection of screenshots, not from pixel comparisons.
- The renderer finding applies to this scene and this Godot build (4.7.1).

## How to run

1. Open the IWE project in Godot 4.7.1 (no additional addons are needed).
2. In the FileSystem dock, open `prototypes/occlusion/occlusion_prototype.tscn`.
3. Press **F6** (Run Current Scene).

To test Alpha Hash under Forward+, copy the folder into a separate project and set `rendering/renderer/rendering_method` to `forward_plus` in `project.godot`. Do not change the renderer of the IWE project.

## How to regenerate the scene

From the project root, with the Godot 4.7.1 executable:

```powershell
godot --headless --path . -s prototypes/occlusion/build_occlusion_prototype.gd
```

This overwrites `occlusion_prototype.tscn`. The generator also prints RID leak messages at exit; they come from the headless dummy renderer and do not indicate a problem with the scene.

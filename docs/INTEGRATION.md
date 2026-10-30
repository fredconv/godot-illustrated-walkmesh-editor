# Using an IWE stage in your game

This page is for the developer who has exported a stage and wants to play it with their own character, in a game that has other scenes. It says what the stage needs at run time, what it does not need, and how to make a character of your own work with it. The working example is [`examples/integration/`](../examples/integration/README.md).

## What the exported scene needs at run time

An exported stage is a normal Godot scene, but it is not free of the plugin:

| It uses | For | Where |
|---|---|---|
| `addons/illustrated_walkmesh_editor/runtime/` | The scripts attached to the nodes: `IWETransitionZone`, `IWEEntryMarker`, `IWEStageRuntime` (and the 2D twins), `IWEStageTravel`, and `IWEWalkmeshCharacter` when you export with `Add player`. | Keep this folder (and `data/iwe_action_zone.gd`, which the zone scripts name for the built-in action names) in your game. |
| Nothing else of the plugin | A stage without zones, entry points or player uses no script at all. | |

The editor part of the plugin (`ui/`, the generator) is not needed in a shipped game, but you do not have to remove it. Export with *Export all resources*, or, if you export selected scenes and their dependencies, add `addons/illustrated_walkmesh_editor/runtime/*` and `addons/illustrated_walkmesh_editor/data/iwe_action_zone.gd` to the include filter: scripts that a scene reaches only through a class name are not always detected as dependencies. Do not rely on a runtime script outside those two places; they may change.

Compatibility: written and tested with **Godot 4.7.1** (the CI pins it) on Windows. Other 4.x versions are not tested. Documents are saved in format **version 3**; version 1 and 2 documents open and are migrated in memory (see [DATA_FORMAT.md](DATA_FORMAT.md)), and a document of a newer format is refused without being touched. The exported scenes do not depend on the document format.

## A character of your own

### What the plugin asks

1. A `CharacterBody3D` (or any physics body) that stands on the floor.
2. Its size: the stage is calibrated so that a character of `calibration.character_height_units` (in illustration units, scaled by the export scale, 0.01 by default) has the right apparent size at every depth. The village example uses 150.6 units (1.5 m at scale 0.01); keep your model's height in that ratio. The perspective itself needs nothing from the character: it is a 3D body in a 3D scene.
3. To take part in transitions: be in the group `iwe_traveller` ([STAGE_TRANSITIONS.md](STAGE_TRANSITIONS.md)).

### What the plugin does not ask

Not the plugin's character class, not a particular controller, input scheme, animation system or rig. The test player (`IWEWalkmeshCharacter`) exists to try a stage quickly; you can leave `Add player` off.

### Walking on the exported navigation

The stage holds one `NavigationRegion3D` per walkable zone, all in one navigation map, and static walls along the outlines of the zones and of their cutouts (physics layer 1). Use them like any other Godot navigation:

- `NavigationServer3D.map_get_path(map, from, to, true)` with `map = get_world_3d().navigation_map`, or a `NavigationAgent3D`.
- Wait until the map has synchronized (`NavigationServer3D.map_get_iteration_id(map)` is non-zero and stable); a path asked for earlier is empty. The example controller keeps the request and retries on the next frame.
- **The planned path touches every obstacle corner.** The navigation follows the outline exactly, so a body with a radius stalls on a corner it goes round. `IWENavigationPath.with_corner_clearance(map, path, clearance)` (or `IWENavigationPath.plan(map, from, to, clearance)`) moves the corners away from the walls; give it the radius of your body plus a margin. It is a static helper with no character in it.
- **Count a waypoint as reached within about the radius of your body** (not a few millimetres), and stop when you make no progress for a few frames. The walls have a thickness and a body cannot always touch the exact point the planner gives; a character that insists on it pushes on the corner for ever. The example does both.
- **At a high testing speed, do not step past the waypoint**: cap the step at the distance left, or the character shuttles around the point.
- A **doorway or corridor narrower than your body cannot be crossed**, whatever the helper does. The export check names doorways narrower than the calibrated character; keep your capsule at most that wide.

### Depth and the foreground pictures

A picture drawn *by depth* sits in the 3D scene at the camera distance of its ground point, so the engine's own depth test hides your character behind it when the character is farther than that point and shows it in front when nearer. Nothing is asked of the character except to be an ordinary opaque 3D object. This is checked on rendered pixels, at three depths each way, with a character that is not the plugin's (`tests/render_check`). Two things to know:

- One picture occludes at one depth (its ground point). A long railing seen at an angle is not exact.
- An exported stage has **no lights** (its illustration is flat and unshaded). A character with a lit material needs the lighting of your own game, as the example levels add (a sun and some ambient light). A flat-coloured character shows without lights.

## Speed while testing

There are two separate speeds, and they do not influence each other:

| | What it acts on | Where it lives |
|---|---|---|
| **Dock → Test → Test character** (`×1 ×2 ×5 ×10`, pause, reset, base speed) | The character of the **editor preview** only | Editor preference. Never saved in the document, never exported. |
| **In the running game**: `PageUp` / `PageDown` step through `×1 ×2 ×5 ×10`, `Home` returns to `×1` | The stage's own test player (`debug_speed_keys`, which the exporter turns on for the player it adds) | The character. Turn `debug_speed_keys` off before you ship. |

Both multiply the character's `move_speed`, apply at once while it walks, and never change `move_speed` itself. The multiplier is not stored in any scene. A character of your own has its own speed: copy the few lines of the example controller (`speed_keys`) if you want the same keys.

## What is and is not verified

Checked by automated tests: the transition flow with a real scene change, from one example level to the other and back, with an external character; navigation, going round the fountain, an unreachable target, apparent size at several depths, and depth sorting; the speed keys while walking.

Checked on rendered pixels (real GPU window, `tests/render_check`): an external character hidden behind the fountain and shown in front of it.

Not verified: a rigged and animated character (the example is a lit capsule model, with no skeleton and no animation: it proves size, depth and navigation, not skeletal animation); a game with its own camera work; other Godot versions or platforms.

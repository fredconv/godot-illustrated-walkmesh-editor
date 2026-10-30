# Stage transitions: zones, entry points and scene travel

This is the part of IWE that lets a character walk from one illustrated scene to another: a door, a staircase, the edge of a map. It has three pieces, all built in and tested:

- **Action zones** drawn on the illustration. When a character walks into one, something happens.
- **Entry points** placed on the illustration. They are the places where a character appears when it arrives.
- **A small runtime** that your game uses (no autoload, no fixed character controller) to detect the entry, load the scene and place the character.

Everything here is saved in the document (format version 3, see [DATA_FORMAT.md](DATA_FORMAT.md)) and written into the exported scenes.

## The idea in one example

In the village scene you draw a zone around the end of the bridge and set it to *Change scene* → `res://levels/cellar.tscn`, entry point `from_village`. In the cellar scene you place an entry point called `from_village`. When the character walks into the zone, the game loads the cellar and the character appears at `from_village`. In the cellar, a zone on the stairs does the reverse, to an entry point `from_cellar` of the village.

## Authoring (Creation tab → *Action zones and entry points*)

1. **Draw a zone.** `Draw zone`, click the corners on the floor, click the first corner (or press Enter) to close. It is added to the list and selected. A zone is a trigger, never a walkable region: it creates no navigation and no collision.
2. **Choose what it does.** In the properties under the list:
   - *When walked into*: **Change scene** or **Jump to an entry point of this scene** (warp).
   - *Scene to load* (for Change scene): type a `res://…` path or press `…` to pick the scene in the project.
   - *Arrive at entry point*: the name of the entry point in the scene that is reached (empty means that scene's default entry point). For a warp it is the entry point of the current scene, with a pick list.
   - *Enabled*: a disabled zone is exported but does nothing until your game enables it.
3. **Place entry points.** `Place entry point`, click the floor where the character should appear. The first one of a scene is its default entry point. Give each a **name** (unique, no space or slash; this is what zones of other scenes use), optionally a direction to face on arrival, and choose which one is the default.
4. **Select and move.** `Select zone` picks a zone on the illustration and drags it; click an entry marker to select and drag it. The list selects the same things. `Delete` removes the selected zone or marker when its tool is active. Every step is undoable and one drag is one undo step.
5. **Check.** *Test → Validation → Check the perspective export* lists problems: a zone with no scene, a scene file that is not in the project, a warp to an entry point the document does not have, two entry points with one name, a zone above the horizon of the calibrated camera.

## What is saved

`IWEActionZone` (in `IWEDocument.action_zones`):

| Field | Meaning |
|---|---|
| `id` | Stable identifier, never shown. |
| `name` | Label, also the exported node name. |
| `points` | The polygon, in illustration pixels. |
| `action` | A **string**: `scene_transition`, `warp`, `event`, or any action of your own. |
| `target_scene` | `res://…` path. Used by `scene_transition`. |
| `entry_id` | The entry point to arrive at (in the other scene for `scene_transition`, in this scene for `warp`). |
| `enabled` | Whether the zone reacts. |
| `params` | A free dictionary. For `event`: `event` (the name) and `repeat` (fire every time). Saved and exported untouched, so later actions can add their own keys. |

`IWEEntryPoint` (in `IWEDocument.entry_points`): `id` (stable), `entry_id` (the name other scenes use), `position` (illustration pixels), `facing_degrees` (NAN keeps the traveller's direction), `is_default`.

An action this plugin does not know is **kept** (and reported by the check) and exported with its settings, so a document made with a later version is not damaged by an earlier one that opens it.

## What the export writes

For every export (perspective, flat 3D, flat 2D), when the document has zones or entry points:

```
Stage
├─ ActionZones            one IWETransitionZone (Area3D) per zone, with a CollisionPolygon3D on the floor
│                         (flat 2D: IWETransitionZone2D, Area2D, CollisionPolygon2D)
├─ EntryPoints            one IWEEntryMarker (Marker3D) per entry point, on the floor
│                         (flat 2D: IWEEntryMarker2D)
└─ StageRuntime           an IWEStageRuntime node: applies the arrival when the scene is ready
```

In the perspective stage the polygon is projected on the floor like the walkable regions, so a zone covers the part of the floor it covers on the illustration; it is a volume as tall as 1.5 characters. A zone or an entry point at or above the horizon of the camera cannot be projected: it is left out and named in the warnings, like a region. A document with no zones and no entry points exports exactly what it did before (no extra node).

The stage's own test player (`Add player`) joins the traveller group.

## Using it in a game

### Who triggers a zone: the group `iwe_traveller`

A zone reacts to nodes of the group **`iwe_traveller`**, and an arrival places the nodes of that group. That is the only thing asked of a character, whatever its controller or model:

```gdscript
func _ready() -> void:
    add_to_group("iwe_traveller")
```

(or add the group in the editor: Node → Groups). A zone's `trigger_group` property can name another group, or be empty to react to any body. An optional method `on_teleported()` on the character is called after the plugin moved it, to drop a path it was following.

### The scene that is reached

An exported IWE stage already holds an `IWEStageRuntime` and its entry markers. A scene you built by hand becomes a destination by adding:

- one **`IWEStageRuntime`** node (Add Node → search "IWEStageRuntime"), and
- one **`IWEEntryMarker`** (3D) or **`IWEEntryMarker2D`** per place a character can arrive, each with an `entry_id`; tick `is_default` on one.

The scene also needs a character of the group `iwe_traveller` (placed anywhere: the arrival moves it).

### What happens, step by step

1. A traveller enters a zone (`body_entered`). The zone checks it is enabled, has not fired, the body is in `trigger_group`, and no travel is under way.
2. The zone emits `triggered(zone, body)`. If `auto_handle` is on (default) it asks `IWEStageTravel` to run the action.
3. `scene_transition`: `IWEStageTravel.request(tree, scene, entry_id)` checks the scene exists, remembers the entry point name and loads the scene (`change_scene_to_file`, deferred).
4. In the new scene `IWEStageRuntime` runs when the scene is ready: it finds the entry marker, moves every traveller to it (and turns it if the entry point has a direction), then marks the travel finished.

### Fallbacks, written down

| Situation | What happens |
|---|---|
| The entry point named is in the scene | The traveller appears there. |
| It is not (or the zone names none) | The scene's **default** entry point (`is_default`). A warning names the missing one. |
| No default is marked | The **first** entry marker found. |
| The scene has no entry marker | The traveller stays where the scene put it; a warning says so. |
| The target scene path is empty or the file does not exist | Nothing happens: the character stays, the zone stays armed, `IWEStageTravel.last_error` says why, and the next transition still works. |
| The scene file is broken | The load error is logged, the current scene stays, and the travel is cleared so the next transition works. |
| The scene has no `IWEStageRuntime` | The travel is dropped after 600 frames (`IWEStageTravel.safety_frames`) with a warning, so no later scene applies a stale arrival and later transitions are not blocked. |

### No double triggers

A zone fires once until `rearm()`. While a travel is under way (`IWEStageTravel.is_traveling`) no zone fires, so walking along two touching zones, or entering the same zone twice in one frame, loads one scene. The flag is cleared when the arrival is applied.

### Your own loading (fade, loading screen)

Set `IWEStageTravel.scene_changer` to a callable that receives the scene path and ends up in a scene that holds an `IWEStageRuntime` (or calls `IWEStageTravel.finish()` after placing the travellers itself). Or turn `auto_handle` off on a zone and connect `triggered`:

```gdscript
zone.auto_handle = false
zone.triggered.connect(func(z, body): await fade_out(); IWEStageTravel.request(get_tree(), z.target_scene, z.entry_id))
```

`IWEStageRuntime.arrival_applied(entry_id, fallback, placed)` tells you when the character has arrived (for a fade in); `fallback` is `none`, `default`, `first` or `missing`. Turn `apply_on_ready` off to place the travellers yourself with `apply_arrival()`.

### Custom events: an explosion, a gate that opens

A zone whose action is **Trigger a custom event** does nothing by itself: when a character walks into it, the game receives the name you gave it. In the dock, pick the action *Trigger a custom event*, type a name (`explosion`, `open_gate`) and choose whether it fires once or **every time the character enters** it.

```gdscript
# One zone:
$Stage/ActionZones/Trap.event_fired.connect(func(event_name, zone, body): explode(zone.global_position))

# Or every zone of the scene, when your game has one place that reacts to events:
for zone in get_tree().get_nodes_in_group("iwe_action_zone"):
    zone.event_fired.connect(_on_zone_event)

func _on_zone_event(event_name: String, zone: Node, body: Node) -> void:
    match event_name:
        "explosion": explode(zone.global_position)
        "open_gate": $Gate.open()
```

- The zone emits `triggered` first, then `event_fired(event_name, zone, body)`. It fires once by default; a repeating event arms itself again when the character has left the zone. `rearm()` arms it by hand, and `enabled` turns it on and off, so a zone that is "the trigger of another thing" can be enabled by your game when the time comes (a gate that opens "further on" is a zone you enable, or a node you show).
- An event never loads a scene or moves a character, and does not block a scene change that is under way.
- The name and the repeat option are saved in the zone's `params` (`event`, `repeat`), so no format change: a document that holds events opens in this version and in later ones.

**You do not have to use the plugin for this.** An exported stage is a normal Godot scene and a zone is a plain `Area3D` with a `CollisionPolygon3D`. Anything that Godot offers works next to it: add your own `Area3D` with a `CollisionShape3D` to the level scene, connect its `body_entered`, and react in your own script. The plugin's zones are useful when you want to **draw the area on the illustration** and have it follow the calibrated floor; a hand-made `Area3D` is simpler when the trigger does not have to match a place in the picture. Entry markers and zones can be read as ordinary nodes to place your own things at the same spots.

### Warp and the actions to come

- **`warp`** moves the travellers to an entry point of the **same** scene (`IWEStageTravel.warp(tree, entry_id)`, or `IWEStageRuntime.warp_to(entry_id)` from code). It never changes the scene. Use it for a shortcut, a ladder, a teleporter.
- **Your own actions.** `action` is a string. A zone whose action is not built in (and is not `event`) only emits `triggered` with its `action`, `target_scene`, `entry_id` and `params` (read them on the zone node); your game decides what to do. For the common case of "tell my game that something was entered", use the built-in custom event above. Order when a zone is entered: `triggered` is emitted first, so your handlers run before the built-in action and can turn `auto_handle` off for that zone; then the built-in action runs if `auto_handle` is still on.
- Planned built-in actions (not implemented): interactions that need a button press, one-way zones, and actions with conditions. They fit the same record (`action` + `params`) without a format change.

## Limits of this version

- The shape of a zone cannot be edited vertex by vertex; move it as a whole or delete it and draw it again.
- Zones react to bodies (physics). A character that moves without physics (changing its position directly without a collision body) does not enter a zone.
- Only the stage root scenes IWE exports and scenes you prepare with `IWEStageRuntime` receive arrivals.
- An entry point is a place, not a state: the game decides everything else (inventory, camera cuts, music).
- The editor preview does not run transitions (the zones are inert there); test them by running the exported scene. The shipped example (`examples/integration/`) is a two-level game you can play.

@tool
class_name IWEActionZone
extends Resource
## A zone of the illustration that does something when a character walks into it: change the scene,
## jump to another place of the same scene. It never creates navigation or collision on its own; it
## only detects the character (docs/STAGE_TRANSITIONS.md).
##
## The geometry is in illustration pixels, like every other authored shape. The action is a plain
## string and its settings are `target_scene`, `entry_id` and the free-form `params`, so a later
## version can add an action without changing the document format: a document keeps an action this
## plugin does not know, exports it with its settings, and the game decides what to do with it.

## Walk into the zone and the game loads `target_scene`, then the traveller appears at the entry point
## named `entry_id` of that scene.
const ACTION_SCENE_TRANSITION := "scene_transition"
## Walk into the zone and the traveller jumps to the entry point named `entry_id` of the same scene.
const ACTION_WARP := "warp"
const KNOWN_ACTIONS := [ACTION_SCENE_TRANSITION, ACTION_WARP]

@export var id := ""
@export var name := "Action zone"
@export var points := PackedVector2Array()
@export var action := ACTION_SCENE_TRANSITION
## The scene to load, as a resource path (res://levels/forest.tscn). Used by scene_transition.
@export_file("*.tscn", "*.scn") var target_scene := ""
## The entry point to arrive at: in the target scene for scene_transition, in this scene for warp.
## Empty means "the default entry point of the scene that is reached".
@export var entry_id := ""
## A disabled zone is exported but does not react until the game enables it.
@export var enabled := true
## Free-form settings of the action, for actions added later. Saved and exported untouched.
@export var params: Dictionary = {}


static func create_zone(zone_name: String, polygon: PackedVector2Array) -> IWEActionZone:
	var zone := IWEActionZone.new()
	zone.id = "zone_%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	zone.name = zone_name
	zone.points = polygon.duplicate()
	return zone


static func is_known_action(action_name: String) -> bool:
	return KNOWN_ACTIONS.has(action_name)


## Whether the action needs a scene to load.
func needs_target_scene() -> bool:
	return action == ACTION_SCENE_TRANSITION


func get_centroid() -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(points.size())


## One line for lists: "Door to forest: forest.tscn at from_village".
func describe() -> String:
	match action:
		ACTION_SCENE_TRANSITION:
			var scene_name := target_scene.get_file() if not target_scene.is_empty() else "no scene chosen"
			return "%s: %s%s" % [name, scene_name, (" at " + entry_id) if not entry_id.is_empty() else ""]
		ACTION_WARP:
			return "%s: warp to %s" % [name, entry_id if not entry_id.is_empty() else "no entry point chosen"]
	return "%s: %s" % [name, action]

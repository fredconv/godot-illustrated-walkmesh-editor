class_name IWEStageTravel
extends RefCounted
## Scene-to-scene travel for stages built with IWE (docs/STAGE_TRANSITIONS.md). It has no autoload and
## no dependency on a character controller:
##
## - A transition zone (IWETransitionZone) asks `request()` to load a scene and remembers the name of
##   the entry point to arrive at.
## - The scene that is reached holds an IWEStageRuntime node. When the scene is ready it calls
##   `place_travellers()`, which puts every node of the group `iwe_traveller` on the entry point.
##
## A traveller is any Node3D or Node2D that joined the group `iwe_traveller` (the stage's own player
## does; so does a character of yours once you add `add_to_group("iwe_traveller")`).
##
## The state lives in static variables, which survive a scene change because they belong to the
## script, not to a node.

const TRAVELLER_GROUP := &"iwe_traveller"
const ENTRY_GROUP := &"iwe_entry_marker"
## Frames after which a travel that no IWEStageRuntime acknowledged is dropped, so a game whose target
## scene has no runtime node is not locked out of later transitions for ever, and a stale arrival is not
## applied by an unrelated scene later. Raise it if your own scene changer takes longer.
static var safety_frames := 600

## The entry point the next scene should place the travellers on. Empty: the scene's default.
static var pending_entry_id := ""
## True from request() until the new scene has placed its travellers (or the safety timeout).
static var is_traveling := false
## True when a travel has been requested and its arrival is not applied yet.
static var arrival_pending := false
## How scenes are loaded. Empty means `SceneTree.change_scene_to_file`. A game can set it to add a
## fade or a loading screen; the callable receives the scene path and must end up in a scene that
## holds an IWEStageRuntime (or call `finish()` itself). Tests set it to avoid a real scene change.
static var scene_changer := Callable()
## The last reason a request was refused, for logs and tests.
static var last_error := ""


## Starts a travel to `scene_path`, arriving at the entry point `entry_id` ("" for the default one).
## Returns false, without touching the current scene, when the request cannot start: another travel
## is under way (a double trigger), the path is empty or the scene does not exist.
static func request(tree: SceneTree, scene_path: String, entry_id: String = "") -> bool:
	last_error = ""
	if tree == null:
		last_error = "no scene tree"
		return false
	if is_traveling:
		last_error = "a travel is already under way"
		return false
	if scene_path.is_empty():
		last_error = "no target scene"
		push_warning("IWE: a transition zone has no target scene.")
		return false
	if not scene_changer.is_valid() and not ResourceLoader.exists(scene_path):
		last_error = "scene not found: %s" % scene_path
		push_warning("IWE: the target scene %s does not exist; the character stays where it is." % scene_path)
		return false
	is_traveling = true
	arrival_pending = true
	pending_entry_id = entry_id
	if scene_changer.is_valid():
		scene_changer.call_deferred(scene_path)
	else:
		(func() -> void: _change_scene(tree, scene_path)).call_deferred()
	_arm_safety(tree)
	return true


## Runs the action of a zone. `scene_transition` loads a scene, `warp` moves the travellers inside the
## current scene. Any other action is the game's business: it listens to the zone's signal.
static func handle_action(tree: SceneTree, action: String, target_scene: String, entry_id: String) -> bool:
	match action:
		IWEActionZone.ACTION_SCENE_TRANSITION:
			return request(tree, target_scene, entry_id)
		IWEActionZone.ACTION_WARP:
			return warp(tree, entry_id)
	return false


## Moves the travellers to an entry point of the current scene. Returns false when there is no
## traveller or no entry point at all.
static func warp(tree: SceneTree, entry_id: String) -> bool:
	if tree == null:
		return false
	return int(place_travellers(tree, entry_id).get("placed", 0)) > 0


## Puts every traveller on the entry point named `entry_id` of the current scene. When the name is
## empty or unknown the default entry point is used, then the first one; with none at all the
## travellers stay where they are and a warning says so. The result tells what happened:
## `placed` (travellers moved), `entry_id` (the one used) and `fallback`: "none" (the entry point
## asked for was found), "default" (its default entry point was used instead), "first" (no default
## was marked, the first entry point was used) or "missing" (the scene has no entry point).
static func place_travellers(tree: SceneTree, entry_id: String) -> Dictionary:
	var result := {"placed": 0, "entry_id": "", "fallback": "none"}
	var markers: Array[Node] = []
	for node in tree.get_nodes_in_group(ENTRY_GROUP):
		if node.is_inside_tree():
			markers.append(node)
	var marker: Node = null
	if not entry_id.is_empty():
		for candidate in markers:
			if String(candidate.get("entry_id")) == entry_id:
				marker = candidate
				break
	if marker == null:
		for candidate in markers:
			if bool(candidate.get("is_default")):
				marker = candidate
				result["fallback"] = "default"
				break
		if marker == null and not markers.is_empty():
			marker = markers[0]
			result["fallback"] = "first"
		if marker == null:
			result["fallback"] = "missing"
			push_warning("IWE: this scene has no entry point (IWEEntryMarker); the travellers stay where they are.")
			return result
		if not entry_id.is_empty():
			push_warning("IWE: entry point \"%s\" does not exist in this scene; arriving at \"%s\" instead." % [entry_id, String(marker.get("entry_id"))])
	result["entry_id"] = String(marker.get("entry_id"))
	for traveller in tree.get_nodes_in_group(TRAVELLER_GROUP):
		if _place(traveller, marker):
			result["placed"] = int(result["placed"]) + 1
	return result


## Marks the arrival as applied. IWEStageRuntime calls it; call it yourself when you replaced the
## scene changer and place the travellers on your own.
static func finish() -> void:
	is_traveling = false
	arrival_pending = false
	pending_entry_id = ""


## Forgets everything (tests, or a game that restarts from its title screen).
static func reset() -> void:
	finish()
	scene_changer = Callable()
	last_error = ""


static func _change_scene(tree: SceneTree, scene_path: String) -> void:
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		last_error = "the scene could not be loaded (%s): %s" % [error_string(error), scene_path]
		push_error("IWE: %s" % last_error)
		finish()


static func _arm_safety(tree: SceneTree) -> void:
	var started_for := pending_entry_id
	(func() -> void:
		for _frame in safety_frames:
			await tree.process_frame
		if is_traveling and arrival_pending and pending_entry_id == started_for:
			push_warning("IWE: the travel was not acknowledged by an IWEStageRuntime within %d frames and was dropped." % safety_frames)
			finish()
	).call()


static func _place(traveller: Node, marker: Node) -> bool:
	if traveller is Node3D and marker is Node3D:
		var body_3d := traveller as Node3D
		body_3d.global_position = (marker as Node3D).global_position
		var facing: float = float(marker.get("facing_degrees"))
		if not is_nan(facing):
			body_3d.rotation.y = deg_to_rad(facing)
	elif traveller is Node2D and marker is Node2D:
		(traveller as Node2D).global_position = (marker as Node2D).global_position
		var facing_2d: float = float(marker.get("facing_degrees"))
		if not is_nan(facing_2d):
			(traveller as Node2D).rotation = deg_to_rad(facing_2d)
	else:
		return false
	if traveller.has_method("on_teleported"):
		traveller.call("on_teleported")
	return true

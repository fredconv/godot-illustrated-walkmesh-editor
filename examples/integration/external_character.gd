extends CharacterBody3D
## A character controller that is not the plugin's: a plain CharacterBody3D that walks to the point you
## click, along a path planned on the navigation that an IWE stage exports.
##
## It shows what a game needs to do to use an exported stage with its own character:
##
##   1. Put a CharacterBody3D in the scene, at the height of your calibration
##      (calibration.character_height_units x the world scale, 1.8 for the village example).
##   2. Add it to the group "iwe_traveller". That is all the plugin asks of a character: transition zones
##      react to the group, and an arrival places its members. (This script does it in _ready.)
##   3. Optionally give it a method on_teleported(): it is called after the plugin moved the character to
##      an entry point, so you can drop the path you were following.
##   4. Plan paths with NavigationServer3D on the character's own navigation map. The exported
##      navigation follows the outline of the zones and cutouts exactly, so a path touches every
##      obstacle corner and a body with a radius would stall on it: IWENavigationPath.with_corner_clearance
##      moves the corners away from the walls. It is a plain helper, not a character: write your own if
##      you prefer.
##
## It uses no IWE character class and no scene-travel class.

@export var move_speed := 2.7
## Distance the path keeps from the walls: the radius of the capsule plus a margin.
@export var path_clearance := 0.36
## A waypoint in the middle of the path counts as reached within this distance. Keep it near the radius
## of the capsule: the walls have a thickness, and a body cannot always touch the exact point the
## planner gives, so a tolerance of a few centimetres would make it push on a corner for ever.
@export var waypoint_tolerance := 0.25
## Frames without progress after which the walk is given up (a target against a wall, for example).
@export var blocked_frames_limit := 20
## Testing only: PageUp / PageDown step the speed through x1, x2, x5, x10, Home goes back to x1. Copy it
## if you want the same convenience in your own controller.
@export var speed_keys := true

var speed_multiplier := 1.0
var _path := PackedVector3Array()
var _path_index := 0
var _wanted_target: Variant = null
var _blocked_frames := 0


func _ready() -> void:
	add_to_group("iwe_traveller")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _unhandled_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		var floor_plane := Plane(Vector3.UP, global_position.y)
		var hit: Variant = floor_plane.intersects_ray(camera.project_ray_origin(mouse.position), camera.project_ray_normal(mouse.position))
		if hit != null:
			walk_to(hit)
	var key := event as InputEventKey
	if speed_keys and key != null and key.pressed and not key.echo:
		var presets := [1.0, 2.0, 5.0, 10.0]
		var nearest: int = maxi(presets.find(speed_multiplier), 0)
		match key.keycode:
			KEY_PAGEUP:
				speed_multiplier = presets[clampi(nearest + 1, 0, presets.size() - 1)]
			KEY_PAGEDOWN:
				speed_multiplier = presets[clampi(nearest - 1, 0, presets.size() - 1)]
			KEY_HOME:
				speed_multiplier = 1.0


## Walks to the nearest walkable point to `world_target`.
func walk_to(world_target: Vector3) -> void:
	_wanted_target = world_target


## Called by the plugin after it moved this character to an entry point.
func on_teleported() -> void:
	_wanted_target = null
	_path = PackedVector3Array()
	_blocked_frames = 0
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	var map := get_world_3d().navigation_map
	# The navigation server needs a few frames before the exported regions are in the map; until then a
	# request is kept and tried again on the next frame.
	if _wanted_target != null and NavigationServer3D.map_get_iteration_id(map) != 0:
		var planned := IWENavigationPath.plan(map, global_position, _wanted_target, path_clearance)
		if not planned.is_empty():
			_path = planned
			_path_index = 0
			_wanted_target = null
	if _path_index >= _path.size():
		velocity = Vector3.ZERO
		return
	var waypoint := _path[_path_index]
	var to_waypoint := waypoint - global_position
	to_waypoint.y = 0.0
	var distance := to_waypoint.length()
	var is_last := _path_index == _path.size() - 1
	if distance < (0.03 if is_last else waypoint_tolerance):
		_path_index += 1
		_blocked_frames = 0
		return
	var direction := to_waypoint / distance
	# Never step past the waypoint: at a high testing speed one frame can be longer than the distance
	# left, and a character that overshoots turns back and shuttles around the point for ever.
	velocity = direction * minf(move_speed * speed_multiplier, distance / maxf(delta, 0.0001))
	var before := global_position
	move_and_slide()
	look_at(global_position + direction, Vector3.UP)
	if (global_position - before).length() < velocity.length() * delta * 0.1:
		_blocked_frames += 1
		if _blocked_frames >= blocked_frames_limit:
			_path = PackedVector3Array()
			_blocked_frames = 0
	else:
		_blocked_frames = 0

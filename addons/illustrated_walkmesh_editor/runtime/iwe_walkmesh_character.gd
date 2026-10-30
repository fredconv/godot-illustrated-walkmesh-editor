@tool
class_name IWEWalkmeshCharacter
extends CharacterBody3D
## Player controller for IWE perspective stages.
##
## The character walks on the flat floor that the stage projects from the illustration.
## Its apparent size comes from the calibrated perspective camera, so it shrinks naturally
## as it walks toward the horizon. Physics walls built from the walkable polygons (and their
## cutouts) keep it inside the walkable area. The navigation map is used only to plan
## click-to-move paths and as a safety net when the character drifts far from walkable space.

signal destination_reached

const MIN_SPEED_MULTIPLIER := 0.1
const MAX_SPEED_MULTIPLIER := 10.0
## Presets offered to the person testing a path: normal, fast, very fast, rapid inspection.
const SPEED_PRESETS := [1.0, 2.0, 5.0, 10.0]

## Base Speed: normal walking speed in world units per second. The speed is the same at every
## depth; the apparent speed on screen comes from the perspective camera alone.
@export var move_speed := 2.5
## Move with arrow keys / WASD, relative to the active camera.
@export var keyboard_control := true
## Left-click the floor to walk there along a navigation path.
@export var click_to_move := true
## Rotate this node (usually the visual model) to face the walking direction.
@export var facing_node: NodePath = ^"Visual"
@export var turn_speed := 12.0
## Distance from the navigation map beyond which the character is pulled back onto it.
## Walls keep normal movement inside the walkable area, so this only catches large errors.
## Keep it larger than the character radius, otherwise a character pressed against a wall
## is snapped onto the edge and cannot move back inward.
@export var snap_tolerance := 0.1
## Frames without progress along a click-to-move path before the path is abandoned.
@export var blocked_frames_limit := 20
## Distance a click-to-move path keeps from obstacle corners and outer corners, in world units.
## The navigation planner returns paths that touch corners, and a character with a physical
## radius stalls on them. Set it to the character radius (the generator does). Zero keeps the
## planner's path unchanged.
@export var path_clearance := 0.0

## Testing multiplier, never saved and never exported: it only makes a path test shorter.
## Effective speed is move_speed * speed_multiplier. Set it with set_speed_multiplier().
var speed_multiplier := 1.0
## Set by the editor preview only. In the editor the character stays still unless this is true,
## so a scene that contains it never moves while someone edits it. The preview walks it without
## physics (the editor does not step the physics of a preview world): see kinematic.
var editor_preview := false
## Move by changing the position directly instead of move_and_slide. The walls cannot stop it;
## the navigation path keeps it on the walkable area.
var kinematic := false
var _paused := false
var _start_position := Vector3.ZERO
var _path := PackedVector3Array()
var _path_index := 0
var _pending_target: Variant = null
var _blocked_frames := 0
var _move_input := Vector3.ZERO
# The navigation server registers regions over several frames. Its iteration id becomes
# non-zero before every region is in the map, so only trust it once it stops changing.
var _navigation_settled := false
var _last_navigation_iteration := -1
var _stable_navigation_frames := 0
const NAVIGATION_STABLE_FRAMES := 5
const MAX_PATH_RETRY_FRAMES := 120
var _path_retry_frames := 0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_start_position = global_position
	# Transition zones react to this group, and a stage arrival places its members.
	add_to_group(IWEStageTravel.TRAVELLER_GROUP)


## Called by IWEStageTravel after it moved the character (a scene arrival or a warp): the path planned
## before is meaningless from the new place, so it is dropped, and the new place becomes the start.
func on_teleported() -> void:
	stop()
	velocity = Vector3.ZERO
	_start_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not click_to_move:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target: Variant = screen_to_floor(event.position)
		if target != null:
			move_to(target)
			get_viewport().set_input_as_handled()


## Projects a screen position onto the horizontal plane under the character.
func screen_to_floor(screen_position: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var floor_plane := Plane(Vector3.UP, global_position.y)
	return floor_plane.intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))


## Walks to the closest walkable point to world_target along a navigation path.
func move_to(world_target: Vector3) -> void:
	_path_retry_frames = 0
	_plan_path(world_target)


## Asks the navigation server for the path. While the server has not synchronized its regions the
## answer is empty, whatever its iteration counter says, so the request is kept and repeated on the
## next physics frames (up to MAX_PATH_RETRY_FRAMES) instead of being lost.
func _plan_path(world_target: Vector3) -> void:
	var map := get_world_3d().navigation_map
	if not _navigation_settled:
		_pending_target = world_target
		return
	var target := NavigationServer3D.map_get_closest_point(map, world_target)
	var planned := NavigationServer3D.map_get_path(map, global_position, target, true)
	if planned.is_empty() and _path_retry_frames < MAX_PATH_RETRY_FRAMES:
		_path_retry_frames += 1
		_pending_target = world_target
		return
	_pending_target = null
	_path = _with_corner_clearance(map, planned)
	_path_index = 0
	_blocked_frames = 0


## Moves each corner of a planned path away from the edge of the walkable area, up to
## path_clearance, so a character with a radius can round it. The first and last points stay,
## and a corner only moves to a spot that is still walkable and has less wall around it.
func _with_corner_clearance(map: RID, path: PackedVector3Array) -> PackedVector3Array:
	if path_clearance <= 0.0 or path.size() < 3:
		return path
	var cleared := path.duplicate()
	for index in range(1, path.size() - 1):
		cleared[index] = _clear_of_edges(map, path[index])
	return cleared


const CLEARANCE_DIRECTIONS := 16


func _clear_of_edges(map: RID, point: Vector3) -> Vector3:
	var blocked := _blocked_directions(map, point)
	if blocked.is_empty():
		return point
	var away := Vector3.ZERO
	for direction in blocked:
		away -= direction
	if away.length() < 0.001:
		return point
	away = away.normalized()
	var best := point
	var best_blocked := blocked.size()
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		var candidate: Vector3 = point + away * path_clearance * fraction
		candidate.y = point.y
		var snapped := NavigationServer3D.map_get_closest_point(map, candidate)
		if snapped.distance_to(candidate) > 0.001:
			continue
		var count := _blocked_directions(map, candidate).size()
		if count < best_blocked:
			best = candidate
			best_blocked = count
	return best


## Directions on the floor in which the walkable area ends within path_clearance of the point.
func _blocked_directions(map: RID, point: Vector3) -> Array[Vector3]:
	var blocked: Array[Vector3] = []
	for step in CLEARANCE_DIRECTIONS:
		var angle := TAU * float(step) / float(CLEARANCE_DIRECTIONS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var probe := point + direction * path_clearance
		var closest := NavigationServer3D.map_get_closest_point(map, probe)
		if closest.distance_to(probe) > path_clearance * 0.05:
			blocked.append(direction)
	return blocked


## Sets a manual move direction on the floor plane. Keyboard input uses this too.
func set_move_input(direction: Vector3) -> void:
	_move_input = Vector3(direction.x, 0.0, direction.z)
	if _move_input != Vector3.ZERO:
		stop()


## Changes the testing multiplier. It can change while the character is walking.
func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = clampf(multiplier, MIN_SPEED_MULTIPLIER, MAX_SPEED_MULTIPLIER)


func get_effective_speed() -> float:
	return move_speed * speed_multiplier


## Freezes the character in place. The path is kept, so resume() continues it.
func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


## Puts the character back where it started and cancels any path. Speed settings are kept.
func reset_position() -> void:
	stop()
	_move_input = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = _start_position


func stop() -> void:
	_path = PackedVector3Array()
	_path_index = 0
	_pending_target = null
	_blocked_frames = 0


## True while a walk is under way, and also while a requested walk waits for the navigation server
## to be ready, so code that waits for the walk to end does not stop before it has begun.
func is_moving_along_path() -> bool:
	return _pending_target != null or _path_index < _path.size()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and not editor_preview:
		return
	_update_navigation_settled()
	if not _navigation_settled or _paused:
		velocity = Vector3.ZERO
		_move(delta)
		if _paused:
			_move_input = Vector3.ZERO
		return
	if _pending_target != null:
		_plan_path(_pending_target)
	if keyboard_control:
		var keyboard := _keyboard_direction()
		if keyboard != Vector3.ZERO:
			set_move_input(keyboard)
	var direction := _move_input
	if direction == Vector3.ZERO:
		direction = _path_direction(delta)
	velocity = direction * get_effective_speed()
	var before := global_position
	_move(delta)
	_update_blocked_state(before, direction)
	constrain_to_walkable()
	_face(direction, delta)
	_move_input = Vector3.ZERO


func _move(delta: float) -> void:
	if kinematic:
		global_position += velocity * delta
	else:
		move_and_slide()


func _update_navigation_settled() -> void:
	var iteration := NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)
	if iteration != 0 and iteration == _last_navigation_iteration:
		_stable_navigation_frames += 1
	else:
		_stable_navigation_frames = 0
	_last_navigation_iteration = iteration
	_navigation_settled = _stable_navigation_frames >= NAVIGATION_STABLE_FRAMES


## Abandons a click-to-move path when walls stop the character for several frames.
func _update_blocked_state(before: Vector3, direction: Vector3) -> void:
	if not is_moving_along_path() or direction == Vector3.ZERO:
		_blocked_frames = 0
		return
	var moved := (global_position - before) * Vector3(1.0, 0.0, 1.0)
	if moved.length() < get_effective_speed() * 0.1 * get_physics_process_delta_time():
		_blocked_frames += 1
		if _blocked_frames >= blocked_frames_limit:
			stop()
	else:
		_blocked_frames = 0


## Pulls the character back onto the navigation map only when it has drifted beyond the
## tolerance. Returns true if it moved.
func constrain_to_walkable() -> bool:
	if not _navigation_settled:
		return false
	var map := get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, global_position)
	if global_position.distance_to(closest) <= snap_tolerance:
		return false
	global_position = closest
	return true


func _keyboard_direction() -> Vector3:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input == Vector2.ZERO:
		input = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		)
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera:
		# Screen "up" walks away from the camera along the floor.
		right = Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
		forward = Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
		if forward == Vector3.ZERO:
			# Camera looks straight down: use its up vector as screen-forward.
			forward = Vector3(camera.global_basis.y.x, 0.0, camera.global_basis.y.z).normalized()
	var direction := right * input.x - forward * input.y
	return direction.normalized() if direction.length() > 1.0 else direction


func _path_direction(delta: float) -> Vector3:
	while _path_index < _path.size():
		var offset := _path[_path_index] - global_position
		offset.y = 0.0
		var step := get_effective_speed() * delta
		if offset.length() > maxf(step, 0.001):
			return offset.normalized()
		_path_index += 1
		if _path_index >= _path.size():
			destination_reached.emit()
			# Land on the destination with a partial step, so the stopping error does not grow
			# with the walking speed.
			return offset / step if step > 0.0001 else Vector3.ZERO
	return Vector3.ZERO


func _face(direction: Vector3, delta: float) -> void:
	var node := get_node_or_null(facing_node) as Node3D
	if node == null or direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	node.rotation.y = lerp_angle(node.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

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

## Walking speed in world units per second.
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


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _unhandled_input(event: InputEvent) -> void:
	if not click_to_move:
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
	var map := get_world_3d().navigation_map
	if not _navigation_settled:
		# The navigation map has not synchronized yet; retry on the next physics frame.
		_pending_target = world_target
		return
	_pending_target = null
	var target := NavigationServer3D.map_get_closest_point(map, world_target)
	_path = NavigationServer3D.map_get_path(map, global_position, target, true)
	_path_index = 0
	_blocked_frames = 0


## Sets a manual move direction on the floor plane. Keyboard input uses this too.
func set_move_input(direction: Vector3) -> void:
	_move_input = Vector3(direction.x, 0.0, direction.z)
	if _move_input != Vector3.ZERO:
		stop()


func stop() -> void:
	_path = PackedVector3Array()
	_path_index = 0
	_pending_target = null
	_blocked_frames = 0


func is_moving_along_path() -> bool:
	return _path_index < _path.size()


func _physics_process(delta: float) -> void:
	_update_navigation_settled()
	if not _navigation_settled:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if _pending_target != null:
		move_to(_pending_target)
	if keyboard_control:
		var keyboard := _keyboard_direction()
		if keyboard != Vector3.ZERO:
			set_move_input(keyboard)
	var direction := _move_input
	if direction == Vector3.ZERO:
		direction = _path_direction(delta)
	velocity = direction * move_speed
	var before := global_position
	move_and_slide()
	_update_blocked_state(before, direction)
	constrain_to_walkable()
	_face(direction, delta)
	_move_input = Vector3.ZERO


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
	if moved.length() < move_speed * 0.1 * get_physics_process_delta_time():
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
		if offset.length() > maxf(move_speed * delta, 0.001):
			return offset.normalized()
		_path_index += 1
		if _path_index >= _path.size():
			destination_reached.emit()
	return Vector3.ZERO


func _face(direction: Vector3, delta: float) -> void:
	var node := get_node_or_null(facing_node) as Node3D
	if node == null or direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	node.rotation.y = lerp_angle(node.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

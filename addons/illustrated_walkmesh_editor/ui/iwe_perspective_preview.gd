@tool
extends SubViewportContainer
## Live 3D preview of the calibrated stage.
##
## The preview only *displays* the calibration. The frame it shows is the calibration's own
## reference viewport; the panel around it can have any size or shape and is only a display
## concern. Nothing here writes to the document.

signal image_point_clicked(image_position: Vector2)
## The test character exists and its base speed (world units per second) is known.
signal test_character_ready(base_speed: float)

const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const MIN_USABLE_SIZE := 64

var _viewport: SubViewport
var _image_size := Vector2i.ZERO
var _top_view := false
## The frame being shown (the calibration's reference viewport). Set by configure().
var _reference_size := Vector2i(1280, 720)
var _calibration: IWEPerspectiveCalibration
var _world_scale := 0.01
## Test walk: a character that walks the generated floor so the person can try the camera and the
## zones. These settings belong to the preview only. They are never written to the document and
## never reach an export.
var _test_walk := false
var _speed_multiplier := 1.0
## Zero keeps the character's own base speed.
var _base_speed := 0.0
var _paused := false


func _ready() -> void:
	# Stretch is off on purpose: the render target is sized explicitly below, and Godot refuses
	# manual SubViewport sizes while the container stretches it.
	stretch = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(MIN_USABLE_SIZE * 2, MIN_USABLE_SIZE * 2)
	_viewport = SubViewport.new()
	_viewport.name = "PerspectiveViewport"
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = _reference_size
	add_child(_viewport)
	resized.connect(_sync_viewport_size)
	visibility_changed.connect(_sync_viewport_size, CONNECT_DEFERRED)


## Stretch sizing is not reliable once the container has been hidden (its SubViewport can be
## left at 2x2 pixels, which renders as a flat grey field). Size the render target explicitly.
## This is the *render* size only; the projection never reads it.
func _sync_viewport_size() -> void:
	if not is_instance_valid(_viewport) or not is_visible_in_tree():
		return
	var target := Vector2i(roundi(size.x), roundi(size.y))
	if target.x < MIN_USABLE_SIZE or target.y < MIN_USABLE_SIZE or target == _viewport.size:
		return
	_viewport.size = target


## Builds the stage for this calibration and frames the panel to its reference aspect ratio.
func configure(document: Resource, texture: Texture2D, calibration: IWEPerspectiveCalibration, world_scale: float, element_textures: Dictionary = {}) -> void:
	if not is_instance_valid(_viewport) or document == null or texture == null or calibration == null:
		return
	_image_size = document.image_size
	_reference_size = calibration.reference_viewport_size
	_calibration = calibration
	_world_scale = world_scale
	_apply_reference_aspect()
	var stage: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, world_scale, _test_walk, element_textures)
	if stage == null:
		return
	stage.name = "PerspectiveStage"
	for child in _viewport.get_children():
		child.free()
	_viewport.add_child(stage)
	_set_camera_mode(_top_view)
	_prepare_test_character()


## Turns the test character on or off. The stage is rebuilt by the next configure().
func set_test_walk(enabled: bool) -> void:
	_test_walk = enabled


func is_test_walk() -> bool:
	return _test_walk


func get_test_character() -> IWEWalkmeshCharacter:
	if not is_instance_valid(_viewport) or _viewport.get_child_count() == 0:
		return null
	return _viewport.get_child(0).get_node_or_null("Player") as IWEWalkmeshCharacter


## The preview drives the character itself: no keyboard, no clicks through the viewport, and no
## physics (the editor does not step the physics of a preview world).
func _prepare_test_character() -> void:
	var player := get_test_character()
	if player == null:
		return
	player.editor_preview = true
	player.kinematic = true
	player.keyboard_control = false
	player.click_to_move = false
	if _base_speed > 0.0:
		player.move_speed = _base_speed
	player.set_speed_multiplier(_speed_multiplier)
	if _paused:
		player.pause()
	test_character_ready.emit(player.move_speed)


## Base speed in world units per second. Zero or less restores the character's own value.
func set_base_speed(value: float) -> void:
	_base_speed = maxf(value, 0.0)
	var player := get_test_character()
	if player != null and _base_speed > 0.0:
		player.move_speed = _base_speed


func get_base_speed() -> float:
	var player := get_test_character()
	return player.move_speed if player != null else _base_speed


## Speed multiplier (x0.1 to x10). It can change while the character walks.
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = clampf(multiplier, IWEWalkmeshCharacter.MIN_SPEED_MULTIPLIER, IWEWalkmeshCharacter.MAX_SPEED_MULTIPLIER)
	var player := get_test_character()
	if player != null:
		player.set_speed_multiplier(_speed_multiplier)


func get_speed_multiplier() -> float:
	return _speed_multiplier


func set_paused(paused: bool) -> void:
	_paused = paused
	var player := get_test_character()
	if player == null:
		return
	if paused:
		player.pause()
	else:
		player.resume()


func is_paused() -> bool:
	return _paused


func reset_test_character() -> void:
	var player := get_test_character()
	if player != null:
		player.reset_position()


## Sends the test character to the floor point under an image pixel. False when the pixel is not
## on the floor (above the horizon) or there is no character.
func walk_to_image_point(image_position: Vector2) -> bool:
	var player := get_test_character()
	if player == null or _calibration == null:
		return false
	var floor_point: Variant = PROJECTOR.image_point_to_floor(image_position, _image_size, _reference_size, _calibration.camera_position, _calibration.camera_rotation_degrees, _calibration.field_of_view_degrees, _calibration.floor_height)
	if floor_point == null:
		return false
	player.move_to(Vector3(floor_point.x, _calibration.floor_height, floor_point.z) * _world_scale)
	return true


## The parent keeps this panel at the reference aspect ratio, so the render matches the
## calibrated frame whatever the dock looks like.
func _apply_reference_aspect() -> void:
	var frame := get_parent() as AspectRatioContainer
	if frame != null and _reference_size.y > 0:
		frame.ratio = float(_reference_size.x) / float(_reference_size.y)


func get_reference_size() -> Vector2i:
	return _reference_size


func set_top_view(enabled: bool) -> void:
	_top_view = enabled
	_set_camera_mode(enabled)


func is_top_view() -> bool:
	return _top_view


func _gui_input(event: InputEvent) -> void:
	if _top_view or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Panel pixel -> reference pixel -> image pixel. Each step is a pure function.
	var reference_point := PROJECTOR.panel_to_reference(event.position, size, _reference_size)
	var image_position: Variant = PROJECTOR.viewport_to_image(reference_point, _image_size, _reference_size)
	if image_position != null:
		image_point_clicked.emit(image_position)
		accept_event()


func _set_camera_mode(top_view: bool) -> void:
	if not is_instance_valid(_viewport):
		return
	var stage := _viewport.get_child(0) as Node3D if _viewport.get_child_count() > 0 else null
	var perspective_camera := stage.get_node_or_null("PerspectiveStage/CameraRig/PerspectiveCamera") as Camera3D if stage else null
	var top_camera := stage.get_node_or_null("PerspectiveStage/CameraRig/TopCamera") as Camera3D if stage else null
	if perspective_camera and top_camera:
		if top_view:
			top_camera.make_current()
		else:
			perspective_camera.make_current()

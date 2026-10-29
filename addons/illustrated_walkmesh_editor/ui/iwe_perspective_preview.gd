@tool
extends SubViewportContainer
## Live 3D preview of the calibrated stage.
##
## The preview only *displays* the calibration. The frame it shows is the calibration's own
## reference viewport; the panel around it can have any size or shape and is only a display
## concern. Nothing here writes to the document.

signal image_point_clicked(image_position: Vector2)

const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const MIN_USABLE_SIZE := 64

var _viewport: SubViewport
var _image_size := Vector2i.ZERO
var _top_view := false
## The frame being shown (the calibration's reference viewport). Set by configure().
var _reference_size := Vector2i(1280, 720)


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
func configure(document: Resource, texture: Texture2D, calibration: IWEPerspectiveCalibration, world_scale: float) -> void:
	if not is_instance_valid(_viewport) or document == null or texture == null or calibration == null:
		return
	_image_size = document.image_size
	_reference_size = calibration.reference_viewport_size
	_apply_reference_aspect()
	var stage: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, world_scale)
	if stage == null:
		return
	stage.name = "PerspectiveStage"
	for child in _viewport.get_children():
		child.free()
	_viewport.add_child(stage)
	_set_camera_mode(_top_view)


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

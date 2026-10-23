@tool
extends SubViewportContainer

signal image_point_clicked(image_position: Vector2)
signal viewport_size_changed(viewport_size: Vector2i)

const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")

var _viewport: SubViewport
var _image_size := Vector2i.ZERO
var _top_view := false


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.name = "PerspectiveViewport"
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(1280, 720)
	add_child(_viewport)
	viewport_size_changed.emit(_viewport.size)


func configure(document: Resource, texture: Texture2D, calibration: IWEPerspectiveCalibration, world_scale: float) -> void:
	if not is_instance_valid(_viewport) or document == null or texture == null or calibration == null:
		return
	_image_size = document.image_size
	var stage: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, world_scale)
	if stage == null:
		return
	stage.name = "PerspectiveStage"
	for child in _viewport.get_children():
		child.free()
	_viewport.add_child(stage)
	_set_camera_mode(_top_view)


func set_top_view(enabled: bool) -> void:
	_top_view = enabled
	_set_camera_mode(enabled)


func is_top_view() -> bool:
	return _top_view


func get_viewport_size() -> Vector2i:
	if _viewport:
		return _viewport.size
	return Vector2i(1280, 720)


func _gui_input(event: InputEvent) -> void:
	if _top_view or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var viewport_point: Vector2 = event.position
	if size.x > 0.0 and size.y > 0.0:
		viewport_point *= Vector2(get_viewport_size()) / size
	var image_position: Variant = PROJECTOR.viewport_to_image(viewport_point, _image_size, get_viewport_size())
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

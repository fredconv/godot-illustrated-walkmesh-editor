@tool
extends VBoxContainer

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")

@onready var _import_button: Button = %ImportButton
@onready var _create_group_button: Button = %CreateGroupButton
@onready var _group_option: OptionButton = %GroupOption
@onready var _zoom_out_button: Button = %ZoomOutButton
@onready var _zoom_in_button: Button = %ZoomInButton
@onready var _zoom_label: Label = %ZoomLabel
@onready var _new_button: Button = %NewButton
@onready var _save_button: Button = %SaveButton
@onready var _open_button: Button = %OpenButton
@onready var _draw_button: Button = %DrawButton
@onready var _subtract_button: Button = %SubtractButton
@onready var _select_button: Button = %SelectButton
@onready var _points_button: Button = %PointsButton
@onready var _add_point_button: Button = %AddPointButton
@onready var _remove_point_button: Button = %RemovePointButton
@onready var _visibility_button: Button = %VisibilityButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _delete_button: Button = %DeleteButton
@onready var _duplicate_button: Button = %DuplicateButton
@onready var _rename_button: Button = %RenameRegionButton
@onready var _rename_group_button: Button = %RenameGroupButton
@onready var _rename_cutout_button: Button = %RenameCutoutButton
@onready var _region_list: Tree = %RegionList
@onready var _file_dialog: FileDialog = $ImageFileDialog
@onready var _save_dialog: FileDialog = %DocumentFileDialog
@onready var _open_dialog: FileDialog = $OpenDocumentDialog
@onready var _image_copy_dialog: FileDialog = %ImageCopyDialog
@onready var _export_dialog: FileDialog = %ExportSceneDialog
@onready var _export_2d_button: Button = %Export2DButton
@onready var _export_3d_button: Button = %Export3DButton
@onready var _scale_2d: SpinBox = %Scale2DInput
@onready var _scale_3d: SpinBox = %Scale3DInput
@onready var _add_camera: CheckButton = %AddCameraInput
@onready var _template_mode_button: Button = %TemplateModeButton
@onready var _template_height_input: SpinBox = %TemplateHeightInput
@onready var _delete_template_button: Button = %DeleteTemplateButton
@onready var _perspective_button: Button = %PerspectiveButton
@onready var _perspective_panel: VBoxContainer = %PerspectivePanel
@onready var _perspective_preview: SubViewportContainer = %PerspectivePreview
@onready var _perspective_preview_frame: AspectRatioContainer = %PerspectivePreviewFrame
@onready var _reference_width_input: SpinBox = %ReferenceViewportWidthInput
@onready var _reference_height_input: SpinBox = %ReferenceViewportHeightInput
@onready var _perspective_top_view_button: CheckButton = %PerspectiveTopViewButton
@onready var _fit_references_button: Button = %FitFromReferencesButton
@onready var _add_player_input: CheckButton = %AddPlayerInput
@onready var _export_perspective_button: Button = %ExportPerspectiveButton
@onready var _camera_fov_input: SpinBox = %CameraFovInput
@onready var _floor_height_input: SpinBox = %FloorHeightInput
@onready var _character_height_input: SpinBox = %CharacterHeightInput
@onready var _camera_position_x_input: SpinBox = %CameraPositionXInput
@onready var _camera_position_y_input: SpinBox = %CameraPositionYInput
@onready var _camera_position_z_input: SpinBox = %CameraPositionZInput
@onready var _camera_rotation_x_input: SpinBox = %CameraRotationXInput
@onready var _camera_rotation_y_input: SpinBox = %CameraRotationYInput
@onready var _camera_rotation_z_input: SpinBox = %CameraRotationZInput
@onready var _image_scroll: ScrollContainer = $Workspace/CanvasArea/ImageScroll
@onready var _status_label: Label = %StatusLabel
@onready var _canvas: Control = $Workspace/CanvasArea/ImageScroll/Canvas
@onready var _canvas_window_button: Button = %CanvasWindowButton
@onready var _canvas_area: Control = $Workspace/CanvasArea
@onready var _document_title_label: Label = %DocumentTitleLabel

var _zoom := 1.0
var _document: Resource
## Undo history of the current document only. It is replaced (and the old one freed)
## whenever the document changes, so actions can never apply to another document, and the
## editor's own histories are never touched.
var _history: IWEDocumentHistory
## Action waiting for the user's answer to the "unsaved changes" question or for the save that
## answer started. Cleared when the user cancels or when the save fails.
var _pending_unsaved_action := Callable()
var _unsaved_dialog: ConfirmationDialog
var _illustration_dialog: ConfirmationDialog
## How a document is written to disk. Tests replace it to simulate a failing disk without
## depending on the engine's own error messages.
var _resource_saver := Callable(ResourceSaver, "save")
## One recovery file per editor session, so repeated saves overwrite instead of piling up.
var _recovery_stamp := Time.get_datetime_string_from_system().replace(":", "-")
var _pending_document_path := ""
var _pending_image_source := ""
var _selected_group_id := ""
var _has_illustration := false
var _pending_export_dimension := 2
var _active_name_dialog: ConfirmationDialog
var _active_name_input: LineEdit
var _selected_cutout_region_id := ""
var _selected_cutout_index := -1
var _selected_scale_anchor_id := ""
var _perspective_mode := false
var _canvas_window: Window
var _canvas_area_parent: Node
var _canvas_area_index := 0


func set_document(document: Resource) -> void:
	_document = document
	if is_node_ready():
		_replace_document(_document)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _history != null:
		_history.dispose()
		_history = null


## Starts a fresh history for the current document. The previous one is freed with every
## action it held, including references to regions and anchors of the previous document.
func _reset_history() -> void:
	if _history != null:
		_history.dispose()
	_history = IWEDocumentHistory.new()
	_history.changed.connect(_on_history_changed)
	_canvas.set_undo_redo(_history)
	_on_history_changed()


func _on_history_changed() -> void:
	if not is_node_ready() or _history == null:
		return
	_undo_button.disabled = not _history.has_undo()
	_redo_button.disabled = not _history.has_redo()
	_update_document_title()


func _document_display_name() -> String:
	var path: String = _document.document_path if _document != null else ""
	return path.get_file().get_basename() if not path.is_empty() else "Untitled"


## "Name" when saved, "Name *" when there are unsaved changes.
func _update_document_title() -> void:
	if _history == null:
		return
	_document_title_label.text = _document_display_name() + (" *" if _history.is_dirty() else "")
	var has_path: bool = _document != null and not _document.document_path.is_empty()
	_document_title_label.tooltip_text = _document.document_path if has_path else "This document has not been saved yet"


func is_dirty() -> bool:
	return _history != null and _history.is_dirty()


func _ready() -> void:
	_import_button.pressed.connect(_file_dialog.popup_centered)
	_create_group_button.pressed.connect(_create_group)
	_group_option.item_selected.connect(_group_selected)
	_file_dialog.file_selected.connect(_load_illustration)
	_zoom_out_button.pressed.connect(_change_zoom.bind(1.0 / 1.2))
	_zoom_in_button.pressed.connect(_change_zoom.bind(1.2))
	_canvas.zoom_requested.connect(_change_zoom)
	_canvas.undo_requested.connect(_undo)
	_canvas.redo_requested.connect(_redo)
	_canvas.region_created.connect(_create_region)
	_canvas.subtraction_created.connect(_create_subtraction)
	_canvas.region_selected.connect(_select_region)
	_canvas.region_changed.connect(_region_changed)
	_canvas.add_vertex_requested.connect(_canvas.add_selected_vertex)
	_canvas.add_vertex_mode_changed.connect(_sync_add_vertex_mode)
	_canvas.vertex_mode_changed.connect(_sync_points_mode)
	_canvas.point_selected.connect(_sync_point_selection)
	_canvas.scale_anchor_created.connect(_create_scale_anchor)
	_canvas.scale_anchor_changed.connect(_move_scale_anchor)
	_canvas.scale_anchor_selected.connect(_select_scale_anchor)
	_canvas.scale_anchor_height_requested.connect(_scale_anchor_height_by)
	_canvas.scale_anchor_delete_requested.connect(_delete_scale_anchor_by_id)
	_perspective_preview.image_point_clicked.connect(_create_perspective_anchor)
	_reference_width_input.value_changed.connect(_set_reference_viewport_axis.bind(0))
	_reference_height_input.value_changed.connect(_set_reference_viewport_axis.bind(1))
	_new_button.pressed.connect(_request_new_document)
	_save_button.pressed.connect(_show_save_dialog)
	_save_dialog.file_selected.connect(_save_document)
	# Cancelling a save that was started from the "unsaved changes" question cancels that action.
	_save_dialog.canceled.connect(_cancel_pending_unsaved_action)
	_image_copy_dialog.canceled.connect(_cancel_pending_unsaved_action)
	_open_button.pressed.connect(_open_dialog.popup_centered)
	_open_dialog.file_selected.connect(_request_open_document)
	_image_copy_dialog.dir_selected.connect(_copy_image_into_document)
	_export_2d_button.pressed.connect(_begin_export.bind(2))
	_export_3d_button.pressed.connect(_begin_export.bind(3))
	_export_dialog.file_selected.connect(_export_scene)
	_draw_button.toggled.connect(_set_polygon_mode)
	_subtract_button.toggled.connect(_set_subtract_mode)
	_select_button.toggled.connect(_set_select_mode)
	_points_button.toggled.connect(_set_points_mode)
	_add_point_button.toggled.connect(_set_add_vertex_mode)
	_template_mode_button.toggled.connect(_set_template_mode)
	_template_height_input.value_changed.connect(_set_selected_template_height)
	_delete_template_button.pressed.connect(_delete_selected_template)
	_perspective_button.toggled.connect(_set_perspective_mode)
	_canvas_window_button.toggled.connect(_set_canvas_window)
	_perspective_top_view_button.toggled.connect(_perspective_preview.set_top_view)
	_fit_references_button.pressed.connect(_fit_camera_to_references)
	_export_perspective_button.pressed.connect(_begin_export.bind(4))
	_camera_fov_input.value_changed.connect(_set_calibration_fov)
	_floor_height_input.value_changed.connect(_set_calibration_floor)
	_character_height_input.value_changed.connect(_set_calibration_character_height)
	_camera_position_x_input.value_changed.connect(_set_camera_position_axis.bind(0))
	_camera_position_y_input.value_changed.connect(_set_camera_position_axis.bind(1))
	_camera_position_z_input.value_changed.connect(_set_camera_position_axis.bind(2))
	_camera_rotation_x_input.value_changed.connect(_set_camera_rotation_axis.bind(0))
	_camera_rotation_y_input.value_changed.connect(_set_camera_rotation_axis.bind(1))
	_camera_rotation_z_input.value_changed.connect(_set_camera_rotation_axis.bind(2))
	_scale_3d.value_changed.connect(func(_value: float) -> void: _refresh_perspective_preview())
	_remove_point_button.pressed.connect(_canvas.remove_selected_vertex)
	_visibility_button.pressed.connect(_toggle_selected_visibility)
	_canvas.draw_mode_changed.connect(_set_draw_mode)
	_canvas.selection_changed.connect(_sync_selection)
	_undo_button.pressed.connect(_undo)
	_redo_button.pressed.connect(_redo)
	_delete_button.pressed.connect(_delete_selected_region)
	_duplicate_button.pressed.connect(_duplicate_selected_region)
	# Deferred: handlers may rebuild the tree, which must not happen while the tree is still
	# inside its own selection or activation callback.
	_region_list.item_selected.connect(_region_item_selected, CONNECT_DEFERRED)
	_region_list.item_activated.connect(_tree_item_activated, CONNECT_DEFERRED)
	_rename_button.pressed.connect(_rename_selected_region)
	_rename_group_button.pressed.connect(_rename_selected_group)
	_rename_cutout_button.pressed.connect(_rename_selected_cutout)
	_reset_history()
	_canvas.set_document(_document)
	if _document != null:
		_canvas.set_scale_anchors(_document.scale_anchors, _document.default_template_height_px)
		_sync_calibration_inputs()
	if _document != null and not _document.groups.is_empty():
		_selected_group_id = _document.groups[0].id
	_sync_selection("")
	_refresh_group_options()
	_refresh_status()


func _load_illustration(path: String) -> void:
	var image := Image.load_from_file(path)
	if image.is_empty():
		push_error("IWE: Could not load illustration at %s" % path)
		return
	var had_illustration: bool = _document.image_size.x > 0 and _document.image_size.y > 0
	if had_illustration:
		# Replacing the picture of a document that already has one never touches the authored
		# data: regions, templates and calibration stay as they are.
		if image.get_size() == _document.image_size:
			_replace_illustration(path, image)
		else:
			_confirm_illustration_replacement(path, image)
		return
	var texture := ImageTexture.create_from_image(image)
	_canvas.set_texture(texture)
	_has_illustration = true
	_document.set_illustration(path, image.get_size())
	# The reference frame of a new calibration is the project's game window: explicit and stable.
	# The size of this panel plays no part in it.
	_document.perspective_calibration = CALIBRATION_SCRIPT.for_image(image.get_size(), CALIBRATION_SCRIPT.project_viewport_size())
	_pending_image_source = path
	_sync_calibration_inputs()
	_refresh_group_options()
	_refresh_regions()
	_refresh_status()
	_refresh_perspective_preview()
	# The first import creates the calibration outside the undo history.
	_history.note_untracked_change()


## The new picture has another size: regions and height references are placed in the pixels of
## the current picture, so they will not line up with it. Ask first; the change can be undone.
func _confirm_illustration_replacement(path: String, image: Image) -> void:
	if is_instance_valid(_illustration_dialog):
		_illustration_dialog.queue_free()
	var current: Vector2i = _document.image_size
	var dialog := ConfirmationDialog.new()
	dialog.title = "Replace illustration"
	dialog.dialog_text = "The new illustration is %d×%d px, the current one is %d×%d px.

Regions, height references and the calibration keep their values, but they are placed in the pixels of the current illustration and may no longer line up. You can undo this." % [image.get_width(), image.get_height(), current.x, current.y]
	dialog.ok_button_text = "Replace illustration"
	dialog.cancel_button_text = "Cancel"
	dialog.confirmed.connect(_replace_illustration.bind(path, image))
	_illustration_dialog = dialog
	add_child(dialog)
	dialog.popup_centered()


## Swaps the picture only. Regions, groups, templates, and the calibration are not touched.
func _replace_illustration(path: String, image: Image) -> void:
	if _document == null:
		return
	var before := {"path": _document.illustration_path, "size": _document.image_size, "texture": _canvas.get_texture(), "source": _pending_image_source, "has": _has_illustration}
	var after := {"path": path, "size": image.get_size(), "texture": ImageTexture.create_from_image(image), "source": path, "has": true}
	_history.create_action("Replace IWE illustration")
	_history.add_do_method(_apply_illustration_state.bind(after))
	_history.add_undo_method(_apply_illustration_state.bind(before))
	_history.commit_action()


func _apply_illustration_state(state: Dictionary) -> void:
	if _document == null:
		return
	_canvas.set_texture(state["texture"])
	_has_illustration = state["has"]
	_document.set_illustration(state["path"], state["size"])
	_pending_image_source = state["source"]
	_update_workflow_controls()
	_refresh_regions()
	_refresh_status()
	_refresh_perspective_preview()


func _change_zoom(factor: float) -> void:
	_zoom = clampf(_zoom * factor, 0.1, 8.0)
	_canvas.set_zoom(_zoom)
	_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)


func _refresh_perspective_preview() -> void:
	if not is_node_ready() or _document == null or not _has_illustration:
		return
	var texture := _load_external_texture(_pending_image_source)
	if texture == null:
		return
	_perspective_preview.configure(_document, texture, _document.perspective_calibration, _scale_3d.value)
	_perspective_preview.set_top_view(_perspective_top_view_button.button_pressed)


func _sync_calibration_inputs() -> void:
	if not is_node_ready() or _document == null or _document.perspective_calibration == null:
		return
	var calibration: IWEPerspectiveCalibration = _document.perspective_calibration
	_camera_fov_input.set_value_no_signal(calibration.field_of_view_degrees)
	_floor_height_input.set_value_no_signal(calibration.floor_height)
	_character_height_input.set_value_no_signal(calibration.character_height_units)
	_camera_position_x_input.set_value_no_signal(calibration.camera_position.x)
	_camera_position_y_input.set_value_no_signal(calibration.camera_position.y)
	_camera_position_z_input.set_value_no_signal(calibration.camera_position.z)
	_camera_rotation_x_input.set_value_no_signal(calibration.camera_rotation_degrees.x)
	_camera_rotation_y_input.set_value_no_signal(calibration.camera_rotation_degrees.y)
	_camera_rotation_z_input.set_value_no_signal(calibration.camera_rotation_degrees.z)
	_reference_width_input.set_value_no_signal(calibration.reference_viewport_size.x)
	_reference_height_input.set_value_no_signal(calibration.reference_viewport_size.y)


func _set_calibration_fov(value: float) -> void:
	_set_calibration_value("field_of_view_degrees", value)


func _set_calibration_floor(value: float) -> void:
	_set_calibration_value("floor_height", value)


func _set_calibration_character_height(value: float) -> void:
	_set_calibration_value("character_height_units", value)


func _set_camera_position_axis(value: float, axis: int) -> void:
	if _document == null:
		return
	var position: Vector3 = _document.perspective_calibration.camera_position
	position[axis] = value
	_set_calibration_value("camera_position", position)


## Editing the reference frame is a deliberate change: it moves every image point on the floor.
func _set_reference_viewport_axis(value: float, axis: int) -> void:
	if _document == null or _document.perspective_calibration == null:
		return
	var reference: Vector2i = _document.perspective_calibration.reference_viewport_size
	reference[axis] = maxi(roundi(value), 64)
	# Own action name: MERGE_ENDS only folds consecutive steps of the same name, so a field
	# change in between is never merged into a reference step.
	_set_calibration_value("reference_viewport_size", reference, "Adjust IWE reference frame", UndoRedo.MERGE_ENDS)


func _set_camera_rotation_axis(value: float, axis: int) -> void:
	if _document == null:
		return
	var rotation: Vector3 = _document.perspective_calibration.camera_rotation_degrees
	rotation[axis] = value
	_set_calibration_value("camera_rotation_degrees", rotation)


func _set_calibration_value(property_name: StringName, value: Variant, action_name := "Adjust IWE perspective calibration", merge_mode := UndoRedo.MERGE_DISABLE) -> void:
	if _document == null or _document.perspective_calibration == null:
		return
	var calibration: IWEPerspectiveCalibration = _document.perspective_calibration
	var previous: Variant = calibration.get(property_name)
	if previous == value:
		return
	_history.create_action(action_name, merge_mode)
	_history.add_do_method(_apply_calibration_value.bind(property_name, value))
	_history.add_undo_method(_apply_calibration_value.bind(property_name, previous))
	_history.commit_action()


func _apply_calibration_value(property_name: StringName, value: Variant) -> void:
	if _document == null or _document.perspective_calibration == null:
		return
	_document.perspective_calibration.set(property_name, value)
	_sync_calibration_inputs()
	_refresh_perspective_preview()


## Solves the camera from the height references and records it as one undoable step.
func _fit_camera_to_references() -> void:
	if _document == null or _document.perspective_calibration == null or not _has_illustration:
		return
	var before: IWEPerspectiveCalibration = _document.perspective_calibration.duplicate()
	var after: IWEPerspectiveCalibration = before.duplicate()
	var error := after.fit_to_scale_anchors(_document.scale_anchors, _document.image_size)
	if not error.is_empty():
		_status_label.text = "Fit failed: %s" % error
		return
	_history.create_action("Fit IWE perspective camera")
	_history.add_do_method(_apply_calibration_snapshot.bind(after))
	_history.add_undo_method(_apply_calibration_snapshot.bind(before))
	_history.commit_action()
	_status_label.text = "Camera fitted to %d height references." % _document.scale_anchors.size()


func _apply_calibration_snapshot(calibration: IWEPerspectiveCalibration) -> void:
	if _document == null:
		return
	_document.perspective_calibration = calibration
	_sync_calibration_inputs()
	_refresh_perspective_preview()


## Moves the canvas area into a large floating window so the whole illustration fits on screen.
## Closing the window (or toggling the button off) puts the canvas back in the dock.
func _set_canvas_window(enabled: bool) -> void:
	if enabled == (_canvas_window != null):
		return
	if enabled:
		_canvas_window = Window.new()
		_canvas_window.title = "IWE - Illustration Editor"
		_canvas_window.size = Vector2i(1400, 900)
		_canvas_window.gui_embed_subwindows = false
		_canvas_window.theme = get_theme()
		_canvas_window.close_requested.connect(_set_canvas_window.bind(false))
		_canvas_area_parent = _canvas_area.get_parent()
		_canvas_area_index = _canvas_area.get_index()
		_canvas_area.reparent(_canvas_window, false)
		_canvas_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_canvas_window)
		_canvas_window.popup_centered_ratio(0.9)
	else:
		_canvas_area.reparent(_canvas_area_parent, false)
		_canvas_area_parent.move_child(_canvas_area, _canvas_area_index)
		_canvas_window.queue_free()
		_canvas_window = null
		_canvas_window_button.set_pressed_no_signal(false)


func _exit_tree() -> void:
	if _canvas_window != null:
		_set_canvas_window(false)


func _set_perspective_mode(enabled: bool) -> void:
	_perspective_mode = enabled
	_perspective_button.set_pressed_no_signal(enabled)
	_perspective_panel.visible = enabled
	_perspective_preview.visible = enabled
	_perspective_preview_frame.visible = enabled
	_image_scroll.visible = not enabled
	if enabled:
		_stop_tools()
		_sync_calibration_inputs()
		_refresh_perspective_preview()
	_update_workflow_controls()
	_refresh_status()


func get_document() -> Resource:
	return _document


func _undo() -> void:
	if _history != null:
		_history.undo()


func _redo() -> void:
	if _history != null:
		_history.redo()


## A new document starts with an empty history. Creating it is not undoable: undoing it would
## have to bring back another document's history.
func _new_document() -> void:
	_replace_document(DOCUMENT_SCRIPT.new())


func _replace_document(document: Resource) -> void:
	_stop_tools()
	_document = document
	_reset_history()
	_set_perspective_mode(false)
	_migrate_document_groups()
	_canvas.set_document(_document)
	if _document != null:
		_canvas.set_scale_anchors(_document.scale_anchors, _document.default_template_height_px)
	_pending_image_source = ""
	if not _document.illustration_path.is_empty() and not _document.document_path.is_empty():
		_pending_image_source = _resolve_document_asset_path(_document.illustration_path, _document.document_path)
	var texture := _load_external_texture(_pending_image_source)
	if texture:
		_canvas.set_texture(texture)
		_has_illustration = true
	else:
		_canvas.set_texture(null)
		_has_illustration = false
	_selected_group_id = ""
	if not _document.groups.is_empty() and _selected_group_id.is_empty():
		_selected_group_id = _document.groups[0].id
	_canvas.set_regions(_document.regions)
	_sync_calibration_inputs()
	_refresh_group_options()
	_refresh_regions()
	_update_workflow_controls()
	_refresh_status()
	_refresh_perspective_preview()


func _save_document(path: String) -> void:
	_pending_document_path = path
	if not _pending_document_path.ends_with(".tres"):
		_pending_document_path += ".tres"
	if not _pending_image_source.is_empty() and not _is_asset_beside_document(_pending_image_source):
		_image_copy_dialog.current_dir = _pending_document_path.get_base_dir()
		_image_copy_dialog.popup_centered()
		return
	_write_document()


func _copy_image_into_document(directory: String) -> void:
	if _pending_image_source.is_empty():
		_write_document()
		return
	var asset_directory := directory.path_join("assets")
	var make_directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_directory))
	if make_directory_error != OK and make_directory_error != ERR_ALREADY_EXISTS:
		push_error("IWE: Could not create assets directory (%s)" % error_string(make_directory_error))
		return
	var source_absolute := _pending_image_source
	if source_absolute.begins_with("res://") or source_absolute.begins_with("user://"):
		source_absolute = ProjectSettings.globalize_path(source_absolute)
	var file_hash := FileAccess.get_md5(source_absolute).substr(0, 12)
	var image_filename := "illustration_%s.%s" % [file_hash, _pending_image_source.get_extension()]
	var destination := asset_directory.path_join(image_filename)
	var copy_error := DirAccess.copy_absolute(source_absolute, ProjectSettings.globalize_path(destination))
	if copy_error != OK and copy_error != ERR_ALREADY_EXISTS:
		push_error("IWE: Could not copy illustration (%s)" % error_string(copy_error))
		return
	_document.illustration_path = "assets/%s" % image_filename
	_pending_image_source = destination
	_history.note_untracked_change()
	_write_document()


func _show_save_dialog() -> void:
	# Start inside the project, next to the current document when there is one.
	var document_path: String = _document.document_path if _document != null else ""
	if document_path.is_empty():
		_save_dialog.current_dir = "res://"
		_save_dialog.current_file = ""
	else:
		_save_dialog.current_dir = document_path.get_base_dir()
		_save_dialog.current_file = document_path.get_file()
	_save_dialog.popup_centered_ratio(0.6)


## Writes the document to _pending_document_path. Returns true on success. A failure keeps the
## document modified, restores its previous path, and is reported to the user.
func _write_document() -> bool:
	var directory := _pending_document_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_report_save_error("Could not create folder %s (%s)" % [directory, error_string(directory_error)])
		return false
	var previous_path: String = _document.document_path
	_document.document_path = _pending_document_path
	var error: int = _resource_saver.call(_document, _pending_document_path)
	if error != OK:
		_document.document_path = previous_path
		_report_save_error("Could not save %s (%s)" % [_pending_document_path, error_string(error)])
		return false
	_history.mark_saved()
	_refresh_status()
	_run_pending_unsaved_action()
	return true


func _report_save_error(message: String) -> void:
	push_error("IWE: %s" % message)
	_status_label.text = "Save failed: %s" % message
	_cancel_pending_unsaved_action()


## Asks what to do with unsaved changes before running action. Unsaved changes are never
## dropped silently: Save runs the action after a successful save, Discard Changes runs it
## now, Cancel keeps the document untouched.
func _run_after_unsaved_check(action: Callable) -> void:
	if _history == null or not _history.is_dirty():
		action.call()
		return
	_pending_unsaved_action = action
	if is_instance_valid(_unsaved_dialog):
		_unsaved_dialog.queue_free()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Unsaved changes"
	dialog.dialog_text = "%s has unsaved changes." % _document_display_name()
	dialog.ok_button_text = "Save"
	dialog.cancel_button_text = "Cancel"
	dialog.add_button("Discard Changes", true, "discard")
	dialog.confirmed.connect(_unsaved_choice.bind("save"))
	dialog.canceled.connect(_unsaved_choice.bind("cancel"))
	dialog.custom_action.connect(func(choice: StringName) -> void: _unsaved_choice(String(choice)))
	_unsaved_dialog = dialog
	add_child(dialog)
	dialog.popup_centered()


## choice is "save", "discard", or "cancel". The tests call it because they cannot click buttons.
func _unsaved_choice(choice: String) -> void:
	if is_instance_valid(_unsaved_dialog):
		_unsaved_dialog.hide()
		_unsaved_dialog.queue_free()
		_unsaved_dialog = null
	match choice:
		"discard":
			var action := _pending_unsaved_action
			_pending_unsaved_action = Callable()
			if action.is_valid():
				action.call()
		"save":
			_save_current()
		_:
			_cancel_pending_unsaved_action()


## Saves to the document's own path, or asks for one when it has none (Save As).
func _save_current() -> void:
	if _document.document_path.is_empty():
		_show_save_dialog()
		return
	_save_document(_document.document_path)


func _run_pending_unsaved_action() -> void:
	if not _pending_unsaved_action.is_valid():
		return
	var action := _pending_unsaved_action
	_pending_unsaved_action = Callable()
	# The action replaces the document and its history; let the save finish unwinding first.
	action.call_deferred()


func _cancel_pending_unsaved_action() -> void:
	_pending_unsaved_action = Callable()


func _request_new_document() -> void:
	_run_after_unsaved_check(_new_document)


func _request_open_document(path: String) -> void:
	_run_after_unsaved_check(_open_document.bind(path))


## Text for Godot's own "unsaved changes" dialog when the editor is closing, or "" when clean.
## for_scene is the scene being closed, or "" when the whole editor is closing. The IWE
## document is not part of any scene, so closing a scene never reports it.
func get_unsaved_status(for_scene: String = "") -> String:
	if not for_scene.is_empty() or not is_dirty():
		return ""
	if _document.document_path.is_empty():
		return "IWE document \"%s\" has never been saved. Choosing Save writes a recovery copy to user://iwe_recovery/; use the IWE Save button to pick a location." % _document_display_name()
	return "IWE document \"%s\" has unsaved changes." % _document_display_name()


## Called by Godot when the user chooses to save (Save All, or Save in the quit dialog).
## It must not show dialogs. A document with a path is written in place; anything that
## would need the user (no path yet, or an image still outside the document folder) gets a
## recovery copy and stays modified.
func save_external_data() -> void:
	if not is_dirty():
		return
	var image_ready: bool = _pending_image_source.is_empty() or _is_asset_beside_document(_pending_image_source)
	if not _document.document_path.is_empty() and image_ready:
		_pending_document_path = _document.document_path
		_write_document()
		return
	var recovery_path := save_recovery_copy()
	if not recovery_path.is_empty():
		push_warning("IWE: the document is not saved yet. A recovery copy was written to %s" % recovery_path)


## Writes the document to user://iwe_recovery/ without touching its path or its modified state.
## Returns the file path, or "" on failure.
func save_recovery_copy() -> String:
	if _document == null:
		return ""
	var folder := "user://iwe_recovery"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := "%s/recovery_%s.tres" % [folder, _recovery_stamp]
	var error := ResourceSaver.save(_document, path)
	if error != OK:
		push_error("IWE: Could not write the recovery copy (%s)" % error_string(error))
		return ""
	return path


func _open_document(path: String) -> void:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	if loaded == null or not loaded is DOCUMENT_SCRIPT:
		push_error("IWE: Could not load an IWE document at %s" % path)
		return
	loaded.document_path = path
	_replace_document(loaded)
	if not _has_illustration:
		push_warning("IWE: Import an illustration before creating regions.")


func _begin_export(dimension: int) -> void:
	if not _has_illustration or _pending_image_source.is_empty():
		return
	_pending_export_dimension = dimension
	_export_dialog.current_dir = ProjectSettings.globalize_path("res://")
	_export_dialog.current_file = "iwe_stage_perspective.tscn" if dimension == 4 else "iwe_stage_%dd.tscn" % dimension
	_export_dialog.popup_centered()


func _export_scene(path: String) -> void:
	if _document == null or _pending_image_source.is_empty():
		push_error("IWE: Import an illustration before exporting a scene.")
		return
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var absolute_project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/") + "/"
	if not absolute_path.replace("\\", "/").to_lower().begins_with(absolute_project.to_lower()):
		push_error("IWE: Export the scene inside this Godot project so its resources remain portable.")
		return
	var texture := _load_external_texture(_pending_image_source)
	if texture == null:
		push_error("IWE: The source illustration could not be loaded for scene export.")
		return
	var scale := _scale_2d.value if _pending_export_dimension == 2 else _scale_3d.value
	var root: Node
	if _pending_export_dimension == 2:
		root = SCENE_GENERATOR.build_2d_scene(_document, texture, scale, _add_camera.button_pressed)
	elif _pending_export_dimension == 3:
		root = SCENE_GENERATOR.build_3d_scene(_document, texture, scale, _add_camera.button_pressed)
	else:
		root = SCENE_GENERATOR.build_perspective_scene(_document, texture, _document.perspective_calibration, scale, _add_player_input.button_pressed)
	if root == null:
		push_error("IWE: Could not build the generated scene.")
		return
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	root.free()
	if pack_error != OK:
		push_error("IWE: Could not pack generated scene (%s)." % error_string(pack_error))
		return
	var save_path := absolute_path if absolute_path.ends_with(".tscn") else absolute_path + ".tscn"
	var save_error := ResourceSaver.save(packed, save_path)
	if save_error != OK:
		push_error("IWE: Could not save generated scene (%s)." % error_string(save_error))
		return
	_status_label.text = "Exported perspective scene: %s" % ProjectSettings.localize_path(save_path) if _pending_export_dimension == 4 else "Exported %dD scene: %s" % [_pending_export_dimension, ProjectSettings.localize_path(save_path)]


func _create_region(points: PackedVector2Array) -> void:
	if not _can_create_region():
		return
	var region: IWERegion = REGION_SCRIPT.new()
	region.id = REGION_SCRIPT._new_id()
	region.name = "Region %d" % (_document.regions.size() + 1)
	region.group_id = _selected_group_id
	region.points = points
	_history.create_action("Create IWE region")
	_history.add_do_method(_add_region.bind(region))
	_history.add_undo_method(_remove_region.bind(region.id))
	_history.commit_action()


func _create_scale_anchor(image_position: Vector2, height_px: float) -> void:
	if not _has_illustration or _document == null:
		return
	var anchor: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(image_position, height_px)
	anchor.name = "Template %d" % (_document.scale_anchors.size() + 1)
	_history.create_action("Place IWE scale template")
	_history.add_do_method(_add_scale_anchor.bind(anchor))
	_history.add_undo_method(_remove_scale_anchor.bind(anchor.id))
	_history.commit_action()


func _add_scale_anchor(anchor: IWEScaleAnchor) -> void:
	if _document == null:
		return
	var found := false
	for existing in _document.scale_anchors:
		found = found or existing.id == anchor.id
	if not found:
		_document.scale_anchors.append(anchor)
	_selected_scale_anchor_id = anchor.id
	_canvas.set_scale_anchors(_document.scale_anchors, _document.default_template_height_px)
	_canvas.select_scale_anchor(anchor.id)
	_template_height_input.set_value_no_signal(anchor.apparent_height_px)
	_refresh_perspective_preview()
	_refresh_status()


func _remove_scale_anchor(anchor_id: String) -> void:
	if _document == null:
		return
	var remaining: Array[IWEScaleAnchor] = []
	for anchor in _document.scale_anchors:
		if anchor.id != anchor_id:
			remaining.append(anchor)
	_document.scale_anchors = remaining
	if _selected_scale_anchor_id == anchor_id:
		_selected_scale_anchor_id = ""
	_canvas.set_scale_anchors(_document.scale_anchors, _document.default_template_height_px)
	_canvas.select_scale_anchor(_selected_scale_anchor_id)
	_refresh_perspective_preview()
	_refresh_status()


func _select_scale_anchor(anchor_id: String) -> void:
	_selected_scale_anchor_id = anchor_id
	var anchor := _find_scale_anchor(anchor_id)
	_template_height_input.set_value_no_signal(anchor.apparent_height_px if anchor else _document.default_template_height_px)
	_delete_template_button.disabled = anchor == null
	_refresh_status()


func _find_scale_anchor(anchor_id: String) -> IWEScaleAnchor:
	if _document == null:
		return null
	for anchor in _document.scale_anchors:
		if anchor.id == anchor_id:
			return anchor
	return null


func _move_scale_anchor(anchor_id: String, before: Vector2, after: Vector2) -> void:
	var anchor := _find_scale_anchor(anchor_id)
	if anchor == null or before == after:
		return
	_history.create_action("Move IWE scale template")
	_history.add_do_method(_set_scale_anchor_position.bind(anchor_id, after))
	_history.add_undo_method(_set_scale_anchor_position.bind(anchor_id, before))
	_history.commit_action()


func _set_scale_anchor_position(anchor_id: String, value: Vector2) -> void:
	var anchor := _find_scale_anchor(anchor_id)
	if anchor:
		anchor.position = value
		_canvas.set_scale_anchors(_document.scale_anchors, _document.default_template_height_px)
		_canvas.select_scale_anchor(anchor_id)
		_refresh_perspective_preview()


func _set_selected_template_height(value: float) -> void:
	var anchor := _find_scale_anchor(_selected_scale_anchor_id)
	if anchor == null:
		if _document:
			_document.default_template_height_px = value
			_canvas.set_scale_anchors(_document.scale_anchors, value)
			_history.note_untracked_change()
		return
	if is_equal_approx(anchor.apparent_height_px, value):
		return
	var before := anchor.apparent_height_px
	_history.create_action("Resize IWE scale template")
	_history.add_do_method(_set_scale_anchor_height.bind(anchor.id, value))
	_history.add_undo_method(_set_scale_anchor_height.bind(anchor.id, before))
	_history.commit_action()


func _scale_anchor_height_by(anchor_id: String, factor: float) -> void:
	var anchor := _find_scale_anchor(anchor_id)
	if anchor:
		_template_height_input.value = clampf(anchor.apparent_height_px * factor, 1.0, 10000.0)


func _set_scale_anchor_height(anchor_id: String, value: float) -> void:
	var anchor := _find_scale_anchor(anchor_id)
	if anchor:
		anchor.apparent_height_px = clampf(value, 1.0, 10000.0)
		_canvas.set_scale_anchors(_document.scale_anchors, _document.default_template_height_px)
		_canvas.select_scale_anchor(anchor_id)
		_template_height_input.set_value_no_signal(anchor.apparent_height_px)
		_refresh_perspective_preview()


func _delete_selected_template() -> void:
	_delete_scale_anchor_by_id(_selected_scale_anchor_id)


func _delete_scale_anchor_by_id(anchor_id: String) -> void:
	var anchor := _find_scale_anchor(anchor_id)
	if anchor == null:
		return
	var saved := anchor.duplicate(true) as IWEScaleAnchor
	_history.create_action("Delete IWE scale template")
	_history.add_do_method(_remove_scale_anchor.bind(anchor.id))
	_history.add_undo_method(_add_scale_anchor.bind(saved))
	_history.commit_action()


func _set_template_mode(enabled: bool) -> void:
	if enabled:
		_set_perspective_mode(false)
		_stop_tools()
		_template_mode_button.set_pressed_no_signal(true)
	_canvas.set_scale_anchor_mode(enabled)
	_refresh_status()


func _create_perspective_anchor(image_position: Vector2) -> void:
	if _document == null:
		return
	_create_scale_anchor(image_position, _document.default_template_height_px)


func _create_subtraction(region_id: String, points: PackedVector2Array) -> void:
	var region := _find_region(region_id)
	if region == null or region.locked:
		return
	if Geometry2D.intersect_polygons(region.points, points).is_empty():
		push_warning("IWE: The subtraction polygon must overlap the selected region.")
		return
	var before: Array[PackedVector2Array] = region.subtraction_polygons.duplicate(true)
	var after: Array[PackedVector2Array] = before.duplicate()
	after.append(points.duplicate())
	var names_before := _get_cutout_names(region)
	var names_after := names_before.duplicate()
	names_after.append("Cutout %d" % (after.size()))
	_history.create_action("Subtract polygon from IWE region")
	_history.add_do_method(_set_region_cutouts.bind(region_id, {"polygons": after, "names": names_after}))
	_history.add_undo_method(_set_region_cutouts.bind(region_id, {"polygons": before, "names": names_before}))
	_history.commit_action()


func _set_region_cutouts(region_id: String, cutouts: Dictionary) -> void:
	var region := _find_region(region_id)
	if region == null:
		return
	region.subtraction_polygons = cutouts.polygons.duplicate(true)
	region.subtraction_names = cutouts.names.duplicate()
	_canvas.queue_redraw()
	_refresh_regions(region_id)


func _add_region(region: IWERegion) -> void:
	_document.add_region(region)
	_canvas.set_regions(_document.regions, region.id)
	_sync_selection(region.id)


func _remove_region(region_id: String) -> void:
	_document.remove_region(region_id)
	_canvas.remove_region(region_id)
	if _canvas.get_selected_region() == null:
		_select_button.set_pressed_no_signal(true)
		_sync_selection("")
	else:
		_refresh_regions()


func _select_region(region_id: String) -> void:
	_selected_cutout_region_id = ""
	_selected_cutout_index = -1
	var selected := _find_region(region_id)
	if selected != null and selected.group_id != _selected_group_id:
		_selected_group_id = selected.group_id
		_refresh_group_options()
	_canvas.select_region(region_id)
	_sync_selection(region_id)


func _region_changed(_region_id: String, _before: PackedVector2Array, _after: PackedVector2Array) -> void:
	_document.replace_region_points(_region_id, _after)
	_refresh_regions(_region_id)


func _delete_selected_region() -> void:
	if _points_button.button_pressed and _canvas.get_selected_vertex_index() >= 0:
		_canvas.remove_selected_vertex()
		return
	var region: IWERegion = _canvas.get_selected_region()
	if region == null:
		return
	var removed := region.duplicate(true) as IWERegion
	_history.create_action("Delete IWE region")
	_history.add_do_method(_remove_region.bind(region.id))
	_history.add_undo_method(_add_region.bind(removed))
	_history.commit_action()


func _duplicate_selected_region() -> void:
	var region: IWERegion = _canvas.get_selected_region()
	if region == null:
		return
	var copy := region.duplicate_region()
	for index in copy.points.size():
		copy.points[index] += Vector2(16.0, 16.0)
	_history.create_action("Duplicate IWE region")
	_history.add_do_method(_add_region.bind(copy))
	_history.add_undo_method(_remove_region.bind(copy.id))
	_history.commit_action()


func _region_item_selected() -> void:
	var metadata: Dictionary = _region_list.get_selected_metadata()
	if metadata.is_empty():
		return
	if metadata.kind == "group":
		_selected_cutout_region_id = ""
		_selected_cutout_index = -1
		_selected_group_id = metadata.id
		_group_option.select(_group_index(metadata.id))
		_stop_tools()
		_canvas.select_region("")
		_refresh_regions("")
		_sync_selection("")
		return
	var selected_region_id: String = metadata.id if metadata.kind == "region" else metadata.region_id
	_selected_group_id = metadata.group_id
	var group_index := _group_index(_selected_group_id)
	if group_index >= 0:
		_group_option.select(group_index)
	var selecting_cutout: bool = metadata.kind == "cutout"
	if not selecting_cutout:
		_selected_cutout_region_id = ""
		_selected_cutout_index = -1
	_stop_tools()
	_canvas.select_region(selected_region_id)
	if selecting_cutout:
		_selected_cutout_region_id = selected_region_id
		_selected_cutout_index = metadata.index
	_sync_selection(selected_region_id)


func _tree_item_activated(item: TreeItem) -> void:
	var metadata: Variant = item.get_metadata(0)
	if not metadata is Dictionary:
		return
	if metadata.get("kind", "") == "region":
		_select_region(metadata.id)
		_rename_selected_region()
	elif metadata.get("kind", "") == "cutout":
		_selected_cutout_region_id = metadata.region_id
		_selected_cutout_index = metadata.index
		_region_item_selected()
		_rename_selected_cutout()
	elif metadata.get("kind", "") == "group":
		_selected_group_id = metadata.id
		_region_item_selected()
		_rename_selected_group()


func _refresh_regions(selected_id: String = "", selected_cutout_index: int = -1) -> void:
	if not is_instance_valid(_document):
		return
	var selected := selected_id
	if selected_cutout_index >= 0:
		_selected_cutout_region_id = selected
		_selected_cutout_index = selected_cutout_index
	elif not selected.is_empty() and selected != _selected_cutout_region_id:
		_selected_cutout_region_id = ""
		_selected_cutout_index = -1
	if selected.is_empty():
		var current: IWERegion = _canvas.get_selected_region()
		if current:
			selected = current.id
	if selected == _selected_cutout_region_id:
		selected_cutout_index = _selected_cutout_index
	_region_list.refresh(_document.groups, _document.regions, _selected_group_id, selected, selected_cutout_index)
	_canvas.set_regions(_document.regions, selected)
	_update_workflow_controls()


func _set_draw_mode(enabled: bool) -> void:
	if _draw_button.button_pressed != enabled:
		_draw_button.set_pressed_no_signal(enabled)


func _sync_selection(region_id: String) -> void:
	_refresh_regions(region_id)
	_add_point_button.disabled = region_id.is_empty()
	_remove_point_button.disabled = region_id.is_empty()
	var selected_metadata: Dictionary = _region_list.get_selected_metadata()
	var selected_kind: String = selected_metadata.get("kind", "")
	_rename_group_button.disabled = selected_kind != "group"
	_rename_cutout_button.disabled = selected_kind != "cutout"
	_rename_button.disabled = selected_kind != "region"
	_delete_button.disabled = region_id.is_empty() or selected_kind == "cutout"
	_duplicate_button.disabled = region_id.is_empty() or selected_kind == "cutout"
	_visibility_button.disabled = region_id.is_empty() or selected_kind == "cutout"
	_sync_point_selection(_canvas.get_selected_vertex_index())
	_update_workflow_controls()
	_refresh_status()


func _set_polygon_mode(enabled: bool) -> void:
	if enabled:
		_set_perspective_mode(false)
		_template_mode_button.set_pressed_no_signal(false)
		_canvas.set_scale_anchor_mode(false)
	if enabled and not _can_create_region():
		_draw_button.button_pressed = false
		enabled = false
	if enabled:
		_subtract_button.set_pressed_no_signal(false)
		_select_button.set_pressed_no_signal(false)
		_points_button.set_pressed_no_signal(false)
		_add_point_button.set_pressed_no_signal(false)
		_canvas.set_vertex_editing(false)
	_canvas.set_drawing(enabled)
	_refresh_status()


func _set_select_mode(enabled: bool) -> void:
	if enabled:
		_set_perspective_mode(false)
		_template_mode_button.set_pressed_no_signal(false)
		_canvas.set_scale_anchor_mode(false)
		_subtract_button.set_pressed_no_signal(false)
		_draw_button.set_pressed_no_signal(false)
		_points_button.set_pressed_no_signal(false)
		_add_point_button.set_pressed_no_signal(false)
		_canvas.set_vertex_editing(false)
	_canvas.set_drawing(false)
	_refresh_status()


func _set_points_mode(enabled: bool) -> void:
	if enabled:
		_set_perspective_mode(false)
		_template_mode_button.set_pressed_no_signal(false)
		_canvas.set_scale_anchor_mode(false)
		_subtract_button.set_pressed_no_signal(false)
		_draw_button.set_pressed_no_signal(false)
		_select_button.set_pressed_no_signal(false)
		_add_point_button.set_pressed_no_signal(false)
		_canvas.set_drawing(false)
	_canvas.set_vertex_editing(enabled)
	_refresh_status()


func _set_subtract_mode(enabled: bool) -> void:
	if enabled:
		_set_perspective_mode(false)
		_template_mode_button.set_pressed_no_signal(false)
		_canvas.set_scale_anchor_mode(false)
		_draw_button.set_pressed_no_signal(false)
		_select_button.set_pressed_no_signal(false)
		_points_button.set_pressed_no_signal(false)
		_add_point_button.set_pressed_no_signal(false)
		_canvas.set_drawing(false)
		_canvas.set_vertex_editing(false)
		var region: IWERegion = _canvas.get_selected_region()
		if region == null or region.locked or not _has_illustration or _selected_group_id.is_empty():
			_subtract_button.button_pressed = false
			_refresh_status()
			return
	_canvas.set_boolean_subtract_mode(enabled)
	_refresh_status()


func _rename_region_at_index(index: int) -> void:
	var metadata: Dictionary = _region_list.get_selected_metadata()
	if metadata.get("kind", "") != "region":
		return
	_select_region(metadata.id)
	_rename_selected_region()


func _rename_selected_region() -> void:
	var region: IWERegion = _canvas.get_selected_region()
	if region == null:
		return
	_show_name_dialog("Rename region", "Enter a new region name", region.name, func(value: String) -> void:
		_rename_region(region.id, value)
	)


func _rename_selected_group() -> void:
	var group := _find_group(_selected_group_id)
	if group == null:
		return
	_show_name_dialog("Rename group", "Enter a new group name", group.name, func(value: String) -> void:
		_rename_group(group.id, value)
	)


func _rename_selected_cutout() -> void:
	var region := _find_region(_selected_cutout_region_id)
	if region == null or _selected_cutout_index < 0 or _selected_cutout_index >= region.subtraction_polygons.size():
		return
	var names := _get_cutout_names(region)
	var cutout_index := _selected_cutout_index
	_show_name_dialog("Rename cutout", "Enter a name for this cutout", names[cutout_index], func(value: String) -> void:
		_rename_cutout(region.id, cutout_index, value)
	)


func _get_cutout_names(region: IWERegion) -> PackedStringArray:
	var names := region.subtraction_names.duplicate()
	while names.size() < region.subtraction_polygons.size():
		names.append("Cutout %d" % (names.size() + 1))
	return names


func _rename_cutout(region_id: String, cutout_index: int, new_name: String) -> void:
	var region := _find_region(region_id)
	if region == null or cutout_index < 0 or cutout_index >= region.subtraction_polygons.size():
		return
	var names := _get_cutout_names(region)
	if names[cutout_index] == new_name:
		return
	var previous_name := names[cutout_index]
	_history.create_action("Rename IWE cutout")
	_history.add_do_method(_set_cutout_name.bind(region_id, {"index": cutout_index, "name": new_name}))
	_history.add_undo_method(_set_cutout_name.bind(region_id, {"index": cutout_index, "name": previous_name}))
	_history.commit_action()


func _set_cutout_name(region_id: String, cutout: Dictionary) -> void:
	var region := _find_region(region_id)
	var cutout_index: int = cutout.index
	if region == null or cutout_index < 0 or cutout_index >= region.subtraction_polygons.size():
		return
	region.subtraction_names = _get_cutout_names(region)
	region.subtraction_names[cutout_index] = cutout.name
	_refresh_regions(region_id, cutout_index)


func _show_name_dialog(title: String, prompt: String, initial_name: String, on_confirm: Callable) -> void:
	if is_instance_valid(_active_name_dialog):
		_active_name_dialog.queue_free()
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = prompt
	var input := LineEdit.new()
	input.name = "NameInput"
	input.text = initial_name
	dialog.add_child(input)
	_active_name_dialog = dialog
	_active_name_input = input
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var new_name := input.text.strip_edges()
		if new_name.is_empty():
			input.placeholder_text = "Name cannot be empty"
			input.grab_focus()
			return
		on_confirm.call(new_name)
		_active_name_dialog = null
		_active_name_input = null
		dialog.queue_free()
	)
	dialog.close_requested.connect(func() -> void:
		_active_name_dialog = null
		_active_name_input = null
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(360, 140))
	input.grab_focus()
	input.select_all()


func _toggle_selected_visibility() -> void:
	var region: IWERegion = _canvas.get_selected_region()
	if region == null:
		return
	_set_region_visibility(region.id, not region.visible, true)


func _rename_region(region_id: String, new_name: String) -> void:
	var region := _find_region(region_id)
	if region == null or region.name == new_name:
		return
	var previous_name := region.name
	_history.create_action("Rename IWE region")
	_history.add_do_method(_set_region_name.bind(region_id, new_name))
	_history.add_undo_method(_set_region_name.bind(region_id, previous_name))
	_history.commit_action()


func _set_region_name(region_id: String, value: String) -> void:
	var region := _find_region(region_id)
	if region:
		region.name = value
		_refresh_regions(region_id)


func _rename_group(group_id: String, new_name: String) -> void:
	var group := _find_group(group_id)
	if group == null or group.name == new_name:
		return
	var previous_name := group.name
	_history.create_action("Rename IWE group")
	_history.add_do_method(_set_group_name.bind(group_id, new_name))
	_history.add_undo_method(_set_group_name.bind(group_id, previous_name))
	_history.commit_action()


func _set_group_name(group_id: String, value: String) -> void:
	var group := _find_group(group_id)
	if group:
		group.name = value
		_refresh_group_options()
		_refresh_regions()
		_refresh_status()


func _set_region_visibility(region_id: String, value: bool, create_action: bool = false) -> void:
	var region := _find_region(region_id)
	if region == null or region.visible == value:
		return
	if create_action:
		_history.create_action("Toggle IWE region visibility")
		_history.add_do_method(_set_region_visibility.bind(region_id, value))
		_history.add_undo_method(_set_region_visibility.bind(region_id, region.visible))
		_history.commit_action()
		return
	region.visible = value
	_visibility_button.text = "Show region" if not value else "Hide region"
	_canvas.queue_redraw()
	_refresh_status()


func _find_region(region_id: String) -> IWERegion:
	if _document == null:
		return null
	for region in _document.regions:
		if region.id == region_id:
			return region
	return null


func _resolve_document_asset_path(asset_path: String, document_path: String) -> String:
	if asset_path.begins_with("res://") or asset_path.begins_with("user://"):
		return asset_path
	if asset_path.is_absolute_path():
		return ProjectSettings.localize_path(asset_path)
	var resolved := document_path.get_base_dir().path_join(asset_path)
	return ProjectSettings.localize_path(resolved) if resolved.is_absolute_path() else resolved


func _load_external_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://") or path.begins_with("user://"):
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		# A picture that a save just copied is not an imported resource yet (the editor imports
		# it on its next scan, and never in a plain folder), so read the file itself.
		path = ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(path)
	if image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _set_add_vertex_mode(enabled: bool) -> void:
	if enabled:
		_set_perspective_mode(false)
		_template_mode_button.set_pressed_no_signal(false)
		_canvas.set_scale_anchor_mode(false)
		_draw_button.set_pressed_no_signal(false)
		_select_button.set_pressed_no_signal(false)
		_points_button.set_pressed_no_signal(false)
		_canvas.set_drawing(false)
		_canvas.set_vertex_editing(false)
	_canvas.set_add_vertex_mode(enabled)
	_refresh_status()


func _sync_add_vertex_mode(enabled: bool) -> void:
	_add_point_button.set_pressed_no_signal(enabled)
	if enabled:
		_points_button.set_pressed_no_signal(false)
		_draw_button.set_pressed_no_signal(false)
		_select_button.set_pressed_no_signal(false)
	_refresh_status()


func _sync_points_mode(enabled: bool) -> void:
	_points_button.set_pressed_no_signal(enabled)
	if enabled:
		_add_point_button.set_pressed_no_signal(false)
		_draw_button.set_pressed_no_signal(false)
		_select_button.set_pressed_no_signal(false)
	_sync_point_selection(_canvas.get_selected_vertex_index())
	_refresh_status()


func _refresh_status() -> void:
	if _perspective_mode:
		_status_label.text = "Perspective calibration  •  Click the preview to place a height reference; adjust FOV, camera and floor controls."
		if _document != null and _document.perspective_calibration != null:
			var reference: Vector2i = _document.perspective_calibration.reference_viewport_size
			var game_window := CALIBRATION_SCRIPT.project_viewport_size()
			if not CALIBRATION_SCRIPT.aspects_match(reference, game_window):
				_status_label.text += "  •  Reference frame %d×%d differs in shape from the game window %d×%d" % [reference.x, reference.y, game_window.x, game_window.y]
		return
	var mode := "Select"
	if _template_mode_button.button_pressed:
		mode = "Scale template"
	elif _draw_button.button_pressed:
		mode = "Polygon"
	elif _points_button.button_pressed:
		mode = "Points"
	elif _subtract_button.button_pressed:
		mode = "Boolean −"
	elif _add_point_button.button_pressed:
		mode = "Add point"
	var region: IWERegion = _canvas.get_selected_region()
	if region:
		var point_status := ""
		if _canvas.has_method("get_selected_vertex_index") and _canvas.get_selected_vertex_index() >= 0:
			point_status = "  •  point %d selected" % (_canvas.get_selected_vertex_index() + 1)
		var subtract_status := "  •  %d cutouts" % region.subtraction_polygons.size()
		var hint := ""
		if _add_point_button.button_pressed:
			hint = "  •  click the highlighted edge to insert a point"
		elif _points_button.button_pressed:
			hint = "  •  click and drag a point; Delete removes that point"
		elif _select_button.button_pressed:
			hint = "  •  drag inside to move the region"
		_status_label.text = "%s  •  %s  •  %d points%s%s%s" % [mode, region.name, region.points.size(), subtract_status, point_status, hint]
	else:
		if not _has_illustration:
			_status_label.text = "Import an illustration to begin"
		elif _selected_group_id.is_empty():
			_status_label.text = "Create a group before drawing polygons"
		else:
			if _template_mode_button.button_pressed:
				var anchor := _find_scale_anchor(_selected_scale_anchor_id)
				_status_label.text = "Scale template  •  Click to place; drag to move; scroll to resize%s" % ("  •  %s, %d px" % [anchor.name, roundi(anchor.apparent_height_px)] if anchor else "")
			else:
				_status_label.text = "%s  •  Select a region or start a polygon" % mode


func _can_create_region() -> bool:
	return _has_illustration and _document != null and not _selected_group_id.is_empty() and _find_group(_selected_group_id) != null


func _create_group() -> void:
	if not _has_illustration:
		return
	var suggested_name := "Group %d" % (_document.groups.size() + 1)
	_show_name_dialog("Create group", "Enter a name for this group", suggested_name, _create_group_named)


func _create_group_named(group_name: String) -> void:
	if not _has_illustration or _document == null:
		return
	var group: IWERegionGroup = GROUP_SCRIPT.create_group(group_name)
	_history.create_action("Create IWE group")
	_history.add_do_method(_add_group.bind(group))
	_history.add_undo_method(_remove_group.bind(group.id))
	_history.commit_action()


func _add_group(group: IWERegionGroup) -> void:
	_stop_tools()
	_document.add_group(group)
	_selected_group_id = group.id
	_refresh_group_options()
	_canvas.select_region("")
	_sync_selection("")
	_refresh_status()


func _remove_group(group_id: String) -> void:
	_stop_tools()
	_document.remove_group(group_id)
	if _selected_group_id == group_id:
		_selected_group_id = _document.groups[0].id if not _document.groups.is_empty() else ""
	_refresh_group_options()
	_refresh_regions()
	_refresh_status()


func _group_selected(index: int) -> void:
	if index < 0 or index >= _document.groups.size():
		return
	_selected_group_id = _document.groups[index].id
	_stop_tools()
	_canvas.select_region("")
	_select_button.button_pressed = true
	_draw_button.button_pressed = false
	_subtract_button.button_pressed = false
	_points_button.button_pressed = false
	_canvas.set_drawing(false)
	_refresh_regions()
	_refresh_status()


func _refresh_group_options() -> void:
	if not is_node_ready():
		return
	_group_option.clear()
	var selected_index := -1
	if _document == null:
		_create_group_button.disabled = true
		_group_option.disabled = true
		return
	for index in _document.groups.size():
		var group: IWERegionGroup = _document.groups[index]
		_group_option.add_item(group.name)
		_group_option.set_item_metadata(index, group.id)
		if group.id == _selected_group_id:
			selected_index = index
	if selected_index >= 0:
		_group_option.select(selected_index)
	_create_group_button.disabled = not _has_illustration
	_group_option.disabled = not _has_illustration or _document.groups.is_empty()


func _find_group(group_id: String) -> IWERegionGroup:
	if _document == null:
		return null
	for group in _document.groups:
		if group.id == group_id:
			return group
	return null


func _migrate_document_groups() -> void:
	if _document.groups.is_empty() and not _document.regions.is_empty():
		var legacy_group: IWERegionGroup = GROUP_SCRIPT.create_group("Imported regions")
		_document.groups.append(legacy_group)
		for region in _document.regions:
			region.group_id = legacy_group.id
	elif not _document.groups.is_empty():
		for region in _document.regions:
			if _find_group(region.group_id) == null:
				region.group_id = _document.groups[0].id
	_selected_group_id = _document.groups[0].id if not _document.groups.is_empty() else ""


func _update_workflow_controls() -> void:
	if not is_node_ready() or _document == null:
		return
	var has_selected_region: bool = _canvas.get_selected_region() != null
	var can_draw := _can_create_region()
	_draw_button.disabled = not can_draw
	_subtract_button.disabled = not can_draw or not has_selected_region
	_select_button.disabled = not _has_illustration
	_points_button.disabled = not _has_illustration or not has_selected_region
	_add_point_button.disabled = not _has_illustration or not has_selected_region
	_create_group_button.disabled = not _has_illustration
	_group_option.disabled = not _has_illustration or _document.groups.is_empty()
	_export_2d_button.disabled = not _has_illustration
	_export_3d_button.disabled = not _has_illustration
	_template_mode_button.disabled = not _has_illustration
	_template_height_input.editable = _has_illustration
	_delete_template_button.disabled = _find_scale_anchor(_selected_scale_anchor_id) == null
	_perspective_button.disabled = not _has_illustration
	_export_perspective_button.disabled = not _has_illustration
	_camera_fov_input.editable = _has_illustration
	_floor_height_input.editable = _has_illustration
	_character_height_input.editable = _has_illustration
	_camera_position_x_input.editable = _has_illustration
	_camera_position_y_input.editable = _has_illustration
	_camera_position_z_input.editable = _has_illustration
	_camera_rotation_x_input.editable = _has_illustration
	_camera_rotation_y_input.editable = _has_illustration
	_camera_rotation_z_input.editable = _has_illustration
	_draw_button.disabled = not _has_illustration or not _can_create_region() or _perspective_mode
	_subtract_button.disabled = not _has_illustration or not _can_create_region() or _canvas.get_selected_region() == null or _perspective_mode
	_select_button.disabled = not _has_illustration or _perspective_mode
	_points_button.disabled = not _has_illustration or _canvas.get_selected_region() == null or _perspective_mode
	_add_point_button.disabled = not _has_illustration or _canvas.get_selected_region() == null or _perspective_mode
	_template_mode_button.disabled = not _has_illustration or _perspective_mode


func _stop_tools() -> void:
	if not is_node_ready():
		return
	_draw_button.set_pressed_no_signal(false)
	_subtract_button.set_pressed_no_signal(false)
	_points_button.set_pressed_no_signal(false)
	_add_point_button.set_pressed_no_signal(false)
	_template_mode_button.set_pressed_no_signal(false)
	_select_button.set_pressed_no_signal(true)
	_canvas.set_drawing(false)
	_canvas.set_vertex_editing(false)
	_canvas.set_boolean_subtract_mode(false)
	_canvas.set_scale_anchor_mode(false)


func _sync_point_selection(index: int) -> void:
	var region: IWERegion = _canvas.get_selected_region()
	_remove_point_button.disabled = region == null or not _points_button.button_pressed or index < 0 or region.locked or region.points.size() <= 3
	_delete_button.text = "Delete point" if index >= 0 and _points_button.button_pressed else "Delete region"
	_delete_button.tooltip_text = "Remove only the selected vertex" if index >= 0 and _points_button.button_pressed else "Remove the selected region and its cutouts"
	_delete_button.disabled = region == null or (index >= 0 and _points_button.button_pressed and (region.locked or region.points.size() <= 3))
	_refresh_status()


func _group_index(group_id: String) -> int:
	if _document == null:
		return -1
	for index in _document.groups.size():
		if _document.groups[index].id == group_id:
			return index
	return -1


func _is_asset_beside_document(asset_path: String) -> bool:
	if _document.document_path.is_empty():
		return false
	if not _document.illustration_path.begins_with("assets/"):
		return false
	var expected_path: String = _document.document_path.get_base_dir().path_join(_document.illustration_path)
	if expected_path.begins_with("res://") or expected_path.begins_with("user://"):
		expected_path = ProjectSettings.globalize_path(expected_path)
	var image_absolute := asset_path
	if image_absolute.begins_with("res://") or image_absolute.begins_with("user://"):
		image_absolute = ProjectSettings.globalize_path(image_absolute)
	return image_absolute.replace("/", "\\").to_lower() == expected_path.replace("/", "\\").to_lower()

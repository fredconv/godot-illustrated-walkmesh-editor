@tool
extends VBoxContainer

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")

@onready var _import_button: Button = %ImportButton
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
@onready var _region_list: ItemList = %RegionList
@onready var _file_dialog: FileDialog = $ImageFileDialog
@onready var _save_dialog: FileDialog = %DocumentFileDialog
@onready var _open_dialog: FileDialog = $OpenDocumentDialog
@onready var _image_copy_dialog: FileDialog = %ImageCopyDialog
@onready var _status_label: Label = %StatusLabel
@onready var _canvas: Control = $ImageScroll/Canvas

var _zoom := 1.0
var _document: Resource
var _undo_redo: EditorUndoRedoManager
var _undo_context: Node
var _pending_document_path := ""
var _pending_image_source := ""


func set_document(document: Resource, undo_redo: EditorUndoRedoManager, undo_context: Node) -> void:
	_document = document
	_undo_redo = undo_redo
	_undo_context = undo_context
	if is_node_ready():
		_canvas.set_undo_context(_undo_context)
		_canvas.set_document(_document)


func _ready() -> void:
	_import_button.pressed.connect(_file_dialog.popup_centered)
	_file_dialog.file_selected.connect(_load_illustration)
	_zoom_out_button.pressed.connect(_change_zoom.bind(1.0 / 1.2))
	_zoom_in_button.pressed.connect(_change_zoom.bind(1.2))
	_canvas.zoom_requested.connect(_change_zoom)
	_canvas.set_undo_redo(_undo_redo)
	_canvas.region_created.connect(_create_region)
	_canvas.subtraction_created.connect(_create_subtraction)
	_canvas.region_selected.connect(_select_region)
	_canvas.region_changed.connect(_region_changed)
	_canvas.add_vertex_requested.connect(_canvas.add_selected_vertex)
	_canvas.add_vertex_mode_changed.connect(_set_add_vertex_mode)
	_canvas.point_selected.connect(_sync_point_selection)
	_new_button.pressed.connect(_new_document)
	_save_button.pressed.connect(_save_dialog.popup_centered)
	_save_dialog.file_selected.connect(_save_document)
	_open_button.pressed.connect(_open_dialog.popup_centered)
	_open_dialog.file_selected.connect(_open_document)
	_image_copy_dialog.dir_selected.connect(_copy_image_into_document)
	_draw_button.toggled.connect(_set_polygon_mode)
	_subtract_button.toggled.connect(_set_subtract_mode)
	_select_button.toggled.connect(_set_select_mode)
	_points_button.toggled.connect(_set_points_mode)
	_add_point_button.toggled.connect(_set_add_vertex_mode)
	_remove_point_button.pressed.connect(_canvas.remove_selected_vertex)
	_visibility_button.pressed.connect(_toggle_selected_visibility)
	_canvas.draw_mode_changed.connect(_set_draw_mode)
	_canvas.selection_changed.connect(_sync_selection)
	_undo_button.pressed.connect(_undo)
	_redo_button.pressed.connect(_redo)
	_delete_button.pressed.connect(_delete_selected_region)
	_duplicate_button.pressed.connect(_duplicate_selected_region)
	_region_list.item_selected.connect(_region_item_selected)
	_region_list.item_activated.connect(_rename_region_at_index)
	_rename_button.pressed.connect(_rename_selected_region)
	_canvas.set_undo_context(_undo_context)
	_canvas.set_undo_redo(_undo_redo)
	_canvas.set_document(_document)
	_sync_selection("")


func _load_illustration(path: String) -> void:
	var image := Image.load_from_file(path)
	if image.is_empty():
		push_error("IWE: Could not load illustration at %s" % path)
		return
	var texture := ImageTexture.create_from_image(image)
	_canvas.set_texture(texture)
	_document.set_illustration(path, image.get_size())
	_pending_image_source = path
	_refresh_regions()


func _change_zoom(factor: float) -> void:
	_zoom = clampf(_zoom * factor, 0.1, 8.0)
	_canvas.set_zoom(_zoom)
	_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)


func get_document() -> Resource:
	return _document


func _undo() -> void:
	_undo_redo.undo(_undo_context)


func _redo() -> void:
	_undo_redo.redo(_undo_context)


func _new_document() -> void:
	var previous := _document
	var replacement: Resource = DOCUMENT_SCRIPT.new()
	_undo_redo.create_action("Create IWE document", UndoRedo.MERGE_DISABLE, _undo_context)
	_undo_redo.add_do_method(self, "_replace_document", replacement)
	_undo_redo.add_undo_method(self, "_replace_document", previous)
	_undo_redo.commit_action()


func _replace_document(document: Resource) -> void:
	_document = document
	_canvas.set_document(_document)
	_pending_image_source = ""
	if not _document.illustration_path.is_empty() and not _document.document_path.is_empty():
		_pending_image_source = _resolve_document_asset_path(_document.illustration_path, _document.document_path)
	var texture := _load_external_texture(_pending_image_source)
	if texture:
		_canvas.set_texture(texture)
	else:
		_canvas.set_texture(null)
	_canvas.set_regions(_document.regions)
	_region_list.clear()


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
	_write_document()


func _write_document() -> void:
	_document.document_path = _pending_document_path
	var error := ResourceSaver.save(_document, _pending_document_path)
	if error != OK:
		push_error("IWE: Could not save document (%s)" % error_string(error))


func _open_document(path: String) -> void:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	if loaded == null or not loaded is DOCUMENT_SCRIPT:
		push_error("IWE: Could not load an IWE document at %s" % path)
		return
	_document = loaded
	_document.document_path = path
	_canvas.set_document(_document)
	var image_path := _resolve_document_asset_path(_document.illustration_path, path)
	if not image_path.is_empty():
		var texture := _load_external_texture(image_path)
		if texture:
			_canvas.set_texture(texture)
			_pending_image_source = image_path
		else:
			_canvas.set_texture(null)
			push_warning("IWE: Illustration could not be loaded from %s" % image_path)
	else:
		_canvas.set_texture(null)
	_refresh_regions()


func _create_region(points: PackedVector2Array) -> void:
	var region: IWERegion = REGION_SCRIPT.new()
	region.id = REGION_SCRIPT._new_id()
	region.name = "Region %d" % (_document.regions.size() + 1)
	region.points = points
	_undo_redo.create_action("Create IWE region", UndoRedo.MERGE_DISABLE, _undo_context)
	_undo_redo.add_do_method(self, "_add_region", region)
	_undo_redo.add_undo_method(self, "_remove_region", region.id)
	_undo_redo.commit_action()


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
	_undo_redo.create_action("Subtract polygon from IWE region", UndoRedo.MERGE_DISABLE, _undo_context)
	_undo_redo.add_do_method(self, "_set_region_subtractions", region_id, after)
	_undo_redo.add_undo_method(self, "_set_region_subtractions", region_id, before)
	_undo_redo.commit_action()


func _set_region_subtractions(region_id: String, polygons: Array[PackedVector2Array]) -> void:
	var region := _find_region(region_id)
	if region == null:
		return
	region.subtraction_polygons = polygons.duplicate(true)
	_canvas.queue_redraw()
	_refresh_regions(region_id)


func _add_region(region: IWERegion) -> void:
	_document.add_region(region)
	_canvas.set_regions(_document.regions, region.id)
	_refresh_regions(region.id)


func _remove_region(region_id: String) -> void:
	_document.remove_region(region_id)
	_canvas.remove_region(region_id)
	_refresh_regions()


func _select_region(region_id: String) -> void:
	_canvas.select_region(region_id)
	_refresh_regions(region_id)


func _region_changed(_region_id: String, _before: PackedVector2Array, _after: PackedVector2Array) -> void:
	_document.replace_region_points(_region_id, _after)
	_refresh_regions(_region_id)


func _delete_selected_region() -> void:
	var region: IWERegion = _canvas.get_selected_region()
	if region == null:
		return
	var removed := region.duplicate(true) as IWERegion
	_undo_redo.create_action("Delete IWE region", UndoRedo.MERGE_DISABLE, _undo_context)
	_undo_redo.add_do_method(self, "_remove_region", region.id)
	_undo_redo.add_undo_method(self, "_add_region", removed)
	_undo_redo.commit_action()


func _duplicate_selected_region() -> void:
	var region: IWERegion = _canvas.get_selected_region()
	if region == null:
		return
	var copy := region.duplicate_region()
	for index in copy.points.size():
		copy.points[index] += Vector2(16.0, 16.0)
	_undo_redo.create_action("Duplicate IWE region", UndoRedo.MERGE_DISABLE, _undo_context)
	_undo_redo.add_do_method(self, "_add_region", copy)
	_undo_redo.add_undo_method(self, "_remove_region", copy.id)
	_undo_redo.commit_action()


func _region_item_selected(index: int) -> void:
	var region_id: String = _region_list.get_region_id(index)
	_select_region(region_id)
	_select_button.button_pressed = true
	_canvas.set_drawing(false)
	_canvas.set_vertex_editing(false)
	_draw_button.button_pressed = false
	_points_button.button_pressed = false


func _refresh_regions(selected_id: String = "") -> void:
	if not is_instance_valid(_document):
		return
	var selected := selected_id
	if selected.is_empty():
		var current: IWERegion = _canvas.get_selected_region()
		if current:
			selected = current.id
	_region_list.refresh(_document.regions, selected)
	_canvas.set_regions(_document.regions, selected)


func _set_draw_mode(enabled: bool) -> void:
	if _draw_button.button_pressed != enabled:
		_draw_button.button_pressed = enabled


func _sync_selection(region_id: String) -> void:
	_refresh_regions(region_id)
	_add_point_button.disabled = region_id.is_empty()
	_remove_point_button.disabled = region_id.is_empty()
	_delete_button.disabled = region_id.is_empty()
	_duplicate_button.disabled = region_id.is_empty()
	_rename_button.disabled = region_id.is_empty()
	_visibility_button.disabled = region_id.is_empty()
	_sync_point_selection(-1)
	_refresh_status()
	if not region_id.is_empty():
		_select_button.button_pressed = true
		_draw_button.button_pressed = false
	_refresh_status()


func _set_polygon_mode(enabled: bool) -> void:
	if enabled:
		_subtract_button.button_pressed = false
		_select_button.button_pressed = false
		_points_button.button_pressed = false
		_canvas.set_vertex_editing(false)
	_canvas.set_drawing(enabled)
	_refresh_status()


func _set_select_mode(enabled: bool) -> void:
	if enabled:
		_subtract_button.button_pressed = false
		_draw_button.button_pressed = false
		_points_button.button_pressed = false
		_canvas.set_vertex_editing(false)
	_canvas.set_drawing(false)
	_refresh_status()


func _set_points_mode(enabled: bool) -> void:
	if enabled:
		_subtract_button.button_pressed = false
		_draw_button.button_pressed = false
		_select_button.button_pressed = false
		_add_point_button.button_pressed = false
		_canvas.set_drawing(false)
	_canvas.set_vertex_editing(enabled)
	_refresh_status()


func _set_subtract_mode(enabled: bool) -> void:
	if enabled:
		_draw_button.button_pressed = false
		_select_button.button_pressed = false
		_points_button.button_pressed = false
		_add_point_button.button_pressed = false
		_canvas.set_drawing(false)
		_canvas.set_vertex_editing(false)
		var region: IWERegion = _canvas.get_selected_region()
		if region == null or region.locked:
			_subtract_button.button_pressed = false
			_refresh_status()
			return
	_canvas.set_boolean_subtract_mode(enabled)
	_refresh_status()


func _rename_region_at_index(index: int) -> void:
	_select_region(_region_list.get_region_id(index))
	_rename_selected_region()


func _rename_selected_region() -> void:
	var region: IWERegion = _canvas.get_selected_region()
	if region == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Rename region"
	dialog.dialog_text = "Enter a new region name"
	var input := LineEdit.new()
	input.text = region.name
	dialog.add_child(input)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var new_name := input.text.strip_edges()
		if new_name.is_empty():
			new_name = "Region"
		_rename_region(region.id, new_name)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
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
	_undo_redo.create_action("Rename IWE region", UndoRedo.MERGE_DISABLE, _undo_context)
	_undo_redo.add_do_method(self, "_set_region_name", region_id, new_name)
	_undo_redo.add_undo_method(self, "_set_region_name", region_id, previous_name)
	_undo_redo.commit_action()


func _set_region_name(region_id: String, value: String) -> void:
	var region := _find_region(region_id)
	if region:
		region.name = value
		_refresh_regions(region_id)


func _set_region_visibility(region_id: String, value: bool, create_action: bool = false) -> void:
	var region := _find_region(region_id)
	if region == null or region.visible == value:
		return
	if create_action:
		_undo_redo.create_action("Toggle IWE region visibility", UndoRedo.MERGE_DISABLE, _undo_context)
		_undo_redo.add_do_method(self, "_set_region_visibility", region_id, value)
		_undo_redo.add_undo_method(self, "_set_region_visibility", region_id, region.visible)
		_undo_redo.commit_action()
		return
	region.visible = value
	_visibility_button.text = "Show region" if not value else "Hide region"
	_canvas.queue_redraw()
	_refresh_status()


func _find_region(region_id: String) -> IWERegion:
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
		return load(path) as Texture2D
	var image := Image.load_from_file(path)
	if image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _set_add_vertex_mode(enabled: bool) -> void:
	if enabled:
		_draw_button.button_pressed = false
		_select_button.button_pressed = false
		_points_button.button_pressed = false
		_canvas.set_drawing(false)
		_canvas.set_vertex_editing(false)
	_canvas.set_add_vertex_mode(enabled)
	_refresh_status()


func _refresh_status() -> void:
	var mode := "Select"
	if _draw_button.button_pressed:
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
		_status_label.text = "%s  •  %s  •  %d points%s%s" % [mode, region.name, region.points.size(), subtract_status, point_status]
	else:
		_status_label.text = "%s  •  Select a region or start a polygon" % mode


func _sync_point_selection(index: int) -> void:
	var region: IWERegion = _canvas.get_selected_region()
	_remove_point_button.disabled = region == null or index < 0 or region.points.size() <= 3
	_refresh_status()


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

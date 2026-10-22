@tool
extends Control

signal zoom_requested(factor: float)
signal region_created(points: PackedVector2Array)
signal region_selected(region_id: String)
signal region_changed(region_id: String, before: PackedVector2Array, after: PackedVector2Array)
signal selection_changed(region_id: String)
signal draw_mode_changed(enabled: bool)
signal vertex_mode_changed(enabled: bool)
signal add_vertex_requested(image_position: Vector2)
signal add_vertex_mode_changed(enabled: bool)
signal point_selected(index: int)

var _texture: Texture2D
var _zoom := 1.0
var _dragging := false
var _drawing := false
var _vertex_editing := false
var _add_vertex_mode := false
var _regions: Array[IWERegion] = []
var _selected_id := ""
var _selected_vertex := -1
var _draft := PackedVector2Array()
var _undo_redo: Object
var _undo_context: Node
var _document: IWEDocument
var _vertex_before := PackedVector2Array()
var _vertex_dragged := false
const HANDLE_RADIUS := 9.0
const CLOSE_RADIUS := 12.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL


func set_undo_redo(undo_redo: Object) -> void:
	_undo_redo = undo_redo


func set_undo_context(undo_context: Node) -> void:
	_undo_context = undo_context


func set_document(document: IWEDocument) -> void:
	_document = document


func set_regions(regions: Array[IWERegion], selected_id: String = "") -> void:
	if _selected_id != selected_id:
		_selected_vertex = -1
	_regions = regions
	_selected_id = selected_id
	queue_redraw()


func set_drawing(enabled: bool) -> void:
	_drawing = enabled
	_vertex_editing = false
	_add_vertex_mode = false
	_draft.clear()
	draw_mode_changed.emit(enabled)
	vertex_mode_changed.emit(false)
	queue_redraw()


func set_vertex_editing(enabled: bool) -> void:
	_vertex_editing = enabled
	_drawing = false
	_add_vertex_mode = false
	_draft.clear()
	draw_mode_changed.emit(false)
	vertex_mode_changed.emit(enabled)
	queue_redraw()


func set_add_vertex_mode(enabled: bool) -> void:
	_add_vertex_mode = enabled
	_drawing = false
	_vertex_editing = false
	_draft.clear()
	draw_mode_changed.emit(false)
	vertex_mode_changed.emit(false)
	add_vertex_mode_changed.emit(enabled)
	queue_redraw()


func set_texture(texture: Texture2D) -> void:
	_texture = texture
	_update_minimum_size()
	queue_redraw()


func set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.1, 8.0)
	_update_minimum_size()
	queue_redraw()


func _update_minimum_size() -> void:
	if _texture:
		custom_minimum_size = Vector2(_texture.get_size()) * _zoom
	else:
		custom_minimum_size = Vector2(320.0, 240.0)
	update_minimum_size()


func _draw() -> void:
	if _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(_texture.get_size()) * _zoom), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("252a33"), true)
		draw_string(ThemeDB.fallback_font, Vector2(16, 32), "Import an illustration to begin", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c5ccd8"))
	for region in _regions:
		if not region.visible or region.points.size() < 3:
			continue
		var display_points := PackedVector2Array()
		for point in region.points:
			display_points.append(point * _zoom)
		var fill := region.color
		fill.a = 0.28
		draw_colored_polygon(display_points, fill)
		for index in display_points.size():
			draw_line(display_points[index], display_points[(index + 1) % display_points.size()], region.color, 2.0, true)
			if region.id == _selected_id and _vertex_editing:
				draw_circle(display_points[index], HANDLE_RADIUS, Color.WHITE)
				draw_circle(display_points[index], 4.0, region.color)
			elif region.id == _selected_id and index == _selected_vertex:
				draw_circle(display_points[index], HANDLE_RADIUS, Color.WHITE)
				draw_circle(display_points[index], 4.0, Color("ffbd4a"))
	if _draft.size() > 0:
		for index in range(1, _draft.size()):
			draw_line(_draft[index - 1] * _zoom, _draft[index] * _zoom, Color("f6cb55"), 2.0, true)
		for point in _draft:
			draw_circle(point * _zoom, 4.0, Color("f6cb55"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var scroll := get_parent() as ScrollContainer
		if scroll:
			scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal - roundi(event.relative.x))
			scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - roundi(event.relative.y))
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_requested.emit(1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(event.position / _zoom)
		accept_event()
	elif event is InputEventMouseMotion and _selected_vertex >= 0 and _vertex_editing:
		_move_selected_vertex(event.position / _zoom)
		accept_event()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_vertex >= 0:
			var moved_region := _get_selected_region()
			if moved_region and _vertex_dragged:
				commit_vertex_move(moved_region.id, _vertex_before, moved_region.points.duplicate())
		_selected_vertex = -1
		_vertex_dragged = false
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and _draft.size() >= 3:
		_finish_draft()
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_draft.clear()
		if _add_vertex_mode:
			set_add_vertex_mode(false)
		queue_redraw()
		accept_event()


func _handle_left_click(image_position: Vector2) -> void:
	if _add_vertex_mode:
		add_vertex_requested.emit(image_position)
		set_add_vertex_mode(false)
		return
	if _drawing:
		if _draft.size() >= 3 and image_position.distance_to(_draft[0]) * _zoom <= CLOSE_RADIUS:
			_finish_draft()
		else:
			_draft.append(image_position)
			queue_redraw()
		return
	var region := _find_region_at(image_position)
	if region:
		_selected_id = region.id
		_selected_vertex = _find_vertex(region, image_position)
		_vertex_before = region.points.duplicate()
		_vertex_dragged = false
		region_selected.emit(_selected_id)
		point_selected.emit(_selected_vertex)
	else:
		_selected_id = ""
		_selected_vertex = -1
		region_selected.emit("")
		point_selected.emit(-1)
	selection_changed.emit(_selected_id)
	queue_redraw()


func _finish_draft() -> void:
	if _draft.size() < 3:
		return
	region_created.emit(_draft.duplicate())
	_draft.clear()
	queue_redraw()


func _find_region_at(point: Vector2) -> IWERegion:
	for index in range(_regions.size() - 1, -1, -1):
		var region := _regions[index]
		if region.visible and Geometry2D.is_point_in_polygon(point, region.points):
			return region
	return null


func _find_vertex(region: IWERegion, point: Vector2) -> int:
	var best_index := -1
	var best_distance := HANDLE_RADIUS / _zoom
	for index in region.points.size():
		var distance := point.distance_to(region.points[index])
		if distance <= best_distance:
			best_distance = distance
			best_index = index
	return best_index


func _move_selected_vertex(image_position: Vector2) -> void:
	var region := _get_selected_region()
	if region == null or region.locked or _selected_vertex >= region.points.size():
		return
	region.points[_selected_vertex] = image_position
	_vertex_dragged = true
	queue_redraw()


func _get_selected_region() -> IWERegion:
	for region in _regions:
		if region.id == _selected_id:
			return region
	return null


func commit_vertex_move(region_id: String, before: PackedVector2Array, after: PackedVector2Array, action_name := "Move polygon vertex") -> void:
	if before == after or _undo_redo == null:
		return
	if _undo_redo is EditorUndoRedoManager:
		_undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _undo_context)
		_undo_redo.add_do_method(self, "set_region_points", region_id, after)
		_undo_redo.add_undo_method(self, "set_region_points", region_id, before)
		_undo_redo.commit_action()
	else:
		_undo_redo.record(self, region_id, before, after)
	region_changed.emit(region_id, before, after)


func set_region_points(region_id: String, points: PackedVector2Array) -> void:
	if _document:
		_document.replace_region_points(region_id, points)
	for region in _regions:
		if region.id == region_id:
			region.points = points.duplicate()
			region_changed.emit(region_id, points, points)
			queue_redraw()
			return


func add_selected_vertex(image_position: Vector2) -> void:
	var region := _get_selected_region()
	if region == null or region.locked or region.points.size() < 2:
		return
	var best_segment := 0
	var best_distance := INF
	for index in region.points.size():
		var next_index := (index + 1) % region.points.size()
		var closest := Geometry2D.get_closest_point_to_segment(image_position, region.points[index], region.points[next_index])
		var distance := closest.distance_to(image_position)
		if distance < best_distance:
			best_distance = distance
			best_segment = index
	if best_distance > 24.0 / _zoom:
		return
	var before := region.points.duplicate()
	var after := region.points.duplicate()
	after.insert(best_segment + 1, image_position)
	commit_vertex_move(region.id, before, after, "Add polygon vertex")
	set_region_points(region.id, after)
	_add_vertex_mode = false


func remove_selected_vertex() -> void:
	var region := _get_selected_region()
	if region == null or region.locked or region.points.size() <= 3 or _selected_vertex < 0:
		return
	var before := region.points.duplicate()
	var after := region.points.duplicate()
	after.remove_at(_selected_vertex)
	_selected_vertex = -1
	commit_vertex_move(region.id, before, after, "Remove polygon vertex")
	set_region_points(region.id, after)


func set_selected_vertex(index: int) -> void:
	var region := _get_selected_region()
	if region == null or index < 0 or index >= region.points.size():
		_selected_vertex = -1
	else:
		_selected_vertex = index
	point_selected.emit(_selected_vertex)
	queue_redraw()


func create_region(region: IWERegion) -> void:
	_regions.append(region)
	_selected_id = region.id
	queue_redraw()


func remove_region(region_id: String) -> void:
	_regions = _regions.filter(func(region: IWERegion) -> bool: return region.id != region_id)
	if _selected_id == region_id:
		_selected_id = ""
	queue_redraw()


func select_region(region_id: String) -> void:
	if _selected_id != region_id:
		_selected_vertex = -1
	_selected_id = region_id
	point_selected.emit(_selected_vertex)
	queue_redraw()


func get_selected_region() -> IWERegion:
	return _get_selected_region()


func get_selected_vertex_index() -> int:
	return _selected_vertex

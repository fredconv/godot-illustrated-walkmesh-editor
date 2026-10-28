@tool
extends Control

signal zoom_requested(factor: float)
signal region_created(points: PackedVector2Array)
signal subtraction_created(region_id: String, points: PackedVector2Array)
signal region_selected(region_id: String)
signal region_changed(region_id: String, before: PackedVector2Array, after: PackedVector2Array)
signal selection_changed(region_id: String)
signal draw_mode_changed(enabled: bool)
signal vertex_mode_changed(enabled: bool)
signal add_vertex_requested(image_position: Vector2)
signal add_vertex_mode_changed(enabled: bool)
signal point_selected(index: int)
signal scale_anchor_created(image_position: Vector2, apparent_height_px: float)
signal scale_anchor_changed(anchor_id: String, before_position: Vector2, after_position: Vector2)
signal scale_anchor_selected(anchor_id: String)
signal scale_anchor_height_requested(anchor_id: String, factor: float)
signal scale_anchor_delete_requested(anchor_id: String)

var _texture: Texture2D
var _zoom := 1.0
var _dragging := false
var _drawing := false
var _vertex_editing := false
var _add_vertex_mode := false
var _boolean_subtract_mode := false
var _regions: Array[IWERegion] = []
var _selected_id := ""
var _selected_vertex := -1
var _draft := PackedVector2Array()
var _undo_redo: Object
var _undo_context: Object
var _document: IWEDocument
var _vertex_before := PackedVector2Array()
var _vertex_dragged := false
var _dragging_vertex := false
var _dragging_region := false
var _region_drag_origin := Vector2.ZERO
var _region_before := PackedVector2Array()
var _region_subtractions_before: Array[PackedVector2Array] = []
var _scale_anchors: Array[IWEScaleAnchor] = []
var _scale_anchor_mode := false
var _selected_scale_anchor_id := ""
var _dragging_scale_anchor := false
var _scale_anchor_drag_origin := Vector2.ZERO
var _scale_anchor_before := Vector2.ZERO
var _scale_anchor_dragged := false
var _default_template_height_px := 160.0
var _hover_position := Vector2.ZERO
var _hovered_segment := -1
const HANDLE_RADIUS := 9.0
const CLOSE_RADIUS := 12.0
const SEGMENT_HIT_RADIUS := 24.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL


func set_undo_redo(undo_redo: Object) -> void:
	_undo_redo = undo_redo


func set_undo_context(undo_context: Object) -> void:
	_undo_context = undo_context


func set_document(document: IWEDocument) -> void:
	_document = document
	if document:
		set_scale_anchors(document.scale_anchors, document.default_template_height_px)


func set_regions(regions: Array[IWERegion], selected_id: String = "") -> void:
	if _selected_id != selected_id:
		_selected_vertex = -1
	_regions = regions
	_selected_id = selected_id
	queue_redraw()


func set_drawing(enabled: bool) -> void:
	_drawing = enabled
	_boolean_subtract_mode = false
	_vertex_editing = false
	_add_vertex_mode = false
	_draft.clear()
	draw_mode_changed.emit(enabled)
	vertex_mode_changed.emit(false)
	queue_redraw()


func set_vertex_editing(enabled: bool) -> void:
	_vertex_editing = enabled
	if not enabled and _selected_vertex >= 0:
		_selected_vertex = -1
		point_selected.emit(-1)
	_boolean_subtract_mode = false
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


func set_boolean_subtract_mode(enabled: bool) -> void:
	_boolean_subtract_mode = enabled
	_drawing = enabled
	_vertex_editing = false
	_add_vertex_mode = false
	_draft.clear()
	draw_mode_changed.emit(false)
	vertex_mode_changed.emit(false)
	queue_redraw()


func set_texture(texture: Texture2D) -> void:
	_texture = texture
	_update_minimum_size()
	queue_redraw()


func set_scale_anchors(anchors: Array[IWEScaleAnchor], default_height_px: float = 160.0) -> void:
	_scale_anchors = anchors
	_default_template_height_px = maxf(default_height_px, 1.0)
	queue_redraw()


func set_scale_anchor_mode(enabled: bool) -> void:
	_scale_anchor_mode = enabled
	_dragging_scale_anchor = false
	if enabled:
		_drawing = false
		_vertex_editing = false
		_add_vertex_mode = false
		_boolean_subtract_mode = false
		_draft.clear()
		draw_mode_changed.emit(false)
		vertex_mode_changed.emit(false)
		add_vertex_mode_changed.emit(false)
	queue_redraw()


func select_scale_anchor(anchor_id: String) -> void:
	_selected_scale_anchor_id = anchor_id
	scale_anchor_selected.emit(anchor_id)
	queue_redraw()


func get_selected_scale_anchor() -> IWEScaleAnchor:
	for anchor in _scale_anchors:
		if anchor.id == _selected_scale_anchor_id:
			return anchor
	return null


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
				draw_circle(display_points[index], 4.0, Color("ffbd4a") if index == _selected_vertex else region.color)
			elif region.id == _selected_id and index == _selected_vertex:
				draw_circle(display_points[index], HANDLE_RADIUS, Color.WHITE)
				draw_circle(display_points[index], 4.0, Color("ffbd4a"))
		for cutout in region.subtraction_polygons:
			if cutout.size() < 3:
				continue
			for cutout_intersection in Geometry2D.intersect_polygons(region.points, cutout):
				var cutout_display := PackedVector2Array()
				for point in cutout_intersection:
					cutout_display.append(point * _zoom)
				draw_colored_polygon(cutout_display, Color("ff5263", 0.38))
				for index in cutout_display.size():
					draw_line(cutout_display[index], cutout_display[(index + 1) % cutout_display.size()], Color("ff5263"), 2.0, true)
	for index in _scale_anchors.size():
		var anchor: IWEScaleAnchor = _scale_anchors[index]
		var foot := anchor.position * _zoom
		var height := anchor.apparent_height_px * _zoom
		var body_color := Color("ffbd4a") if anchor.id == _selected_scale_anchor_id else Color("65d6a6")
		var head_radius := clampf(height * 0.09, 4.0, 12.0)
		var head_center := foot + Vector2(0.0, -height + head_radius)
		draw_line(foot, foot + Vector2(0.0, -height * 0.72), body_color, 3.0, true)
		draw_line(foot + Vector2(0.0, -height * 0.52), foot + Vector2(-height * 0.18, -height * 0.28), body_color, 2.0, true)
		draw_line(foot + Vector2(0.0, -height * 0.52), foot + Vector2(height * 0.18, -height * 0.28), body_color, 2.0, true)
		draw_line(foot, foot + Vector2(-height * 0.13, 0.0), body_color, 2.0, true)
		draw_line(foot, foot + Vector2(height * 0.13, 0.0), body_color, 2.0, true)
		draw_circle(head_center, head_radius, body_color)
		draw_line(foot + Vector2(-head_radius, 0.0), foot + Vector2(head_radius, 0.0), body_color, 2.0, true)
		# A dark backing keeps the label readable over bright sky and grass.
		var label := "%s · %d px" % [anchor.name, roundi(anchor.apparent_height_px)]
		var label_position := foot + Vector2(8.0, -height - 5.0)
		var label_size := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_rect(Rect2(label_position + Vector2(-4.0, -label_size.y + 2.0), label_size + Vector2(8.0, 6.0)), Color(0.0, 0.0, 0.0, 0.6))
		draw_string(ThemeDB.fallback_font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffffff") if anchor.id != _selected_scale_anchor_id else Color("ffbd4a"))
	if _add_vertex_mode and _hovered_segment >= 0:
		var hovered := _get_selected_region()
		if hovered and _hovered_segment < hovered.points.size():
			var start := hovered.points[_hovered_segment] * _zoom
			var finish := hovered.points[(_hovered_segment + 1) % hovered.points.size()] * _zoom
			var projected := Geometry2D.get_closest_point_to_segment(_hover_position / _zoom, hovered.points[_hovered_segment], hovered.points[(_hovered_segment + 1) % hovered.points.size()]) * _zoom
			draw_line(start, finish, Color("ffe066"), 5.0, true)
			draw_circle(projected, 7.0, Color("ffe066"))
			draw_circle(projected, 3.0, Color("20232a"))
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
		if _scale_anchor_mode and get_selected_scale_anchor() != null:
			scale_anchor_height_requested.emit(_selected_scale_anchor_id, 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
			accept_event()
			return
		zoom_requested.emit(1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _scale_anchor_mode:
			_handle_scale_anchor_click(event.position / _zoom)
		else:
			_handle_left_click(event.position / _zoom)
		accept_event()
	elif event is InputEventMouseMotion:
		_hover_position = event.position
		if _scale_anchor_mode and _dragging_scale_anchor:
			var anchor := get_selected_scale_anchor()
			if anchor:
				anchor.position = event.position / _zoom
				_scale_anchor_dragged = true
				queue_redraw()
			accept_event()
		elif _add_vertex_mode:
			_hovered_segment = _find_nearest_segment(event.position / _zoom)
			queue_redraw()
		elif _dragging_vertex and _selected_vertex >= 0 and _vertex_editing:
			_move_selected_vertex(event.position / _zoom)
			accept_event()
		elif _dragging_region:
			_move_selected_region(event.position / _zoom)
			accept_event()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _dragging_scale_anchor:
			var anchor := get_selected_scale_anchor()
			if anchor and _scale_anchor_dragged:
				scale_anchor_changed.emit(anchor.id, _scale_anchor_before, anchor.position)
			_dragging_scale_anchor = false
			_scale_anchor_dragged = false
		elif _selected_vertex >= 0 and _vertex_editing:
			var moved_region := _get_selected_region()
			if moved_region and _vertex_dragged:
				commit_vertex_move(moved_region.id, _vertex_before, moved_region.points.duplicate())
		elif _dragging_region:
			var moved_region := _get_selected_region()
			if moved_region and _vertex_dragged:
				commit_region_move(moved_region.id, _region_before, moved_region.points.duplicate(), _region_subtractions_before, moved_region.subtraction_polygons.duplicate(true))
		_dragging_region = false
		_dragging_vertex = false
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
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		if _scale_anchor_mode and not _selected_scale_anchor_id.is_empty():
			scale_anchor_delete_requested.emit(_selected_scale_anchor_id)
			accept_event()
		elif _vertex_editing and _selected_vertex >= 0:
			remove_selected_vertex()
			accept_event()


func _handle_scale_anchor_click(image_position: Vector2) -> void:
	var hit: IWEScaleAnchor = null
	var hit_radius := HANDLE_RADIUS / _zoom
	for index in range(_scale_anchors.size() - 1, -1, -1):
		var anchor: IWEScaleAnchor = _scale_anchors[index]
		var head := anchor.position + Vector2(0.0, -anchor.apparent_height_px * 0.91)
		var body := anchor.position + Vector2(0.0, -anchor.apparent_height_px * 0.5)
		if image_position.distance_to(anchor.position) <= hit_radius or image_position.distance_to(head) <= hit_radius or Geometry2D.get_closest_point_to_segment(image_position, head, body).distance_to(image_position) <= hit_radius:
			hit = anchor
			break
	if hit:
		_selected_scale_anchor_id = hit.id
		_scale_anchor_before = hit.position
		_dragging_scale_anchor = true
		_scale_anchor_dragged = false
		scale_anchor_selected.emit(hit.id)
	else:
		_selected_scale_anchor_id = ""
		scale_anchor_selected.emit("")
		if _document and _document.image_size.x > 0 and _document.image_size.y > 0:
			var point := Vector2(clampf(image_position.x, 0.0, _document.image_size.x), clampf(image_position.y, 0.0, _document.image_size.y))
			scale_anchor_created.emit(point, _default_template_height_px)
	queue_redraw()


func _handle_left_click(image_position: Vector2) -> void:
	if _add_vertex_mode:
		add_vertex_requested.emit(image_position)
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
		_selected_vertex = _find_vertex(region, image_position) if _vertex_editing else -1
		_vertex_before = region.points.duplicate()
		_region_before = region.points.duplicate()
		_region_subtractions_before = region.subtraction_polygons.duplicate(true)
		_region_drag_origin = image_position
		_vertex_dragged = false
		_dragging_vertex = _vertex_editing and _selected_vertex >= 0 and not region.locked
		_dragging_region = not _vertex_editing and not region.locked and _selected_vertex < 0
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
	if _boolean_subtract_mode:
		subtraction_created.emit(_selected_id, _draft.duplicate())
	else:
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


func _move_selected_region(image_position: Vector2) -> void:
	var region := _get_selected_region()
	if region == null or region.locked:
		return
	var offset := image_position - _region_drag_origin
	if offset == Vector2.ZERO:
		return
	for index in region.points.size():
		region.points[index] = _region_before[index] + offset
	var moved_subtractions: Array[PackedVector2Array] = []
	for polygon in _region_subtractions_before:
		var moved_polygon := polygon.duplicate()
		for index in moved_polygon.size():
			moved_polygon[index] += offset
		moved_subtractions.append(moved_polygon)
	region.subtraction_polygons = moved_subtractions
	_vertex_dragged = true
	queue_redraw()


func _find_nearest_segment(image_position: Vector2) -> int:
	var region := _get_selected_region()
	if region == null or region.locked or region.points.size() < 3:
		return -1
	var best_index := -1
	var best_distance := SEGMENT_HIT_RADIUS / _zoom
	for index in region.points.size():
		var closest := Geometry2D.get_closest_point_to_segment(image_position, region.points[index], region.points[(index + 1) % region.points.size()])
		var distance := closest.distance_to(image_position)
		if distance <= best_distance:
			best_distance = distance
			best_index = index
	return best_index


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


func commit_region_move(region_id: String, before: PackedVector2Array, after: PackedVector2Array, before_subtractions: Array[PackedVector2Array], after_subtractions: Array[PackedVector2Array]) -> void:
	if before == after and before_subtractions == after_subtractions:
		return
	if _undo_redo is EditorUndoRedoManager:
		_undo_redo.create_action("Move polygon", UndoRedo.MERGE_DISABLE, _undo_context)
		_undo_redo.add_do_method(self, "set_region_geometry", region_id, after, after_subtractions)
		_undo_redo.add_undo_method(self, "set_region_geometry", region_id, before, before_subtractions)
		_undo_redo.commit_action()
	else:
		_undo_redo.record(self, region_id, before, after)
	region_changed.emit(region_id, before, after)


func set_region_geometry(region_id: String, points: PackedVector2Array, subtraction_polygons: Array[PackedVector2Array]) -> void:
	if _document:
		_document.replace_region_points(region_id, points)
	for region in _regions:
		if region.id == region_id:
			region.points = points.duplicate()
			region.subtraction_polygons = subtraction_polygons.duplicate(true)
			region_changed.emit(region_id, points, points)
			queue_redraw()
			return


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
	var best_segment := _find_nearest_segment(image_position)
	if best_segment < 0:
		return
	var next_index := (best_segment + 1) % region.points.size()
	var inserted_point := Geometry2D.get_closest_point_to_segment(image_position, region.points[best_segment], region.points[next_index])
	var before := region.points.duplicate()
	var after := region.points.duplicate()
	after.insert(best_segment + 1, inserted_point)
	_selected_vertex = best_segment + 1
	commit_vertex_move(region.id, before, after, "Add polygon vertex")
	set_region_points(region.id, after)
	_vertex_editing = true
	_add_vertex_mode = false
	add_vertex_mode_changed.emit(false)
	vertex_mode_changed.emit(true)
	point_selected.emit(_selected_vertex)
	queue_redraw()


func remove_selected_vertex() -> void:
	var region := _get_selected_region()
	if region == null or region.locked or region.points.size() <= 3 or _selected_vertex < 0:
		return
	var before := region.points.duplicate()
	var after := region.points.duplicate()
	after.remove_at(_selected_vertex)
	_selected_vertex = mini(_selected_vertex, after.size() - 1)
	commit_vertex_move(region.id, before, after, "Remove polygon vertex")
	set_region_points(region.id, after)
	point_selected.emit(_selected_vertex)


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

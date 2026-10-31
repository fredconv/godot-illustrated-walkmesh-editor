extends GdUnitTestSuite
## Editing the corners of an action zone on the illustration: move a corner, add one on an edge, remove one,
## each as one undo step.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const CANVAS_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_canvas.gd")


func _click(dock: Control, image_position: Vector2, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = image_position * dock._canvas._zoom
	dock._canvas._gui_input(event)


func _motion(dock: Control, image_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = image_position * dock._canvas._zoom
	dock._canvas._gui_input(event)


func _delete_key(dock: Control) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_DELETE
	event.pressed = true
	dock._canvas._gui_input(event)


func _dock_with_zone() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._canvas.action_zone_created.emit(PackedVector2Array([Vector2(300, 600), Vector2(500, 600), Vector2(500, 760), Vector2(300, 760)]))
	dock._set_action_tool(CANVAS_SCRIPT.ACTION_TOOL_ZONE_POINTS)
	return dock


func _points(dock: Control) -> PackedVector2Array:
	return dock._document.action_zones[0].points


func test_dragging_a_corner_moves_only_that_corner_in_one_undo_step() -> void:
	var dock := await _dock_with_zone()
	assert_int(dock._document.action_zones.size()).is_equal(1)
	assert_int(dock._canvas.get_selected_zone_vertex()).is_equal(-1)
	_click(dock, Vector2(500, 600))
	assert_int(dock._canvas.get_selected_zone_vertex()).is_equal(1)
	_motion(dock, Vector2(540, 590))
	_motion(dock, Vector2(560, 580))
	_click(dock, Vector2(560, 580), false)
	assert_array(Array(_points(dock))).is_equal([Vector2(300, 600), Vector2(560, 580), Vector2(500, 760), Vector2(300, 760)])
	dock._undo()
	assert_array(Array(_points(dock))).is_equal([Vector2(300, 600), Vector2(500, 600), Vector2(500, 760), Vector2(300, 760)])
	dock._redo()
	assert_vector(_points(dock)[1]).is_equal(Vector2(560, 580))
	dock.queue_free()


func test_a_click_on_an_edge_adds_a_corner_there() -> void:
	var dock := await _dock_with_zone()
	_click(dock, Vector2(400, 603))
	_click(dock, Vector2(400, 603), false)
	assert_int(_points(dock).size()).is_equal(5)
	assert_vector(_points(dock)[1]).is_equal(Vector2(400, 600))
	assert_int(dock._canvas.get_selected_zone_vertex()).override_failure_message("the new corner is the picked one").is_equal(1)
	dock._undo()
	assert_int(_points(dock).size()).is_equal(4)
	dock.queue_free()


func test_delete_removes_the_picked_corner_and_never_goes_below_three() -> void:
	var dock := await _dock_with_zone()
	_click(dock, Vector2(300, 760))
	_click(dock, Vector2(300, 760), false)
	_delete_key(dock)
	assert_int(_points(dock).size()).is_equal(3)
	assert_array(Array(_points(dock))).is_equal([Vector2(300, 600), Vector2(500, 600), Vector2(500, 760)])
	_click(dock, Vector2(500, 760))
	_click(dock, Vector2(500, 760), false)
	_delete_key(dock)
	assert_int(_points(dock).size()).override_failure_message("a zone keeps three corners").is_equal(3)
	dock._undo()
	assert_int(_points(dock).size()).is_equal(4)
	dock.queue_free()


func test_the_tool_selects_a_zone_first_and_clears_on_empty_ground() -> void:
	var dock := await _dock_with_zone()
	dock._canvas.select_action_zone("")
	_click(dock, Vector2(400, 680))
	_click(dock, Vector2(400, 680), false)
	assert_str(dock._canvas._selected_zone_id).is_equal(dock._document.action_zones[0].id)
	_click(dock, Vector2(1200, 200))
	_click(dock, Vector2(1200, 200), false)
	assert_str(dock._canvas._selected_zone_id).is_empty()
	dock.queue_free()


func test_the_panel_button_turns_the_tool_on_and_off() -> void:
	var dock := await _dock_with_zone()
	assert_str(dock._canvas.get_action_tool()).is_equal(CANVAS_SCRIPT.ACTION_TOOL_ZONE_POINTS)
	assert_bool(dock._action_panel._edit_points_button.button_pressed).is_true()
	assert_str(dock._status_label.text).contains("Edit corners")
	dock._action_panel._edit_points_button.button_pressed = false
	assert_str(dock._canvas.get_action_tool()).is_equal("")
	dock.queue_free()

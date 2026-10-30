extends GdUnitTestSuite
## Authoring action zones and entry points in the dock: drawing, selecting, configuring, undo and redo,
## saving and reopening. Everything goes through the signals the canvas and the panel emit.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const WORK_FOLDER := "user://iwe_action_panel"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_FOLDER))


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(WORK_FOLDER))


func _dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	return dock


func _square(x: float, y: float, size := 100.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)])


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


# ---- zones ---------------------------------------------------------------------------------------


func test_a_drawn_zone_is_added_selected_and_can_be_undone_and_redone() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(100, 600))
	var document: IWEDocument = dock._document
	assert_int(document.action_zones.size()).is_equal(1)
	var zone := document.action_zones[0]
	assert_str(zone.name).is_equal("Zone 1")
	assert_str(zone.action).is_equal(IWEActionZone.ACTION_SCENE_TRANSITION)
	assert_str(dock._action_panel.get_selected().id).is_equal(zone.id)
	assert_bool(dock.is_dirty()).is_true()
	dock._undo()
	assert_int(document.action_zones.size()).is_equal(0)
	assert_str(dock._action_panel.get_selected().kind).is_empty()
	dock._redo()
	assert_int(document.action_zones.size()).is_equal(1)
	assert_str(document.action_zones[0].id).is_equal(zone.id)
	dock.queue_free()


func test_two_zones_get_distinct_names_even_after_a_removal() -> void:
	var dock := await _dock()
	for index in 3:
		dock._canvas.action_zone_created.emit(_square(100.0 + index * 150.0, 600))
	var document: IWEDocument = dock._document
	dock._remove_action_item(IWEActionPanel.KIND_ZONE, document.action_zones[0].id)
	dock._canvas.action_zone_created.emit(_square(700, 600))
	var names := PackedStringArray()
	for zone in document.action_zones:
		names.append(zone.name)
	assert_array(Array(names)).is_equal(["Zone 2", "Zone 3", "Zone 4"])
	dock.queue_free()


func test_the_settings_of_a_zone_are_edited_with_undo() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(100, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	var panel: IWEActionPanel = dock._action_panel
	panel.zone_property_requested.emit(zone.id, "name", "Door to the forest")
	panel.zone_property_requested.emit(zone.id, "target_scene", "res://levels/forest.tscn")
	panel.zone_property_requested.emit(zone.id, "entry_id", "from_village")
	panel.zone_property_requested.emit(zone.id, "enabled", false)
	assert_str(zone.name).is_equal("Door to the forest")
	assert_str(zone.target_scene).is_equal("res://levels/forest.tscn")
	assert_str(zone.entry_id).is_equal("from_village")
	assert_bool(zone.enabled).is_false()
	dock._undo()
	assert_bool(zone.enabled).is_true()
	dock._undo()
	assert_str(zone.entry_id).is_empty()
	dock._undo()
	assert_str(zone.target_scene).is_empty()
	dock._redo()
	assert_str(zone.target_scene).is_equal("res://levels/forest.tscn")
	dock.queue_free()


func test_an_empty_zone_name_is_refused_and_the_panel_shows_the_real_one() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(100, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	dock._action_panel.zone_property_requested.emit(zone.id, "name", "   ")
	assert_str(zone.name).is_equal("Zone 1")
	assert_str(dock._action_panel._zone_name.text).is_equal("Zone 1")
	dock.queue_free()


func test_a_property_that_is_not_a_zone_setting_is_ignored() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(100, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	var id_before := zone.id
	dock._action_panel.zone_property_requested.emit(zone.id, "id", "hacked")
	assert_str(zone.id).is_equal(id_before)
	dock.queue_free()


func test_moving_a_zone_is_one_undo_step() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(100, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	var before := zone.points.duplicate()
	var moved := PackedVector2Array()
	for point in before:
		moved.append(point + Vector2(50, -20))
	zone.points = moved
	dock._canvas.action_zone_moved.emit(zone.id, before, moved)
	dock._undo()
	assert_array(Array(zone.points)).is_equal(Array(before))
	dock._redo()
	assert_array(Array(zone.points)).is_equal(Array(moved))
	dock.queue_free()


func test_removing_a_zone_can_be_undone_into_the_same_place() -> void:
	var dock := await _dock()
	for index in 3:
		dock._canvas.action_zone_created.emit(_square(100.0 + index * 150.0, 600))
	var document: IWEDocument = dock._document
	var middle := document.action_zones[1]
	var middle_name := middle.name
	dock._remove_action_item(IWEActionPanel.KIND_ZONE, middle.id)
	assert_int(document.action_zones.size()).is_equal(2)
	dock._undo()
	assert_int(document.action_zones.size()).is_equal(3)
	assert_str(document.action_zones[1].name).override_failure_message("order is part of the document").is_equal(middle_name)
	dock.queue_free()


# ---- entry points --------------------------------------------------------------------------------


func test_the_first_entry_point_is_the_default_and_later_ones_are_not() -> void:
	var dock := await _dock()
	dock._canvas.entry_point_created.emit(Vector2(300, 700))
	dock._canvas.entry_point_created.emit(Vector2(900, 700))
	var entries: Array[IWEEntryPoint] = dock._document.entry_points
	assert_str(entries[0].entry_id).is_equal("entry_1")
	assert_str(entries[1].entry_id).is_equal("entry_2")
	assert_bool(entries[0].is_default).is_true()
	assert_bool(entries[1].is_default).is_false()
	dock.queue_free()


func test_choosing_another_default_releases_the_first_in_one_undo_step() -> void:
	var dock := await _dock()
	dock._canvas.entry_point_created.emit(Vector2(300, 700))
	dock._canvas.entry_point_created.emit(Vector2(900, 700))
	var entries: Array[IWEEntryPoint] = dock._document.entry_points
	dock._action_panel.entry_property_requested.emit(entries[1].id, "is_default", true)
	assert_bool(entries[0].is_default).is_false()
	assert_bool(entries[1].is_default).is_true()
	dock._undo()
	assert_bool(entries[0].is_default).is_true()
	assert_bool(entries[1].is_default).is_false()
	dock.queue_free()


func test_an_entry_point_name_must_be_unique_and_simple() -> void:
	var dock := await _dock()
	dock._canvas.entry_point_created.emit(Vector2(300, 700))
	dock._canvas.entry_point_created.emit(Vector2(900, 700))
	var entries: Array[IWEEntryPoint] = dock._document.entry_points
	dock._action_panel.entry_property_requested.emit(entries[1].id, "entry_id", "entry_1")
	assert_str(entries[1].entry_id).override_failure_message("a duplicate name is refused").is_equal("entry_2")
	dock._action_panel.entry_property_requested.emit(entries[1].id, "entry_id", "with space")
	assert_str(entries[1].entry_id).is_equal("entry_2")
	dock._action_panel.entry_property_requested.emit(entries[1].id, "entry_id", "from_forest")
	assert_str(entries[1].entry_id).is_equal("from_forest")
	dock._undo()
	assert_str(entries[1].entry_id).is_equal("entry_2")
	dock.queue_free()


func test_the_direction_of_an_entry_point_can_be_set_and_cleared() -> void:
	var dock := await _dock()
	dock._canvas.entry_point_created.emit(Vector2(300, 700))
	var entry: IWEEntryPoint = dock._document.entry_points[0]
	assert_bool(entry.has_facing()).is_false()
	dock._action_panel.entry_property_requested.emit(entry.id, "facing_degrees", 90.0)
	assert_float(entry.facing_degrees).is_equal(90.0)
	dock._action_panel.entry_property_requested.emit(entry.id, "facing_degrees", NAN)
	assert_bool(entry.has_facing()).is_false()
	# Two edits of the same field in a row are one undo step, like the other numeric fields.
	dock._undo()
	assert_bool(entry.has_facing()).override_failure_message("both edits were undone together").is_false()
	dock._redo()
	assert_bool(entry.has_facing()).is_false()
	dock.queue_free()


func test_moving_and_removing_an_entry_point_with_undo() -> void:
	var dock := await _dock()
	dock._canvas.entry_point_created.emit(Vector2(300, 700))
	var entry: IWEEntryPoint = dock._document.entry_points[0]
	entry.position = Vector2(350, 720)
	dock._canvas.entry_point_moved.emit(entry.id, Vector2(300, 700), Vector2(350, 720))
	dock._undo()
	assert_vector(entry.position).is_equal(Vector2(300, 700))
	dock._remove_action_item(IWEActionPanel.KIND_ENTRY, entry.id)
	assert_int(dock._document.entry_points.size()).is_equal(0)
	dock._undo()
	assert_int(dock._document.entry_points.size()).is_equal(1)
	assert_bool(dock._document.entry_points[0].is_default).override_failure_message("what was removed comes back as it was").is_true()
	dock.queue_free()


# ---- the mouse on the canvas --------------------------------------------------------------------


func test_clicking_the_corners_and_the_first_corner_again_draws_a_zone() -> void:
	var dock := await _dock()
	dock._set_action_tool(IWECanvas.ACTION_TOOL_ZONE_DRAW)
	assert_str(dock._canvas.get_action_tool()).is_equal(IWECanvas.ACTION_TOOL_ZONE_DRAW)
	for corner in _square(200, 600):
		_click(dock, corner)
		_click(dock, corner, false)
	assert_int(dock._document.action_zones.size()).override_failure_message("not closed yet").is_equal(0)
	_click(dock, Vector2(200, 600))
	assert_int(dock._document.action_zones.size()).is_equal(1)
	assert_int(dock._document.action_zones[0].points.size()).is_equal(4)
	assert_int(dock._document.regions.size()).override_failure_message("a zone is not a walkable region").is_equal(0)
	dock.queue_free()


func test_a_click_with_the_entry_tool_places_a_marker_and_a_click_on_it_selects_it() -> void:
	var dock := await _dock()
	dock._set_action_tool(IWECanvas.ACTION_TOOL_ENTRY)
	_click(dock, Vector2(400, 500))
	_click(dock, Vector2(400, 500), false)
	assert_int(dock._document.entry_points.size()).is_equal(1)
	assert_vector(dock._document.entry_points[0].position).is_equal(Vector2(400, 500))
	_click(dock, Vector2(900, 300))
	_click(dock, Vector2(900, 300), false)
	assert_int(dock._document.entry_points.size()).is_equal(2)
	_click(dock, Vector2(402, 503))
	_click(dock, Vector2(402, 503), false)
	assert_int(dock._document.entry_points.size()).override_failure_message("clicking a marker selects it, it does not add another").is_equal(2)
	assert_str(dock._action_panel.get_selected().id).is_equal(dock._document.entry_points[0].id)
	dock.queue_free()


func test_dragging_a_zone_with_the_select_tool_moves_it_as_one_undo_step() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(300, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	var before := zone.points.duplicate()
	dock._set_action_tool(IWECanvas.ACTION_TOOL_ZONE_SELECT)
	_click(dock, Vector2(350, 650))
	_motion(dock, Vector2(380, 640))
	_motion(dock, Vector2(450, 620))
	_click(dock, Vector2(450, 620), false)
	assert_vector(zone.points[0]).is_equal(before[0] + Vector2(100, -30))
	dock._undo()
	assert_array(Array(zone.points)).is_equal(Array(before))
	dock.queue_free()


func test_clicking_empty_ground_with_the_select_tool_clears_the_selection() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(300, 600))
	dock._set_action_tool(IWECanvas.ACTION_TOOL_ZONE_SELECT)
	_click(dock, Vector2(1500, 100))
	_click(dock, Vector2(1500, 100), false)
	assert_str(dock._action_panel.get_selected().kind).is_empty()
	dock.queue_free()


# ---- tools ---------------------------------------------------------------------------------------


func test_an_action_tool_releases_the_region_tools_and_the_other_way_round() -> void:
	var dock := await _dock()
	dock._create_group_named("Ground")
	dock._draw_button.button_pressed = true
	assert_bool(dock._draw_button.button_pressed).is_true()
	dock._set_action_tool(IWECanvas.ACTION_TOOL_ZONE_DRAW)
	assert_bool(dock._draw_button.button_pressed).override_failure_message("drawing a region and a zone at once would be ambiguous").is_false()
	assert_bool(dock._action_panel._draw_zone_button.button_pressed).is_true()
	dock._draw_button.button_pressed = true
	assert_str(dock._canvas.get_action_tool()).is_empty()
	assert_bool(dock._action_panel._draw_zone_button.button_pressed).override_failure_message("the panel released its button").is_false()
	dock.queue_free()


func test_turning_a_tool_on_leaves_perspective_mode() -> void:
	var dock := await _dock()
	dock._set_perspective_mode(true)
	dock._set_action_tool(IWECanvas.ACTION_TOOL_ENTRY)
	assert_bool(dock._perspective_mode).override_failure_message("the canvas is not shown in perspective mode").is_false()
	dock.queue_free()


# ---- the panel -----------------------------------------------------------------------------------


func test_selecting_a_zone_in_the_list_shows_its_settings() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(100, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	dock._action_panel.zone_property_requested.emit(zone.id, "target_scene", "res://levels/forest.tscn")
	dock._action_panel.select("", "")
	assert_bool(dock._action_panel._zone_box.visible).is_false()
	dock._action_panel._zone_list.select(0)
	dock._action_panel._on_zone_item_selected(0)
	assert_bool(dock._action_panel._zone_box.visible).is_true()
	assert_str(dock._action_panel._zone_scene.text).is_equal("res://levels/forest.tscn")
	assert_bool(dock._action_panel._scene_row.visible).override_failure_message("a scene change shows the scene field").is_true()
	dock._action_panel.zone_property_requested.emit(zone.id, "action", IWEActionZone.ACTION_WARP)
	assert_bool(dock._action_panel._scene_row.visible).override_failure_message("a warp has no scene").is_false()
	dock.queue_free()


func test_an_unknown_action_is_shown_by_name_and_kept() -> void:
	var dock := await _dock()
	var zone := IWEActionZone.create_zone("Cutscene", _square(100, 600))
	zone.action = "play_cutscene"
	dock._document.action_zones.append(zone)
	dock._refresh_actions()
	dock._action_panel.select(IWEActionPanel.KIND_ZONE, zone.id)
	var option: OptionButton = dock._action_panel._zone_action
	assert_str(option.get_item_text(option.selected)).contains("play_cutscene")
	assert_str(zone.action).is_equal("play_cutscene")
	dock.queue_free()


func test_the_export_check_names_a_scene_that_is_not_in_the_project() -> void:
	var dock := await _dock()
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	dock._canvas.action_zone_created.emit(_square(1380, 540))
	var zone: IWEActionZone = dock._document.action_zones[0]
	dock._action_panel.zone_property_requested.emit(zone.id, "target_scene", "res://levels/missing_level.tscn")
	dock._check_export()
	assert_str(dock._validation_label.text).contains("res://levels/missing_level.tscn was not found")
	dock.queue_free()


# ---- saving ----------------------------------------------------------------------------------------


func test_zones_and_entry_points_come_back_when_the_document_is_reopened() -> void:
	var dock := await _dock()
	dock._canvas.action_zone_created.emit(_square(100, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	dock._action_panel.zone_property_requested.emit(zone.id, "target_scene", "res://levels/forest.tscn")
	dock._action_panel.zone_property_requested.emit(zone.id, "entry_id", "from_village")
	dock._canvas.entry_point_created.emit(Vector2(300, 700))
	var path := WORK_FOLDER.path_join("level.tres")
	dock._save_document(path)
	await get_tree().process_frame
	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(path)
	var document: IWEDocument = reopened._document
	assert_int(document.schema_version).is_equal(IWEDocument.CURRENT_SCHEMA_VERSION)
	assert_int(document.action_zones.size()).is_equal(1)
	assert_str(document.action_zones[0].target_scene).is_equal("res://levels/forest.tscn")
	assert_str(document.action_zones[0].entry_id).is_equal("from_village")
	assert_int(document.entry_points.size()).is_equal(1)
	assert_bool(document.entry_points[0].is_default).is_true()
	assert_int(reopened._action_panel._zone_list.item_count).override_failure_message("the panel lists what was loaded").is_equal(1)
	assert_int(reopened._action_panel._entry_list.item_count).is_equal(1)
	assert_bool(reopened.is_dirty()).is_false()
	dock.queue_free()
	reopened.queue_free()

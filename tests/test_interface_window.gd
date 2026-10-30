extends GdUnitTestSuite
## The Window button detaches the whole IWE interface, not only the picture, and bringing it back
## returns exactly what was left: document, history, selection, tool, zoom, tab, folded sections.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")


func _authored_dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	dock._canvas.action_zone_created.emit(PackedVector2Array([Vector2(1380, 540), Vector2(1480, 540), Vector2(1480, 620), Vector2(1380, 620)]))
	dock._canvas.entry_point_created.emit(Vector2(300, 800))
	return dock


func _state(dock: Control) -> Dictionary:
	var sections := {}
	for title in ["Layers and pictures", "Regions", "Drawing tools", "Action zones and entry points", "Height references", "Camera and perspective"]:
		var section := dock.get_section(title) as IWECollapsibleSection
		sections[title] = section.is_expanded() if section != null else null
	return {
		"document": dock._document,
		"history": dock._history,
		"dirty": dock.is_dirty(),
		"tab": dock._dock_tabs.current_tab,
		"zoom": dock._canvas._zoom,
		"zoom_label": dock._zoom_label.text,
		"selected_region": dock._canvas.get_selected_region().id if dock._canvas.get_selected_region() != null else "",
		"action_tool": dock._canvas.get_action_tool(),
		"selected_action": dock._action_panel.get_selected(),
		"group": dock._selected_group_id,
		"can_undo": dock._history.has_undo(),
		"can_redo": dock._history.has_redo(),
		"regions": dock._document.regions.size(),
		"zones": dock._document.action_zones.size(),
		"sections": sections,
		"draw_pressed": dock._draw_button.button_pressed,
	}


func _settle() -> void:
	for _frame in 4:
		await get_tree().process_frame


func test_detaching_and_returning_keeps_every_part_of_the_state() -> void:
	var dock := await _authored_dock()
	dock._change_zoom(1.5)
	dock.select_tab(IWEDock_TAB_CREATION)
	(dock.get_section("Layers and pictures") as IWECollapsibleSection).set_expanded(false)
	(dock.get_section("Action zones and entry points") as IWECollapsibleSection).set_expanded(true)
	dock._canvas.select_region(dock._document.regions[1].id)
	dock._set_action_tool(IWECanvas.ACTION_TOOL_ZONE_SELECT)
	var before := _state(dock)
	dock._set_interface_window(true)
	await _settle()
	assert_bool(dock.is_interface_detached()).is_true()
	var detached := _state(dock)
	assert_dict(detached).override_failure_message("detaching changed the state").is_equal(before)
	dock._set_interface_window(false)
	await _settle()
	assert_bool(dock.is_interface_detached()).is_false()
	assert_dict(_state(dock)).override_failure_message("returning changed the state").is_equal(before)
	assert_object(dock._document).is_same(before.document)
	assert_object(dock._history).is_same(before.history)
	dock.queue_free()


const IWEDock_TAB_CREATION := 0


func test_the_interface_works_while_it_is_in_its_window() -> void:
	var dock := await _authored_dock()
	dock._set_interface_window(true)
	await _settle()
	var zones_before: int = dock._document.action_zones.size()
	dock._canvas.action_zone_created.emit(PackedVector2Array([Vector2(100, 600), Vector2(200, 600), Vector2(200, 700)]))
	assert_int(dock._document.action_zones.size()).is_equal(zones_before + 1)
	dock._undo_button.pressed.emit()
	assert_int(dock._document.action_zones.size()).override_failure_message("the Undo button works in the window").is_equal(zones_before)
	dock._redo_button.pressed.emit()
	assert_int(dock._document.action_zones.size()).is_equal(zones_before + 1)
	dock.select_tab(1)
	assert_int(dock._dock_tabs.current_tab).is_equal(1)
	dock._set_interface_window(false)
	await _settle()
	assert_int(dock._document.action_zones.size()).override_failure_message("what was done in the window is kept").is_equal(zones_before + 1)
	assert_int(dock._dock_tabs.current_tab).override_failure_message("the tab chosen in the window is kept").is_equal(1)
	assert_bool(dock._history.has_undo()).is_true()
	dock.queue_free()


func test_closing_the_window_brings_the_interface_back() -> void:
	var dock := await _authored_dock()
	dock._set_interface_window(true)
	await _settle()
	dock._interface_window.close_requested.emit()
	await _settle()
	assert_bool(dock.is_interface_detached()).is_false()
	assert_object(dock.get_node("Workspace")).is_not_null()
	assert_bool(dock.get_node_or_null("DetachedNotice") == null).override_failure_message("the notice is gone").is_true()
	dock.queue_free()


func test_the_notice_button_brings_the_interface_back() -> void:
	var dock := await _authored_dock()
	dock._set_interface_window(true)
	await _settle()
	(dock.get_node("DetachedNotice/BringBackButton") as Button).pressed.emit()
	await _settle()
	assert_bool(dock.is_interface_detached()).is_false()
	dock.queue_free()


func test_the_dialogs_open_in_the_window_the_interface_is_in() -> void:
	var dock := await _authored_dock()
	var open_dialog: Window = dock._open_dialog
	assert_object(open_dialog.get_parent()).is_same(dock)
	dock._set_interface_window(true)
	await _settle()
	assert_object(open_dialog.get_parent()).override_failure_message("a file dialog opened from the window belongs to the window").is_same(dock._interface_content)
	# A dialog created while detached also goes to the window, and follows the interface back.
	dock._show_name_dialog("Name it", "Anything", "Name", func(_text: String) -> void: pass)
	await _settle()
	var name_dialog: Window = dock._active_name_dialog
	assert_object(name_dialog).is_not_null()
	assert_object(name_dialog.get_parent()).is_same(dock._interface_content)
	dock._set_interface_window(false)
	await _settle()
	assert_object(open_dialog.get_parent()).is_same(dock)
	if is_instance_valid(name_dialog):
		assert_object(name_dialog.get_parent()).is_same(dock)
	dock.queue_free()


func test_going_back_and_forth_several_times_is_stable() -> void:
	var dock := await _authored_dock()
	var before := _state(dock)
	for _round in 3:
		dock._window_button.set_pressed(true)
		await _settle()
		dock._window_button.set_pressed(false)
		await _settle()
	assert_dict(_state(dock)).is_equal(before)
	dock.queue_free()


func test_removing_the_dock_while_detached_does_not_leave_a_window_open() -> void:
	var dock := await _authored_dock()
	dock._set_interface_window(true)
	await _settle()
	var window: Window = dock._interface_window
	get_tree().root.remove_child(dock)
	await _settle()
	assert_bool(not is_instance_valid(window) or window.is_queued_for_deletion()).override_failure_message("the window is closed with the dock").is_true()
	dock.free()

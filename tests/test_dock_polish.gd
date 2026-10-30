extends GdUnitTestSuite
## Clarity of the dock: every control explains itself, the status line helps with the active tool, and the
## sections show counts that stay visible when they are folded.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const CANVAS_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_canvas.gd")


func _dock_with_illustration() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	return dock


func test_every_button_and_field_of_the_dock_has_a_tooltip() -> void:
	var dock := await _dock_with_illustration()
	var missing := PackedStringArray()
	for control in dock.find_children("*", "Control", true, false):
		var is_input := control is Button or control is SpinBox or control is OptionButton or control is CheckButton
		if not is_input or control.name == "Header" or control.name == "BringBackButton":
			continue
		# The internals of a SpinBox and the controls inside a Godot dialog are not the plugin's.
		var inside_other_control := false
		var ancestor := control.get_parent()
		while ancestor != null and ancestor != dock:
			if ancestor is SpinBox or ancestor is Window or ancestor is ItemList:
				inside_other_control = true
			ancestor = ancestor.get_parent()
		if inside_other_control:
			continue
		if (control as Control).tooltip_text.is_empty():
			missing.append(str(dock.get_path_to(control)))
	assert_array(Array(missing)).override_failure_message("controls without a tooltip: %s" % ", ".join(missing)).is_empty()
	dock.queue_free()


func test_the_section_titles_show_counts_that_follow_the_document() -> void:
	var dock := await _dock_with_illustration()
	VILLAGE.author_regions(dock)
	dock._canvas.action_zone_created.emit(PackedVector2Array([Vector2(1380, 540), Vector2(1480, 540), Vector2(1480, 620)]))
	dock._canvas.entry_point_created.emit(Vector2(300, 800))
	var actions := dock.get_section("Action zones and entry points") as IWECollapsibleSection
	assert_str(actions.get_badge()).is_equal("1 zone, 1 entry")
	assert_str((dock.get_section("Regions") as IWECollapsibleSection).get_badge()).is_equal("4")
	actions.set_expanded(false)
	assert_str(actions._header.text).override_failure_message("the count stays visible when folded").contains("1 zone, 1 entry")
	dock._undo()
	assert_str(actions.get_badge()).override_failure_message("the badge follows Undo").is_equal("1 zone, 0 entries")
	dock.queue_free()


func test_the_status_line_explains_the_active_tool() -> void:
	var dock := await _dock_with_illustration()
	dock._create_group_named("Ground")
	dock._set_action_tool(CANVAS_SCRIPT.ACTION_TOOL_ZONE_DRAW)
	assert_str(dock._status_label.text).contains("Action zone").contains("first corner")
	dock._set_action_tool(CANVAS_SCRIPT.ACTION_TOOL_ENTRY)
	assert_str(dock._status_label.text).contains("Entry point").contains("click the floor")
	dock._set_action_tool(CANVAS_SCRIPT.ACTION_TOOL_ZONE_SELECT)
	assert_str(dock._status_label.text).contains("Select zone")
	dock._set_action_tool("")
	dock._draw_button.button_pressed = true
	assert_str(dock._status_label.text).contains("Polygon").contains("Enter")
	dock.queue_free()


func test_an_action_tool_is_refused_with_a_reason_when_there_is_no_illustration() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	dock._set_action_tool(CANVAS_SCRIPT.ACTION_TOOL_ZONE_DRAW)
	assert_str(dock._canvas.get_action_tool()).override_failure_message("nothing to draw on").is_empty()
	assert_bool(dock._action_panel._draw_zone_button.button_pressed).is_false()
	assert_str(dock._status_label.text).contains("Import an illustration")
	dock.queue_free()


func test_drawing_a_polygon_without_a_group_says_what_is_missing() -> void:
	var dock := await _dock_with_illustration()
	dock._draw_button.button_pressed = true
	assert_bool(dock._draw_button.button_pressed).is_false()
	assert_str(dock._status_label.text).contains("group")
	dock.queue_free()

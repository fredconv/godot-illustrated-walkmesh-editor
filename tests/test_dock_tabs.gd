extends GdUnitTestSuite

## M5: the dock has two tabs, Creation and Test, each made of foldable sections. The controls are the
## ones that were already there; this suite checks where they live and that the tabs behave.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")


func _dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	return dock


func _tab_of(dock: Control, control: Node) -> String:
	var node := control
	while node != null and node != dock:
		if node.get_parent() == dock._dock_tabs:
			return node.name
		node = node.get_parent()
	return ""


func _section_of(control: Node) -> String:
	var node := control
	while node != null:
		if node is IWECollapsibleSection:
			return node.get_title()
		node = node.get_parent()
	return ""


func test_the_dock_has_a_creation_tab_and_a_test_tab() -> void:
	var dock := await _dock()
	var tabs: TabContainer = dock._dock_tabs
	assert_int(tabs.get_tab_count()).is_equal(2)
	assert_str(tabs.get_tab_title(0)).is_equal("Creation")
	assert_str(tabs.get_tab_title(1)).is_equal("Test")
	assert_object(dock.get_node_or_null("Workspace/Sidebar")).override_failure_message("the old single sidebar is gone").is_null()
	dock.queue_free()


func test_creation_holds_pictures_regions_tools_references_and_the_camera() -> void:
	var dock := await _dock()
	var expected := {
		"Layers and pictures": [dock._layer_panel],
		"Regions": [dock._region_list, dock._duplicate_button, dock._delete_button, dock._visibility_button],
		"Drawing tools": [dock._select_button, dock._draw_button, dock._points_button, dock._subtract_button, dock._add_point_button, dock._remove_point_button],
		"Height references": [dock._template_mode_button, dock._template_height_input, dock._delete_template_button],
		"Camera and perspective": [dock._camera_fov_input, dock._fit_references_button, dock._fit_report_label, dock._reference_width_input],
	}
	for section in expected:
		for control in expected[section]:
			assert_str(_tab_of(dock, control)).override_failure_message("%s is not in the Creation tab" % control.name).is_equal("Creation")
			assert_str(_section_of(control)).override_failure_message("%s is in the wrong section" % control.name).is_equal(section)
	dock.queue_free()


func test_test_holds_the_character_the_speed_controls_export_and_validation() -> void:
	var dock := await _dock()
	var expected := {
		"Test character": [dock._perspective_top_view_button, dock._test_walk_button, dock._base_speed_input, dock._pause_button, dock._reset_walker_button, dock._speed_buttons[0], dock._speed_buttons[3]],
		"Export": [dock._export_perspective_button, dock._export_2d_button, dock._export_3d_button, dock._add_player_input, dock._add_camera],
		"Validation": [dock._check_export_button, dock._validation_label],
	}
	for section in expected:
		for control in expected[section]:
			assert_str(_tab_of(dock, control)).override_failure_message("%s is not in the Test tab" % control.name).is_equal("Test")
			assert_str(_section_of(control)).override_failure_message("%s is in the wrong section" % control.name).is_equal(section)
	dock.queue_free()


func test_a_section_folds_and_unfolds_from_its_header() -> void:
	var dock := await _dock()
	var section: IWECollapsibleSection = dock.get_section("Drawing tools")
	assert_bool(section.is_expanded()).is_true()
	var header: Button = section.get_node("Header")
	assert_str(header.text).contains("Drawing tools").contains("▾")
	header.button_pressed = false
	assert_bool(section.is_expanded()).is_false()
	assert_bool(section.content.visible).is_false()
	assert_str(header.text).contains("▸")
	header.button_pressed = true
	assert_bool(section.content.visible).is_true()
	dock.queue_free()


func test_folding_a_section_does_not_disable_its_controls() -> void:
	var dock := await _dock()
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock.get_section("Drawing tools").set_expanded(false)
	dock._draw_button.button_pressed = true
	assert_bool(dock._draw_button.button_pressed).is_true()
	dock.get_section("Drawing tools").set_expanded(true)
	assert_bool(dock._draw_button.button_pressed).is_true()
	dock.queue_free()


func test_opening_the_test_tab_turns_perspective_on_and_leaving_it_keeps_it() -> void:
	var dock := await _dock()
	VILLAGE.import_background(dock)
	assert_bool(dock._perspective_mode).is_false()
	dock.select_tab(1)
	assert_bool(dock._perspective_mode).override_failure_message("the test tab needs the preview").is_true()
	dock.select_tab(0)
	assert_bool(dock._perspective_mode).is_true()
	dock.queue_free()


func test_without_an_illustration_the_test_tab_does_not_force_perspective() -> void:
	var dock := await _dock()
	dock.select_tab(1)
	assert_bool(dock._perspective_mode).is_false()
	dock.queue_free()


func test_the_camera_section_explains_how_to_turn_perspective_on() -> void:
	var dock := await _dock()
	var hint: Label = dock._camera_hint_label
	assert_bool(hint.visible).is_true()
	assert_bool(dock._perspective_panel.visible).is_false()
	dock._set_perspective_mode(true)
	assert_bool(hint.visible).is_false()
	assert_bool(dock._perspective_panel.visible).is_true()
	dock._set_perspective_mode(false)
	assert_bool(hint.visible).is_true()
	dock.queue_free()


func test_the_dock_fits_a_narrow_panel() -> void:
	var dock := await _dock()
	var minimum := dock.get_combined_minimum_size()
	assert_float(minimum.x).override_failure_message("minimum width %.0f px" % minimum.x).is_less_equal(520.0)
	dock.queue_free()


func test_validation_reports_a_zone_the_export_would_drop() -> void:
	var dock := await _dock()
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock._canvas.scale_anchor_created.emit(Vector2(300, 900), 200.0)
	dock._canvas.scale_anchor_created.emit(Vector2(1000, 500), 76.9)
	dock._fit_camera_to_references()
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.YARD))
	dock._check_export_button.pressed.emit()
	assert_str(dock._validation_label.text).is_equal("No problem found.")
	var horizon: float = dock._document.perspective_calibration.horizon_image_row(dock._document.image_size)
	dock._canvas.region_created.emit(PackedVector2Array([Vector2(100, 20), Vector2(300, 20), Vector2(300, horizon - 10.0), Vector2(100, horizon - 10.0)]))
	dock._check_export_button.pressed.emit()
	assert_str(dock._validation_label.text).contains("horizon").contains("was not exported")
	dock.queue_free()


func test_validation_needs_an_illustration() -> void:
	var dock := await _dock()
	dock._check_export_button.pressed.emit()
	assert_str(dock._validation_label.text).contains("Import an illustration")
	dock.queue_free()


func test_validation_writes_no_file_and_changes_nothing() -> void:
	var dock := await _dock()
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.YARD))
	dock._canvas.scale_anchor_created.emit(Vector2(300, 900), 200.0)
	dock._canvas.scale_anchor_created.emit(Vector2(1000, 500), 76.9)
	dock._fit_camera_to_references()
	var before := var_to_str([dock._document.regions, dock._document.scale_anchors, dock._document.layers])
	var dirty_before: bool = dock.is_dirty()
	dock._check_export_button.pressed.emit()
	assert_str(var_to_str([dock._document.regions, dock._document.scale_anchors, dock._document.layers])).is_equal(before)
	assert_bool(dock.is_dirty()).is_equal(dirty_before)
	dock.queue_free()

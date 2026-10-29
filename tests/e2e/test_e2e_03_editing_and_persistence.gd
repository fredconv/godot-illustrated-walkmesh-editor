extends GdUnitTestSuite
## End-to-end scenario "village + fountain", part 3: selection, editing, undo/redo, save and reopen.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
## A user:// folder: a picture copied into res:// is only loadable once the editor has imported it.
const SAVE_FOLDER := "user://iwe_e2e_village"
const FLOOR_PROBES := [Vector2(300, 600), Vector2(800, 700), Vector2(1300, 590), Vector2(1000, 350)]


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(SAVE_FOLDER))


func _authored_dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	return dock


## Everything that is saved about the regions, as plain values that can be compared.
func _signature(dock: Control) -> Array:
	var result := []
	for region in dock._document.regions:
		result.append([region.id, region.name, region.group_id, region.visible, var_to_str(region.points), var_to_str(region.subtraction_polygons), var_to_str(region.subtraction_names)])
	return result


func test_selecting_a_region_selects_it_on_the_canvas_and_in_the_dock() -> void:
	var dock := await _authored_dock()
	var bridge: IWERegion = dock._document.regions[2]
	dock._select_region(bridge.id)
	assert_str(dock._canvas.get_selected_region().id).is_equal(bridge.id)
	dock._select_region("")
	assert_object(dock._canvas.get_selected_region()).is_null()
	dock.queue_free()


func test_moving_a_vertex_then_undo_and_redo_restore_exact_points() -> void:
	var dock := await _authored_dock()
	var yard: IWERegion = dock._document.regions[0]
	dock._select_region(yard.id)
	var before := yard.points.duplicate()
	var after := before.duplicate()
	after[2] += Vector2(30, -20)
	dock._canvas.commit_vertex_move(yard.id, before, after)
	assert_array(dock._document.regions[0].points).is_equal(after)
	dock._undo()
	assert_array(dock._document.regions[0].points).is_equal(before)
	dock._redo()
	assert_array(dock._document.regions[0].points).is_equal(after)
	dock.queue_free()


func test_adding_and_removing_a_vertex_on_an_edge() -> void:
	var dock := await _authored_dock()
	var yard: IWERegion = dock._document.regions[0]
	dock._select_region(yard.id)
	dock._canvas.add_selected_vertex(Vector2(280, 301))
	assert_int(dock._document.regions[0].points.size()).is_equal(5)
	assert_vector(dock._document.regions[0].points[1]).is_equal_approx(Vector2(280, 300), Vector2(0.01, 0.01))
	dock._canvas.set_selected_vertex(1)
	dock._canvas.remove_selected_vertex()
	assert_int(dock._document.regions[0].points.size()).is_equal(4)
	dock._undo()
	dock._undo()
	assert_array(dock._document.regions[0].points).is_equal(VILLAGE.points(VILLAGE.YARD))
	dock.queue_free()


func test_a_polygon_cannot_lose_its_third_vertex() -> void:
	var dock := await _authored_dock()
	var triangle := PackedVector2Array([Vector2(100, 100), Vector2(200, 100), Vector2(150, 200)])
	dock._canvas.region_created.emit(triangle)
	var region: IWERegion = dock._document.regions.back()
	dock._select_region(region.id)
	dock._canvas.set_selected_vertex(0)
	dock._canvas.remove_selected_vertex()
	assert_int(region.points.size()).is_equal(3)
	dock.queue_free()


func test_delete_and_undo_bring_back_the_same_region_with_its_cutouts() -> void:
	var dock := await _authored_dock()
	var before := _signature(dock)
	var crossroads: IWERegion = dock._document.regions[1]
	dock._select_region(crossroads.id)
	dock._delete_selected_region()
	assert_int(dock._document.regions.size()).is_equal(3)
	dock._undo()
	assert_int(dock._document.regions.size()).is_equal(4)
	var restored: IWERegion = dock._find_region(crossroads.id)
	assert_object(restored).is_not_null()
	assert_int(restored.subtraction_polygons.size()).is_equal(2)
	assert_array(restored.points).is_equal(VILLAGE.points(VILLAGE.CROSSROADS))
	# Undoing a deletion restores the region at the end of the list: its content is identical.
	var after := _signature(dock)
	after.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
	before.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
	assert_array(after).is_equal(before)
	dock.queue_free()


func test_rename_and_visibility_are_undoable() -> void:
	var dock := await _authored_dock()
	var yard: IWERegion = dock._document.regions[0]
	dock._rename_region(yard.id, "Cour")
	assert_str(yard.name).is_equal("Cour")
	dock._select_region(yard.id)
	dock._toggle_selected_visibility()
	assert_bool(yard.visible).is_false()
	dock._undo()
	assert_bool(yard.visible).is_true()
	dock._undo()
	assert_str(yard.name).is_equal("Region 1")
	dock.queue_free()


func test_the_whole_authoring_session_undoes_back_to_an_empty_illustrated_document() -> void:
	var dock := await _authored_dock()
	var guard := 0
	while dock._history.has_undo() and guard < 50:
		dock._undo()
		guard += 1
	assert_int(dock._document.regions.size()).is_equal(0)
	assert_int(dock._document.scale_anchors.size()).is_equal(0)
	assert_str(dock._document.illustration_path.get_file()).override_failure_message("the first import is not undoable").is_equal("background_template.png")
	assert_bool(dock.is_dirty()).override_failure_message("the import keeps the document modified").is_true()
	while dock._history.has_redo() and guard < 100:
		dock._redo()
		guard += 1
	assert_int(dock._document.regions.size()).is_equal(4)
	assert_int(dock._document.scale_anchors.size()).is_equal(2)
	dock.queue_free()


func test_duplicating_a_region_with_cutouts_currently_leaves_the_cutouts_in_place() -> void:
	# Known defect P1-10: the copy's outline is moved by 16 px but its cutouts are not, so the
	# holes no longer sit where they were drawn. Flip this assertion when P1-10 is fixed.
	var dock := await _authored_dock()
	var crossroads: IWERegion = dock._document.regions[1]
	dock._select_region(crossroads.id)
	dock._duplicate_selected_region()
	var copy: IWERegion = dock._document.regions.back()
	assert_vector(copy.points[0] - crossroads.points[0]).is_equal(Vector2(16, 16))
	assert_array(copy.subtraction_polygons[0]).override_failure_message("P1-10 fixed? update this test").is_equal(crossroads.subtraction_polygons[0])
	dock.queue_free()


func test_save_and_reopen_in_a_fresh_dock_restores_everything() -> void:
	var dock := await _authored_dock()
	dock._canvas.set_selected_vertex(-1)
	dock._set_calibration_fov(58.0)
	var expected_regions := _signature(dock)
	var expected_calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var expected_floor: Array = []
	for probe in FLOOR_PROBES:
		expected_floor.append(VILLAGE.floor_world(probe, expected_calibration))

	var folder := SAVE_FOLDER
	var target := folder.path_join("village.tres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	dock._pending_document_path = target
	dock._copy_image_into_document(folder)
	assert_bool(FileAccess.file_exists(target)).is_true()
	assert_bool(dock.is_dirty()).override_failure_message("saving clears the modified mark").is_false()
	assert_str(dock._document.illustration_path).override_failure_message("the picture is copied beside the document").starts_with("assets/illustration_")
	assert_bool(FileAccess.file_exists(folder.path_join(dock._document.illustration_path))).is_true()
	dock.queue_free()
	await get_tree().process_frame

	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(target)
	assert_bool(reopened._has_illustration).override_failure_message("the copied picture loads").is_true()
	assert_vector(reopened._document.image_size).is_equal(VILLAGE.IMAGE_SIZE)
	assert_array(_signature(reopened)).is_equal(expected_regions)
	assert_int(reopened._document.scale_anchors.size()).is_equal(2)
	assert_float(reopened._document.perspective_calibration.field_of_view_degrees).is_equal(58.0)
	for index in FLOOR_PROBES.size():
		assert_vector(VILLAGE.floor_world(FLOOR_PROBES[index], reopened._document.perspective_calibration)).is_equal_approx(expected_floor[index], Vector3.ONE * 0.0001)
	assert_bool(reopened.is_dirty()).override_failure_message("a freshly opened document is clean").is_false()
	reopened.queue_free()

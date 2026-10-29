extends GdUnitTestSuite

## Regression tests for perspective calibration stability (audit P1-4).
## The reference viewport is part of the calibration. Resizing or detaching the editor, zooming,
## or changing the editor resolution must never change it, and so never move the projection.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const OLD_DOCUMENT := "res://tests/fixtures/iwe_document_old_panel_reference.tres"
const ILLUSTRATION := "res://assets/img/background.png"
const SAVE_FOLDER := "user://iwe_stability_tests"
const IMAGE := Vector2i(1672, 941)
## Numeric tolerance for floor coordinates, in floor units (the scene is 1000s of units wide).
const TOLERANCE := 0.001
## Relative error of the fitted camera's apparent heights, measured at the anchors on 2026-10-29
## with the default 1280x720 reference: 2.54 % for both anchors (one above, one below). The fit is
## a least-squares line of height against screen row, while the camera's real apparent height is
## not exactly linear in row, so the error is a property of the fit model, not noise. 2.6 % is
## just above that measured maximum. It is a regression bound, not a precision claim: a change that
## makes the fit worse than this must be looked at.
const FIT_TOLERANCE := 0.026
const PANEL_SIZES := [Vector2(380, 900), Vector2(1200, 500), Vector2(240, 240), Vector2(900, 700)]
const PROBE_POINTS := [Vector2(836, 700), Vector2(200, 900), Vector2(1400, 500), Vector2(836, 470)]


func after_test() -> void:
	var folder := ProjectSettings.globalize_path(SAVE_FOLDER)
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file_name))
		DirAccess.remove_absolute(folder)


# ---- helpers ------------------------------------------------------------------------------


func _calibration(reference: Vector2i) -> IWEPerspectiveCalibration:
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.new()
	calibration.field_of_view_degrees = 45.0
	calibration.camera_position = Vector3(836.0, 1200.0, 1458.55)
	calibration.camera_rotation_degrees = Vector3(-44.6, 0.0, 0.0)
	calibration.floor_height = 0.0
	calibration.character_height_units = 150.0
	calibration.reference_viewport_size = reference
	return calibration


func _floor(calibration: IWEPerspectiveCalibration, image_point: Vector2) -> Vector3:
	var floor_point: Variant = PROJECTOR.image_point_to_floor(image_point, IMAGE, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	return floor_point


func _snapshot(calibration: IWEPerspectiveCalibration) -> Dictionary:
	return {
		"fov": calibration.field_of_view_degrees,
		"position": calibration.camera_position,
		"rotation": calibration.camera_rotation_degrees,
		"floor": calibration.floor_height,
		"character": calibration.character_height_units,
		"reference": calibration.reference_viewport_size,
	}


func _floors(calibration: IWEPerspectiveCalibration) -> Array:
	var points := []
	for probe in PROBE_POINTS:
		points.append(_floor(calibration, probe))
	return points


func _assert_floors_equal(actual: Array, expected: Array, message: String) -> void:
	for index in expected.size():
		assert_float(actual[index].distance_to(expected[index])).override_failure_message("%s (point %d moved)" % [message, index]).is_less(TOLERANCE)


## A dock in perspective mode on a freshly imported illustration, treated as saved.
func _make_dock_in_perspective_mode() -> Control:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.add_group(GROUP_SCRIPT.create_group("Path"))
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(document)
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	await get_tree().process_frame
	dock._load_illustration(ProjectSettings.globalize_path(ILLUSTRATION))
	dock._history.mark_saved()
	dock._set_perspective_mode(true)
	return dock


func _resize_dock(dock: Control, panel_size: Vector2) -> void:
	dock.size = panel_size
	for _frame in 4:
		await get_tree().process_frame


# ---- the pure maths -----------------------------------------------------------------------


func test_projection_depends_only_on_the_aspect_of_the_reference_not_its_pixel_size() -> void:
	var full := _calibration(Vector2i(1280, 720))
	var half := _calibration(Vector2i(640, 360))
	var tall := _calibration(Vector2i(440, 790))
	for probe in PROBE_POINTS:
		assert_float(_floor(full, probe).distance_to(_floor(half, probe))).override_failure_message("same aspect, other size").is_less(TOLERANCE)
	assert_float(_floor(full, PROBE_POINTS[0]).distance_to(_floor(tall, PROBE_POINTS[0]))).override_failure_message("another aspect is another projection").is_greater(1.0)


func test_golden_floor_points_for_a_wide_and_a_portrait_reference() -> void:
	# Captured from the projector before this change; they pin the maths for old documents.
	var wide := _calibration(Vector2i(1280, 720))
	var wide_expected := [Vector3(836.0, 0.0, 649.8262), Vector3(144.3085, 0.0, 906.9296), Vector3(1662.8060, 0.0, 303.2675), Vector3(836.0, 0.0, 240.6050)]
	_assert_floors_equal(_floors(wide), wide_expected, "wide reference")
	var portrait := _calibration(Vector2i(432, 905))
	var portrait_expected := [Vector3(836.0, 0.0, 366.8997), Vector3(602.9333, 0.0, 465.8350), Vector3(1062.3705, 0.0, 258.5396), Vector3(836.0, 0.0, 241.3889)]
	_assert_floors_equal(_floors(portrait), portrait_expected, "portrait reference")


func test_display_transform_centres_letterboxes_and_round_trips() -> void:
	var reference := Vector2i(1280, 720)
	var panel := Vector2(1000, 1000)
	# The reference centre sits at the panel centre whatever the panel shape.
	assert_vector(PROJECTOR.panel_to_reference(panel * 0.5, panel, reference)).is_equal_approx(Vector2(640, 360), Vector2(0.001, 0.001))
	# Wide frame in a square panel: letterbox bars above and below (fit scale 0.78125, offset y 218.75).
	var fit: Dictionary = PROJECTOR.panel_fit(panel, reference)
	assert_float(fit.scale).is_equal_approx(0.78125, 0.00001)
	assert_vector(fit.offset).is_equal_approx(Vector2(0.0, 218.75), Vector2(0.001, 0.001))
	assert_vector(PROJECTOR.panel_to_reference(Vector2(0, 218.75), panel, reference)).is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))
	for point in [Vector2(10, 20), Vector2(1270, 700), Vector2(640, 360)]:
		var back: Vector2 = PROJECTOR.reference_to_panel(PROJECTOR.panel_to_reference(point, panel, reference), panel, reference)
		assert_vector(back).is_equal_approx(point, Vector2(0.001, 0.001))
	# An unusable panel never produces a position.
	assert_vector(PROJECTOR.panel_to_reference(Vector2(5, 5), Vector2.ZERO, reference)).is_equal(Vector2.ZERO)


# ---- the dock never writes the calibration ------------------------------------------------


func test_resizing_the_dock_never_changes_the_calibration_or_the_projection() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var before := _snapshot(calibration)
	var floors_before := _floors(calibration)
	for panel_size in PANEL_SIZES:
		await _resize_dock(dock, panel_size)
		assert_dict(_snapshot(dock._document.perspective_calibration)).override_failure_message("calibration after resizing to %s" % panel_size).is_equal(before)
		_assert_floors_equal(_floors(dock._document.perspective_calibration), floors_before, "after resizing to %s" % panel_size)
		assert_bool(dock.is_dirty()).override_failure_message("a resize is not an edit (%s)" % panel_size).is_false()
	dock.queue_free()


func test_detaching_and_reattaching_the_editor_never_changes_the_calibration() -> void:
	var dock := await _make_dock_in_perspective_mode()
	await _resize_dock(dock, Vector2(900, 700))
	var before := _snapshot(dock._document.perspective_calibration)
	var floors_before := _floors(dock._document.perspective_calibration)
	dock._canvas_window_button.set_pressed(true)
	for _frame in 6:
		await get_tree().process_frame
	assert_dict(_snapshot(dock._document.perspective_calibration)).override_failure_message("detached").is_equal(before)
	assert_bool(dock.is_dirty()).is_false()
	dock._canvas_window_button.set_pressed(false)
	for _frame in 6:
		await get_tree().process_frame
	assert_dict(_snapshot(dock._document.perspective_calibration)).override_failure_message("reattached").is_equal(before)
	_assert_floors_equal(_floors(dock._document.perspective_calibration), floors_before, "after detach and reattach")
	assert_bool(dock.is_dirty()).is_false()
	dock.queue_free()


func test_changing_the_zoom_does_not_touch_the_calibration() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var before := _snapshot(dock._document.perspective_calibration)
	dock._change_zoom(2.0)
	dock._change_zoom(0.25)
	await get_tree().process_frame
	assert_dict(_snapshot(dock._document.perspective_calibration)).is_equal(before)
	assert_bool(dock.is_dirty()).is_false()
	dock.queue_free()


func test_a_new_document_takes_the_game_window_as_its_reference_not_the_panel() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var game_window: Vector2i = CALIBRATION_SCRIPT.project_viewport_size()
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).is_equal(game_window)
	await _resize_dock(dock, Vector2(300, 900))
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).is_equal(game_window)
	dock.queue_free()


# ---- saving, reopening, and old documents -------------------------------------------------


func test_save_and_reopen_keep_the_projection() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var calibration: IWEPerspectiveCalibration = _calibration(Vector2i(1000, 640))
	dock._document.perspective_calibration = calibration
	var floors_before := _floors(calibration)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_FOLDER))
	var path := SAVE_FOLDER.path_join("saved.tres")
	assert_int(ResourceSaver.save(dock._document, path)).is_equal(OK)
	await _resize_dock(dock, Vector2(380, 900))
	dock._open_document(path)
	await get_tree().process_frame
	var reopened: IWEPerspectiveCalibration = dock._document.perspective_calibration
	assert_vector(reopened.reference_viewport_size).is_equal(Vector2i(1000, 640))
	_assert_floors_equal(_floors(reopened), floors_before, "after save and reopen")
	dock.queue_free()


func test_an_old_document_keeps_its_projection_and_its_file_is_never_rewritten() -> void:
	var md5_before := FileAccess.get_md5(OLD_DOCUMENT)
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new())
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	await get_tree().process_frame
	dock._open_document(OLD_DOCUMENT)
	await get_tree().process_frame
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	# The stored reference is honoured as it is; nothing replaces it with a new value.
	assert_vector(calibration.reference_viewport_size).is_equal(Vector2i(432, 905))
	var golden := [Vector3(836.0, 0.0, 366.8997), Vector3(602.9333, 0.0, 465.8350), Vector3(1062.3705, 0.0, 258.5396), Vector3(836.0, 0.0, 241.3889)]
	_assert_floors_equal(_floors(calibration), golden, "old document right after opening")
	assert_bool(dock.is_dirty()).override_failure_message("opening is not a change").is_false()
	dock._set_perspective_mode(true)
	for panel_size in PANEL_SIZES:
		await _resize_dock(dock, panel_size)
		assert_vector(dock._document.perspective_calibration.reference_viewport_size).override_failure_message("old reference after %s" % panel_size).is_equal(Vector2i(432, 905))
		_assert_floors_equal(_floors(dock._document.perspective_calibration), golden, "old document after resizing to %s" % panel_size)
	assert_bool(dock.is_dirty()).is_false()
	assert_str(FileAccess.get_md5(OLD_DOCUMENT)).override_failure_message("the original file must not change").is_equal(md5_before)
	dock.queue_free()


# ---- template sizes and exports -----------------------------------------------------------


func test_template_apparent_heights_stay_coherent_when_the_panel_changes() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var anchors: Array = [ANCHOR_SCRIPT.create_anchor(Vector2(400, 880), 220.0), ANCHOR_SCRIPT.create_anchor(Vector2(1200, 540), 110.0)]
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	assert_str(calibration.fit_to_scale_anchors(anchors, IMAGE)).is_empty()
	var reference := calibration.reference_viewport_size
	var fit_scale: float = PROJECTOR.image_scale_in_viewport(IMAGE, reference)
	var heights_before := []
	for anchor in anchors:
		var feet: Vector2 = PROJECTOR.image_to_viewport(anchor.position, IMAGE, reference)
		var apparent: float = calibration._apparent_height_at(feet, reference, PROJECTOR)
		heights_before.append(apparent)
		# The fitted camera reproduces the authored apparent height within FIT_TOLERANCE.
		assert_float(apparent).override_failure_message("fitted height of %s" % anchor.position).is_equal_approx(anchor.apparent_height_px * fit_scale, anchor.apparent_height_px * fit_scale * FIT_TOLERANCE)
	for panel_size in PANEL_SIZES:
		await _resize_dock(dock, panel_size)
		for index in anchors.size():
			var feet: Vector2 = PROJECTOR.image_to_viewport(anchors[index].position, IMAGE, dock._document.perspective_calibration.reference_viewport_size)
			var apparent: float = dock._document.perspective_calibration._apparent_height_at(feet, dock._document.perspective_calibration.reference_viewport_size, PROJECTOR)
			assert_float(apparent).override_failure_message("height %d after %s" % [index, panel_size]).is_equal_approx(heights_before[index], 0.0001)
	dock.queue_free()


func test_perspective_export_projects_through_the_stored_reference_whatever_the_dock_does() -> void:
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new())
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	await get_tree().process_frame
	dock._open_document(OLD_DOCUMENT)
	dock._set_perspective_mode(true)
	await _resize_dock(dock, Vector2(380, 900))
	await _resize_dock(dock, Vector2(1200, 500))
	var document: Resource = dock._document
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	assert_vector(calibration.reference_viewport_size).override_failure_message("the stored reference survived the dock").is_equal(Vector2i(432, 905))
	var texture := load(ILLUSTRATION) as Texture2D
	var stage: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01)
	assert_object(stage).is_not_null()
	var regions := stage.find_children("*", "NavigationRegion3D", true, false)
	assert_int(regions.size()).is_equal(1)
	var vertices: PackedVector3Array = regions[0].navigation_mesh.get_vertices()
	# Every corner of the authored polygon must appear on the floor where the *stored* reference puts it.
	for corner in document.regions[0].points:
		var expected := _floor(calibration, corner)
		var found := false
		for vertex in vertices:
			if Vector2(vertex.x, vertex.z).distance_to(Vector2(expected.x, expected.z)) < 0.01:
				found = true
				break
		assert_bool(found).override_failure_message("corner %s on the floor" % corner).is_true()
	# Calibration templates stand where the same reference puts their feet.
	for anchor in document.scale_anchors:
		var template: Node3D = null
		for node in stage.find_children("*", "Node3D", true, false):
			if node.has_meta("iwe_anchor_id") and node.get_meta("iwe_anchor_id") == anchor.id:
				template = node
		assert_object(template).is_not_null()
		var expected_feet := _floor(calibration, anchor.position)
		assert_float(Vector2(template.position.x, template.position.z).distance_to(Vector2(expected_feet.x, expected_feet.z))).is_less(0.01)
	stage.free()
	dock.queue_free()


# ---- deliberate edits and the display transform -------------------------------------------


func test_editing_the_reference_is_deliberate_undoable_and_changes_the_projection() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var original: Vector2i = calibration.reference_viewport_size
	var floors_before := _floors(calibration)
	dock._set_reference_viewport_axis(float(original.x) * 0.8, 0)
	assert_bool(dock.is_dirty()).is_true()
	assert_int(dock._document.perspective_calibration.reference_viewport_size.x).is_equal(roundi(original.x * 0.8))
	assert_float(_floor(dock._document.perspective_calibration, PROBE_POINTS[0]).distance_to(floors_before[0])).override_failure_message("a new reference is a new projection").is_greater(1.0)
	assert_float(dock._reference_width_input.value).is_equal(float(roundi(original.x * 0.8)))
	# The panel follows the new shape of the frame.
	assert_float(dock._perspective_preview_frame.ratio).is_equal_approx(float(roundi(original.x * 0.8)) / float(original.y), 0.001)
	dock._undo()
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).is_equal(original)
	assert_bool(dock.is_dirty()).is_false()
	_assert_floors_equal(_floors(dock._document.perspective_calibration), floors_before, "after undoing the edit")
	dock.queue_free()


## Arrow clicks and drags emit one value_changed per step. Consecutive steps must undo as one entry.
func test_a_run_of_reference_steps_is_a_single_undo_entry() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var original: Vector2i = dock._document.perspective_calibration.reference_viewport_size
	for step in 5:
		dock._set_reference_viewport_axis(float(original.x + 10 * (step + 1)), 0)
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).is_equal(Vector2i(original.x + 50, original.y))
	dock._undo()
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).override_failure_message("one undo must restore the value before the whole run").is_equal(original)
	assert_bool(dock._history.has_undo()).override_failure_message("the run must not leave one entry per step").is_false()
	assert_bool(dock.is_dirty()).is_false()
	dock.queue_free()


## A field change between two reference steps must not be folded into them.
func test_a_field_change_between_reference_steps_is_not_merged() -> void:
	var dock := await _make_dock_in_perspective_mode()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var original_reference := calibration.reference_viewport_size
	var original_fov: float = calibration.field_of_view_degrees
	dock._set_reference_viewport_axis(float(original_reference.x + 20), 0)
	dock._set_calibration_value("field_of_view_degrees", original_fov + 5.0)
	dock._set_reference_viewport_axis(float(original_reference.x + 40), 0)
	dock._undo()
	assert_float(dock._document.perspective_calibration.field_of_view_degrees).override_failure_message("undoing the last reference step must not revert the field").is_equal_approx(original_fov + 5.0, TOLERANCE)
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).is_equal(Vector2i(original_reference.x + 20, original_reference.y))
	dock._undo()
	assert_float(dock._document.perspective_calibration.field_of_view_degrees).override_failure_message("the field change undoes on its own").is_equal_approx(original_fov, TOLERANCE)
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).is_equal(Vector2i(original_reference.x + 20, original_reference.y))
	dock._undo()
	assert_vector(dock._document.perspective_calibration.reference_viewport_size).is_equal(original_reference)
	assert_bool(dock._history.has_undo()).is_false()
	dock.queue_free()


func test_a_click_in_the_preview_maps_through_the_reference_for_any_panel_shape() -> void:
	var dock := await _make_dock_in_perspective_mode()
	for panel_size in PANEL_SIZES:
		await _resize_dock(dock, panel_size)
		var preview: SubViewportContainer = dock._perspective_preview
		var clicked := []
		var capture := func(point: Vector2) -> void: clicked.append(point)
		preview.image_point_clicked.connect(capture)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = preview.size * 0.5
		preview._gui_input(click)
		preview.image_point_clicked.disconnect(capture)
		assert_int(clicked.size()).override_failure_message("a click at the centre lands on the image (%s)" % panel_size).is_equal(1)
		assert_vector(clicked[0]).is_equal_approx(Vector2(IMAGE) * 0.5, Vector2(1.0, 1.0))
	dock.queue_free()

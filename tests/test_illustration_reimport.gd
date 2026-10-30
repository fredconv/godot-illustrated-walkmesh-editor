extends GdUnitTestSuite
## Audit P1-5: replacing the illustration of a document must not overwrite its calibration.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const ORIGINAL_IMAGE := "res://assets/img/background.png"
const FOLDER := "user://iwe_reimport_tests"
const TOLERANCE := 0.0001


func after_test() -> void:
	var folder := ProjectSettings.globalize_path(FOLDER)
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file_name))
		DirAccess.remove_absolute(folder)


# ---- helpers ------------------------------------------------------------------------------


## Writes a plain image of the given size and returns its absolute path.
func _make_image(file_name: String, image_size: Vector2i, color: Color) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var path := ProjectSettings.globalize_path(FOLDER).path_join(file_name)
	assert_int(image.save_png(path)).is_equal(OK)
	return path


## A saved-looking dock with an illustration, a custom calibration, a region and templates.
func _make_authored_dock() -> Control:
	var document: Resource = DOCUMENT_SCRIPT.new()
	var group: Resource = GROUP_SCRIPT.create_group("Path")
	document.add_group(group)
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(document)
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	await get_tree().process_frame
	dock._load_illustration(ProjectSettings.globalize_path(ORIGINAL_IMAGE))
	var region: Resource = REGION_SCRIPT.new()
	region.group_id = group.id
	region.name = "Chemin"
	region.points = PackedVector2Array([Vector2(400, 520), Vector2(1200, 520), Vector2(1300, 900), Vector2(300, 900)])
	dock._document.add_region(region)
	dock._document.scale_anchors.append(ANCHOR_SCRIPT.create_anchor(Vector2(400, 880), 220.0))
	dock._document.scale_anchors.append(ANCHOR_SCRIPT.create_anchor(Vector2(1200, 540), 110.0))
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	calibration.field_of_view_degrees = 52.0
	calibration.camera_position = Vector3(900.0, 1100.0, 1300.0)
	calibration.camera_rotation_degrees = Vector3(-41.0, 3.0, 0.0)
	calibration.floor_height = 12.0
	calibration.character_height_units = 140.0
	calibration.reference_viewport_size = Vector2i(1600, 900)
	dock._history.mark_saved()
	return dock


func _authored(dock: Control) -> Dictionary:
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var region: Resource = dock._document.regions[0]
	var anchors := []
	for anchor in dock._document.scale_anchors:
		anchors.append([anchor.position, anchor.apparent_height_px])
	return {
		"fov": calibration.field_of_view_degrees,
		"position": calibration.camera_position,
		"rotation": calibration.camera_rotation_degrees,
		"floor": calibration.floor_height,
		"character": calibration.character_height_units,
		"reference": calibration.reference_viewport_size,
		"points": region.points.duplicate(),
		"region_count": dock._document.regions.size(),
		"anchors": anchors,
	}


func _assert_authored_unchanged(dock: Control, expected: Dictionary, message: String) -> void:
	var actual := _authored(dock)
	for key in expected:
		assert_that(actual[key]).override_failure_message("%s: %s changed" % [message, key]).is_equal(expected[key])


# ---- tests --------------------------------------------------------------------------------


func test_replacing_with_a_same_size_picture_keeps_every_authored_value() -> void:
	var dock := await _make_authored_dock()
	var expected := _authored(dock)
	var size: Vector2i = dock._document.image_size
	var replacement := _make_image("same_size.png", size, Color.RED)
	dock._load_illustration(replacement)
	assert_str(dock._document.illustration_path).is_equal(replacement)
	assert_vector(dock._document.image_size).is_equal(size)
	_assert_authored_unchanged(dock, expected, "after a same-size replacement")
	dock.queue_free()


func test_a_replacement_is_undoable_and_marks_the_document_modified() -> void:
	var dock := await _make_authored_dock()
	var original_path: String = dock._document.illustration_path
	var original_texture: Texture2D = dock._canvas.get_texture()
	var expected := _authored(dock)
	dock._load_illustration(_make_image("undo.png", dock._document.image_size, Color.BLUE))
	assert_bool(dock.is_dirty()).is_true()
	dock._undo()
	assert_str(dock._document.illustration_path).is_equal(original_path)
	assert_object(dock._canvas.get_texture()).is_same(original_texture)
	assert_bool(dock.is_dirty()).override_failure_message("undo returns to the saved state").is_false()
	_assert_authored_unchanged(dock, expected, "after undoing the replacement")
	dock._redo()
	assert_bool(dock._document.illustration_path.ends_with("undo.png")).is_true()
	assert_bool(dock.is_dirty()).is_true()
	dock.queue_free()


func test_a_picture_of_another_size_asks_first_and_changes_nothing_until_confirmed() -> void:
	var dock := await _make_authored_dock()
	var expected := _authored(dock)
	var old_size: Vector2i = dock._document.image_size
	var old_path: String = dock._document.illustration_path
	dock._load_illustration(_make_image("other_size.png", Vector2i(800, 450), Color.GREEN))
	assert_object(dock._illustration_dialog).override_failure_message("a size change must be confirmed").is_not_null()
	assert_vector(dock._document.image_size).is_equal(old_size)
	assert_str(dock._document.illustration_path).is_equal(old_path)
	assert_bool(dock.is_dirty()).is_false()
	_assert_authored_unchanged(dock, expected, "while the question is open")
	dock.queue_free()


func test_confirming_a_size_change_keeps_regions_templates_and_calibration() -> void:
	var dock := await _make_authored_dock()
	var expected := _authored(dock)
	var old_size: Vector2i = dock._document.image_size
	dock._load_illustration(_make_image("confirmed.png", Vector2i(800, 450), Color.GREEN))
	dock._illustration_dialog.confirmed.emit()
	assert_vector(dock._document.image_size).is_equal(Vector2i(800, 450))
	assert_bool(dock.is_dirty()).is_true()
	_assert_authored_unchanged(dock, expected, "after a confirmed size change")
	dock._undo()
	assert_vector(dock._document.image_size).is_equal(old_size)
	assert_bool(dock.is_dirty()).is_false()
	_assert_authored_unchanged(dock, expected, "after undoing a size change")
	dock.queue_free()


func test_cancelling_a_size_change_leaves_the_document_untouched() -> void:
	var dock := await _make_authored_dock()
	var expected := _authored(dock)
	var old_path: String = dock._document.illustration_path
	dock._load_illustration(_make_image("cancelled.png", Vector2i(800, 450), Color.GREEN))
	dock._illustration_dialog.canceled.emit()
	assert_str(dock._document.illustration_path).is_equal(old_path)
	assert_bool(dock.is_dirty()).is_false()
	assert_bool(dock._history.has_undo()).is_false()
	_assert_authored_unchanged(dock, expected, "after cancelling")
	dock.queue_free()


func test_the_first_import_still_creates_a_calibration_for_the_new_image() -> void:
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new())
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	await get_tree().process_frame
	dock._load_illustration(ProjectSettings.globalize_path(ORIGINAL_IMAGE))
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	assert_vector(dock._document.image_size).is_equal(Vector2i(1672, 941))
	assert_float(calibration.camera_position.x).is_equal_approx(836.0, TOLERANCE)
	assert_bool(dock.is_dirty()).is_true()
	dock.queue_free()

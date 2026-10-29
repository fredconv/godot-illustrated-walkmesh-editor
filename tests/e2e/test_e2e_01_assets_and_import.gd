extends GdUnitTestSuite
## End-to-end scenario "village + fountain", part 1: the assets, the scene, and starting from empty.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(VILLAGE.OUTPUT_FOLDER))


func test_the_asset_set_is_what_the_scenario_expects() -> void:
	var background := Image.load_from_file(ProjectSettings.globalize_path(VILLAGE.BACKGROUND))
	var foreground := Image.load_from_file(ProjectSettings.globalize_path(VILLAGE.FOREGROUND))
	assert_vector(background.get_size()).is_equal(VILLAGE.IMAGE_SIZE)
	assert_vector(foreground.get_size()).override_failure_message("the foreground must share the background canvas").is_equal(VILLAGE.IMAGE_SIZE)
	assert_bool(foreground.detect_alpha() != Image.ALPHA_NONE).override_failure_message("the foreground needs transparency").is_true()
	# The background is opaque everywhere; the foreground is transparent at the corners and opaque in the fountain.
	for corner in [Vector2i(0, 0), Vector2i(1671, 0), Vector2i(0, 940), Vector2i(1671, 940)]:
		assert_float(background.get_pixelv(corner).a).is_equal(1.0)
		assert_float(foreground.get_pixelv(corner).a).is_equal(0.0)
	assert_float(foreground.get_pixelv(Vector2i(VILLAGE.FOUNTAIN_CENTER)).a).override_failure_message("the fountain is (almost) opaque").is_greater(0.95)


func test_the_composite_scene_stacks_the_foreground_above_the_background() -> void:
	var packed := load(VILLAGE.SCENE) as PackedScene
	assert_object(packed).is_not_null()
	var root := packed.instantiate()
	var background := root.get_node("Background") as Sprite2D
	var foreground := root.get_node("Foreground") as Sprite2D
	assert_str(background.texture.resource_path).is_equal(VILLAGE.BACKGROUND)
	assert_str(foreground.texture.resource_path).is_equal(VILLAGE.FOREGROUND)
	assert_int(foreground.z_index).is_greater(background.z_index)
	assert_vector(background.texture.get_size()).is_equal(Vector2(VILLAGE.IMAGE_SIZE))
	assert_vector(foreground.texture.get_size()).is_equal(Vector2(VILLAGE.IMAGE_SIZE))
	root.free()


func test_a_new_setup_starts_empty_and_refuses_work_until_an_illustration_exists() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	assert_int(dock._document.regions.size()).is_equal(0)
	assert_int(dock._document.scale_anchors.size()).is_equal(0)
	assert_vector(dock._document.image_size).is_equal(Vector2i.ZERO)
	assert_str(dock._document.illustration_path).is_empty()
	assert_bool(dock._has_illustration).is_false()
	assert_bool(dock.is_dirty()).is_false()
	# Drawing a region before importing is refused and leaves no trace.
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.YARD))
	assert_int(dock._document.regions.size()).is_equal(0)
	assert_bool(dock._history.has_undo()).is_false()
	assert_bool(dock._perspective_button.disabled).is_true()
	assert_bool(dock._export_perspective_button.disabled).is_true()
	dock.queue_free()


func test_importing_the_new_background_builds_a_fresh_calibration_from_the_new_image() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	var document: Resource = dock._document
	assert_vector(document.image_size).is_equal(VILLAGE.IMAGE_SIZE)
	assert_str(document.illustration_path.get_file()).is_equal("background_template.png")
	assert_bool(dock._has_illustration).is_true()
	assert_bool(dock.is_dirty()).override_failure_message("a first import is a change to save").is_true()
	assert_bool(dock._perspective_button.disabled).is_false()
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	assert_float(calibration.camera_position.x).override_failure_message("camera centred on this image").is_equal_approx(VILLAGE.IMAGE_SIZE.x * 0.5, 0.001)
	assert_vector(calibration.reference_viewport_size).override_failure_message("reference frame is the project's game window").is_equal(IWEPerspectiveCalibration.project_viewport_size())
	dock.queue_free()


func test_two_documents_in_a_row_do_not_share_state() -> void:
	var first: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(first)
	VILLAGE.author_regions(first)
	assert_int(first._document.regions.size()).is_greater(0)
	first.queue_free()
	await get_tree().process_frame
	var second: Control = await VILLAGE.new_dock(get_tree())
	assert_int(second._document.regions.size()).is_equal(0)
	assert_bool(second._history.has_undo()).override_failure_message("undo history is per document").is_false()
	assert_bool(second.is_dirty()).is_false()
	second.queue_free()


func test_replacing_the_picture_keeps_the_authored_scene_and_can_be_undone() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	var region_count: int = dock._document.regions.size()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	calibration.field_of_view_degrees = 61.0
	var points: PackedVector2Array = dock._document.regions[1].points.duplicate()
	# Same size, different picture: nothing authored may move.
	dock._load_illustration(ProjectSettings.globalize_path("res://assets/img/background.png"))
	assert_str(dock._document.illustration_path.get_file()).is_equal("background.png")
	assert_int(dock._document.regions.size()).is_equal(region_count)
	assert_float(dock._document.perspective_calibration.field_of_view_degrees).is_equal(61.0)
	assert_array(dock._document.regions[1].points).is_equal(points)
	assert_int(dock._document.scale_anchors.size()).is_equal(2)
	dock._undo()
	assert_str(dock._document.illustration_path.get_file()).is_equal("background_template.png")
	dock.queue_free()

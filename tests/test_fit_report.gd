extends GdUnitTestSuite

## M4: the person calibrating the camera sees how far it is from each height reference, is warned
## when the miss is large, and learns where the horizon is and which zones lie above it.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const IMAGE_SIZE := Vector2i(1000, 700)


func _gentle_references() -> Array:
	var near: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0)
	near.name = "Near"
	var far: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0)
	far.name = "Far"
	return [near, far]


func _fitted(anchors: Array) -> IWEPerspectiveCalibration:
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, Vector2i(1280, 720))
	assert_str(calibration.fit_to_scale_anchors(anchors, IMAGE_SIZE)).is_empty()
	return calibration


func test_a_gentle_scene_fits_within_the_warning_threshold() -> void:
	var anchors := _gentle_references()
	var residuals := _fitted(anchors).reference_residuals(anchors, IMAGE_SIZE)
	assert_int(residuals.size()).is_equal(2)
	for residual in residuals:
		assert_float(absf(residual)).override_failure_message("miss %.3f" % residual).is_less(IWEPerspectiveCalibration.RESIDUAL_WARNING)


func test_the_residual_is_signed_taller_is_positive() -> void:
	var anchors := _gentle_references()
	var calibration := _fitted(anchors)
	var baseline := calibration.reference_residuals(anchors, IMAGE_SIZE)
	anchors[0].apparent_height_px = 100.0
	var shorter_reference := calibration.reference_residuals(anchors, IMAGE_SIZE)
	assert_float(shorter_reference[0]).override_failure_message("the character is now taller than its reference").is_greater(baseline[0] + 0.5)


func test_a_reference_above_the_horizon_has_no_residual() -> void:
	var anchors := _gentle_references()
	var calibration := _fitted(anchors)
	var sky: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(500, 5), 30.0)
	anchors.append(sky)
	var residuals := calibration.reference_residuals(anchors, IMAGE_SIZE)
	assert_bool(is_inf(residuals[2])).is_true()


func test_the_horizon_row_lies_above_the_references_and_moves_with_the_camera_pitch() -> void:
	var anchors := _gentle_references()
	var calibration := _fitted(anchors)
	var horizon := calibration.horizon_image_row(IMAGE_SIZE)
	assert_float(horizon).is_less(400.0)
	var steeper: IWEPerspectiveCalibration = calibration.duplicate()
	steeper.camera_rotation_degrees.x -= 5.0
	assert_float(steeper.horizon_image_row(IMAGE_SIZE)).override_failure_message("looking further down raises the horizon in the picture").is_less(horizon)


func test_the_horizon_row_is_where_the_floor_stops() -> void:
	var anchors := _gentle_references()
	var calibration := _fitted(anchors)
	var horizon := calibration.horizon_image_row(IMAGE_SIZE)
	var projector: GDScript = VILLAGE.PROJECTOR
	var above: Variant = projector.image_point_to_floor(Vector2(500, horizon - 5.0), IMAGE_SIZE, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	var below: Variant = projector.image_point_to_floor(Vector2(500, horizon + 5.0), IMAGE_SIZE, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	assert_object(above).override_failure_message("floor above the horizon").is_null()
	assert_object(below).override_failure_message("no floor below the horizon").is_not_null()


func _village_dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	return dock


func test_the_steep_village_scene_shows_its_miss_and_a_warning() -> void:
	var dock := await _village_dock()
	dock._fit_camera_to_references()
	var report: Dictionary = dock.get_fit_report()
	assert_int(report.residuals.size()).is_equal(2)
	assert_float(report.worst).override_failure_message("the e2e run measured about 10%").is_greater(0.05)
	assert_bool(report.warn).is_true()
	assert_str(dock._status_label.text).contains("Largest miss").contains("above 5%")
	assert_str(dock._fit_report_label.text).contains("Template 1").contains("%")
	assert_str(dock._fit_report_label.text).contains("by the most, more than 5%")
	dock.queue_free()


func test_a_good_fit_shows_no_warning() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock._canvas.scale_anchor_created.emit(Vector2(300, 700), 150.0)
	dock._canvas.scale_anchor_created.emit(Vector2(1000, 600), 133.0)
	dock._fit_camera_to_references()
	var report: Dictionary = dock.get_fit_report()
	assert_bool(report.warn).override_failure_message("worst miss %.3f" % report.worst).is_false()
	assert_str(dock._fit_report_label.text).not_contains("misses a reference")
	dock.queue_free()


func test_zones_on_or_above_the_horizon_are_named() -> void:
	# A gentle scene whose horizon falls inside the picture.
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	# Heights grow linearly with the row, from zero at row 250: the horizon is there.
	dock._canvas.scale_anchor_created.emit(Vector2(300, 900), 200.0)
	dock._canvas.scale_anchor_created.emit(Vector2(1000, 500), 76.9)
	dock._fit_camera_to_references()
	var horizon: float = dock._document.perspective_calibration.horizon_image_row(dock._document.image_size)
	assert_float(horizon).override_failure_message("this scene needs a horizon inside the picture").is_between(60.0, 500.0)
	dock._canvas.region_created.emit(PackedVector2Array([Vector2(100, 20), Vector2(300, 20), Vector2(300, horizon - 10.0), Vector2(100, horizon - 10.0)]))
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.YARD))
	var sky_name: String = dock._document.regions[0].name
	var yard_name: String = dock._document.regions[1].name
	var report: Dictionary = dock.get_fit_report()
	assert_array(report.zones_above_horizon).is_equal(PackedStringArray([sky_name]))
	assert_str(dock._fit_report_label.text).contains("not exported").contains(sky_name)
	assert_str(dock._fit_report_label.text).contains("Horizon at image row")
	assert_bool(dock._fit_report_label.text.contains(yard_name + ".") or dock._fit_report_label.text.contains(yard_name + ",")).override_failure_message("a zone on the floor is not listed").is_false()
	dock.queue_free()


func test_no_report_without_height_references() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	var report: Dictionary = dock.get_fit_report()
	assert_int(report.residuals.size()).is_equal(0)
	assert_bool(report.warn).is_false()
	dock.queue_free()

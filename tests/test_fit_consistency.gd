extends GdUnitTestSuite
## A height reference that contradicts the others (taller although it is farther away) must not bend the
## camera silently: the fit is refused with a sentence that names the references, and the camera stays.

const SIZE := Vector2i(1672, 941)


func _anchor(position: Vector2, height: float, anchor_name: String) -> IWEScaleAnchor:
	var anchor := IWEScaleAnchor.create_anchor(position, height)
	anchor.name = anchor_name
	return anchor


func _fit(anchors: Array) -> Dictionary:
	var calibration := IWEPerspectiveCalibration.for_image(SIZE)
	var before := calibration.duplicate() as IWEPerspectiveCalibration
	var message := calibration.fit_to_scale_anchors(anchors, SIZE)
	return {"message": message, "calibration": calibration, "unchanged": calibration.camera_position == before.camera_position and calibration.camera_rotation_degrees == before.camera_rotation_degrees}


func test_references_that_shrink_with_distance_are_fitted() -> void:
	var result := _fit([_anchor(Vector2(800, 850), 230.0, "Near"), _anchor(Vector2(800, 600), 170.0, "Middle"), _anchor(Vector2(800, 400), 105.0, "Far")])
	assert_str(result.message).is_empty()
	assert_bool(result.unchanged).is_false()


func test_a_far_reference_that_is_bigger_than_a_nearer_one_is_refused_by_name() -> void:
	var result := _fit([_anchor(Vector2(800, 850), 230.0, "Near"), _anchor(Vector2(800, 600), 170.0, "Middle"), _anchor(Vector2(800, 400), 210.0, "Far")])
	assert_str(result.message).contains("\"Far\"").contains("\"Middle\"").contains("not smaller").contains("210 px against 170 px")
	assert_bool(result.unchanged).override_failure_message("a refused fit leaves the camera as it was").is_true()


func test_a_middle_reference_that_is_too_big_is_refused_and_the_nearer_one_is_named() -> void:
	var result := _fit([_anchor(Vector2(800, 850), 230.0, "Near"), _anchor(Vector2(800, 600), 260.0, "Middle"), _anchor(Vector2(800, 400), 105.0, "Far")])
	assert_str(result.message).contains("\"Middle\"").contains("\"Near\"")
	assert_bool(result.unchanged).is_true()


func test_the_order_in_the_list_does_not_matter_only_the_position_in_the_picture() -> void:
	var result := _fit([_anchor(Vector2(800, 400), 210.0, "Far"), _anchor(Vector2(800, 850), 230.0, "Near"), _anchor(Vector2(800, 600), 170.0, "Middle")])
	assert_str(result.message).contains("\"Far\"")


func test_references_at_the_same_height_are_refused_with_a_clear_reason() -> void:
	var result := _fit([_anchor(Vector2(800, 850), 150.0, "A"), _anchor(Vector2(800, 400), 150.0, "B")])
	assert_str(result.message).contains("not smaller")
	assert_bool(result.unchanged).is_true()


func test_two_references_almost_at_the_same_row_are_not_compared() -> void:
	# Ten pixels apart in a picture 941 high: a hand placing them cannot be that exact.
	var result := _fit([_anchor(Vector2(800, 850), 230.0, "Near"), _anchor(Vector2(900, 858), 226.0, "Nearly the same"), _anchor(Vector2(800, 400), 105.0, "Far")])
	assert_str(result.message).is_empty()


func test_inverted_references_are_still_refused() -> void:
	var result := _fit([_anchor(Vector2(800, 850), 100.0, "Near"), _anchor(Vector2(800, 400), 200.0, "Far")])
	assert_str(result.message).is_not_empty()
	assert_bool(result.unchanged).is_true()


func test_the_dock_reports_the_reference_that_the_camera_misses_the_most_by_name() -> void:
	var village := preload("res://tests/e2e/village_scenario.gd")
	var dock: Control = await village.new_dock(get_tree())
	village.import_background(dock)
	village.author_regions(dock)
	village.author_templates(dock)
	dock._fit_camera_to_references()
	var report: Dictionary = dock.get_fit_report()
	assert_bool(report.warn).override_failure_message("the steep village scene misses by about 10%").is_true()
	var text := "\n".join(report.lines)
	assert_str(text).contains("misses \"Template")
	dock.queue_free()


func test_the_dock_says_why_a_fit_was_refused() -> void:
	var village := preload("res://tests/e2e/village_scenario.gd")
	var dock: Control = await village.new_dock(get_tree())
	village.import_background(dock)
	dock._canvas.scale_anchor_created.emit(Vector2(800, 850), 230.0)
	dock._canvas.scale_anchor_created.emit(Vector2(800, 400), 300.0)
	var before: Vector3 = dock._document.perspective_calibration.camera_position
	dock._fit_camera_to_references()
	assert_str(dock._status_label.text).contains("Fit failed").contains("not smaller")
	assert_vector(dock._document.perspective_calibration.camera_position).is_equal(before)
	dock.queue_free()

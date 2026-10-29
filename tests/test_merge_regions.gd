extends GdUnitTestSuite

## Merging two regions into one polygon (a union command). A point is walkable in the result when it was
## walkable in either region.

const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const TOLERANCE := 1.0


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _region(region_name: String, points: PackedVector2Array) -> IWERegion:
	var region: IWERegion = REGION_SCRIPT.new()
	region.id = region_name.to_lower()
	region.name = region_name
	region.points = points
	return region


func _area(points: PackedVector2Array) -> float:
	return absf(REGION_SCRIPT._signed_area(points))


## Walkable area of a region built from a merge result.
func _walkable_area(result: Dictionary) -> float:
	var region := _region("Merged", result.points)
	region.subtraction_polygons = result.cutouts
	var contours := region.get_walkable_contours()
	if contours.is_empty():
		return 0.0
	var reference := Geometry2D.is_polygon_clockwise(contours[0])
	var total := 0.0
	for contour in contours:
		total += _area(contour) * (1.0 if Geometry2D.is_polygon_clockwise(contour) == reference else -1.0)
	return total


func test_two_regions_sharing_an_edge_merge_into_one_outline() -> void:
	var result := REGION_SCRIPT.merge_result(_region("A", _rect(0, 0, 100, 100)), _region("B", _rect(100, 0, 100, 100)))
	assert_bool(result.ok).is_true()
	assert_float(_area(result.points)).is_equal_approx(20000.0, TOLERANCE)


func test_overlapping_regions_merge_into_the_union_area() -> void:
	var result := REGION_SCRIPT.merge_result(_region("A", _rect(0, 0, 200, 100)), _region("B", _rect(150, 20, 200, 60)))
	assert_bool(result.ok).is_true()
	assert_float(_area(result.points)).is_equal_approx(200.0 * 100.0 + 200.0 * 60.0 - 50.0 * 60.0, TOLERANCE)


func test_regions_that_do_not_touch_are_refused() -> void:
	var result := REGION_SCRIPT.merge_result(_region("A", _rect(0, 0, 100, 100)), _region("B", _rect(300, 0, 100, 100)))
	assert_bool(result.ok).is_false()
	assert_str(result.reason).contains("neither touch nor overlap")


func test_a_union_that_would_leave_a_hole_is_refused() -> void:
	# A U shape closed by a bar: the union has a hole in the middle.
	var u_shape := _region("U", PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, 300), Vector2(200, 300), Vector2(200, 100), Vector2(100, 100), Vector2(100, 300), Vector2(0, 300)]))
	var bar := _region("Bar", _rect(0, 250, 300, 50))
	var result := REGION_SCRIPT.merge_result(u_shape, bar)
	assert_bool(result.ok).is_false()
	assert_str(result.reason).contains("hole").contains("cutout")


func test_a_cutout_outside_the_other_region_survives() -> void:
	var first := _region("A", _rect(0, 0, 200, 100))
	first.subtraction_polygons.append(_rect(20, 20, 40, 40))
	first.subtraction_names.append("Pond")
	var result := REGION_SCRIPT.merge_result(first, _region("B", _rect(150, 0, 200, 100)))
	assert_bool(result.ok).is_true()
	assert_float(_walkable_area(result)).is_equal_approx(350.0 * 100.0 - 40.0 * 40.0, TOLERANCE)
	assert_str(result.names[0]).is_equal("Pond")


func test_a_cutout_the_other_region_covers_becomes_walkable() -> void:
	# Union rule: the pond of A under B is walkable because B covers it.
	var first := _region("A", _rect(0, 0, 200, 100))
	first.subtraction_polygons.append(_rect(150, 20, 40, 60))
	var result := REGION_SCRIPT.merge_result(first, _region("B", _rect(100, 0, 200, 100)))
	assert_bool(result.ok).is_true()
	assert_float(_walkable_area(result)).is_equal_approx(300.0 * 100.0, TOLERANCE)


func test_ground_blocked_in_both_regions_stays_blocked() -> void:
	var first := _region("A", _rect(0, 0, 200, 100))
	first.subtraction_polygons.append(_rect(120, 20, 40, 60))
	var second := _region("B", _rect(100, 0, 200, 100))
	second.subtraction_polygons.append(_rect(130, 30, 40, 40))
	var result := REGION_SCRIPT.merge_result(first, second)
	assert_bool(result.ok).is_true()
	# Blocked in both ponds only: x 130..160, y 30..70.
	assert_float(_walkable_area(result)).is_equal_approx(300.0 * 100.0 - 30.0 * 40.0, TOLERANCE)


func test_a_cutout_that_surrounds_the_other_region_is_refused() -> void:
	var first := _region("A", _rect(0, 0, 400, 400))
	first.subtraction_polygons.append(_rect(100, 100, 200, 200))
	var result := REGION_SCRIPT.merge_result(first, _region("B", _rect(150, 150, 50, 50)))
	assert_bool(result.ok).is_false()
	assert_str(result.reason).contains("surrounds")


func test_merging_does_not_modify_the_regions_it_reads() -> void:
	var first := _region("A", _rect(0, 0, 100, 100))
	first.subtraction_polygons.append(_rect(10, 10, 20, 20))
	var second := _region("B", _rect(100, 0, 100, 100))
	var before := var_to_str([first.points, first.subtraction_polygons, second.points])
	REGION_SCRIPT.merge_result(first, second)
	assert_str(var_to_str([first.points, first.subtraction_polygons, second.points])).is_equal(before)


# ---- the dock -----------------------------------------------------------------------------------


func _dock_with_three_zones() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock._canvas.region_created.emit(_rect(0, 400, 300, 200))
	dock._canvas.region_created.emit(_rect(300, 400, 300, 200))
	dock._canvas.region_created.emit(_rect(1200, 100, 100, 100))
	return dock


func test_the_dock_merges_two_regions_and_undo_gives_both_back_in_order() -> void:
	var dock := await _dock_with_three_zones()
	var first: IWERegion = dock._document.regions[0]
	var second: IWERegion = dock._document.regions[1]
	var third_id: String = dock._document.regions[2].id
	var second_id := second.id
	dock._select_region(first.id)
	assert_bool(dock.merge_selected_region_with(second_id)).is_true()
	assert_int(dock._document.regions.size()).is_equal(2)
	assert_float(_area(first.points)).is_equal_approx(600.0 * 200.0, TOLERANCE)
	assert_str(dock._document.regions[1].id).is_equal(third_id)
	dock._undo()
	assert_int(dock._document.regions.size()).is_equal(3)
	assert_str(dock._document.regions[1].id).override_failure_message("the second region comes back at its place").is_equal(second_id)
	assert_float(_area(first.points)).is_equal_approx(300.0 * 200.0, TOLERANCE)
	dock._redo()
	assert_int(dock._document.regions.size()).is_equal(2)
	assert_float(_area(first.points)).is_equal_approx(600.0 * 200.0, TOLERANCE)
	dock.queue_free()


func test_the_dock_refuses_to_merge_regions_that_do_not_touch_and_says_why() -> void:
	var dock := await _dock_with_three_zones()
	dock._select_region(dock._document.regions[0].id)
	assert_bool(dock.merge_selected_region_with(dock._document.regions[2].id)).is_false()
	assert_int(dock._document.regions.size()).is_equal(3)
	assert_str(dock._status_label.text).contains("Merge refused").contains("neither touch nor overlap")
	dock.queue_free()


func test_a_locked_region_is_not_merged() -> void:
	var dock := await _dock_with_three_zones()
	dock._document.regions[1].locked = true
	dock._select_region(dock._document.regions[0].id)
	assert_bool(dock.merge_selected_region_with(dock._document.regions[1].id)).is_false()
	assert_int(dock._document.regions.size()).is_equal(3)
	dock.queue_free()


func test_the_merge_menu_lists_the_other_regions_and_merges_the_chosen_one() -> void:
	var dock := await _dock_with_three_zones()
	var first: IWERegion = dock._document.regions[0]
	dock._select_region(first.id)
	assert_bool(dock._merge_button.disabled).is_false()
	dock._fill_merge_menu()
	var popup: PopupMenu = dock._merge_button.get_popup()
	assert_int(popup.item_count).is_equal(2)
	assert_str(popup.get_item_text(0)).is_equal(dock._document.regions[1].name)
	popup.id_pressed.emit(0)
	assert_int(dock._document.regions.size()).is_equal(2)
	dock.queue_free()


func test_the_merge_menu_is_off_without_a_selection_or_with_one_region() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock._canvas.region_created.emit(_rect(0, 400, 300, 200))
	dock._select_region(dock._document.regions[0].id)
	assert_bool(dock._merge_button.disabled).override_failure_message("one region has nothing to merge with").is_true()
	dock.queue_free()


func test_a_merged_region_is_saved_and_walkable_as_the_union() -> void:
	var dock := await _dock_with_three_zones()
	var first: IWERegion = dock._document.regions[0]
	dock._select_region(first.id)
	dock.merge_selected_region_with(dock._document.regions[1].id)
	assert_array(dock._document.validate_references()).is_empty()
	assert_int(first.get_walkable_contours().size()).is_equal(1)
	dock.queue_free()

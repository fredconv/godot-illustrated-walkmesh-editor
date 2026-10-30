extends GdUnitTestSuite
## End-to-end scenario "village + fountain", part 2: drawing polygons and the boolean operations.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const AREA_TOLERANCE := 1.0


func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for index in polygon.size():
		var next := polygon[(index + 1) % polygon.size()]
		total += polygon[index].x * next.y - next.x * polygon[index].y
	return absf(total) * 0.5


func _total_area(polygons: Array) -> float:
	var total := 0.0
	for polygon in polygons:
		total += _area(polygon)
	return total


func _authored_dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	return dock


func test_polygons_drawn_from_scratch_keep_their_points_group_and_defaults() -> void:
	var dock := await _authored_dock()
	var document: Resource = dock._document
	assert_int(document.regions.size()).is_equal(4)
	assert_int(document.groups.size()).is_equal(1)
	assert_array(document.regions[0].points).is_equal(VILLAGE.points(VILLAGE.YARD))
	assert_array(document.regions[1].points).is_equal(VILLAGE.points(VILLAGE.CROSSROADS))
	assert_array(document.regions[2].points).is_equal(VILLAGE.points(VILLAGE.BRIDGE))
	assert_array(document.regions[3].points).is_equal(VILLAGE.points(VILLAGE.OVERLAP_PATCH))
	for index in 4:
		assert_str(document.regions[index].name).is_equal("Region %d" % (index + 1))
		assert_str(document.regions[index].group_id).is_equal(document.groups[0].id)
	assert_int(document.regions[1].subtraction_polygons.size()).is_equal(2)
	assert_str(document.regions[1].subtraction_names[0]).is_equal("Cutout 1")
	assert_bool(dock.is_dirty()).is_true()
	dock.queue_free()


func test_zones_sharing_an_edge_merge_into_one_polygon_with_the_summed_area() -> void:
	var dock := await _authored_dock()
	var yard: PackedVector2Array = dock._document.regions[0].points
	var crossroads: PackedVector2Array = dock._document.regions[1].points
	var merged := Geometry2D.merge_polygons(yard, crossroads)
	assert_int(merged.size()).override_failure_message("edge-sharing zones form one outline").is_equal(1)
	assert_float(_area(merged[0])).is_equal_approx(_area(yard) + _area(crossroads), AREA_TOLERANCE)
	# The bridge shares the whole far edge of the crossroads' tab.
	var with_bridge := Geometry2D.merge_polygons(merged[0], dock._document.regions[2].points)
	assert_int(with_bridge.size()).is_equal(1)
	dock.queue_free()


func test_overlapping_cutouts_are_subtracted_as_a_union_not_twice() -> void:
	var dock := await _authored_dock()
	var crossroads: IWERegion = dock._document.regions[1]
	var footprint := VILLAGE.fountain_footprint()
	var bench := VILLAGE.points(VILLAGE.BENCH_CUTOUT)
	var overlap := _total_area(Geometry2D.intersect_polygons(footprint, bench))
	assert_float(overlap).override_failure_message("the two cutouts must overlap for this test to mean anything").is_greater(500.0)
	var expected_hole := _area(footprint) + _area(bench) - overlap
	var contours := crossroads.get_walkable_contours()
	var outer := _area(crossroads.points)
	var holes := 0.0
	for index in range(1, contours.size()):
		holes += _area(contours[index])
	assert_float(holes).override_failure_message("holes = union of the cutouts").is_equal_approx(expected_hole, AREA_TOLERANCE)
	assert_float(outer - holes).is_greater(0.0)
	assert_int(contours.size()).override_failure_message("one merged hole, not two").is_equal(2)
	dock.queue_free()


func test_a_cutout_that_misses_the_region_is_refused() -> void:
	var dock := await _authored_dock()
	var crossroads: IWERegion = dock._document.regions[1]
	var count := crossroads.subtraction_polygons.size()
	# Over the waterfall: nowhere near the crossroads.
	dock._canvas.subtraction_created.emit(crossroads.id, PackedVector2Array([Vector2(1450, 60), Vector2(1560, 60), Vector2(1560, 160), Vector2(1450, 160)]))
	assert_int(crossroads.subtraction_polygons.size()).is_equal(count)
	dock.queue_free()


func test_cutouts_undo_and_redo_in_order() -> void:
	var dock := await _authored_dock()
	var crossroads: IWERegion = dock._document.regions[1]
	dock._undo()
	assert_int(crossroads.subtraction_polygons.size()).is_equal(1)
	dock._undo()
	assert_int(crossroads.subtraction_polygons.size()).is_equal(0)
	assert_int(crossroads.get_walkable_contours().size()).is_equal(1)
	dock._redo()
	dock._redo()
	assert_int(crossroads.subtraction_polygons.size()).is_equal(2)
	assert_str(crossroads.subtraction_names[1]).is_equal("Cutout 2")
	dock.queue_free()


func test_a_zone_overlapping_two_others_stays_a_separate_region_with_its_own_outline() -> void:
	var dock := await _authored_dock()
	var patch: IWERegion = dock._document.regions[3]
	var contours := patch.get_walkable_contours()
	assert_int(contours.size()).is_equal(1)
	assert_float(_area(contours[0])).is_equal_approx(300.0 * 160.0, AREA_TOLERANCE)
	dock.queue_free()


func test_two_regions_can_be_merged_into_one_polygon_with_the_summed_area() -> void:
	# The yard and the crossroads share the full edge x = 500. Merging them gives one polygon.
	var dock := await _authored_dock()
	var yard: IWERegion = dock._document.regions[0]
	var crossroads: IWERegion = dock._document.regions[1]
	var expected := _area(yard.points) + _area(crossroads.points)
	dock._select_region(yard.id)
	assert_bool(dock.merge_selected_region_with(crossroads.id)).is_true()
	assert_int(dock._document.regions.size()).is_equal(3)
	assert_float(_area(yard.points)).is_equal_approx(expected, AREA_TOLERANCE)
	dock._undo()
	assert_int(dock._document.regions.size()).is_equal(4)
	assert_float(_area(dock._document.regions[0].points)).is_equal_approx(_area(yard.points), AREA_TOLERANCE)
	dock.queue_free()

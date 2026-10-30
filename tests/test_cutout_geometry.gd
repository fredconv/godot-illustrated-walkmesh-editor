extends GdUnitTestSuite

## Regression tests for overlapping cutouts (audit P1-1). A point inside two cutouts that
## overlap must stay non-walkable, and the walkable area must equal the region minus the
## union of its cutouts.

const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const SAVE_FOLDER := "user://iwe_cutout_tests"


func after_test() -> void:
	var folder := ProjectSettings.globalize_path(SAVE_FOLDER)
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file_name))
		DirAccess.remove_absolute(folder)


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _region(outline: PackedVector2Array, cutouts: Array[PackedVector2Array]) -> Resource:
	var region: Resource = REGION_SCRIPT.new()
	region.points = outline
	for cutout in cutouts:
		region.subtraction_polygons.append(cutout)
		region.subtraction_names.append("Cutout")
	return region


## Walkable area: outer contour counted positively, every contour wound the other way subtracted.
func _walkable_area(region: Resource) -> float:
	var outer_clockwise := Geometry2D.is_polygon_clockwise(region.points)
	var area := 0.0
	for contour in region.get_walkable_contours():
		var contour_area := absf(_signed_area(contour))
		area += contour_area if Geometry2D.is_polygon_clockwise(contour) == outer_clockwise else -contour_area
	return area


func _signed_area(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in points.size():
		total += points[index].cross(points[(index + 1) % points.size()])
	return total * 0.5


## Winding-number test over all walkable contours: contours wound like the outline add one,
## contours wound the other way (holes) subtract one. Nested islands are counted correctly.
func _is_walkable(region: Resource, point: Vector2) -> bool:
	var outer_clockwise := Geometry2D.is_polygon_clockwise(region.points)
	var winding := 0
	for contour in region.get_walkable_contours():
		if Geometry2D.is_point_in_polygon(point, contour):
			winding += 1 if Geometry2D.is_polygon_clockwise(contour) == outer_clockwise else -1
	return winding > 0


func test_two_independent_cutouts_remove_both_areas() -> void:
	var region := _region(_rect(0, 0, 400, 400), [_rect(20, 20, 50, 50), _rect(300, 300, 50, 50)])
	assert_float(_walkable_area(region)).is_equal_approx(160000.0 - 2500.0 - 2500.0, 0.5)
	assert_bool(_is_walkable(region, Vector2(40, 40))).is_false()
	assert_bool(_is_walkable(region, Vector2(320, 320))).is_false()
	assert_bool(_is_walkable(region, Vector2(200, 200))).is_true()


func test_overlapping_cutouts_keep_their_intersection_non_walkable() -> void:
	# Regression: cutouts A (100..200) and B (150..250) overlap in 150..200.
	var region := _region(_rect(0, 0, 400, 400), [_rect(100, 100, 100, 100), _rect(150, 150, 100, 100)])
	assert_bool(_is_walkable(region, Vector2(175, 175))).is_false()
	assert_bool(_is_walkable(region, Vector2(120, 120))).is_false()
	assert_bool(_is_walkable(region, Vector2(230, 230))).is_false()
	assert_bool(_is_walkable(region, Vector2(50, 50))).is_true()
	# Union area is 10000 + 10000 - 2500 = 17500.
	assert_float(_walkable_area(region)).is_equal_approx(160000.0 - 17500.0, 0.5)


func test_cutout_fully_inside_another_adds_nothing() -> void:
	var region := _region(_rect(0, 0, 400, 400), [_rect(50, 50, 200, 200), _rect(100, 100, 50, 50)])
	assert_float(_walkable_area(region)).is_equal_approx(160000.0 - 40000.0, 0.5)
	assert_bool(_is_walkable(region, Vector2(125, 125))).is_false()


func test_cutouts_sharing_an_edge_remove_their_combined_area() -> void:
	# Two rectangles that meet at x = 200. They do not overlap; the union is one 200x100 block.
	var region := _region(_rect(0, 0, 400, 400), [_rect(100, 100, 100, 100), _rect(200, 100, 100, 100)])
	assert_float(_walkable_area(region)).is_equal_approx(160000.0 - 20000.0, 0.5)
	assert_bool(_is_walkable(region, Vector2(200, 150))).is_false()
	assert_bool(_is_walkable(region, Vector2(150, 150))).is_false()


func test_cutout_touching_the_outer_edge_is_clipped_to_the_region() -> void:
	# The cutout reaches 20 units outside the region; only the 30 units inside count.
	var region := _region(_rect(0, 0, 400, 400), [_rect(-20, 100, 50, 100)])
	assert_float(_walkable_area(region)).is_equal_approx(160000.0 - 3000.0, 0.5)
	assert_bool(_is_walkable(region, Vector2(10, 150))).is_false()
	assert_bool(_is_walkable(region, Vector2(40, 150))).is_true()


func test_concave_outline_with_overlapping_cutouts() -> void:
	# L-shaped outline: 400x200 on top and 200x200 on the left, area 120000.
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(400, 200), Vector2(200, 200), Vector2(200, 400), Vector2(0, 400)])
	# The second cutout lies entirely inside the first, which crosses the concave corner.
	var region := _region(outline, [_rect(100, 100, 200, 200), _rect(150, 150, 100, 100)])
	# Inside the L, the first cutout covers 40000 - 10000 = 30000.
	assert_float(_walkable_area(region)).is_equal_approx(120000.0 - 30000.0, 0.5)
	assert_bool(_is_walkable(region, Vector2(175, 175))).is_false()
	assert_bool(_is_walkable(region, Vector2(320, 150))).is_true()


func test_no_degenerate_contours_are_returned() -> void:
	var region := _region(_rect(0, 0, 400, 400), [_rect(100, 100, 100, 100), _rect(150, 150, 100, 100), _rect(200, 100, 100, 100)])
	for contour in region.get_walkable_contours():
		assert_bool(contour.size() >= 3).is_true()
		assert_bool(absf(_signed_area(contour)) > 0.001).is_true()


func test_original_cutouts_survive_save_and_reopen_unchanged() -> void:
	var originals: Array[PackedVector2Array] = [_rect(100, 100, 100, 100), _rect(150, 150, 100, 100)]
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.add_region(_region(_rect(0, 0, 400, 400), originals))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_FOLDER))
	var path := SAVE_FOLDER.path_join("overlapping.tres")
	assert_int(ResourceSaver.save(document, path)).is_equal(OK)
	var reopened: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var region: Resource = reopened.regions[0]
	# The source polygons are stored as drawn; the union is derived, never written back.
	assert_int(region.subtraction_polygons.size()).is_equal(2)
	assert_array(region.subtraction_polygons[0]).is_equal(originals[0])
	assert_array(region.subtraction_polygons[1]).is_equal(originals[1])
	assert_float(_walkable_area(region)).is_equal_approx(160000.0 - 17500.0, 0.5)

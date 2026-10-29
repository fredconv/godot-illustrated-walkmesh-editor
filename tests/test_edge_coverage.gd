extends GdUnitTestSuite
## Which parts of a zone's edge are walls: only those that no other walkable zone covers.

const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const TOLERANCE := 0.002


func _zone(points: Array, cutouts: Array = []) -> Resource:
	var zone: Resource = REGION_SCRIPT.new()
	zone.id = "zone_%d" % randi()
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(point)
	zone.points = polygon
	for cutout in cutouts:
		var hole := PackedVector2Array()
		for point in cutout:
			hole.append(point)
		zone.subtraction_polygons.append(hole)
		zone.subtraction_names.append("hole")
	return zone


func _square(x: float, y: float, size: float) -> Array:
	return [Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)]


func _pieces(edge_start: Vector2, edge_end: Vector2, zone: Resource, zones: Array) -> Array:
	return GENERATOR._uncovered_edge_pieces(edge_start, edge_end, zone, zones)


func _assert_pieces(actual: Array, expected: Array) -> void:
	assert_int(actual.size()).override_failure_message("pieces %s, expected %s" % [actual, expected]).is_equal(expected.size())
	for index in expected.size():
		assert_vector(actual[index]).is_equal_approx(expected[index], Vector2(TOLERANCE, TOLERANCE))


func test_an_edge_no_other_zone_touches_is_one_wall() -> void:
	var zone := _zone(_square(0, 0, 100))
	var far := _zone(_square(500, 500, 100))
	_assert_pieces(_pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, far]), [Vector2(0, 1)])


func test_an_edge_shared_in_full_has_no_wall() -> void:
	var zone := _zone(_square(0, 0, 100))
	var neighbour := _zone(_square(100, 0, 100))
	_assert_pieces(_pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, neighbour]), [])


func test_an_edge_shared_in_part_keeps_the_wall_on_the_rest() -> void:
	var zone := _zone(_square(0, 0, 100))
	var bridge := _zone([Vector2(100, 40), Vector2(200, 40), Vector2(200, 60), Vector2(100, 60)])
	_assert_pieces(_pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, bridge]), [Vector2(0, 0.4), Vector2(0.6, 1)])
	# The bridge's own edge is covered by the zone, so the bridge has no wall there.
	_assert_pieces(_pieces(Vector2(100, 60), Vector2(100, 40), bridge, [zone, bridge]), [])


func test_an_edge_that_runs_inside_another_zone_is_open() -> void:
	var zone := _zone(_square(0, 0, 100))
	var big := _zone(_square(-50, -50, 300))
	_assert_pieces(_pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, big]), [])


func test_an_edge_crossing_into_another_zone_is_open_only_inside_it() -> void:
	var zone := _zone(_square(0, 0, 100))
	var overlap := _zone([Vector2(80, 30), Vector2(160, 30), Vector2(160, 70), Vector2(80, 70)])
	_assert_pieces(_pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, overlap]), [Vector2(0, 0.3), Vector2(0.7, 1)])


func test_an_edge_on_the_neighbours_outline_stays_open_beside_its_cutout() -> void:
	var zone := _zone(_square(0, 0, 100))
	var neighbour := _zone(_square(100, 0, 100), [[Vector2(100, 40), Vector2(140, 40), Vector2(140, 60), Vector2(100, 60)]])
	# The hole touches the shared edge, so part of the neighbour is not walkable there. The
	# neighbour's outline still lies on the edge, so it counts as shared border (a known simplification).
	var pieces := _pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, neighbour])
	assert_array(pieces).is_empty()


func test_a_corner_touch_opens_nothing() -> void:
	var zone := _zone(_square(0, 0, 100))
	var corner := _zone(_square(100, 100, 100))
	_assert_pieces(_pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, corner]), [Vector2(0, 1)])


func test_a_hidden_zone_opens_nothing() -> void:
	var zone := _zone(_square(0, 0, 100))
	var neighbour := _zone(_square(100, 0, 100))
	neighbour.visible = false
	_assert_pieces(_pieces(Vector2(100, 0), Vector2(100, 100), zone, [zone, neighbour]), [Vector2(0, 1)])

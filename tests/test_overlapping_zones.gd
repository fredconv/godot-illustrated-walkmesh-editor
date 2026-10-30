extends GdUnitTestSuite

## Audit P1-2: zones that overlap without sharing an exact edge are walkable as one. The earlier
## zone keeps the shared ground, the later zone's navigation mesh stops on its outline, and the
## character walks from one to the other.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PERSPECTIVE_PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const IMAGE_SIZE := Vector2i(1000, 700)
const VIEWPORT_SIZE := Vector2i(1280, 720)
const AREA_TOLERANCE := 1.0


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _zone(id: String, points: PackedVector2Array) -> Resource:
	var region: Resource = REGION_SCRIPT.new()
	region.id = id
	region.name = id
	region.points = points
	return region


func _area(points: PackedVector2Array) -> float:
	return absf(REGION_SCRIPT._signed_area(points))


func _mesh_area(region: Resource, all_regions: Array) -> float:
	var mesh: NavigationMesh = SCENE_GENERATOR._make_navigation_mesh(region, all_regions)
	var vertices := mesh.get_vertices()
	var total := 0.0
	for polygon_index in mesh.get_polygon_count():
		var polygon := PackedVector2Array()
		for vertex_index in mesh.get_polygon(polygon_index):
			polygon.append(Vector2(vertices[vertex_index].x, vertices[vertex_index].z))
		total += _area(polygon)
	return total


func test_the_later_zone_keeps_only_the_ground_the_earlier_zone_does_not_cover() -> void:
	var first := _zone("first", _rect(0, 0, 200, 100))
	var second := _zone("second", _rect(150, 20, 200, 60))
	var all := [first, second]
	assert_float(_mesh_area(first, all)).is_equal_approx(200.0 * 100.0, AREA_TOLERANCE)
	# 200x60 minus the 50x60 overlap.
	assert_float(_mesh_area(second, all)).is_equal_approx(150.0 * 60.0, AREA_TOLERANCE)


func test_the_union_is_covered_exactly_once_whatever_the_drawing_order() -> void:
	var a := _zone("a", _rect(0, 0, 200, 100))
	var b := _zone("b", _rect(150, 20, 200, 60))
	var union_area := 200.0 * 100.0 + 200.0 * 60.0 - 50.0 * 60.0
	for order in [[a, b], [b, a]]:
		var total := 0.0
		for region in order:
			total += _mesh_area(region, order)
		assert_float(total).override_failure_message("each point of the union is walkable once").is_equal_approx(union_area, AREA_TOLERANCE)


func test_a_zone_inside_an_earlier_zone_adds_no_navigation() -> void:
	var outer := _zone("outer", _rect(0, 0, 300, 200))
	var inner := _zone("inner", _rect(50, 50, 100, 80))
	assert_float(_mesh_area(inner, [outer, inner])).is_equal_approx(0.0, 0.01)
	assert_float(_mesh_area(outer, [outer, inner])).is_equal_approx(300.0 * 200.0, AREA_TOLERANCE)


func test_a_zone_around_an_earlier_zone_leaves_a_hole_where_it_is() -> void:
	var inner := _zone("inner", _rect(100, 80, 100, 40))
	var outer := _zone("outer", _rect(0, 0, 300, 200))
	assert_float(_mesh_area(outer, [inner, outer])).is_equal_approx(300.0 * 200.0 - 100.0 * 40.0, AREA_TOLERANCE)


func test_ground_inside_an_earlier_zones_cutout_stays_walkable_for_the_later_zone() -> void:
	var first := _zone("first", _rect(0, 0, 300, 200))
	first.subtraction_polygons.append(_rect(100, 50, 100, 100))
	first.subtraction_names.append("Pond")
	# The later zone covers x 150..350. The first zone walks everything but the pond, so the later
	# zone keeps the part right of x = 300 (50 x 160) and the half of the pond it covers (50 x 100).
	var second := _zone("second", _rect(150, 20, 200, 160))
	assert_float(_mesh_area(second, [first, second])).is_equal_approx(50.0 * 160.0 + 50.0 * 100.0, AREA_TOLERANCE)


func test_the_second_zone_mesh_ends_on_the_first_zone_outline() -> void:
	var first := _zone("first", _rect(0, 0, 200, 100))
	var second := _zone("second", _rect(150, 20, 200, 60))
	var mesh: NavigationMesh = SCENE_GENERATOR._make_navigation_mesh(second, [first, second])
	var smallest_x := INF
	for vertex in mesh.get_vertices():
		smallest_x = minf(smallest_x, vertex.x)
	assert_float(smallest_x).is_equal_approx(200.0, 0.01)


func test_hidden_and_incomplete_zones_do_not_cover_anything() -> void:
	var hidden := _zone("hidden", _rect(0, 0, 200, 100))
	hidden.visible = false
	var broken := _zone("broken", PackedVector2Array([Vector2(0, 0), Vector2(10, 10)]))
	var shown := _zone("shown", _rect(50, 20, 100, 60))
	assert_float(_mesh_area(shown, [hidden, broken, shown])).is_equal_approx(100.0 * 60.0, AREA_TOLERANCE)


func _world_to_image(world_position: Vector3, calibration: IWEPerspectiveCalibration) -> Vector2:
	var floor_point := world_position / 0.01
	var screen: Variant = PERSPECTIVE_PROJECTOR.world_to_viewport(Vector3(floor_point.x, calibration.floor_height, floor_point.z), calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	if screen == null:
		return Vector2.INF
	var image: Variant = PERSPECTIVE_PROJECTOR.viewport_to_image(screen, IMAGE_SIZE, calibration.reference_viewport_size)
	return image if image != null else Vector2.INF


func _floor_world(image_point: Vector2, calibration: IWEPerspectiveCalibration) -> Vector3:
	var floor_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(image_point, IMAGE_SIZE, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	return Vector3(floor_point.x, calibration.floor_height, floor_point.z) * 0.01


func _walk(regions: Array, from_point: Vector2, to_point: Vector2) -> Vector2:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	for region in regions:
		document.add_region(region)
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0))
	var texture := ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	assert_str(calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)).is_empty()
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, true)
	var player := root.get_node("Player") as CharacterBody3D
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	for _frame in 10:
		await scene_tree.physics_frame
	player.global_position = _floor_world(from_point, calibration)
	for _frame in 20:
		await scene_tree.physics_frame
	player.move_to(_floor_world(to_point, calibration))
	for _frame in 2000:
		await scene_tree.physics_frame
		if not player.is_moving_along_path():
			break
	var reached := _world_to_image(player.global_position, calibration)
	root.queue_free()
	await scene_tree.process_frame
	return reached


func test_the_character_walks_across_two_overlapping_zones() -> void:
	var left := _zone("left", _rect(100, 380, 350, 200))
	var right := _zone("right", _rect(380, 380, 400, 200))
	var reached: Vector2 = await _walk([left, right], Vector2(200, 480), Vector2(700, 480))
	assert_float(reached.x).override_failure_message("stopped at %s instead of crossing the overlap" % reached).is_greater(660.0)


func test_the_character_walks_back_across_two_overlapping_zones() -> void:
	var left := _zone("left", _rect(100, 380, 350, 200))
	var right := _zone("right", _rect(380, 380, 400, 200))
	var reached: Vector2 = await _walk([left, right], Vector2(700, 480), Vector2(200, 480))
	assert_float(reached.x).override_failure_message("stopped at %s" % reached).is_less(240.0)


func test_the_character_crosses_a_chain_of_three_overlapping_zones() -> void:
	var first := _zone("first", _rect(100, 380, 250, 200))
	var second := _zone("second", _rect(300, 420, 250, 100))
	var third := _zone("third", _rect(500, 380, 300, 200))
	var reached: Vector2 = await _walk([first, second, third], Vector2(150, 480), Vector2(750, 480))
	assert_float(reached.x).override_failure_message("stopped at %s" % reached).is_greater(700.0)


func test_an_overlap_does_not_open_a_path_across_ground_no_zone_covers() -> void:
	var left := _zone("left", _rect(100, 380, 250, 200))
	var right := _zone("right", _rect(600, 380, 200, 200))
	var reached: Vector2 = await _walk([left, right], Vector2(200, 480), Vector2(700, 480))
	assert_float(reached.x).override_failure_message("crossed a gap at %s" % reached).is_less(360.0)


func test_a_cutout_stays_an_obstacle_when_another_zone_overlaps_its_zone_elsewhere() -> void:
	# A lake cut out of the first zone, and a second zone that overlaps the first but not the lake.
	var ground := _zone("ground", _rect(0, 0, 300, 200))
	ground.subtraction_polygons.append(_rect(50, 50, 60, 60))
	ground.subtraction_names.append("Lake")
	var path := _zone("path", _rect(200, 20, 200, 60))
	var all := [ground, path]
	assert_float(_mesh_area(ground, all)).override_failure_message("the lake is still a hole").is_equal_approx(300.0 * 200.0 - 60.0 * 60.0, AREA_TOLERANCE)
	assert_float(_mesh_area(path, all)).is_equal_approx(100.0 * 60.0, AREA_TOLERANCE)
	for mesh_owner in all:
		var mesh: NavigationMesh = SCENE_GENERATOR._make_navigation_mesh(mesh_owner, all)
		var vertices := mesh.get_vertices()
		for polygon_index in mesh.get_polygon_count():
			var polygon := PackedVector2Array()
			for vertex_index in mesh.get_polygon(polygon_index):
				polygon.append(Vector2(vertices[vertex_index].x, vertices[vertex_index].z))
			var centre := Vector2.ZERO
			for corner in polygon:
				centre += corner
			centre /= float(polygon.size())
			assert_bool(Rect2(50, 50, 60, 60).has_point(centre)).override_failure_message("a navigation polygon sits on the lake at %s" % centre).is_false()


func test_a_zone_drawn_over_a_lake_makes_that_part_walkable_as_the_union_rule_says() -> void:
	# Union semantics: the lake blocks only where no zone covers it. A second zone drawn over half of
	# the lake walks across that half, the same as the walls do.
	var ground := _zone("ground", _rect(0, 0, 300, 200))
	ground.subtraction_polygons.append(_rect(100, 50, 100, 100))
	ground.subtraction_names.append("Lake")
	var bridge := _zone("bridge", _rect(150, 80, 200, 40))
	var all := [ground, bridge]
	assert_float(_mesh_area(bridge, all)).is_equal_approx(50.0 * 40.0 + 50.0 * 40.0, AREA_TOLERANCE)

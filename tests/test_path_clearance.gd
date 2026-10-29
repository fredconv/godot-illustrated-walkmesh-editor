extends GdUnitTestSuite

## Audit N-2: click-to-move paths keep a distance from obstacle corners, so a character with a
## physical radius can round them instead of stalling on the corner.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PERSPECTIVE_PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const IMAGE_SIZE := Vector2i(1000, 700)
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _floor_world(image_point: Vector2, calibration: IWEPerspectiveCalibration) -> Vector3:
	var floor_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(image_point, IMAGE_SIZE, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	return Vector3(floor_point.x, calibration.floor_height, floor_point.z) * 0.01


func _world_to_image(world_position: Vector3, calibration: IWEPerspectiveCalibration) -> Vector2:
	var floor_point := world_position / 0.01
	var screen: Variant = PERSPECTIVE_PROJECTOR.world_to_viewport(Vector3(floor_point.x, calibration.floor_height, floor_point.z), calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	if screen == null:
		return Vector2.INF
	var image: Variant = PERSPECTIVE_PROJECTOR.viewport_to_image(screen, IMAGE_SIZE, calibration.reference_viewport_size)
	return image if image != null else Vector2.INF


## Distance on the floor (world units) from a point to the outline of an image-space polygon.
func _distance_to_outline(world_point: Vector3, outline: PackedVector2Array, calibration: IWEPerspectiveCalibration) -> float:
	var corners := PackedVector2Array()
	for point in outline:
		var world := _floor_world(point, calibration)
		corners.append(Vector2(world.x, world.z))
	var flat := Vector2(world_point.x, world_point.z)
	var best := INF
	for index in corners.size():
		var closest := Geometry2D.get_closest_point_to_segment(flat, corners[index], corners[(index + 1) % corners.size()])
		best = minf(best, closest.distance_to(flat))
	return best


func _stage(cutout: PackedVector2Array) -> Array:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	var zone: Resource = REGION_SCRIPT.new()
	zone.id = "ground"
	zone.name = "Ground"
	zone.points = _rect(100, 380, 700, 250)
	zone.subtraction_polygons.append(cutout)
	zone.subtraction_names.append("Obstacle")
	document.add_region(zone)
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0))
	var texture := ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	assert_str(calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)).is_empty()
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, true)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	var player := root.get_node("Player") as CharacterBody3D
	var frames := 0
	while (frames < 12 or not player._navigation_settled) and frames < 600:
		await scene_tree.physics_frame
		frames += 1
	return [root, player, calibration]


func _radius(player: CharacterBody3D) -> float:
	return (player.get_node("CollisionShape3D").shape as CapsuleShape3D).radius


func test_the_generated_character_keeps_a_clearance_of_about_its_radius() -> void:
	var stage := await _stage(_rect(350, 450, 150, 90))
	var player: CharacterBody3D = stage[1]
	assert_float(player.path_clearance).is_greater(_radius(player) * 0.99)
	stage[0].queue_free()


func test_planned_corners_stay_clear_of_the_obstacle() -> void:
	var cutout := _rect(350, 450, 150, 90)
	var stage := await _stage(cutout)
	var player: CharacterBody3D = stage[1]
	var calibration: IWEPerspectiveCalibration = stage[2]
	player.global_position = _floor_world(Vector2(200, 495), calibration)
	await get_tree().physics_frame
	player.move_to(_floor_world(Vector2(650, 495), calibration))
	var path: PackedVector3Array = player._path
	assert_int(path.size()).override_failure_message("the obstacle forces a detour with corners").is_greater(2)
	var radius := _radius(player)
	for index in range(1, path.size() - 1):
		var distance := _distance_to_outline(path[index], cutout, calibration)
		assert_float(distance).override_failure_message("corner %d is %.4f from the obstacle, radius %.4f" % [index, distance, radius]).is_greater(radius * 0.8)
	stage[0].queue_free()


func test_a_character_without_clearance_gets_the_planners_path_with_corners_on_the_obstacle() -> void:
	var cutout := _rect(350, 450, 150, 90)
	var stage := await _stage(cutout)
	var player: CharacterBody3D = stage[1]
	var calibration: IWEPerspectiveCalibration = stage[2]
	player.path_clearance = 0.0
	player.global_position = _floor_world(Vector2(200, 495), calibration)
	await get_tree().physics_frame
	player.move_to(_floor_world(Vector2(650, 495), calibration))
	var path: PackedVector3Array = player._path
	var closest := INF
	for index in range(1, path.size() - 1):
		closest = minf(closest, _distance_to_outline(path[index], cutout, calibration))
	assert_float(closest).override_failure_message("zero clearance is the previous behaviour").is_less(0.01)
	stage[0].queue_free()


func test_the_character_walks_around_the_obstacle_and_arrives() -> void:
	var cutout := _rect(350, 450, 150, 90)
	var stage := await _stage(cutout)
	var player: CharacterBody3D = stage[1]
	var calibration: IWEPerspectiveCalibration = stage[2]
	player.set_speed_multiplier(10.0)
	player.global_position = _floor_world(Vector2(200, 495), calibration)
	await get_tree().physics_frame
	player.move_to(_floor_world(Vector2(650, 495), calibration))
	var frames := 0
	var closest := INF
	while player.is_moving_along_path() and frames < 2000:
		await get_tree().physics_frame
		frames += 1
		closest = minf(closest, _distance_to_outline(player.global_position, cutout, calibration))
	var arrived := _world_to_image(player.global_position, calibration)
	assert_bool(player.is_moving_along_path()).override_failure_message("stalled at %s" % arrived).is_false()
	assert_float(arrived.distance_to(Vector2(650, 495))).is_less(30.0)
	assert_float(closest).override_failure_message("never entered the obstacle").is_greater(0.0)
	stage[0].queue_free()


func test_a_straight_path_is_left_alone() -> void:
	var stage := await _stage(_rect(350, 450, 150, 90))
	var player: CharacterBody3D = stage[1]
	var calibration: IWEPerspectiveCalibration = stage[2]
	player.global_position = _floor_world(Vector2(200, 600), calibration)
	await get_tree().physics_frame
	var target := _floor_world(Vector2(650, 600), calibration)
	player.move_to(target)
	var path: PackedVector3Array = player._path
	assert_int(path.size()).is_less_equal(2)
	assert_float(path[path.size() - 1].distance_to(NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, target))).is_less(0.001)
	stage[0].queue_free()


func test_the_character_crosses_a_narrow_doorway_between_two_rooms() -> void:
	# Room B is a corridor that touches only the middle of room A's right wall: a doorway.
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	var room: Resource = REGION_SCRIPT.new()
	room.id = "room"
	room.name = "Room"
	room.points = _rect(100, 380, 300, 250)
	document.add_region(room)
	var corridor: Resource = REGION_SCRIPT.new()
	corridor.id = "corridor"
	corridor.name = "Corridor"
	corridor.points = _rect(400, 480, 350, 60)
	document.add_region(corridor)
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0))
	var texture := ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	assert_str(calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)).is_empty()
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, true)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	var player := root.get_node("Player") as CharacterBody3D
	var frames := 0
	while (frames < 12 or not player._navigation_settled) and frames < 600:
		await scene_tree.physics_frame
		frames += 1
	player.set_speed_multiplier(10.0)
	player.global_position = _floor_world(Vector2(150, 600), calibration)
	await scene_tree.physics_frame
	player.move_to(_floor_world(Vector2(700, 510), calibration))
	frames = 0
	while player.is_moving_along_path() and frames < 3000:
		await scene_tree.physics_frame
		frames += 1
	var arrived := _world_to_image(player.global_position, calibration)
	assert_float(arrived.x).override_failure_message("stalled at %s" % arrived).is_greater(650.0)
	root.queue_free()
	await scene_tree.process_frame


func test_a_walk_requested_before_the_navigation_is_ready_counts_as_under_way() -> void:
	# Code that waits for the walk to end must not stop before the walk has begun: a request made while
	# the navigation server has no regions yet is kept, and reports as moving.
	var player := IWEWalkmeshCharacter.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(player)
	player.move_to(Vector3(1.0, 0.0, 1.0))
	assert_bool(player.is_moving_along_path()).is_true()
	player.stop()
	assert_bool(player.is_moving_along_path()).is_false()
	player.queue_free()
	await scene_tree.process_frame

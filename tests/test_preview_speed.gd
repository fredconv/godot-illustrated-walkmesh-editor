extends GdUnitTestSuite
## Test-character speed: base speed, a testing multiplier, pause, and reset.
##
## The multiplier is a testing aid. It must not change what is authored or exported, and it must
## not add a second perspective effect: the walk is the same in world space at every depth, and
## the apparent speed on screen comes from the camera.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const IMAGE_SIZE := Vector2i(1000, 700)
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WORLD_SCALE := 0.01
const PRESETS := [1.0, 2.0, 5.0, 10.0]
## Where the character is and which way it faces depend on the walk, not on what is exported.
const MOVING_STATE := ["position", "rotation", "transform", "basis", "quaternion", "velocity", "scale"]

var _calibration: IWEPerspectiveCalibration


# ---- helpers ------------------------------------------------------------------------------


## One wide walkable zone, deep enough for a near and a far lane.
func _make_document() -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	var group: Resource = GROUP_SCRIPT.create_group("Ground")
	document.add_group(group)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "wide_floor"
	region.name = "Wide floor"
	region.group_id = group.id
	region.points = PackedVector2Array([Vector2(50, 300), Vector2(950, 300), Vector2(950, 650), Vector2(50, 650)])
	document.add_region(region)
	document.scale_anchors.append(ANCHOR_SCRIPT.create_anchor(Vector2(250, 620), 200.0))
	document.scale_anchors.append(ANCHOR_SCRIPT.create_anchor(Vector2(750, 320), 90.0))
	return document


func _texture() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))


func _build(document: Resource) -> Node3D:
	_calibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	assert_str(_calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)).is_empty()
	return SCENE_GENERATOR.build_perspective_scene(document, _texture(), _calibration, WORLD_SCALE, true)


## A stage in the tree whose navigation has settled, with its player.
func _start_stage(document: Resource) -> Array:
	var root := _build(document)
	var player := root.get_node("Player") as CharacterBody3D
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	for _frame in 12:
		await scene_tree.physics_frame
	return [root, player]


func _floor_world(image_point: Vector2) -> Vector3:
	var floor_point: Variant = PROJECTOR.image_point_to_floor(image_point, IMAGE_SIZE, _calibration.reference_viewport_size, _calibration.camera_position, _calibration.camera_rotation_degrees, _calibration.field_of_view_degrees, _calibration.floor_height)
	return Vector3(floor_point.x, _calibration.floor_height, floor_point.z) * WORLD_SCALE


func _screen(world_position: Vector3) -> Vector2:
	var floor_point := world_position / WORLD_SCALE
	var screen: Variant = PROJECTOR.world_to_viewport(Vector3(floor_point.x, _calibration.floor_height, floor_point.z), _calibration.reference_viewport_size, _calibration.camera_position, _calibration.camera_rotation_degrees, _calibration.field_of_view_degrees)
	return screen


## Walks `frames` physics frames along +X (sideways on screen) and returns the world distance.
func _walk_sideways(player: CharacterBody3D, from_image_point: Vector2, frames: int) -> float:
	var scene_tree := Engine.get_main_loop() as SceneTree
	player.global_position = _floor_world(from_image_point)
	await scene_tree.physics_frame
	var start := player.global_position
	for _frame in frames:
		player.set_move_input(Vector3.RIGHT)
		await scene_tree.physics_frame
	return (player.global_position - start).length()


func _finish(root: Node) -> void:
	root.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame


# ---- speed model --------------------------------------------------------------------------


func test_effective_speed_is_base_speed_times_the_multiplier() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	var base: float = player.move_speed
	assert_float(base).is_greater(0.0)
	for preset in PRESETS:
		player.set_speed_multiplier(preset)
		assert_float(player.get_effective_speed()).is_equal_approx(base * preset, 0.0001)
	assert_float(player.move_speed).override_failure_message("the base speed is never altered by the multiplier").is_equal(base)
	player.set_speed_multiplier(1000.0)
	assert_float(player.speed_multiplier).is_equal(player.MAX_SPEED_MULTIPLIER)
	player.set_speed_multiplier(0.0)
	assert_float(player.speed_multiplier).is_equal(player.MIN_SPEED_MULTIPLIER)
	await _finish(stage[0])


func test_a_new_character_walks_at_normal_speed() -> void:
	var stage := await _start_stage(_make_document())
	assert_float(stage[1].speed_multiplier).is_equal(1.0)
	assert_bool(stage[1].is_paused()).is_false()
	await _finish(stage[0])


func test_distance_walked_is_proportional_to_the_multiplier_at_every_preset() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	var frames := 6
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	for preset in PRESETS:
		player.set_speed_multiplier(preset)
		var distance: float = await _walk_sideways(player, Vector2(120, 600), frames)
		var expected: float = player.move_speed * preset * frames * step
		assert_float(distance).override_failure_message("distance at x%s" % preset).is_equal_approx(expected, expected * 0.01)
	await _finish(stage[0])


# ---- playback -----------------------------------------------------------------------------


func test_changing_the_multiplier_while_walking_takes_effect_without_a_restart() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	var scene_tree := Engine.get_main_loop() as SceneTree
	player.global_position = _floor_world(Vector2(100, 600))
	await scene_tree.physics_frame
	player.move_to(_floor_world(Vector2(900, 600)))
	assert_bool(player.is_moving_along_path()).is_true()
	var slow_steps := []
	var fast_steps := []
	var last: Vector3 = player.global_position
	for _frame in 6:
		await scene_tree.physics_frame
		slow_steps.append((player.global_position - last).length())
		last = player.global_position
	player.set_speed_multiplier(5.0)
	assert_bool(player.is_moving_along_path()).override_failure_message("the walk continues").is_true()
	for _frame in 6:
		await scene_tree.physics_frame
		fast_steps.append((player.global_position - last).length())
		last = player.global_position
	var slow: float = slow_steps.back()
	var fast: float = fast_steps.back()
	assert_float(fast / slow).override_failure_message("same path, five times the step").is_equal_approx(5.0, 0.1)
	await _finish(stage[0])


func test_pause_freezes_the_character_and_resume_continues_the_same_path() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	var scene_tree := Engine.get_main_loop() as SceneTree
	var destination := _floor_world(Vector2(900, 600))
	player.global_position = _floor_world(Vector2(100, 600))
	await scene_tree.physics_frame
	player.move_to(destination)
	for _frame in 10:
		await scene_tree.physics_frame
	player.pause()
	assert_bool(player.is_paused()).is_true()
	var frozen: Vector3 = player.global_position
	for _frame in 30:
		await scene_tree.physics_frame
	assert_vector(player.global_position).override_failure_message("no movement while paused").is_equal_approx(frozen, Vector3.ONE * 0.0001)
	assert_bool(player.is_moving_along_path()).override_failure_message("the path is kept while paused").is_true()
	player.resume()
	player.set_speed_multiplier(10.0)
	for _frame in 600:
		await scene_tree.physics_frame
		if not player.is_moving_along_path():
			break
	assert_bool(player.is_moving_along_path()).is_false()
	assert_float(player.global_position.distance_to(destination)).is_less(0.15)
	await _finish(stage[0])


func test_reset_position_returns_to_the_start_and_keeps_speed_settings() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	var scene_tree := Engine.get_main_loop() as SceneTree
	var start: Vector3 = player.global_position
	player.set_speed_multiplier(5.0)
	player.move_to(_floor_world(Vector2(900, 600)))
	for _frame in 20:
		await scene_tree.physics_frame
	assert_float(player.global_position.distance_to(start)).is_greater(0.2)
	player.pause()
	player.reset_position()
	# The start is where the stage placed the character; the navigation snap may have moved it a
	# millimetre or so before the walk began (contact offset).
	assert_vector(player.global_position).is_equal_approx(start, Vector3.ONE * 0.005)
	assert_bool(player.is_moving_along_path()).override_failure_message("a reset cancels the path").is_false()
	assert_float(player.speed_multiplier).is_equal(5.0)
	assert_bool(player.is_paused()).is_true()
	player.resume()
	for _frame in 10:
		await scene_tree.physics_frame
	assert_vector(player.global_position).override_failure_message("stays at the start with no path").is_equal_approx(start, Vector3.ONE * 0.005)
	await _finish(stage[0])


func test_the_character_stays_on_the_walkable_floor_at_the_highest_speed() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	var scene_tree := Engine.get_main_loop() as SceneTree
	player.set_speed_multiplier(10.0)
	player.global_position = _floor_world(Vector2(100, 600))
	await scene_tree.physics_frame
	# Aim past the lower edge of the floor: the walls and the navigation snap must hold.
	var map: RID = player.get_world_3d().navigation_map
	for _frame in 120:
		player.set_move_input((_floor_world(Vector2(500, 700)) - player.global_position).normalized() * Vector3(1, 0, 1))
		await scene_tree.physics_frame
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, player.global_position)
		assert_float(player.global_position.distance_to(closest)).override_failure_message("left the walkable floor").is_less(player.snap_tolerance + 0.01)
	await _finish(stage[0])


# ---- perspective --------------------------------------------------------------------------


func test_world_distance_is_the_same_at_every_depth_so_perspective_is_not_applied_twice() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	for preset in PRESETS:
		player.set_speed_multiplier(preset)
		var near: float = await _walk_sideways(player, Vector2(120, 620), 4)
		var far: float = await _walk_sideways(player, Vector2(120, 340), 4)
		assert_float(near).override_failure_message("near vs far at x%s" % preset).is_equal_approx(far, near * 0.01)
	await _finish(stage[0])


func test_apparent_speed_follows_the_camera_and_scales_with_the_multiplier_at_every_depth() -> void:
	var stage := await _start_stage(_make_document())
	var player: Node = stage[1]
	var screen_distance := {}
	for lane in [Vector2(120, 620), Vector2(120, 340)]:
		for preset in PRESETS:
			player.set_speed_multiplier(preset)
			player.global_position = _floor_world(lane)
			await get_tree().physics_frame
			var before := _screen(player.global_position)
			for _frame in 3:
				player.set_move_input(Vector3.RIGHT)
				await get_tree().physics_frame
			screen_distance[[lane, preset]] = (_screen(player.global_position) - before).length()
	var near := Vector2(120, 620)
	var far := Vector2(120, 340)
	assert_float(screen_distance[[near, 1.0]]).override_failure_message("near moves faster across the screen").is_greater(screen_distance[[far, 1.0]] * 1.2)
	for preset in PRESETS:
		for lane in [near, far]:
			assert_float(screen_distance[[lane, preset]] / screen_distance[[lane, 1.0]]).override_failure_message("x%s at %s" % [preset, lane]).is_equal_approx(preset, preset * 0.03)
	await _finish(stage[0])


# ---- nothing authored or exported changes -------------------------------------------------


func _hash_document(document: Resource) -> String:
	var calibration: IWEPerspectiveCalibration = _calibration
	var parts := [var_to_str(document.regions[0].points), var_to_str(document.image_size), var_to_str(calibration.camera_position), var_to_str(calibration.camera_rotation_degrees), str(calibration.field_of_view_degrees), var_to_str(calibration.reference_viewport_size)]
	for anchor in document.scale_anchors:
		parts.append(var_to_str(anchor.position) + str(anchor.apparent_height_px))
	return "|".join(parts)


## What the exported scene would store: every stored property of every node, plus the navigation
## polygons and wall shapes. Packing the whole stage to a file is far too heavy for a test.
func _export_signature(root: Node) -> Array:
	var lines := []
	var nodes := [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		var entry := [str(root.get_path_to(node)), node.get_class()]
		for property in node.get_property_list():
			if not (property["usage"] & PROPERTY_USAGE_STORAGE) or property["name"] in MOVING_STATE:
				continue
			var value: Variant = node.get(property["name"])
			if value is NavigationMesh:
				entry.append([property["name"], var_to_str(value.vertices), var_to_str(value.get_polygon_count())])
			elif value is ConcavePolygonShape3D:
				entry.append([property["name"], var_to_str(value.data)])
			elif not (value is Object):
				entry.append([property["name"], var_to_str(value)])
		lines.append(entry)
	return lines


func test_the_multiplier_changes_neither_the_document_nor_the_exported_scene() -> void:
	var document := _make_document()
	var stage := await _start_stage(document)
	var root: Node3D = stage[0]
	var player: Node = stage[1]
	var scene_tree := Engine.get_main_loop() as SceneTree
	var document_before := _hash_document(document)
	var exported_before := _export_signature(root)
	player.set_speed_multiplier(10.0)
	player.global_position = _floor_world(Vector2(100, 600))
	await scene_tree.physics_frame
	player.move_to(_floor_world(Vector2(900, 600)))
	for _frame in 30:
		await scene_tree.physics_frame
	player.pause()
	player.reset_position()
	assert_str(_hash_document(document)).override_failure_message("authored data and calibration are untouched").is_equal(document_before)
	assert_array(_export_signature(root)).override_failure_message("the exported scene must not depend on the testing speed").is_equal(exported_before)
	# The multiplier is a plain variable, not a stored property, so it can never reach a saved scene.
	var stored := []
	for property in player.get_property_list():
		if property["usage"] & PROPERTY_USAGE_STORAGE:
			stored.append(property["name"])
	assert_array(stored).contains(["move_speed"])
	assert_bool("speed_multiplier" in stored).is_false()
	await _finish(root)

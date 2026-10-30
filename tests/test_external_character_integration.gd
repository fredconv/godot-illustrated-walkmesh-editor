extends GdUnitTestSuite
## An exported stage used with a character that is not the plugin's: a plain CharacterBody3D with its own
## controller (examples/integration/external_character.gd), Godot's NavigationAgent3D, and nothing from the
## plugin but the group "iwe_traveller". Also the shipped example levels, played from one to the other.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const CHARACTER_SCENE := preload("res://examples/integration/external_character.tscn")
const CHARACTER_SCRIPT_PATH := "res://examples/integration/external_character.gd"
const GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")


func before_test() -> void:
	IWEStageTravel.reset()


func after_test() -> void:
	IWEStageTravel.reset()
	var current := get_tree().current_scene
	if current != null and current.name.begins_with("Level"):
		get_tree().root.remove_child(current)
		current.free()
		get_tree().current_scene = null


func _calibrated_document() -> IWEDocument:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var document: IWEDocument = dock._document
	dock.queue_free()
	return document


## The exported village stage with an external character standing at `start_pixel`.
func _stage_with_external_hero(document: IWEDocument, start_pixel: Vector2, element_textures: Dictionary = {}) -> Array:
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	var stage := GENERATOR.build_perspective_scene(document, load(VILLAGE.BACKGROUND) as Texture2D, calibration, VILLAGE.WORLD_SCALE, false, element_textures)
	get_tree().root.add_child(stage)
	var hero := CHARACTER_SCENE.instantiate() as CharacterBody3D
	hero.position = VILLAGE.floor_world(start_pixel, calibration)
	get_tree().root.add_child(hero)
	var map := hero.get_world_3d().navigation_map
	var frames := 0
	var last_iteration := -1
	var stable := 0
	while stable < 8 and frames < 600:
		await get_tree().physics_frame
		var iteration := NavigationServer3D.map_get_iteration_id(map)
		stable = stable + 1 if iteration != 0 and iteration == last_iteration else 0
		last_iteration = iteration
		frames += 1
	return [stage, hero, calibration]


func _walk_until_arrival(hero: CharacterBody3D, target: Vector3, max_frames := 2400) -> Dictionary:
	hero.walk_to(target)
	var positions: Array[Vector3] = []
	var frames := 0
	var still := 0
	var previous := hero.global_position
	while frames < max_frames and still < 25:
		await get_tree().physics_frame
		frames += 1
		positions.append(hero.global_position)
		still = still + 1 if hero.global_position.distance_to(previous) < 0.0005 else 0
		previous = hero.global_position
	return {"positions": positions, "frames": frames}


func _script_code_without_comments(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


# ---- independence --------------------------------------------------------------------------------


func test_the_external_character_is_a_plain_character_body_with_its_own_script() -> void:
	var hero := CHARACTER_SCENE.instantiate()
	assert_bool(hero is CharacterBody3D).is_true()
	assert_bool(hero is IWEWalkmeshCharacter).override_failure_message("the example must not be the plugin's character").is_false()
	assert_str((hero.get_script() as Script).resource_path).is_equal(CHARACTER_SCRIPT_PATH)
	var code := _script_code_without_comments(CHARACTER_SCRIPT_PATH)
	for forbidden in ["IWEWalkmeshCharacter", "IWEStageTravel", "IWETransitionZone", "IWEDocument", "iwe_walkmesh_character"]:
		assert_bool(code.contains(forbidden)).override_failure_message("the controller refers to %s" % forbidden).is_false()
	hero.free()


# ---- navigation ----------------------------------------------------------------------------------


func test_the_external_character_walks_across_the_exported_zones_to_where_it_was_sent() -> void:
	var document := await _calibrated_document()
	var setup: Array = await _stage_with_external_hero(document, Vector2(150, 880))
	var stage: Node3D = setup[0]
	var hero: CharacterBody3D = setup[1]
	var calibration: IWEPerspectiveCalibration = setup[2]
	hero.speed_multiplier = 10.0
	var target := VILLAGE.floor_world(Vector2(1000, 800), calibration)
	var walk := await _walk_until_arrival(hero, target)
	assert_float(hero.global_position.distance_to(target)).override_failure_message("stopped %.2f from the target after %d frames" % [hero.global_position.distance_to(target), walk.frames]).is_less(0.3)
	stage.free()
	hero.free()


func test_the_external_character_goes_around_the_fountain_and_never_enters_it() -> void:
	var document := await _calibrated_document()
	# From the west side of the fountain to the south-east of it: the straight line crosses the footprint,
	# so the path has to curve round it through the open ground to the south.
	var setup: Array = await _stage_with_external_hero(document, Vector2(500, 520))
	var stage: Node3D = setup[0]
	var hero: CharacterBody3D = setup[1]
	var calibration: IWEPerspectiveCalibration = setup[2]
	hero.speed_multiplier = 10.0
	var target := VILLAGE.floor_world(Vector2(1060, 780), calibration)
	var walk := await _walk_until_arrival(hero, target)
	var footprint := VILLAGE.fountain_footprint(1.0)
	var inside := 0
	var detour := 0.0
	for position in walk.positions:
		var pixel := VILLAGE.world_to_image(position, calibration)
		if pixel != Vector2.INF and Geometry2D.is_point_in_polygon(pixel, footprint):
			inside += 1
	for index in range(1, walk.positions.size()):
		detour += walk.positions[index].distance_to(walk.positions[index - 1])
	var straight := VILLAGE.floor_world(Vector2(500, 520), calibration).distance_to(target)
	assert_int(inside).override_failure_message("the character was inside the fountain on %d frames" % inside).is_equal(0)
	assert_float(hero.global_position.distance_to(target)).override_failure_message("it reached the far side").is_less(0.4)
	assert_float(detour).override_failure_message("it went around, so the walk is longer than the straight line (%.2f against %.2f)" % [detour, straight]).is_greater(straight * 1.03)
	stage.free()
	hero.free()


func test_a_target_that_cannot_be_walked_to_ends_on_the_nearest_walkable_point() -> void:
	var document := await _calibrated_document()
	var setup: Array = await _stage_with_external_hero(document, Vector2(300, 700))
	var stage: Node3D = setup[0]
	var hero: CharacterBody3D = setup[1]
	var calibration: IWEPerspectiveCalibration = setup[2]
	hero.speed_multiplier = 10.0
	# The middle of the fountain is a cutout: nothing can stand there.
	var target := VILLAGE.floor_world(VILLAGE.FOUNTAIN_CENTER, calibration)
	await _walk_until_arrival(hero, target)
	var map := hero.get_world_3d().navigation_map
	var nearest := NavigationServer3D.map_get_closest_point(map, hero.global_position)
	assert_float(hero.global_position.distance_to(nearest)).override_failure_message("the character ended off the walkable area").is_less(0.12)
	var pixel := VILLAGE.world_to_image(hero.global_position, calibration)
	assert_bool(Geometry2D.is_point_in_polygon(pixel, VILLAGE.fountain_footprint(1.0))).is_false()
	stage.free()
	hero.free()


# ---- perspective ---------------------------------------------------------------------------------


## How tall a character of `height_units` (illustration units, before the stage scale) looks on the
## illustration, in illustration pixels, standing where `hero` stands. It uses the calibration's own
## reference frame, so it does not depend on the size of the window the test runs in.
func _apparent_height_in_image_pixels(hero: Node3D, calibration: IWEPerspectiveCalibration, height_units: float) -> float:
	var feet := hero.global_position / VILLAGE.WORLD_SCALE
	var head: Variant = PROJECTOR.world_to_viewport(feet + Vector3.UP * height_units, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	var base: Variant = PROJECTOR.world_to_viewport(feet, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	var viewport_pixels := absf(base.y - head.y)
	return viewport_pixels / PROJECTOR.image_scale_in_viewport(VILLAGE.IMAGE_SIZE, calibration.reference_viewport_size)


func test_the_character_has_the_apparent_size_the_calibration_gives_at_several_depths() -> void:
	var document := await _calibrated_document()
	var setup: Array = await _stage_with_external_hero(document, VILLAGE.NEAR_TEMPLATE[0])
	var stage: Node3D = setup[0]
	var hero: CharacterBody3D = setup[1]
	var calibration: IWEPerspectiveCalibration = setup[2]
	# The capsule of the example is 1.8 high. The calibration's reference character is
	# character_height_units tall (16% of the illustration here), so every size is in the ratio of the two.
	var capsule_height_units := 180.0
	var ratio := capsule_height_units / calibration.character_height_units
	# Both references are met within the calibration's own tolerance (it warns above 5%; the village
	# scene is steep and misses by about 10%), and sizes keep decreasing with depth.
	var near_height := _apparent_height_in_image_pixels(hero, calibration, capsule_height_units)
	hero.global_position = VILLAGE.floor_world(VILLAGE.FAR_TEMPLATE[0], calibration)
	var far_height := _apparent_height_in_image_pixels(hero, calibration, capsule_height_units)
	hero.global_position = VILLAGE.floor_world(Vector2(800, 600), calibration)
	var middle_height := _apparent_height_in_image_pixels(hero, calibration, capsule_height_units)
	assert_float(near_height).override_failure_message("near: %.1f px, expected about %.1f" % [near_height, 230.0 * ratio]).is_between(230.0 * ratio * 0.85, 230.0 * ratio * 1.15)
	assert_float(far_height).override_failure_message("far: %.1f px, expected about %.1f" % [far_height, 105.0 * ratio]).is_between(105.0 * ratio * 0.85, 105.0 * ratio * 1.15)
	assert_bool(near_height > middle_height and middle_height > far_height).override_failure_message("it shrinks steadily with depth: %.1f > %.1f > %.1f" % [near_height, middle_height, far_height]).is_true()
	stage.free()
	hero.free()


func test_the_character_sorts_behind_and_in_front_of_the_foreground_picture_at_several_depths() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var fountain: IWEVisualElement = dock.import_element(ProjectSettings.globalize_path(VILLAGE.FOREGROUND))
	dock._set_element_property(fountain.id, "ground_anchor", Vector2(815, 590))
	var document: IWEDocument = dock._document
	var textures: Dictionary = dock._export_element_textures()
	dock.queue_free()
	var setup: Array = await _stage_with_external_hero(document, Vector2(300, 800), textures)
	var stage: Node3D = setup[0]
	var hero: CharacterBody3D = setup[1]
	var calibration: IWEPerspectiveCalibration = setup[2]
	var camera := stage.find_child("PerspectiveCamera", true, false) as Camera3D
	var quad := stage.find_child("*%s*" % fountain.name.substr(0, 6), true, false) as Node3D
	assert_object(quad).override_failure_message("the exported stage holds the picture as a node").is_not_null()
	var forward := -camera.global_transform.basis.z
	var quad_depth := (quad.global_position - camera.global_position).dot(forward)
	var behind_spots := [Vector2(815, 440), Vector2(815, 400), Vector2(700, 430), Vector2(930, 430)]
	var front_spots := [Vector2(815, 800), Vector2(815, 720), Vector2(700, 790), Vector2(930, 770)]
	for spot in behind_spots:
		hero.global_position = VILLAGE.floor_world(spot, calibration)
		var depth := (hero.global_position - camera.global_position).dot(forward)
		assert_float(depth).override_failure_message("%s is farther than the fountain's ground point, so it is hidden" % spot).is_greater(quad_depth)
	for spot in front_spots:
		hero.global_position = VILLAGE.floor_world(spot, calibration)
		var depth := (hero.global_position - camera.global_position).dot(forward)
		assert_float(depth).override_failure_message("%s is nearer than the fountain's ground point, so it shows in front" % spot).is_less(quad_depth)
	stage.free()
	hero.free()


# ---- the shipped example levels --------------------------------------------------------------------


func _centre_of_zone(level: Node, zone_name: String) -> Vector3:
	var zone := level.find_child(zone_name, true, false) as Area3D
	var shape := zone.get_node("Shape") as CollisionPolygon3D
	var total := Vector3.ZERO
	for vertex in shape.polygon:
		total += shape.global_transform * Vector3(vertex.x, vertex.y, 0.0)
	var centre := total / float(shape.polygon.size())
	return Vector3(centre.x, zone.global_position.y, centre.z)


func _wait_for_scene(scene_name: String, max_frames := 300) -> Node:
	var frames := 0
	while frames < max_frames and (get_tree().current_scene == null or get_tree().current_scene.name != scene_name):
		await get_tree().process_frame
		frames += 1
	for _frame in 4:
		await get_tree().physics_frame
	return get_tree().current_scene


func _wait_for_navigation(hero: Node3D) -> void:
	var map := hero.get_world_3d().navigation_map
	var last := -1
	var stable := 0
	var frames := 0
	while stable < 8 and frames < 600:
		await get_tree().physics_frame
		var iteration := NavigationServer3D.map_get_iteration_id(map)
		stable = stable + 1 if iteration != 0 and iteration == last else 0
		last = iteration
		frames += 1


func test_the_example_levels_send_the_external_character_to_the_cellar_and_back() -> void:
	var village := (load("res://examples/integration/level_village.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(village)
	get_tree().current_scene = village
	var hero := village.get_node("Hero") as CharacterBody3D
	assert_bool(hero.is_in_group(IWEStageTravel.TRAVELLER_GROUP)).is_true()
	await _wait_for_navigation(hero)
	hero.speed_multiplier = 10.0
	var door := _centre_of_zone(village, "Door to the cellar")
	hero.walk_to(door)
	var cellar := await _wait_for_scene("LevelCellar", 900)
	assert_object(cellar).override_failure_message("walking into the door loaded the cellar").is_not_null()
	assert_bool(cellar != village).is_true()
	var arrived := cellar.get_node("Hero") as CharacterBody3D
	var from_village := cellar.find_child("from_village", true, false) as Node3D
	assert_float(arrived.global_position.distance_to(from_village.global_position)).override_failure_message("arrived at the entry point the door names").is_less(0.05)
	assert_bool(IWEStageTravel.is_traveling).override_failure_message("the travel ended once the character arrived").is_false()
	await _wait_for_navigation(arrived)
	# And back up the stairs: the village receives the character at "from_cellar", facing west.
	arrived.speed_multiplier = 10.0
	arrived.walk_to(_centre_of_zone(cellar, "Stairs up"))
	var back := await _wait_for_scene("LevelVillage", 900)
	assert_object(back).override_failure_message("the stairs loaded the village again").is_not_null()
	var returned := back.get_node("Hero") as CharacterBody3D
	var from_cellar := back.find_child("from_cellar", true, false) as Node3D
	assert_float(returned.global_position.distance_to(from_cellar.global_position)).is_less(0.05)
	assert_float(returned.rotation.y).override_failure_message("the entry point faces west").is_equal_approx(deg_to_rad(90.0), 0.05)
	assert_bool(IWEStageTravel.is_traveling).is_false()

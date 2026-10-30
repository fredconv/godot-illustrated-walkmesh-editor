extends GdUnitTestSuite
## End-to-end scenario "village + fountain", part 5: the foreground fountain as a layer. From an empty
## document: import the background, put the fountain picture on the Foreground layer with its ground
## point, draw zones, merge two of them, calibrate, save and reopen, export, and walk behind and in
## front of the fountain. Everything goes through the same calls the dock makes for a person; no mouse.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const SAVE_FOLDER := "user://iwe_e2e_layers"
const FOUNTAIN_GROUND := Vector2(815, 590)


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(SAVE_FOLDER))


func _authored_dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var fountain: IWEVisualElement = dock.import_element(ProjectSettings.globalize_path(VILLAGE.FOREGROUND))
	dock._set_element_property(fountain.id, "ground_anchor", FOUNTAIN_GROUND)
	return dock


func test_the_fountain_is_a_foreground_picture_that_draws_by_depth() -> void:
	var dock := await _authored_dock()
	var fountain: IWEVisualElement = dock._document.visual_elements[0]
	assert_str(fountain.layer_id).is_equal(IWELayer.FOREGROUND_ID)
	assert_int(fountain.depth_mode).is_equal(IWEVisualElement.DepthMode.DEPTH)
	assert_vector(fountain.ground_anchor).is_equal(FOUNTAIN_GROUND)
	assert_int(dock._document.layers.size()).is_equal(2)
	dock.queue_free()


func test_the_stage_hides_the_character_behind_the_fountain_and_shows_it_in_front() -> void:
	var dock := await _authored_dock()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var stage := await VILLAGE.start_stage(get_tree(), dock._document, dock._export_element_textures())
	var quad: MeshInstance3D = null
	for node in stage[0].find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("iwe_element_id"):
			quad = node
	assert_object(quad).override_failure_message("the fountain quad is in the stage").is_not_null()
	var camera_basis := Basis.from_euler(Vector3(deg_to_rad(calibration.camera_rotation_degrees.x), deg_to_rad(calibration.camera_rotation_degrees.y), deg_to_rad(calibration.camera_rotation_degrees.z)))
	var depth_of := func(image_point: Vector2) -> float:
		var world: Vector3 = VILLAGE.floor_world(image_point, calibration)
		return -(camera_basis.inverse() * (world / VILLAGE.WORLD_SCALE - calibration.camera_position)).z * VILLAGE.WORLD_SCALE
	var quad_depth: float = quad.get_meta("iwe_depth_world_units")
	assert_float(depth_of.call(Vector2(815, 440))).override_failure_message("behind the fountain is farther than its quad").is_greater(quad_depth)
	assert_float(depth_of.call(Vector2(815, 800))).override_failure_message("in front of the fountain is nearer than its quad").is_less(quad_depth)
	stage[0].queue_free()
	dock.queue_free()


func test_the_character_walks_around_the_fountain_pictures_do_not_block_it() -> void:
	var dock := await _authored_dock()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var stage := await VILLAGE.start_stage(get_tree(), dock._document, dock._export_element_textures())
	var player: Node = stage[1]
	player.set_speed_multiplier(10.0)
	player.global_position = VILLAGE.floor_world(Vector2(300, 600), calibration)
	await get_tree().physics_frame
	player.move_to(VILLAGE.floor_world(Vector2(1100, 780), calibration))
	var frames := 0
	while player.is_moving_along_path() and frames < 5000:
		await get_tree().physics_frame
		frames += 1
	var arrived := VILLAGE.world_to_image(player.global_position, calibration)
	assert_bool(player.is_moving_along_path()).override_failure_message("did not arrive").is_false()
	assert_float(arrived.distance_to(Vector2(1100, 780))).is_less(60.0)
	stage[0].queue_free()
	dock.queue_free()


func test_save_reopen_and_export_keep_the_fountain() -> void:
	var dock := await _authored_dock()
	var target := SAVE_FOLDER.path_join("village.tres")
	dock._save_document(target)
	var stored: String = dock._document.visual_elements[0].texture_path
	assert_str(stored).starts_with("assets/elements/")
	dock.queue_free()
	await get_tree().process_frame
	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(target)
	assert_int(reopened._document.visual_elements.size()).is_equal(1)
	assert_vector(reopened._document.visual_elements[0].ground_anchor).is_equal(FOUNTAIN_GROUND)
	assert_int(reopened._element_textures.size()).is_equal(1)
	assert_int(reopened._document.schema_version).is_equal(IWEDocument.CURRENT_SCHEMA_VERSION)
	# Export from the reopened document: the stage has the fountain, the 2D scene has a sprite.
	var texture := load(VILLAGE.BACKGROUND) as Texture2D
	var root: Node3D = VILLAGE.SCENE_GENERATOR.build_perspective_scene(reopened._document, texture, reopened._document.perspective_calibration, VILLAGE.WORLD_SCALE, false, reopened._export_element_textures())
	assert_int(root.find_children("*", "MeshInstance3D", true, false).filter(func(node: Node) -> bool: return node.has_meta("iwe_element_id")).size()).is_equal(1)
	assert_int(VILLAGE.SCENE_GENERATOR.take_warnings(root).size()).override_failure_message("a clean export has no warnings").is_equal(0)
	root.free()
	var flat: Node2D = VILLAGE.SCENE_GENERATOR.build_2d_scene(reopened._document, texture, 1.0, false, reopened._export_element_textures())
	assert_object(flat.find_child("VisualElements", true, false)).is_not_null()
	flat.free()
	reopened.queue_free()


func test_layers_do_not_change_where_the_character_can_walk() -> void:
	var dock := await _authored_dock()
	var regions_before := var_to_str(dock._document.regions)
	dock._set_layer_property(IWELayer.FOREGROUND_ID, "visible", false)
	dock._set_layer_property(IWELayer.FOREGROUND_ID, "opacity", 0.3)
	assert_str(var_to_str(dock._document.regions)).is_equal(regions_before)
	dock.queue_free()


func test_merging_the_yard_and_the_crossroads_keeps_the_fountain_cutouts_and_the_walk() -> void:
	var dock := await _authored_dock()
	var yard: IWERegion = dock._document.regions[0]
	var crossroads: IWERegion = dock._document.regions[1]
	dock._select_region(yard.id)
	assert_bool(dock.merge_selected_region_with(crossroads.id)).is_true()
	assert_int(yard.subtraction_polygons.size()).override_failure_message("the fountain footprint and the bench survive").is_greater_equal(2)
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var stage := await VILLAGE.start_stage(get_tree(), dock._document, dock._export_element_textures())
	var player: Node = stage[1]
	player.set_speed_multiplier(10.0)
	player.global_position = VILLAGE.floor_world(Vector2(300, 600), calibration)
	await get_tree().physics_frame
	player.move_to(VILLAGE.floor_world(Vector2(1100, 780), calibration))
	var frames := 0
	var entered_fountain := false
	while player.is_moving_along_path() and frames < 5000:
		await get_tree().physics_frame
		frames += 1
		var image := VILLAGE.world_to_image(player.global_position, calibration)
		if image != Vector2.INF and Geometry2D.is_point_in_polygon(image, VILLAGE.fountain_footprint()):
			entered_fountain = true
	assert_bool(entered_fountain).override_failure_message("the merged zone must still keep the fountain closed").is_false()
	assert_bool(player.is_moving_along_path()).is_false()
	stage[0].queue_free()
	dock.queue_free()

extends GdUnitTestSuite
## End-to-end scenario "village + fountain", part 4: calibration, perspective export, layers,
## and walking around the fountain at several test speeds.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const STAGE_FRAME_LIMIT := 5000
## Measured on 2026-10-29: the fitted camera misses the two templates by 10.6 % (near one too small,
## far one too large). This scene looks down steeply, which the line fitted to the templates models
## less well than the 2.5 % of the gentler demo scene. The bound is a regression guard, not a goal:
## the plugin does not show this residual to the person calibrating yet.
const FIT_BOUND := 0.12


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(VILLAGE.OUTPUT_FOLDER))


func _authored_dock() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	return dock


func _inside_cutout(image_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(image_point, VILLAGE.fountain_footprint()) or Geometry2D.is_point_in_polygon(image_point, VILLAGE.points(VILLAGE.BENCH_CUTOUT))


# ---- calibration --------------------------------------------------------------------------


func test_fitting_the_camera_to_two_templates_reproduces_their_heights_and_is_undoable() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var original_position := calibration.camera_position
	dock._fit_camera_to_references()
	# The fit installs a new calibration object (so undo can swap it back): read it again.
	calibration = dock._document.perspective_calibration
	assert_bool(calibration.camera_position.is_equal_approx(original_position)).override_failure_message("the fit moves the camera").is_false()
	var projector: GDScript = VILLAGE.PROJECTOR
	var reference := calibration.reference_viewport_size
	var fit_scale: float = projector.image_scale_in_viewport(VILLAGE.IMAGE_SIZE, reference)
	for template in [VILLAGE.NEAR_TEMPLATE, VILLAGE.FAR_TEMPLATE]:
		var feet: Vector2 = projector.image_to_viewport(template[0], VILLAGE.IMAGE_SIZE, reference)
		var apparent: float = calibration._apparent_height_at(feet, reference, projector)
		var expected: float = template[1] * fit_scale
		assert_float(absf(apparent - expected) / expected).override_failure_message("template at %s" % template[0]).is_less(FIT_BOUND)
	dock._undo()
	assert_vector(dock._document.perspective_calibration.camera_position).is_equal_approx(original_position, Vector3.ONE * 0.0001)
	dock.queue_free()


func test_the_perspective_view_follows_the_calibration_not_the_dock() -> void:
	var dock := await _authored_dock()
	dock._set_perspective_mode(true)
	await get_tree().process_frame
	assert_bool(dock._perspective_preview.visible).is_true()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var before: Vector3 = VILLAGE.floor_world(Vector2(800, 700), calibration)
	var dirty_before: bool = dock.is_dirty()
	for panel_size in [Vector2(420, 800), Vector2(1100, 520)]:
		dock.size = panel_size
		await get_tree().process_frame
		await get_tree().process_frame
		assert_vector(VILLAGE.floor_world(Vector2(800, 700), dock._document.perspective_calibration)).is_equal_approx(before, Vector3.ONE * 0.0001)
		assert_vector(dock._perspective_preview.get_reference_size()).is_equal(calibration.reference_viewport_size)
	assert_bool(dock.is_dirty()).is_equal(dirty_before)
	dock.queue_free()


# ---- exported perspective scene and layers ------------------------------------------------


func _export(dock: Control) -> Node:
	var folder := ProjectSettings.globalize_path(VILLAGE.OUTPUT_FOLDER)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := VILLAGE.OUTPUT_FOLDER.path_join("village_perspective.tscn")
	dock._pending_export_dimension = 4
	dock._add_player_input.button_pressed = true
	dock._export_scene(path)
	assert_bool(FileAccess.file_exists(path)).override_failure_message("the export wrote a file").is_true()
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert_object(packed).is_not_null()
	return packed.instantiate()


func test_the_exported_perspective_scene_has_regions_templates_a_player_and_one_backdrop() -> void:
	var dock := await _authored_dock()
	var root := _export(dock)
	assert_object(root.get_node_or_null("Player")).is_not_null()
	assert_object(root.find_child("IllustrationBackdrop", true, false)).is_not_null()
	assert_int(root.find_children("Template*", "", true, false).size()).is_greater_equal(2)
	# The four regions are all projected, the crossroads with its merged cutouts.
	var regions := root.get_node("PerspectiveStage/ProjectedWalkableRegions")
	assert_int(regions.get_child_count()).is_greater_equal(1)
	assert_object(root.find_child("Region 2", true, false)).is_not_null()
	root.free()
	dock.queue_free()


func test_there_is_no_foreground_layer_in_the_export_yet() -> void:
	# Layers are designed (docs/LAYER_MANAGER_DESIGN.md) but not implemented: the export has one
	# illustration and nothing that can hide the character behind the fountain. Update this
	# test, and add occlusion tests, when the Layer Manager lands.
	var dock := await _authored_dock()
	var root := _export(dock)
	for node in root.find_children("*", "", true, false):
		var lowered := String(node.name).to_lower()
		assert_bool(lowered.contains("foreground") or lowered.contains("occlu") or lowered.begins_with("layer")).override_failure_message("%s: layers now exist, add tests" % node.name).is_false()
	root.free()
	dock.queue_free()


func test_the_authored_fountain_footprint_matches_the_foreground_picture() -> void:
	var foreground := Image.load_from_file(ProjectSettings.globalize_path(VILLAGE.FOREGROUND))
	var inner := VILLAGE.fountain_footprint(0.8)
	for point in inner:
		assert_float(foreground.get_pixelv(Vector2i(point)).a).override_failure_message("inside the fountain at %s" % point).is_greater(0.9)
	assert_float(foreground.get_pixelv(Vector2i(VILLAGE.FOUNTAIN_CENTER)).a).is_greater(0.9)
	# Well outside the paving the foreground is transparent, so the cutout is not hiding real ground.
	# Only the lower half is checked: the water jet rises above the footprint.
	for point in VILLAGE.fountain_footprint(2.2):
		var pixel := Vector2i(point)
		if point.y >= VILLAGE.FOUNTAIN_CENTER.y and pixel.x >= 0 and pixel.y >= 0 and pixel.x < VILLAGE.IMAGE_SIZE.x and pixel.y < VILLAGE.IMAGE_SIZE.y:
			assert_float(foreground.get_pixelv(pixel).a).override_failure_message("outside the fountain at %s" % point).is_less(0.1)


# ---- walking around the fountain ----------------------------------------------------------


## Walks the player from the yard to the lower right of the crossroads and returns what happened.
func _walk(multiplier: float) -> Dictionary:
	var dock := await _authored_dock()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var stage := await VILLAGE.start_stage(get_tree(), dock._document)
	var player: Node = stage[1]
	player.set_speed_multiplier(multiplier)
	player.global_position = VILLAGE.floor_world(Vector2(300, 600), calibration)
	await get_tree().physics_frame
	player.move_to(VILLAGE.floor_world(Vector2(1100, 780), calibration))
	var path_points: PackedVector3Array = player._path.duplicate()
	var frames := 0
	var entered_cutout := false
	while player.is_moving_along_path() and frames < STAGE_FRAME_LIMIT:
		await get_tree().physics_frame
		frames += 1
		var image := VILLAGE.world_to_image(player.global_position, calibration)
		if image != Vector2.INF and _inside_cutout(image):
			entered_cutout = true
	var final_image := VILLAGE.world_to_image(player.global_position, calibration)
	var result := {"frames": frames, "path": path_points, "entered_cutout": entered_cutout, "final": final_image, "moving": player.is_moving_along_path()}
	stage[0].queue_free()
	dock.queue_free()
	await get_tree().process_frame
	return result


func test_the_character_walks_around_the_fountain_across_the_yard_and_crossroads() -> void:
	var walk := await _walk(1.0)
	assert_bool(walk["moving"]).override_failure_message("did not arrive within %d frames" % STAGE_FRAME_LIMIT).is_false()
	assert_bool(walk["entered_cutout"]).override_failure_message("walked through the fountain or the bench").is_false()
	assert_float(walk["final"].distance_to(Vector2(1100, 780))).override_failure_message("arrival point in image pixels").is_less(60.0)
	assert_int(walk["path"].size()).override_failure_message("a detour is a path with several corners").is_greater(2)


func test_a_faster_test_speed_arrives_sooner_over_the_same_path_without_cutting_corners() -> void:
	var normal := await _walk(1.0)
	var fast := await _walk(5.0)
	var rapid := await _walk(10.0)
	assert_array(fast["path"]).override_failure_message("the path does not depend on the speed").is_equal(normal["path"])
	assert_array(rapid["path"]).is_equal(normal["path"])
	assert_bool(fast["entered_cutout"] or rapid["entered_cutout"]).override_failure_message("fast walking must still respect the cutouts").is_false()
	assert_float(float(normal["frames"]) / float(fast["frames"])).override_failure_message("x5 takes about a fifth of the time").is_equal_approx(5.0, 0.6)
	assert_float(float(normal["frames"]) / float(rapid["frames"])).override_failure_message("x10 takes about a tenth of the time").is_equal_approx(10.0, 1.5)
	assert_float(rapid["final"].distance_to(normal["final"])).override_failure_message("same arrival point").is_less(25.0)


func test_the_bridge_is_reachable_from_the_crossroads_through_the_fully_shared_edge() -> void:
	var dock := await _authored_dock()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var stage := await VILLAGE.start_stage(get_tree(), dock._document)
	var player: Node = stage[1]
	player.set_speed_multiplier(10.0)
	player.global_position = VILLAGE.floor_world(Vector2(1000, 700), calibration)
	await get_tree().physics_frame
	player.move_to(VILLAGE.floor_world(Vector2(1420, 590), calibration))
	var frames := 0
	while player.is_moving_along_path() and frames < STAGE_FRAME_LIMIT:
		await get_tree().physics_frame
		frames += 1
	var arrived := VILLAGE.world_to_image(player.global_position, calibration)
	assert_float(arrived.x).override_failure_message("crossed onto the bridge, ended at %s" % arrived).is_greater(1300.0)
	stage[0].queue_free()
	dock.queue_free()


func _blocked(space: PhysicsDirectSpaceState3D, from_world: Vector3, to_world: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from_world, to_world)
	query.collide_with_bodies = true
	return not space.intersect_ray(query).is_empty()


func test_a_bridge_touching_only_part_of_an_edge_opens_only_that_part() -> void:
	# The bridge shares y = 540..640 of the crossroads' right edge (x = 1200). The wall must be
	# open there and stay everywhere else on that edge.
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Chemins")
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.PLAIN_CROSSROADS))
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.PARTIAL_BRIDGE))
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var stage := await VILLAGE.start_stage(get_tree(), dock._document)
	var player: Node = stage[1]
	var space: PhysicsDirectSpaceState3D = stage[0].get_world_3d().direct_space_state
	var lift := Vector3.UP * 0.8
	for row in [420.0, 480.0, 700.0, 800.0]:
		assert_bool(_blocked(space, VILLAGE.floor_world(Vector2(1150, row), calibration) + lift, VILLAGE.floor_world(Vector2(1250, row), calibration) + lift)).override_failure_message("wall missing at y = %s" % row).is_true()
	for row in [560.0, 590.0, 620.0]:
		assert_bool(_blocked(space, VILLAGE.floor_world(Vector2(1150, row), calibration) + lift, VILLAGE.floor_world(Vector2(1250, row), calibration) + lift)).override_failure_message("wall still closed at y = %s" % row).is_false()
	# And a click-to-move walk crosses it.
	player.set_speed_multiplier(10.0)
	player.global_position = VILLAGE.floor_world(Vector2(1000, 700), calibration)
	await get_tree().physics_frame
	player.move_to(VILLAGE.floor_world(Vector2(1420, 590), calibration))
	var frames := 0
	while player.is_moving_along_path() and frames < STAGE_FRAME_LIMIT:
		await get_tree().physics_frame
		frames += 1
	var arrived := VILLAGE.world_to_image(player.global_position, calibration)
	assert_float(arrived.x).override_failure_message("ended at %s" % arrived).is_greater(1380.0)
	stage[0].queue_free()
	dock.queue_free()

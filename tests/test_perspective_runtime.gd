extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PERSPECTIVE_PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")


func _make_document() -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.resource_name = "Runtime proof"
	document.image_size = Vector2i(400, 300)
	var group: Resource = GROUP_SCRIPT.create_group("Ground")
	document.add_group(group)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "runtime_walkway"
	region.name = "Walkway"
	region.group_id = group.id
	region.points = PackedVector2Array([Vector2(20, 180), Vector2(380, 170), Vector2(380, 290), Vector2(20, 290)])
	document.add_region(region)
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(120, 260), 120.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(300, 200), 60.0))
	return document


func _make_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_SEA_GREEN)
	return ImageTexture.create_from_image(image)


func test_world_to_viewport_inverts_image_to_floor_projection() -> void:
	var image_size := Vector2i(400, 300)
	var viewport_size := Vector2i(1280, 720)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(image_size, viewport_size)
	for image_point in [Vector2(40, 200), Vector2(200, 150), Vector2(360, 280)]:
		var floor_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(image_point, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		assert_bool(floor_point != null).is_true()
		var screen: Variant = PERSPECTIVE_PROJECTOR.world_to_viewport(floor_point, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
		var expected: Vector2 = PERSPECTIVE_PROJECTOR.image_to_viewport(image_point, image_size, viewport_size)
		assert_vector(screen).is_equal_approx(expected, Vector2.ONE * 0.01)


func test_fit_to_scale_anchors_recovers_consistent_character_size() -> void:
	var image_size := Vector2i(400, 300)
	var viewport_size := Vector2i(1280, 720)
	var near: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(120, 280), 120.0)
	var far: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(260, 190), 45.0)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(image_size, viewport_size)
	calibration.character_height_units = 180.0
	var error := calibration.fit_to_scale_anchors([near, far], image_size)
	assert_str(error).is_empty()
	# Each reference must now project to its authored apparent height, within 2%.
	var fit_scale: float = PERSPECTIVE_PROJECTOR.image_scale_in_viewport(image_size, viewport_size)
	for anchor in [near, far]:
		var feet: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(anchor.position, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		var head: Variant = PERSPECTIVE_PROJECTOR.world_to_viewport(feet + Vector3.UP * calibration.character_height_units, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
		var feet_screen: Vector2 = PERSPECTIVE_PROJECTOR.image_to_viewport(anchor.position, image_size, viewport_size)
		var apparent: float = feet_screen.y - head.y
		assert_float(apparent).is_equal_approx(anchor.apparent_height_px * fit_scale, anchor.apparent_height_px * fit_scale * 0.02)


func test_fit_to_scale_anchors_rejects_insufficient_or_inverted_references() -> void:
	var image_size := Vector2i(400, 300)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(image_size)
	var single: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(120, 280), 120.0)
	assert_str(calibration.fit_to_scale_anchors([single], image_size)).is_not_empty()
	# Farther references that look taller contradict a flat floor.
	var near: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(120, 280), 40.0)
	var far: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(260, 190), 150.0)
	assert_str(calibration.fit_to_scale_anchors([near, far], image_size)).is_not_empty()


func test_player_walks_only_on_walkable_floor_and_is_scaled_by_perspective() -> void:
	var document := _make_document()
	var texture := _make_texture(document.image_size)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(document.image_size, Vector2i(1280, 720))
	# Calibrate the camera from the authored references so apparent sizes are meaningful.
	assert_str(calibration.fit_to_scale_anchors(document.scale_anchors, document.image_size)).is_empty()
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, true)
	assert_object(root).is_not_null()
	var player := root.get_node("Player") as CharacterBody3D
	assert_object(player).is_not_null()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	for _frame in 10:
		await scene_tree.physics_frame
	# Walk toward the far end of the walkway, then stop at a point outside it.
	var far_target: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(Vector2(340, 230), document.image_size, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	player.move_to(Vector3(far_target.x, calibration.floor_height, far_target.z) * 0.01)
	for _frame in 1500:
		await scene_tree.physics_frame
		if not player.is_moving_along_path():
			break
	var reached_image := _world_to_image(player.global_position, calibration, document.image_size)
	assert_bool(reached_image.distance_to(Vector2(340, 230)) < 12.0).is_true()
	# Try to leave the walkway through its lower edge (y=290). The bottom of the image is
	# below that edge and still lies on the floor, so the character must stop short of it.
	var outside: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(Vector2(200, 298), document.image_size, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	player.move_to(Vector3(outside.x, calibration.floor_height, outside.z) * 0.01)
	for _frame in 600:
		await scene_tree.physics_frame
	var after := _world_to_image(player.global_position, calibration, document.image_size)
	assert_bool(after.y <= 292.0).is_true()
	# Apparent size: the near character should be taller on screen than the far one.
	var near_height := _screen_height_at(Vector2(120, 280), calibration, document.image_size)
	var far_height := _screen_height_at(Vector2(300, 200), calibration, document.image_size)
	assert_bool(near_height > far_height * 1.5).is_true()
	root.queue_free()
	await scene_tree.process_frame


func _world_to_image(world_position: Vector3, calibration: IWEPerspectiveCalibration, image_size: Vector2i) -> Vector2:
	# The stage root is scaled by 0.01; undo that to get floor units back.
	var floor_point := world_position / 0.01
	var screen: Variant = PERSPECTIVE_PROJECTOR.world_to_viewport(Vector3(floor_point.x, calibration.floor_height, floor_point.z), calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	if screen == null:
		return Vector2.INF
	var image: Variant = PERSPECTIVE_PROJECTOR.viewport_to_image(screen, image_size, calibration.reference_viewport_size)
	return image if image != null else Vector2.INF


func _screen_height_at(image_point: Vector2, calibration: IWEPerspectiveCalibration, image_size: Vector2i) -> float:
	var viewport_size := calibration.reference_viewport_size
	var feet: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(image_point, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	var head: Variant = PERSPECTIVE_PROJECTOR.world_to_viewport(feet + Vector3.UP * calibration.character_height_units, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	var feet_screen: Vector2 = PERSPECTIVE_PROJECTOR.image_to_viewport(image_point, image_size, viewport_size)
	return feet_screen.y - head.y


func test_dock_fit_button_recalibrates_camera_and_undoes() -> void:
	var dock: Control = DOCK_SCENE.instantiate()
	var document := _make_document()
	dock.set_document(document)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(dock)
	await scene_tree.process_frame
	dock._load_illustration(ProjectSettings.globalize_path("res://assets/img/background.png"))
	# The document already has a 400x300 picture, so a picture of another size is confirmed first.
	dock._illustration_dialog.confirmed.emit()
	document.scale_anchors.clear()
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(120, 260), 120.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(300, 200), 60.0))
	var original_height: float = document.perspective_calibration.camera_position.y
	dock._fit_camera_to_references()
	# Regression: a hidden preview must not shrink the calibration reference viewport.
	assert_bool(document.perspective_calibration.reference_viewport_size.x >= 64).is_true()
	var fitted_height: float = document.perspective_calibration.camera_position.y
	assert_bool(is_equal_approx(fitted_height, original_height)).is_false()
	dock._undo()
	assert_bool(is_equal_approx(document.perspective_calibration.camera_position.y, original_height)).is_true()
	dock.queue_free()
	await scene_tree.process_frame


func test_walls_block_the_character_at_walkway_edges() -> void:
	var document := _make_document()
	var texture := _make_texture(document.image_size)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(document.image_size, Vector2i(1280, 720))
	calibration.fit_to_scale_anchors(document.scale_anchors, document.image_size)
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, true)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	for _frame in 10:
		await scene_tree.physics_frame
	var walls := root.get_node("PerspectiveStage/ProjectedWalkableRegions/Ground/Walkway/Collision/Walls") as CollisionShape3D
	assert_object(walls).is_not_null()
	var space := root.get_world_3d().direct_space_state
	var height := calibration.character_height_units * 0.01 * 0.5
	var inside := _floor_world(Vector2(200, 230), document, calibration) + Vector3.UP * height
	var outside := _floor_world(Vector2(200, 298), document, calibration) + Vector3.UP * height
	var inside_query := PhysicsRayQueryParameters3D.create(inside, _floor_world(Vector2(260, 230), document, calibration) + Vector3.UP * height)
	inside_query.collide_with_bodies = true
	assert_bool(space.intersect_ray(inside_query).is_empty()).is_true()
	var leave_query := PhysicsRayQueryParameters3D.create(inside, outside)
	leave_query.collide_with_bodies = true
	var hit := space.intersect_ray(leave_query)
	assert_bool(hit.is_empty()).is_false()
	root.queue_free()
	await scene_tree.process_frame


func _floor_world(image_point: Vector2, document: Resource, calibration: IWEPerspectiveCalibration) -> Vector3:
	var floor_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(image_point, document.image_size, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	return Vector3(floor_point.x, calibration.floor_height, floor_point.z) * 0.01


func test_character_can_back_off_from_a_wall_it_was_pressed_against() -> void:
	var document := _make_document()
	var texture := _make_texture(document.image_size)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(document.image_size, Vector2i(1280, 720))
	calibration.fit_to_scale_anchors(document.scale_anchors, document.image_size)
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, true)
	var player := root.get_node("Player") as CharacterBody3D
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	for _frame in 10:
		await scene_tree.physics_frame
	var start := player.global_position
	var toward_edge := (_floor_world(Vector2(200, 298), document, calibration) - start) * Vector3(1, 0, 1)
	# Press into the lower wall for a while.
	for _frame in 90:
		player.set_move_input(toward_edge.normalized())
		await scene_tree.physics_frame
	var pressed := _world_to_image(player.global_position, calibration, document.image_size)
	assert_bool(pressed.y > 270.0).is_true()
	# Back off toward the centre of the walkway. This used to stay pinned on the edge.
	var back := (_floor_world(Vector2(200, 200), document, calibration) - player.global_position) * Vector3(1, 0, 1)
	for _frame in 60:
		player.set_move_input(back.normalized())
		await scene_tree.physics_frame
	var released := _world_to_image(player.global_position, calibration, document.image_size)
	assert_bool(released.y < pressed.y - 8.0).is_true()
	root.queue_free()
	await scene_tree.process_frame

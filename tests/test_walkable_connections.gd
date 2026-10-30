extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PERSPECTIVE_PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const IMAGE_SIZE := Vector2i(1000, 700)
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


# Three touching zones, drawn one after the other: left path, bridge, right path.
# Each shares a full edge with its neighbour (x=400 and x=600), like a real walkway.
func _make_connected_document() -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	var group: Resource = GROUP_SCRIPT.create_group("Chemin")
	document.add_group(group)
	var left: Resource = REGION_SCRIPT.new()
	left.id = "left_path"
	left.name = "Chemin de gauche"
	left.group_id = group.id
	left.points = _rect(100, 380, 300, 200)
	document.add_region(left)
	var bridge: Resource = REGION_SCRIPT.new()
	bridge.id = "bridge"
	bridge.name = "Pont"
	bridge.group_id = group.id
	bridge.points = _rect(400, 430, 200, 100)
	document.add_region(bridge)
	var right: Resource = REGION_SCRIPT.new()
	right.id = "right_path"
	right.name = "Chemin de droite"
	right.group_id = group.id
	right.points = _rect(600, 380, 300, 200)
	document.add_region(right)
	var near: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0)
	near.name = "Proche"
	var far: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0)
	far.name = "Lointain"
	document.scale_anchors.append(near)
	document.scale_anchors.append(far)
	return document


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


func test_character_walks_across_touching_zones_left_bridge_right() -> void:
	var document := _make_connected_document()
	var texture := ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	assert_str(calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)).is_empty()
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, true)
	var player := root.get_node("Player") as CharacterBody3D
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	for _frame in 10:
		await scene_tree.physics_frame

	# Start on the left path, walk to the far right path through the bridge.
	player.global_position = _floor_world(Vector2(200, 480), calibration)
	for _frame in 20:
		await scene_tree.physics_frame
	player.move_to(_floor_world(Vector2(700, 480), calibration))
	for _frame in 2000:
		await scene_tree.physics_frame
		if not player.is_moving_along_path():
			break
	var reached := _world_to_image(player.global_position, calibration)
	# Walking across the junctions must not stop the character at x=400 or x=600.
	assert_float(reached.x).is_greater(620.0)
	root.queue_free()
	await scene_tree.process_frame

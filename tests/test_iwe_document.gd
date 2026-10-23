extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PERSPECTIVE_PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const CANVAS_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_canvas.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const UNDO_STUB := preload("res://tests/undo_history_stub.gd")
const DOCK_UNDO_STUB := preload("res://tests/dock_undo_stub.gd")


func test_document_serializes_illustration_coordinates() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("assets/illustration_test.png", Vector2i(1920, 1080))
	var region: Resource = REGION_SCRIPT.new()
	region.id = "region_test"
	region.name = "Test region"
	var group: Resource = GROUP_SCRIPT.create_group("Test group")
	region.group_id = group.id
	region.points = PackedVector2Array([Vector2(10, 20), Vector2(100, 20), Vector2(80, 90), Vector2(30, 80)])
	region.subtraction_polygons.append(PackedVector2Array([Vector2(35, 35), Vector2(45, 35), Vector2(45, 45), Vector2(35, 45)]))
	region.subtraction_names.append("Bridge")
	document.add_region(region)
	document.add_group(group)
	var anchor: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(420, 360), 145.0)
	anchor.name = "Far character"
	document.scale_anchors.append(anchor)
	document.perspective_calibration = CALIBRATION_SCRIPT.for_image(document.image_size)
	document.perspective_calibration.field_of_view_degrees = 58.0
	document.perspective_calibration.floor_height = 3.5
	var save_error := ResourceSaver.save(document, "user://iwe_document_test.tres")
	assert_int(save_error).is_equal(OK)
	var loaded: Resource = ResourceLoader.load("user://iwe_document_test.tres")
	assert_object(loaded).is_not_null()
	assert_str(loaded.illustration_path).is_equal("assets/illustration_test.png")
	assert_int(loaded.scale_anchors.size()).is_equal(1)
	assert_str(loaded.scale_anchors[0].name).is_equal("Far character")
	assert_vector(loaded.scale_anchors[0].position).is_equal(Vector2(420, 360))
	assert_float(loaded.scale_anchors[0].apparent_height_px).is_equal(145.0)
	assert_float(loaded.perspective_calibration.field_of_view_degrees).is_equal(58.0)
	assert_float(loaded.perspective_calibration.floor_height).is_equal(3.5)
	assert_vector(loaded.image_size).is_equal(Vector2i(1920, 1080))
	assert_int(loaded.regions.size()).is_equal(1)
	assert_str(loaded.regions[0].id).is_equal("region_test")
	assert_vector(loaded.regions[0].points[2]).is_equal(Vector2(80, 90))
	assert_int(loaded.regions[0].subtraction_polygons.size()).is_equal(1)
	assert_str(loaded.regions[0].subtraction_names[0]).is_equal("Bridge")
	assert_int(loaded.groups.size()).is_equal(1)
	assert_str(loaded.regions[0].group_id).is_equal(loaded.groups[0].id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://iwe_document_test.tres"))


func test_region_hit_testing_and_locked_state_data() -> void:
	var region: Resource = REGION_SCRIPT.new()
	region.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(50, 50), region.points)).is_true()
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(120, 50), region.points)).is_false()
	region.locked = true
	assert_bool(region.locked).is_true()
	var duplicate: Resource = region.duplicate_region()
	assert_str(duplicate.id).is_not_equal(region.id)


func test_dock_requires_image_and_group_then_creates_polygon() -> void:
	var dock: Control = DOCK_SCENE.instantiate()
	var document: Resource = DOCUMENT_SCRIPT.new()
	var undo_history: RefCounted = DOCK_UNDO_STUB.new()
	var undo_context := RefCounted.new()
	dock.set_document(document, undo_history, undo_context)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(dock)
	await scene_tree.process_frame
	var draw_button: Button = dock.get_node("%DrawButton")
	var create_group_button: Button = dock.get_node("%CreateGroupButton")
	assert_bool(create_group_button.disabled).is_true()
	assert_bool(draw_button.disabled).is_true()
	dock._create_group()
	assert_int(document.groups.size()).is_equal(0)

	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	dock._canvas.set_texture(ImageTexture.create_from_image(image))
	dock._has_illustration = true
	dock._refresh_group_options()
	dock._update_workflow_controls()
	assert_bool(create_group_button.disabled).is_false()
	assert_bool(draw_button.disabled).is_true()
	dock._create_group()
	assert_object(dock._active_name_dialog).is_not_null()
	assert_str(dock._active_name_input.text).is_equal("Group 1")
	dock._active_name_input.text = "Chemin de droite"
	dock._active_name_dialog.confirmed.emit()
	assert_int(document.groups.size()).is_equal(1)
	assert_str(document.groups[0].name).is_equal("Chemin de droite")
	assert_bool(draw_button.disabled).is_false()
	var group_id: String = document.groups[0].id
	assert_bool(dock.get_node("%RenameGroupButton").disabled).is_false()
	await scene_tree.process_frame
	dock.get_node("%RenameGroupButton").pressed.emit()
	assert_str(dock._active_name_dialog.title).is_equal("Rename group")
	dock._active_name_input.text = "Sentier principal"
	dock._active_name_dialog.confirmed.emit()
	assert_str(document.groups[0].name).is_equal("Sentier principal")
	assert_int(document.regions.size()).is_equal(0)
	assert_str(dock._group_option.get_item_text(dock._group_option.selected)).is_equal("Sentier principal")
	dock._undo()
	assert_str(document.groups[0].name).is_equal("Chemin de droite")
	dock._redo()
	assert_str(document.groups[0].name).is_equal("Sentier principal")

	var canvas: Control = dock._canvas
	draw_button.button_pressed = true
	for point in [Vector2(10, 10), Vector2(50, 10), Vector2(50, 50), Vector2(10, 10)]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = point
		canvas._gui_input(click)
	assert_int(document.regions.size()).is_equal(1)
	assert_int(document.regions[0].points.size()).is_equal(3)
	assert_str(document.regions[0].group_id).is_equal(group_id)
	dock._select_region(document.regions[0].id)
	assert_bool(dock.get_node("%RenameGroupButton").disabled).is_true()
	assert_bool(dock.get_node("%RenameRegionButton").disabled).is_false()
	assert_bool(dock.get_node("%DuplicateButton").disabled).is_false()
	assert_str(dock.get_node("%DeleteButton").text).is_equal("Delete region")
	dock._undo()
	assert_int(document.regions.size()).is_equal(0)
	dock._redo()
	assert_int(document.regions.size()).is_equal(1)
	var selected_region := false
	canvas.selection_changed.connect(func(region_id: String) -> void: selected_region = region_id == document.regions[0].id)
	dock.get_node("%SelectButton").button_pressed = true
	var selection_click := InputEventMouseButton.new()
	selection_click.button_index = MOUSE_BUTTON_LEFT
	selection_click.pressed = true
	selection_click.position = Vector2(30, 20)
	canvas._gui_input(selection_click)
	assert_str(canvas.get_selected_region().id).is_equal(document.regions[0].id)
	var quad := PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)])
	dock._create_region(quad)
	canvas.set_undo_redo(UNDO_STUB.new())
	var points_button: Button = dock.get_node("%PointsButton")
	points_button.button_pressed = true
	canvas._handle_left_click(Vector2(8, 8))
	assert_int(canvas.get_selected_vertex_index()).is_equal(0)
	var delete_button: Button = dock.get_node("%DeleteButton")
	assert_str(delete_button.text).is_equal("Delete point")
	delete_button.pressed.emit()
	assert_int(document.regions.size()).is_equal(2)
	assert_int(document.regions[1].points.size()).is_equal(3)
	var subtract_button: Button = dock.get_node("%SubtractButton")
	subtract_button.button_pressed = true
	for point in [Vector2(18, 16), Vector2(20, 16), Vector2(18, 18), Vector2(18, 16)]:
		canvas._handle_left_click(point)
	assert_int(document.regions[1].subtraction_polygons.size()).is_equal(1)
	assert_str(document.regions[1].subtraction_names[0]).is_equal("Cutout 1")
	var group_item: TreeItem = dock._region_list.get_root().get_first_child()
	var region_item: TreeItem = group_item.get_first_child()
	while region_item != null and region_item.get_metadata(0).get("id", "") != document.regions[1].id:
		region_item = region_item.get_next()
	assert_object(region_item).is_not_null()
	var cutout_item: TreeItem = region_item.get_first_child()
	assert_str(cutout_item.get_text(0)).is_equal("Cutout 1")
	cutout_item.select(0)
	dock._region_item_selected()
	var rename_cutout_button: Button = dock.get_node("%RenameCutoutButton")
	assert_bool(rename_cutout_button.disabled).is_false()
	await scene_tree.process_frame
	rename_cutout_button.pressed.emit()
	assert_str(dock._active_name_dialog.title).is_equal("Rename cutout")
	dock._active_name_input.text = "Pont"
	dock._active_name_dialog.confirmed.emit()
	assert_str(document.regions[1].subtraction_names[0]).is_equal("Pont")
	assert_str(dock._region_list.get_selected_metadata().get("kind", "")).is_equal("cutout")
	dock._undo()
	assert_str(document.regions[1].subtraction_names[0]).is_equal("Cutout 1")
	dock._redo()
	assert_str(document.regions[1].subtraction_names[0]).is_equal("Pont")
	dock.queue_free()
	await scene_tree.process_frame


func test_region_boolean_subtraction_keeps_multiple_holes() -> void:
	var region: Resource = REGION_SCRIPT.new()
	region.points = PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 200), Vector2(0, 200)])
	region.subtraction_polygons.append(PackedVector2Array([Vector2(20, 20), Vector2(60, 20), Vector2(60, 60), Vector2(20, 60)]))
	region.subtraction_polygons.append(PackedVector2Array([Vector2(120, 120), Vector2(180, 120), Vector2(180, 180), Vector2(120, 180)]))
	var contours: Array[PackedVector2Array] = region.get_walkable_contours()
	assert_int(contours.size()).is_equal(3)
	var holes := 0
	for contour in contours:
		if Geometry2D.is_polygon_clockwise(contour) != Geometry2D.is_polygon_clockwise(region.points):
			holes += 1
	assert_int(holes).is_equal(2)
	var serialized_region: Resource = REGION_SCRIPT.new()
	serialized_region.points = region.points
	serialized_region.subtraction_polygons = region.subtraction_polygons.duplicate(true)
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.add_region(serialized_region)
	var save_error := ResourceSaver.save(document, "user://iwe_boolean_test.tres")
	assert_int(save_error).is_equal(OK)
	var loaded: Resource = ResourceLoader.load("user://iwe_boolean_test.tres")
	assert_int(loaded.regions[0].subtraction_polygons.size()).is_equal(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://iwe_boolean_test.tres"))


func test_canvas_vertex_edit_supports_undo_and_redo() -> void:
	var canvas: Control = CANVAS_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(canvas)
	var history: RefCounted = UNDO_STUB.new()
	canvas.set_undo_redo(history)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "editable_region"
	region.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var regions: Array[IWERegion] = [region]
	canvas.set_regions(regions, region.id)
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.add_region(region)
	canvas.set_document(document)
	var before: PackedVector2Array = region.points.duplicate()
	var after := before.duplicate()
	after[0] = Vector2(10, 10)
	canvas.set_region_points(region.id, after)
	canvas.commit_vertex_move(region.id, before, after)
	assert_vector(region.points[0]).is_equal(Vector2(10, 10))
	history.undo()
	assert_vector(region.points[0]).is_equal(Vector2.ZERO)
	history.redo()
	assert_vector(region.points[0]).is_equal(Vector2(10, 10))
	assert_vector(document.regions[0].points[0]).is_equal(Vector2(10, 10))
	canvas.queue_free()


func test_add_vertex_on_polygon_edge_is_undoable() -> void:
	var canvas: Control = CANVAS_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(canvas)
	var history: RefCounted = UNDO_STUB.new()
	canvas.set_undo_redo(history)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "edge_region"
	region.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var regions: Array[IWERegion] = [region]
	canvas.set_regions(regions, region.id)
	canvas.add_vertex_requested.connect(canvas.add_selected_vertex)
	canvas.set_add_vertex_mode(true)
	canvas._handle_left_click(Vector2(50, 1))
	assert_int(region.points.size()).is_equal(4)
	assert_int(canvas.get_selected_vertex_index()).is_equal(1)
	assert_bool(canvas._vertex_editing).is_true()
	assert_bool(canvas._add_vertex_mode).is_false()
	canvas.remove_selected_vertex()
	assert_int(region.points.size()).is_equal(3)
	assert_object(canvas.get_selected_region()).is_not_null()
	history.undo()
	assert_int(region.points.size()).is_equal(4)
	canvas.queue_free()


func test_scale_template_can_be_placed_moved_resized_and_undone() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var dock: Control = DOCK_SCENE.instantiate()
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.image_size = Vector2i(400, 300)
	var anchor: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(100, 160), 80.0)
	anchor.name = "Traveler"
	document.scale_anchors.append(anchor)
	var history: RefCounted = DOCK_UNDO_STUB.new()
	scene_tree.root.add_child(dock)
	dock.set_document(document, history, RefCounted.new())
	await scene_tree.process_frame
	dock._has_illustration = true
	dock._update_workflow_controls()
	var canvas: Control = dock._canvas
	canvas.set_scale_anchor_mode(true)
	canvas._handle_scale_anchor_click(Vector2(240, 200))
	assert_int(document.scale_anchors.size()).is_equal(2)
	assert_vector(document.scale_anchors[1].position).is_equal(Vector2(240, 200))
	assert_float(document.scale_anchors[1].apparent_height_px).is_equal(160.0)
	history.undo()
	assert_int(document.scale_anchors.size()).is_equal(1)
	history.redo()
	assert_int(document.scale_anchors.size()).is_equal(2)
	canvas._handle_scale_anchor_click(Vector2(100, 160))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(130, 140)
	canvas._gui_input(motion)
	var moved := InputEventMouseButton.new()
	moved.button_index = MOUSE_BUTTON_LEFT
	moved.pressed = false
	canvas._gui_input(moved)
	assert_vector(anchor.position).is_equal(Vector2(130, 140))
	history.undo()
	assert_vector(anchor.position).is_equal(Vector2(100, 160))
	history.redo()
	assert_vector(anchor.position).is_equal(Vector2(130, 140))
	var height_input: SpinBox = dock.get_node("%TemplateHeightInput")
	height_input.value = 120.0
	assert_float(anchor.apparent_height_px).is_equal(120.0)
	history.undo()
	assert_float(anchor.apparent_height_px).is_equal(80.0)
	dock.get_node("%DeleteTemplateButton").pressed.emit()
	assert_int(document.scale_anchors.size()).is_equal(1)
	history.undo()
	assert_int(document.scale_anchors.size()).is_equal(2)
	dock.queue_free()
	await scene_tree.process_frame


func test_dock_perspective_mode_shows_preview_and_places_known_height_anchor() -> void:
	var dock: Control = DOCK_SCENE.instantiate()
	var document: Resource = DOCUMENT_SCRIPT.new()
	var history: RefCounted = DOCK_UNDO_STUB.new()
	var context := RefCounted.new()
	dock.set_document(document, history, context)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(dock)
	await scene_tree.process_frame
	dock._load_illustration(ProjectSettings.globalize_path("res://assets/img/background.png"))
	assert_bool(dock._has_illustration).is_true()
	dock._set_perspective_mode(true)
	assert_bool(dock._perspective_preview.visible).is_true()
	assert_bool(dock._image_scroll.visible).is_false()
	assert_object(dock._perspective_preview._viewport.get_camera_3d()).is_not_null()
	dock._perspective_preview.set_top_view(true)
	assert_bool(dock._perspective_preview._viewport.get_camera_3d().projection == Camera3D.PROJECTION_ORTHOGONAL).is_true()
	dock._perspective_preview.set_top_view(false)
	dock._set_calibration_fov(60.0)
	assert_float(document.perspective_calibration.field_of_view_degrees).is_equal(60.0)
	dock._undo()
	assert_float(document.perspective_calibration.field_of_view_degrees).is_equal(45.0)
	dock._redo()
	assert_float(document.perspective_calibration.field_of_view_degrees).is_equal(60.0)
	dock._create_perspective_anchor(Vector2(400, 320))
	assert_int(document.scale_anchors.size()).is_equal(1)
	assert_vector(document.scale_anchors[0].position).is_equal(Vector2(400, 320))
	dock.queue_free()
	await scene_tree.process_frame


func test_perspective_projection_maps_image_to_floor_and_back() -> void:
	var image_size := Vector2i(320, 180)
	var viewport_size := Vector2i(1280, 720)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(image_size, viewport_size)
	var viewport_center: Vector2 = PERSPECTIVE_PROJECTOR.image_to_viewport(Vector2(160, 90), image_size, viewport_size)
	assert_vector(viewport_center).is_equal(Vector2(640, 360))
	var image_center: Variant = PERSPECTIVE_PROJECTOR.viewport_to_image(viewport_center, image_size, viewport_size)
	assert_vector(image_center).is_equal(Vector2(160, 90))
	var ground_center: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(Vector2(160, 90), image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	assert_bool(ground_center != null).is_true()
	assert_bool(ground_center.is_equal_approx(Vector3(160, 0, 90))).is_true()
	for edge_point in [Vector2.ZERO, Vector2(320, 0), Vector2(320, 180), Vector2(0, 180)]:
		var projected: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(edge_point, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		assert_bool(projected != null).is_true()
	var letterbox_point: Variant = PERSPECTIVE_PROJECTOR.viewport_to_image(Vector2(640, 10), Vector2i(320, 100), Vector2i(1280, 720))
	assert_bool(letterbox_point == null).is_true()


func test_perspective_scene_reprojects_regions_holes_and_known_height_templates() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.resource_name = "Perspective proof"
	document.image_size = Vector2i(160, 120)
	var group: Resource = GROUP_SCRIPT.create_group("Ground")
	var region: Resource = REGION_SCRIPT.new()
	region.id = "projected_walkway"
	region.name = "Walkway"
	region.group_id = group.id
	region.points = PackedVector2Array([Vector2(10, 10), Vector2(150, 12), Vector2(148, 110), Vector2(12, 108)])
	region.subtraction_polygons.append(PackedVector2Array([Vector2(60, 40), Vector2(100, 40), Vector2(100, 80), Vector2(60, 80)]))
	region.subtraction_names.append("Bridge gap")
	document.add_group(group)
	document.add_region(region)
	var marker: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(35, 90), 42.0)
	marker.name = "Near marker"
	document.scale_anchors.append(marker)
	var image := Image.create(160, 120, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_SEA_GREEN)
	var texture := ImageTexture.create_from_image(image)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(document.image_size, Vector2i(800, 600))
	calibration.character_height_units = 36.0
	calibration.floor_height = 2.0
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01)
	assert_object(root).is_not_null()
	assert_bool(root.get_node("PerspectiveStage").scale.is_equal_approx(Vector3.ONE * 0.01)).is_true()
	var perspective_camera: Camera3D = root.get_node("PerspectiveStage/CameraRig/PerspectiveCamera")
	assert_int(perspective_camera.projection).is_equal(Camera3D.PROJECTION_PERSPECTIVE)
	assert_float(perspective_camera.fov).is_equal(45.0)
	var top_camera: Camera3D = root.get_node("PerspectiveStage/CameraRig/TopCamera")
	assert_int(top_camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	var image_plane: MeshInstance3D = root.get_node("PerspectiveStage/PerspectiveProjectedIllustration")
	assert_bool(image_plane.mesh.get_surface_count() > 0).is_true()
	var projected_region: NavigationRegion3D = root.get_node("PerspectiveStage/ProjectedWalkableRegions/Ground/Walkway")
	assert_bool(projected_region.navigation_mesh.get_polygon_count() > 0).is_true()
	assert_object(projected_region.get_node_or_null("Walkable outline")).is_not_null()
	assert_object(projected_region.get_node_or_null("Bridge gap")).is_not_null()
	var projected_hole: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(Vector2(80, 60), document.image_size, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	assert_bool(_navigation_mesh_contains_point(projected_region.navigation_mesh, Vector2(projected_hole.x, projected_hole.z))).is_false()
	var template: Node3D = root.get_node("PerspectiveStage/Near marker")
	var expected_ground: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(marker.position, document.image_size, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	assert_bool(template.position.is_equal_approx(Vector3(expected_ground.x, 2.0, expected_ground.z))).is_true()
	assert_bool(is_equal_approx(template.get_node("Known-height character template").mesh.height, 36.0)).is_true()
	var packed := PackedScene.new()
	assert_int(packed.pack(root)).is_equal(OK)
	assert_int(ResourceSaver.save(packed, "user://iwe_perspective_test.tscn")).is_equal(OK)
	root.free()
	var saved: PackedScene = ResourceLoader.load("user://iwe_perspective_test.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	var loaded := saved.instantiate() as Node3D
	assert_object(loaded.get_node("PerspectiveStage/CameraRig/PerspectiveCamera")).is_not_null()
	assert_object(loaded.get_node("PerspectiveStage/Near marker/Known-height character template").mesh).is_not_null()
	loaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://iwe_perspective_test.tscn"))


func test_perspective_demo_scene_contains_calibrated_image_regions_holes_and_templates() -> void:
	var packed := ResourceLoader.load("res://examples/perspective_calibration_demo.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert_object(packed).is_not_null()
	var stage := packed.instantiate() as Node3D
	assert_object(stage).is_not_null()
	var perspective_camera: Camera3D = stage.get_node("PerspectiveStage/CameraRig/PerspectiveCamera")
	var top_camera: Camera3D = stage.get_node("PerspectiveStage/CameraRig/TopCamera")
	assert_int(perspective_camera.projection).is_equal(Camera3D.PROJECTION_PERSPECTIVE)
	assert_int(top_camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	var image_plane: MeshInstance3D = stage.get_node("PerspectiveStage/PerspectiveProjectedIllustration")
	assert_object(image_plane.material_override.albedo_texture).is_not_null()
	var regions_root: Node3D = stage.get_node("PerspectiveStage/ProjectedWalkableRegions/Walkable ground")
	assert_int(regions_root.get_child_count()).is_equal(2)
	assert_object(regions_root.get_node("Left path/Rock cutout")).is_not_null()
	assert_object(regions_root.get_node("Right path/Water cutout")).is_not_null()
	assert_object(stage.get_node("PerspectiveStage/Near reference/Known-height character template")).is_not_null()
	assert_object(stage.get_node("PerspectiveStage/Far reference/Known-height character template")).is_not_null()
	stage.free()


func test_vertex_selection_persists_after_mouse_release_and_can_move() -> void:
	var canvas: Control = CANVAS_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(canvas)
	var history: RefCounted = UNDO_STUB.new()
	canvas.set_undo_redo(history)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "persistent_vertex"
	region.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var regions: Array[IWERegion] = [region]
	canvas.set_regions(regions, region.id)
	canvas.set_vertex_editing(true)
	canvas._handle_left_click(Vector2(0, 0))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	canvas._gui_input(release)
	assert_int(canvas.get_selected_vertex_index()).is_equal(0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(0, 0)
	canvas._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(15, 20)
	canvas._gui_input(motion)
	canvas._gui_input(release)
	assert_vector(region.points[0]).is_equal(Vector2(15, 20))
	assert_int(canvas.get_selected_vertex_index()).is_equal(0)
	region.subtraction_polygons.append(PackedVector2Array([Vector2(40, 40), Vector2(50, 40), Vector2(50, 50), Vector2(40, 50)]))
	canvas.set_vertex_editing(false)
	assert_int(canvas.get_selected_vertex_index()).is_equal(-1)
	canvas._handle_left_click(Vector2(50, 50))
	motion.position = Vector2(70, 80)
	canvas._gui_input(motion)
	canvas._gui_input(release)
	assert_vector(region.points[0]).is_equal(Vector2(35, 50))
	assert_vector(region.subtraction_polygons[0][0]).is_equal(Vector2(60, 70))
	canvas.queue_free()


func test_remove_selected_vertex_keeps_three_point_minimum() -> void:
	var canvas: Control = CANVAS_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(canvas)
	var history: RefCounted = UNDO_STUB.new()
	canvas.set_undo_redo(history)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "remove_region"
	region.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var regions: Array[IWERegion] = [region]
	canvas.set_regions(regions, region.id)
	canvas.set_selected_vertex(1)
	canvas.remove_selected_vertex()
	assert_int(region.points.size()).is_equal(3)
	history.undo()
	assert_int(region.points.size()).is_equal(4)
	canvas.set_selected_vertex(0)
	canvas.remove_selected_vertex()
	assert_int(region.points.size()).is_equal(3)
	canvas.set_selected_vertex(0)
	canvas.remove_selected_vertex()
	assert_int(region.points.size()).is_equal(3)
	canvas.queue_free()


func test_exported_2d_and_3d_scenes_keep_illustration_scale_and_holes() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.resource_name = "Test walkmesh"
	document.image_size = Vector2i(200, 120)
	var export_group: Resource = GROUP_SCRIPT.create_group("River path")
	var region: Resource = REGION_SCRIPT.new()
	region.id = "export_region"
	region.name = "Riverbank"
	region.group_id = export_group.id
	region.points = PackedVector2Array([Vector2(10, 12), Vector2(188, 24), Vector2(162, 104), Vector2(32, 91)])
	region.subtraction_polygons.append(PackedVector2Array([Vector2(60, 40), Vector2(100, 42), Vector2(95, 62), Vector2(64, 65)]))
	region.subtraction_names.append("Bridge")
	region.subtraction_polygons.append(PackedVector2Array([Vector2(120, 55), Vector2(145, 57), Vector2(140, 75), Vector2(122, 72)]))
	region.subtraction_names.append("Pond")
	var hidden_region: Resource = REGION_SCRIPT.new()
	hidden_region.id = "hidden_region"
	hidden_region.name = "Hidden"
	hidden_region.visible = false
	hidden_region.points = region.points.duplicate()
	document.add_region(region)
	document.add_region(hidden_region)
	document.add_group(export_group)
	var scale_anchor: IWEScaleAnchor = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(72, 86), 90.0)
	scale_anchor.name = "Distant traveler"
	document.scale_anchors.append(scale_anchor)
	var image := Image.create(200, 120, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORNFLOWER_BLUE)
	var texture := ImageTexture.create_from_image(image)

	var root_2d: Node2D = SCENE_GENERATOR.build_2d_scene(document, texture, 0.5, true)
	assert_object(root_2d).is_not_null()
	assert_vector(root_2d.get_node("Template").scale).is_equal(Vector2(0.5, 0.5))
	assert_object(root_2d.get_node_or_null("Template/Illustration")).is_not_null()
	var navigation_2d: NavigationRegion2D = root_2d.get_node("Template/WalkableRegions/Region_Riverbank")
	assert_int(navigation_2d.navigation_polygon.get_outline_count()).is_equal(3)
	assert_bool(navigation_2d.navigation_polygon.get_polygon_count() > 0).is_true()
	assert_object(root_2d.get_node_or_null("Template/Camera2D")).is_not_null()
	assert_object(root_2d.get_node_or_null("Template/WalkableRegions/Region_Hidden")).is_null()
	var packed_2d := PackedScene.new()
	assert_int(packed_2d.pack(root_2d)).is_equal(OK)
	assert_int(ResourceSaver.save(packed_2d, "user://iwe_export_2d_test.tscn")).is_equal(OK)
	root_2d.free()
	var loaded_2d: PackedScene = ResourceLoader.load("user://iwe_export_2d_test.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_object(loaded_2d).is_not_null()
	var instance_2d := loaded_2d.instantiate() as Node2D
	assert_object(instance_2d.get_node("Template/Illustration").texture).is_not_null()
	assert_vector(instance_2d.get_node("Template/Illustration").texture.get_size()).is_equal(Vector2(200, 120))
	assert_bool(instance_2d.get_node("Template/WalkableRegions/Region_Riverbank").navigation_polygon.get_polygon_count() > 0).is_true()
	instance_2d.free()

	var root_3d: Node3D = SCENE_GENERATOR.build_3d_scene(document, texture, 0.01, true)
	assert_object(root_3d).is_not_null()
	assert_bool(root_3d.get_node("Template").scale.is_equal_approx(Vector3(0.01, 0.01, 0.01))).is_true()
	var exported_template: Node3D = root_3d.get_node("Template/ScaleTemplates/Distant traveler")
	assert_bool(exported_template.position.is_equal_approx(Vector3(72, 0, 86))).is_true()
	assert_bool(is_equal_approx(exported_template.get_node("3D height template").mesh.height, 90.0)).is_true()
	assert_bool(is_equal_approx(exported_template.get_node("3D height template").position.y, 45.0)).is_true()
	var plane: Sprite3D = root_3d.get_node("Template/IllustrationPlane")
	assert_object(plane.texture).is_not_null()
	assert_bool(plane.position.is_equal_approx(Vector3(100, -0.25, 60))).is_true()
	var navigation_3d: NavigationRegion3D = root_3d.get_node("Template/WalkableRegions/River path/Riverbank")
	assert_bool(navigation_3d.navigation_mesh.get_polygon_count() > 0).is_true()
	assert_int(navigation_3d.get_child_count()).is_equal(4)
	var walkable_surface: MeshInstance3D = navigation_3d.get_node("Walkable surface")
	assert_object(walkable_surface.mesh).is_not_null()
	assert_bool(walkable_surface.position.y > plane.position.y).is_true()
	assert_bool(walkable_surface.material_override.albedo_color.a > 0.0).is_true()
	assert_object(navigation_3d.get_node_or_null("Walkable outline")).is_not_null()
	assert_object(navigation_3d.get_node_or_null("Bridge")).is_not_null()
	assert_object(navigation_3d.get_node_or_null("Pond")).is_not_null()
	assert_bool(is_zero_approx(navigation_3d.navigation_mesh.agent_radius)).is_true()
	var nav_vertices: PackedVector3Array = navigation_3d.navigation_mesh.get_vertices()
	var z_min := INF
	var z_max := -INF
	var x_min := INF
	var x_max := -INF
	for vertex in nav_vertices:
		assert_bool(is_zero_approx(vertex.y)).is_true()
		x_min = minf(x_min, vertex.x)
		x_max = maxf(x_max, vertex.x)
		z_min = minf(z_min, vertex.z)
		z_max = maxf(z_max, vertex.z)
	assert_bool(is_equal_approx(x_min, 10.0)).is_true()
	assert_bool(is_equal_approx(x_max, 188.0)).is_true()
	assert_bool(is_equal_approx(z_min, 12.0)).is_true()
	assert_bool(is_equal_approx(z_max, 104.0)).is_true()
	for polygon_index in navigation_3d.navigation_mesh.get_polygon_count():
		var polygon_indices: PackedInt32Array = navigation_3d.navigation_mesh.get_polygon(polygon_index)
		var centroid := Vector2.ZERO
		for vertex_index in polygon_indices:
			centroid += Vector2(nav_vertices[vertex_index].x, nav_vertices[vertex_index].z)
		centroid /= polygon_indices.size()
		assert_bool(Geometry2D.is_point_in_polygon(centroid, region.points)).is_true()
		for cutout in region.subtraction_polygons:
			assert_bool(Geometry2D.is_point_in_polygon(centroid, cutout)).is_false()
	assert_bool(_navigation_mesh_contains_point(navigation_3d.navigation_mesh, Vector2(40, 50))).is_true()
	assert_bool(_navigation_mesh_contains_point(navigation_3d.navigation_mesh, Vector2(80, 50))).is_false()
	assert_bool(_navigation_mesh_contains_point(navigation_3d.navigation_mesh, Vector2(132, 65))).is_false()
	var camera_3d: Camera3D = root_3d.get_node("Template/Camera3D")
	assert_bool(is_equal_approx(camera_3d.size, 2.0)).is_true()
	assert_int(camera_3d.keep_aspect).is_equal(Camera3D.KEEP_WIDTH)
	assert_bool(camera_3d.basis.x.is_equal_approx(Vector3.RIGHT)).is_true()
	assert_bool(camera_3d.basis.y.is_equal_approx(Vector3.FORWARD)).is_true()
	var packed_3d := PackedScene.new()
	assert_int(packed_3d.pack(root_3d)).is_equal(OK)
	assert_int(ResourceSaver.save(packed_3d, "user://iwe_export_3d_test.tscn")).is_equal(OK)
	root_3d.free()
	var loaded_3d: PackedScene = ResourceLoader.load("user://iwe_export_3d_test.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_object(loaded_3d).is_not_null()
	var instance_3d := loaded_3d.instantiate() as Node3D
	assert_object(instance_3d.get_node("Template/IllustrationPlane").texture).is_not_null()
	var reloaded_template: Node3D = instance_3d.get_node("Template/ScaleTemplates/Distant traveler")
	assert_bool(reloaded_template.position.is_equal_approx(Vector3(72, 0, 86))).is_true()
	assert_bool(is_equal_approx(reloaded_template.get_node("3D height template").mesh.height, 90.0)).is_true()
	assert_vector(instance_3d.get_node("Template/IllustrationPlane").texture.get_size()).is_equal(Vector2(200, 120))
	var loaded_navigation: NavigationRegion3D = instance_3d.get_node("Template/WalkableRegions/River path/Riverbank")
	assert_bool(loaded_navigation.navigation_mesh.get_polygon_count() > 0).is_true()
	var loaded_bridge: MeshInstance3D = loaded_navigation.get_node("Bridge")
	var loaded_pond: MeshInstance3D = loaded_navigation.get_node("Pond")
	assert_object(loaded_bridge.mesh).is_not_null()
	assert_object(loaded_pond.mesh).is_not_null()
	assert_bool(_navigation_mesh_contains_point(loaded_navigation.navigation_mesh, Vector2(80, 50))).is_false()
	assert_bool(_navigation_mesh_contains_point(loaded_navigation.navigation_mesh, Vector2(132, 65))).is_false()
	var loaded_vertices: PackedVector3Array = loaded_navigation.navigation_mesh.get_vertices()
	var loaded_x_min := INF
	var loaded_x_max := -INF
	var loaded_z_min := INF
	var loaded_z_max := -INF
	for vertex in loaded_vertices:
		loaded_x_min = minf(loaded_x_min, vertex.x)
		loaded_x_max = maxf(loaded_x_max, vertex.x)
		loaded_z_min = minf(loaded_z_min, vertex.z)
		loaded_z_max = maxf(loaded_z_max, vertex.z)
	assert_bool(is_equal_approx(loaded_x_min, 10.0)).is_true()
	assert_bool(is_equal_approx(loaded_x_max, 188.0)).is_true()
	assert_bool(is_equal_approx(loaded_z_min, 12.0)).is_true()
	assert_bool(is_equal_approx(loaded_z_max, 104.0)).is_true()
	instance_3d.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://iwe_export_2d_test.tscn"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://iwe_export_3d_test.tscn"))


func _navigation_mesh_contains_point(navigation_mesh: NavigationMesh, point: Vector2) -> bool:
	var vertices := navigation_mesh.get_vertices()
	for polygon_index in navigation_mesh.get_polygon_count():
		var polygon := PackedVector2Array()
		for vertex_index in navigation_mesh.get_polygon(polygon_index):
			polygon.append(Vector2(vertices[vertex_index].x, vertices[vertex_index].z))
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func test_dock_exports_project_scenes_with_selected_scale_and_camera_option() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.image_size = Vector2i(80, 60)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "dock_export_region"
	region.name = "Path"
	region.points = PackedVector2Array([Vector2(0, 0), Vector2(80, 0), Vector2(80, 60), Vector2(0, 60)])
	document.add_region(region)
	var image := Image.create(80, 60, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_SEA_GREEN)
	var source_path := ProjectSettings.globalize_path("user://iwe_dock_export_source.png")
	assert_int(image.save_png(source_path)).is_equal(OK)
	var dock: Control = DOCK_SCENE.instantiate()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(dock)
	dock.set_document(document, DOCK_UNDO_STUB.new(), RefCounted.new())
	await scene_tree.process_frame
	dock._pending_image_source = source_path
	dock._has_illustration = true
	dock._canvas.set_texture(ImageTexture.create_from_image(image))
	dock._update_workflow_controls()
	assert_bool(dock.get_node("%Export2DButton").disabled).is_false()
	assert_bool(dock.get_node("%Export3DButton").disabled).is_false()
	dock.get_node("%Scale2DInput").value = 0.5
	dock.get_node("%AddCameraInput").button_pressed = true
	dock._pending_export_dimension = 2
	dock._export_scene("res://tests/iwe_dock_export_2d_test.tscn")
	assert_bool(FileAccess.file_exists("res://tests/iwe_dock_export_2d_test.tscn")).is_true()
	var scene_2d: PackedScene = ResourceLoader.load("res://tests/iwe_dock_export_2d_test.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	var instance_2d := scene_2d.instantiate() as Node2D
	assert_bool(instance_2d.get_node("Template").scale.is_equal_approx(Vector2(0.5, 0.5))).is_true()
	assert_object(instance_2d.get_node_or_null("Template/Camera2D")).is_not_null()
	instance_2d.free()
	dock.get_node("%Scale3DInput").value = 0.02
	dock._pending_export_dimension = 3
	dock._export_scene("res://tests/iwe_dock_export_3d_test.tscn")
	assert_bool(FileAccess.file_exists("res://tests/iwe_dock_export_3d_test.tscn")).is_true()
	var scene_3d: PackedScene = ResourceLoader.load("res://tests/iwe_dock_export_3d_test.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	var instance_3d := scene_3d.instantiate() as Node3D
	assert_bool(instance_3d.get_node("Template").scale.is_equal_approx(Vector3(0.02, 0.02, 0.02))).is_true()
	assert_object(instance_3d.get_node_or_null("Template/Camera3D")).is_not_null()
	instance_3d.free()
	dock.queue_free()
	await scene_tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/iwe_dock_export_2d_test.tscn"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/iwe_dock_export_3d_test.tscn"))
	DirAccess.remove_absolute(source_path)

extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
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
	document.add_region(region)
	document.add_group(group)
	var save_error := ResourceSaver.save(document, "user://iwe_document_test.tres")
	assert_int(save_error).is_equal(OK)
	var loaded: Resource = ResourceLoader.load("user://iwe_document_test.tres")
	assert_object(loaded).is_not_null()
	assert_str(loaded.illustration_path).is_equal("assets/illustration_test.png")
	assert_vector(loaded.image_size).is_equal(Vector2i(1920, 1080))
	assert_int(loaded.regions.size()).is_equal(1)
	assert_str(loaded.regions[0].id).is_equal("region_test")
	assert_vector(loaded.regions[0].points[2]).is_equal(Vector2(80, 90))
	assert_int(loaded.regions[0].subtraction_polygons.size()).is_equal(1)
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
	var undo_context := Node.new()
	dock.set_document(document, undo_history, undo_context)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(dock)
	scene_tree.root.add_child(undo_context)
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
	assert_int(document.groups.size()).is_equal(1)
	assert_bool(draw_button.disabled).is_false()
	var group_id: String = document.groups[0].id

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
	dock.queue_free()
	undo_context.queue_free()
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
	canvas.add_selected_vertex(Vector2(50, 1))
	assert_int(region.points.size()).is_equal(4)
	history.undo()
	assert_int(region.points.size()).is_equal(3)
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

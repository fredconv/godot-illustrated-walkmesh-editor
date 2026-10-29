extends GdUnitTestSuite

## Regression tests for the per-document undo history (audit P0-1 and P0-2).
## They drive the real dock and Godot's own UndoRedo class; no test double replaces it.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const SAVE_FOLDER := "user://iwe_history_tests"


func after_test() -> void:
	var folder := ProjectSettings.globalize_path(SAVE_FOLDER)
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file_name))
		DirAccess.remove_absolute(folder)


func _square(x: float, y: float, size: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)])


func _make_document(group_name: String) -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.image_size = Vector2i(400, 300)
	document.add_group(GROUP_SCRIPT.create_group(group_name))
	return document


## A dock ready for authoring: illustration flag set and a group selected.
func _make_dock(document: Resource) -> Control:
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(document)
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	_prepare(dock)
	return dock


func _prepare(dock: Control) -> void:
	dock._has_illustration = true
	if not dock._document.groups.is_empty():
		dock._selected_group_id = dock._document.groups[0].id
	dock._update_workflow_controls()


func _region_ids(document: Resource) -> Array:
	var ids := []
	for region in document.regions:
		ids.append(region.id)
	return ids


func _tree_has_region(dock: Control, region_id: String) -> bool:
	var stack: Array[TreeItem] = [dock._region_list.get_root()]
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		var metadata: Variant = item.get_metadata(0)
		if metadata is Dictionary and metadata.get("kind", "") == "region" and metadata.get("id", "") == region_id:
			return true
		var child := item.get_first_child()
		while child != null:
			stack.append(child)
			child = child.get_next()
	return false


func test_history_is_a_real_godot_undo_redo() -> void:
	var dock := _make_dock(_make_document("Path"))
	await get_tree().process_frame
	assert_bool(dock._history is UndoRedo).is_true()
	assert_bool(dock._undo_button.disabled).is_true()
	assert_bool(dock._redo_button.disabled).is_true()
	dock.queue_free()


func test_create_region_then_undo_and_redo() -> void:
	var document := _make_document("Path")
	var dock := _make_dock(document)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	assert_int(document.regions.size()).is_equal(1)
	var region_id: String = document.regions[0].id
	assert_bool(dock._undo_button.disabled).is_false()
	dock._undo()
	assert_int(document.regions.size()).is_equal(0)
	assert_bool(_tree_has_region(dock, region_id)).is_false()
	dock._redo()
	assert_int(document.regions.size()).is_equal(1)
	assert_str(document.regions[0].id).is_equal(region_id)
	assert_bool(_tree_has_region(dock, region_id)).is_true()
	dock.queue_free()


func test_vertex_move_goes_through_the_dock_history() -> void:
	var document := _make_document("Path")
	var dock := _make_dock(document)
	await get_tree().process_frame
	dock._create_region(_square(0, 0, 100))
	var region: Resource = document.regions[0]
	var canvas: Control = dock._canvas
	canvas.select_region(region.id)
	var before: PackedVector2Array = region.points.duplicate()
	var after := before.duplicate()
	after[0] = Vector2(15, 20)
	canvas.set_region_points(region.id, after)
	canvas.commit_vertex_move(region.id, before, after)
	assert_vector(region.points[0]).is_equal(Vector2(15, 20))
	dock._undo()
	assert_vector(region.points[0]).is_equal(Vector2.ZERO)
	dock._redo()
	assert_vector(region.points[0]).is_equal(Vector2(15, 20))
	dock.queue_free()


func test_delete_then_restore_a_region() -> void:
	var document := _make_document("Path")
	var dock := _make_dock(document)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	var region_id: String = document.regions[0].id
	dock._canvas.select_region(region_id)
	dock._delete_selected_region()
	assert_int(document.regions.size()).is_equal(0)
	dock._undo()
	assert_array(_region_ids(document)).contains_exactly([region_id])
	assert_bool(_tree_has_region(dock, region_id)).is_true()
	dock._redo()
	assert_int(document.regions.size()).is_equal(0)
	dock.queue_free()


func test_cutout_creation_and_rename_are_undoable() -> void:
	var document := _make_document("Path")
	var dock := _make_dock(document)
	await get_tree().process_frame
	dock._create_region(_square(0, 0, 200))
	var region: Resource = document.regions[0]
	dock._create_subtraction(region.id, _square(50, 50, 40))
	assert_int(region.subtraction_polygons.size()).is_equal(1)
	dock._rename_cutout(region.id, 0, "Rock")
	assert_str(region.subtraction_names[0]).is_equal("Rock")
	dock._undo()
	assert_str(region.subtraction_names[0]).is_equal("Cutout 1")
	dock._undo()
	assert_int(region.subtraction_polygons.size()).is_equal(0)
	dock._redo()
	assert_int(region.subtraction_polygons.size()).is_equal(1)
	dock.queue_free()


func test_opening_document_b_does_not_replay_document_a_history() -> void:
	var document_a := _make_document("A")
	var dock := _make_dock(document_a)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	var region_from_a: String = document_a.regions[0].id
	dock._create_region(_square(100, 10, 50))
	dock._undo()   # leaves one action in the redo stack
	var history_a: UndoRedo = dock._history
	# Save document B to disk and open it through the real Open path.
	var document_b := _make_document("B")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_FOLDER))
	var path_b := SAVE_FOLDER.path_join("document_b.tres")
	assert_int(ResourceSaver.save(document_b, path_b)).is_equal(OK)
	dock._open_document(path_b)
	_prepare(dock)
	var opened_b: Resource = dock.get_document()
	assert_bool(is_instance_valid(history_a)).is_false()
	assert_bool(dock._history.has_undo()).is_false()
	assert_bool(dock._history.has_redo()).is_false()
	dock._redo()
	dock._undo()
	dock._undo()
	assert_int(opened_b.regions.size()).is_equal(0)
	assert_bool(_tree_has_region(dock, region_from_a)).is_false()
	# Document A is untouched by anything done after the switch.
	assert_array(_region_ids(document_a)).contains_exactly([region_from_a])
	dock.queue_free()


func test_new_document_starts_with_an_empty_history() -> void:
	var document_a := _make_document("A")
	var dock := _make_dock(document_a)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	dock._new_document()
	var fresh: Resource = dock.get_document()
	assert_object(fresh).is_not_same(document_a)
	assert_bool(dock._history.has_undo()).is_false()
	dock._undo()
	assert_int(fresh.regions.size()).is_equal(0)
	assert_int(document_a.regions.size()).is_equal(1)
	assert_bool(dock._undo_button.disabled).is_true()
	dock.queue_free()


func test_tree_selection_stays_valid_across_undo_and_redo() -> void:
	var document := _make_document("Path")
	var dock := _make_dock(document)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	var region_id: String = document.regions[0].id
	dock._select_region(region_id)
	await get_tree().process_frame
	dock._undo()
	await get_tree().process_frame
	assert_object(dock._canvas.get_selected_region()).is_null()
	var metadata: Dictionary = dock._region_list.get_selected_metadata()
	assert_str(metadata.get("id", "")).is_not_equal(region_id)
	dock._redo()
	await get_tree().process_frame
	dock._select_region(region_id)
	await get_tree().process_frame
	assert_str(dock._region_list.get_selected_metadata().get("id", "")).is_equal(region_id)
	dock.queue_free()


func test_ctrl_z_and_ctrl_shift_z_on_the_canvas_drive_the_history() -> void:
	var document := _make_document("Path")
	var dock := _make_dock(document)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	var undo_key := InputEventKey.new()
	undo_key.keycode = KEY_Z
	undo_key.ctrl_pressed = true
	undo_key.pressed = true
	dock._canvas._gui_input(undo_key)
	assert_int(document.regions.size()).is_equal(0)
	var redo_key := InputEventKey.new()
	redo_key.keycode = KEY_Z
	redo_key.ctrl_pressed = true
	redo_key.shift_pressed = true
	redo_key.pressed = true
	dock._canvas._gui_input(redo_key)
	assert_int(document.regions.size()).is_equal(1)
	dock.queue_free()


func test_freeing_the_dock_frees_its_history() -> void:
	var dock := _make_dock(_make_document("Path"))
	await get_tree().process_frame
	var history: UndoRedo = dock._history
	dock.free()
	assert_bool(is_instance_valid(history)).is_false()

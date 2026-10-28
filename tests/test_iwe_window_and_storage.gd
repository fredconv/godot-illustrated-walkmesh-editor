extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const DOCK_UNDO_STUB := preload("res://tests/dock_undo_stub.gd")
const TEST_FOLDER := "res://iwdock_test_storage"


func after_test() -> void:
	_remove_folder_recursive(ProjectSettings.globalize_path(TEST_FOLDER))


func _make_dock() -> Control:
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new(), DOCK_UNDO_STUB.new(), RefCounted.new())
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(dock)
	return dock


func _remove_folder_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in DirAccess.get_directories_at(path):
		_remove_folder_recursive(path.path_join(directory_name))
	DirAccess.remove_absolute(path)


func test_canvas_window_toggle_moves_canvas_area_and_restores_it() -> void:
	var dock := _make_dock()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var canvas_area: Control = dock.get_node("Workspace/CanvasArea")
	var original_parent := canvas_area.get_parent()
	var original_index := canvas_area.get_index()

	dock._canvas_window_button.set_pressed(true)
	assert_object(dock._canvas_window).is_not_null()
	assert_object(canvas_area.get_parent()).is_same(dock._canvas_window)

	dock._set_canvas_window(false)
	assert_object(dock._canvas_window).is_null()
	assert_object(canvas_area.get_parent()).is_same(original_parent)
	assert_int(canvas_area.get_index()).is_equal(original_index)
	assert_bool(dock._canvas_window_button.button_pressed).is_false()
	dock.queue_free()


func test_save_creates_missing_folder_and_reopen_restores_anchors() -> void:
	var dock := _make_dock()
	await (Engine.get_main_loop() as SceneTree).process_frame
	dock._load_illustration(ProjectSettings.globalize_path("res://assets/img/background.png"))
	dock._create_scale_anchor(Vector2(300, 820), 220.0)
	dock._create_scale_anchor(Vector2(900, 520), 110.0)

	var target := TEST_FOLDER.path_join("chemin_test.tres")
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_FOLDER))).is_false()
	dock._pending_document_path = target
	dock._pending_image_source = ""
	dock._write_document()
	assert_bool(FileAccess.file_exists(target)).is_true()

	dock._open_document(target)
	var document: Resource = dock.get_document()
	assert_int(document.scale_anchors.size()).is_equal(2)
	assert_float(document.scale_anchors[0].apparent_height_px).is_equal(220.0)
	assert_vector(document.scale_anchors[1].position).is_equal(Vector2(900, 520))
	dock.queue_free()


func test_save_dialog_is_a_save_dialog_and_starts_in_project() -> void:
	var dock := _make_dock()
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_int(dock._save_dialog.file_mode).is_equal(FileDialog.FILE_MODE_SAVE_FILE)
	assert_int(dock._open_dialog.file_mode).is_equal(FileDialog.FILE_MODE_OPEN_FILE)
	dock._show_save_dialog()
	# FileDialog shows res:// as the absolute project folder, so compare against that.
	var project_folder := ProjectSettings.globalize_path("res://").simplify_path()
	assert_str(dock._save_dialog.current_dir.simplify_path()).is_equal(project_folder)
	dock._save_dialog.hide()
	dock.queue_free()

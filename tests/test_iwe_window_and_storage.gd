extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const TEST_FOLDER := "res://iwdock_test_storage"


func after_test() -> void:
	_remove_folder_recursive(ProjectSettings.globalize_path(TEST_FOLDER))


func _make_dock() -> Control:
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new())
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


func test_the_window_button_moves_the_whole_interface_and_brings_it_back() -> void:
	var dock := _make_dock()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var toolbar: Control = dock.get_node("DocumentToolbar")
	var workspace: Control = dock.get_node("Workspace")
	var toolbar_index := toolbar.get_index()
	var workspace_index := workspace.get_index()

	dock._window_button.set_pressed(true)
	assert_object(dock._interface_window).is_not_null()
	assert_bool(dock.is_interface_detached()).is_true()
	assert_object(toolbar.get_parent()).override_failure_message("the toolbar goes with the interface").is_same(dock._interface_content)
	assert_object(workspace.get_parent()).override_failure_message("tabs, panels and canvas go with it").is_same(dock._interface_content)
	assert_bool(dock.get_node("DetachedNotice") != null).override_failure_message("the dock keeps a notice").is_true()

	dock._set_interface_window(false)
	assert_object(dock._interface_window).is_null()
	assert_object(toolbar.get_parent()).is_same(dock)
	assert_object(workspace.get_parent()).is_same(dock)
	assert_int(toolbar.get_index()).is_equal(toolbar_index)
	assert_int(workspace.get_index()).is_equal(workspace_index)
	assert_bool(dock._window_button.button_pressed).is_false()
	assert_str(dock._window_button.text).is_equal("Window")
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


func test_region_tree_has_a_column_before_items_are_added() -> void:
	# A tree without columns crashed the editor when selecting a cutout item (cell index 0).
	var dock := _make_dock()
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_int(dock._region_list.columns).is_greater_equal(1)
	var item: TreeItem = dock._region_list.create_item()
	item.set_text(0, "probe")
	item.select(0)
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

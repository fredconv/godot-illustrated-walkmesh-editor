extends GdUnitTestSuite

## Audit P1-7 and P1-8: the picture is stored relative to the document, always beside it, and an
## exported scene references a picture that lives in the project instead of embedding its pixels.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const WORK_FOLDER := "user://iwe_picture_paths"
const PROJECT_EXPORT := "res://tests/_picture_paths_export.tscn"


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(WORK_FOLDER))
	if FileAccess.file_exists(PROJECT_EXPORT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROJECT_EXPORT))


func _dock_with_picture() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.YARD))
	return dock


func test_saving_copies_the_picture_beside_the_document_without_asking_for_a_folder() -> void:
	var dock := await _dock_with_picture()
	var target := WORK_FOLDER.path_join("project_a").path_join("village.tres")
	dock._save_document(target)
	assert_bool(FileAccess.file_exists(target)).override_failure_message("saved without a second dialog").is_true()
	assert_str(dock._document.illustration_path).starts_with("assets/illustration_")
	assert_bool(FileAccess.file_exists(target.get_base_dir().path_join(dock._document.illustration_path))).is_true()
	assert_bool(dock.is_dirty()).is_false()
	dock.queue_free()


func test_the_stored_picture_path_is_relative_not_absolute() -> void:
	var dock := await _dock_with_picture()
	var target := WORK_FOLDER.path_join("project_b").path_join("village.tres")
	dock._save_document(target)
	var stored: String = dock._document.illustration_path
	assert_bool(stored.is_absolute_path()).override_failure_message("stored %s" % stored).is_false()
	assert_bool(stored.contains(":")).is_false()
	var text := FileAccess.get_file_as_string(target)
	assert_bool(text.contains("C:/") or text.contains("res://assets/img")).override_failure_message("the file names no absolute location").is_false()
	dock.queue_free()


func test_a_saved_project_still_opens_after_its_folder_is_moved() -> void:
	var dock := await _dock_with_picture()
	var original_folder := WORK_FOLDER.path_join("before")
	var target := original_folder.path_join("village.tres")
	dock._save_document(target)
	var regions_before: int = dock._document.regions.size()
	dock.queue_free()
	await get_tree().process_frame
	var moved_folder := WORK_FOLDER.path_join("after")
	assert_int(DirAccess.rename_absolute(ProjectSettings.globalize_path(original_folder), ProjectSettings.globalize_path(moved_folder))).is_equal(OK)
	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(moved_folder.path_join("village.tres"))
	assert_bool(reopened._has_illustration).override_failure_message("the picture is found in the moved folder").is_true()
	assert_int(reopened._document.regions.size()).is_equal(regions_before)
	reopened.queue_free()


func test_saving_a_second_time_does_not_copy_the_picture_again() -> void:
	var dock := await _dock_with_picture()
	var target := WORK_FOLDER.path_join("project_c").path_join("village.tres")
	dock._save_document(target)
	var first_path: String = dock._document.illustration_path
	dock._save_document(target)
	assert_str(dock._document.illustration_path).is_equal(first_path)
	assert_int(DirAccess.get_files_at(ProjectSettings.globalize_path(target.get_base_dir().path_join("assets"))).size()).is_equal(1)
	dock.queue_free()


func test_save_as_into_another_folder_brings_its_own_copy_of_the_picture() -> void:
	var dock := await _dock_with_picture()
	dock._save_document(WORK_FOLDER.path_join("first").path_join("village.tres"))
	dock._save_document(WORK_FOLDER.path_join("second").path_join("village.tres"))
	assert_bool(FileAccess.file_exists(WORK_FOLDER.path_join("second").path_join(dock._document.illustration_path))).is_true()
	assert_bool(FileAccess.file_exists(WORK_FOLDER.path_join("first").path_join(dock._document.illustration_path))).is_true()
	dock.queue_free()


func test_an_export_references_a_picture_inside_the_project_instead_of_embedding_it() -> void:
	var dock := await _dock_with_picture()
	dock._create_group_named("Walk")
	dock._pending_export_dimension = 4
	dock._export_scene(PROJECT_EXPORT)
	assert_bool(FileAccess.file_exists(PROJECT_EXPORT)).is_true()
	var size := FileAccess.open(PROJECT_EXPORT, FileAccess.READ).get_length()
	assert_int(size).override_failure_message("exported scene is %d bytes" % size).is_less(1000000)
	var text := FileAccess.get_file_as_string(PROJECT_EXPORT)
	assert_bool(text.contains("background_template.png")).override_failure_message("the scene points at the picture file").is_true()
	dock.queue_free()


func test_exports_of_the_flat_scenes_are_small_too() -> void:
	var dock := await _dock_with_picture()
	for dimension in [2, 3]:
		dock._pending_export_dimension = dimension
		dock._export_scene(PROJECT_EXPORT)
		var size := FileAccess.open(PROJECT_EXPORT, FileAccess.READ).get_length()
		assert_int(size).override_failure_message("%dD scene is %d bytes" % [dimension, size]).is_less(1000000)
	dock.queue_free()

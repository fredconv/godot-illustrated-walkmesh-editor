extends GdUnitTestSuite

## Audit P1-9: the document format version is written explicitly, files from before the field
## still load, and a newer file is refused with a message and left untouched.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const WORK_FOLDER := "user://iwe_schema_version"
const OLD_FIXTURE := "res://tests/fixtures/iwe_document_old_panel_reference.tres"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_FOLDER))


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(WORK_FOLDER))


func _save(document: Resource, file_name: String) -> String:
	var path := WORK_FOLDER.path_join(file_name)
	assert_int(ResourceSaver.save(document, path)).is_equal(OK)
	return path


func test_a_document_is_stamped_with_the_current_version_when_prepared_for_saving() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	assert_int(document.schema_version).override_failure_message("an unsaved document carries no stamp yet").is_equal(1)
	document.prepare_for_save()
	assert_int(document.schema_version).is_equal(DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION)


func test_a_saved_document_names_its_version_in_the_file() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.prepare_for_save()
	var path := _save(document, "current.tres")
	assert_str(FileAccess.get_file_as_string(path)).contains("schema_version = %d" % DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION)


func test_a_document_without_the_field_loads_as_version_one() -> void:
	var loaded: Resource = ResourceLoader.load(OLD_FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_object(loaded).is_not_null()
	assert_str(FileAccess.get_file_as_string(OLD_FIXTURE)).override_failure_message("the fixture must predate the field").not_contains("schema_version")
	assert_int(loaded.schema_version).is_equal(1)
	assert_str(DOCUMENT_SCRIPT.schema_problem(loaded)).is_empty()


func test_a_version_one_file_migrates_in_memory_and_is_saved_as_the_current_version() -> void:
	var loaded: Resource = ResourceLoader.load(OLD_FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE)
	var regions_before: int = loaded.regions.size()
	loaded.prepare_for_save()
	var path := _save(loaded, "resaved.tres")
	var again: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(again.schema_version).is_equal(DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION)
	assert_int(again.layers.size()).is_equal(2)
	assert_int(again.regions.size()).is_equal(regions_before)


func test_a_newer_version_is_reported_with_both_numbers() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.schema_version = DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION + 1
	var message: String = DOCUMENT_SCRIPT.schema_problem(document)
	assert_str(message).contains("version %d" % (DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION + 1))
	assert_str(message).contains("up to version %d" % DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION)


func test_an_invalid_version_is_refused() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.schema_version = 0
	assert_str(DOCUMENT_SCRIPT.schema_problem(document)).is_not_empty()
	document.schema_version = -3
	assert_str(DOCUMENT_SCRIPT.schema_problem(document)).is_not_empty()


func test_the_dock_refuses_a_newer_file_keeps_the_open_document_and_leaves_the_file_alone() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Mine")
	var open_document: Resource = dock._document
	var future: Resource = DOCUMENT_SCRIPT.new()
	future.schema_version = DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION + 1
	var path := _save(future, "future.tres")
	var before := FileAccess.get_md5(path)
	dock._open_document(path)
	assert_object(dock._document).override_failure_message("the open document stays").is_same(open_document)
	assert_str(dock._status_label.text).contains("version %d" % (DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION + 1))
	assert_str(FileAccess.get_md5(path)).override_failure_message("the file is not touched").is_equal(before)
	assert_int(dock._document.groups.size()).is_equal(1)
	dock.queue_free()


func test_the_dock_opens_a_current_file() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	var current: Resource = DOCUMENT_SCRIPT.new()
	current.prepare_for_save()
	var path := _save(current, "ok.tres")
	var before: Resource = dock._document
	dock._open_document(path)
	assert_object(dock._document).override_failure_message("a supported file replaces the document").is_not_same(before)
	dock.queue_free()

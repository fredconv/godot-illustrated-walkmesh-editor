extends GdUnitTestSuite

## Regression tests for unsaved-change protection (audit P1-6): the modified state, its
## consistency with undo and redo, the prompts before data could be lost, save failures, and
## the dock methods behind the two EditorPlugin hooks Godot calls when closing or saving.
## EditorPlugin cannot be instantiated outside the editor, so the plugin's own forwarding is
## checked by hand (docs/DEVELOPMENT.md).

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const FOLDER := "user://iwe_unsaved_tests"


func after_test() -> void:
	_remove_folder_recursive(ProjectSettings.globalize_path(FOLDER))
	_remove_folder_recursive(ProjectSettings.globalize_path("user://iwe_recovery"))


func _remove_folder_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in DirAccess.get_directories_at(path):
		_remove_folder_recursive(path.path_join(directory_name))
	DirAccess.remove_absolute(path)


func _square(x: float, y: float, size: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)])


func _make_document(group_name := "Path") -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.image_size = Vector2i(400, 300)
	document.add_group(GROUP_SCRIPT.create_group(group_name))
	return document


func _make_dock(document: Resource = null) -> Control:
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(document if document != null else _make_document())
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	_prepare(dock)
	return dock


func _prepare(dock: Control) -> void:
	dock._has_illustration = true
	if not dock._document.groups.is_empty():
		dock._selected_group_id = dock._document.groups[0].id
	dock._update_workflow_controls()


func _path(file_name: String) -> String:
	return FOLDER.path_join(file_name)


func _save_to(dock: Control, file_name: String) -> void:
	dock._save_document(_path(file_name))


# ---- The history on its own -------------------------------------------------------------


func _do(history: IWEDocumentHistory, counter: Array, amount: int) -> void:
	history.create_action("change %d" % amount)
	history.add_do_method(func() -> void: counter[0] += amount)
	history.add_undo_method(func() -> void: counter[0] -= amount)
	history.commit_action()


func test_a_new_history_is_not_modified() -> void:
	assert_bool(IWEDocumentHistory.new().is_dirty()).is_false()


func test_a_change_marks_the_document_modified_and_saving_clears_it() -> void:
	var counter := [0]
	var history := IWEDocumentHistory.new()
	_do(history, counter, 1)
	assert_bool(history.is_dirty()).is_true()
	history.mark_saved()
	assert_bool(history.is_dirty()).is_false()


func test_undoing_back_to_the_saved_state_is_clean_and_redo_is_modified_again() -> void:
	var counter := [0]
	var history := IWEDocumentHistory.new()
	_do(history, counter, 1)
	history.mark_saved()
	_do(history, counter, 10)
	assert_bool(history.is_dirty()).is_true()
	history.undo()
	assert_int(counter[0]).is_equal(1)
	assert_bool(history.is_dirty()).is_false()
	history.redo()
	assert_bool(history.is_dirty()).is_true()
	history.undo()
	assert_bool(history.is_dirty()).is_false()


func test_undoing_past_the_saved_state_is_modified() -> void:
	var counter := [0]
	var history := IWEDocumentHistory.new()
	_do(history, counter, 1)
	history.mark_saved()
	history.undo()
	assert_bool(history.is_dirty()).is_true()
	history.redo()
	assert_bool(history.is_dirty()).is_false()


func test_a_new_action_after_undoing_past_the_saved_state_stays_modified() -> void:
	# Saved with one change, undo it, make a different change. The raw undo version equals the
	# saved version again, but the content differs, so the document must stay modified.
	var counter := [0]
	var history := IWEDocumentHistory.new()
	_do(history, counter, 1)
	history.mark_saved()
	var version_when_saved: int = history._undo.get_version()
	history.undo()
	_do(history, counter, 5)
	assert_int(history._undo.get_version()).override_failure_message("the trap: raw versions match again").is_equal(version_when_saved)
	assert_int(counter[0]).is_equal(5)
	assert_bool(history.is_dirty()).is_true()
	history.undo()
	assert_bool(history.is_dirty()).is_true()
	history.mark_saved()
	assert_bool(history.is_dirty()).is_false()


func test_an_untracked_change_survives_undo_until_saved() -> void:
	var counter := [0]
	var history := IWEDocumentHistory.new()
	_do(history, counter, 1)
	history.mark_saved()
	history.note_untracked_change()
	assert_bool(history.is_dirty()).is_true()
	_do(history, counter, 2)
	history.undo()
	assert_bool(history.is_dirty()).is_true()
	history.mark_saved()
	assert_bool(history.is_dirty()).is_false()


# ---- The dock ----------------------------------------------------------------------------


func test_a_new_document_is_not_modified_and_is_called_untitled() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	assert_bool(dock.is_dirty()).is_false()
	assert_str(dock._document_title_label.text).is_equal("Untitled")
	dock.queue_free()


func test_modify_then_save_shows_and_clears_the_indicator() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	assert_bool(dock.is_dirty()).is_true()
	assert_str(dock._document_title_label.text).is_equal("Untitled *")
	_save_to(dock, "my_level.tres")
	assert_bool(FileAccess.file_exists(_path("my_level.tres"))).is_true()
	assert_bool(dock.is_dirty()).is_false()
	assert_str(dock._document_title_label.text).is_equal("my_level")
	dock.queue_free()


func test_undo_to_the_saved_state_clears_the_indicator_and_redo_restores_it() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	_save_to(dock, "my_level.tres")
	dock._create_region(_square(100, 10, 50))
	assert_str(dock._document_title_label.text).is_equal("my_level *")
	dock._undo()
	assert_bool(dock.is_dirty()).is_false()
	assert_str(dock._document_title_label.text).is_equal("my_level")
	dock._redo()
	assert_bool(dock.is_dirty()).is_true()
	assert_str(dock._document_title_label.text).is_equal("my_level *")
	dock.queue_free()


func test_a_change_after_an_undo_past_the_save_stays_modified() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	_save_to(dock, "my_level.tres")
	dock._undo()
	assert_bool(dock.is_dirty()).is_true()
	dock._create_region(_square(200, 10, 50))
	assert_bool(dock.is_dirty()).is_true()
	dock._undo()
	assert_bool(dock.is_dirty()).is_true()
	dock.queue_free()


func test_every_kind_of_edit_marks_the_document_modified_and_undo_restores_the_clean_state() -> void:
	var edits := {
		"create region": func(dock: Control) -> void: dock._create_region(_square(10, 10, 50)),
		"move a vertex": func(dock: Control) -> void:
			dock._create_region(_square(0, 0, 100))
			_mark_clean(dock)
			var region: Resource = dock._document.regions[0]
			var after: PackedVector2Array = region.points.duplicate()
			after[0] = Vector2(5, 5)
			dock._canvas.commit_vertex_move(region.id, region.points.duplicate(), after),
		"create a cutout": func(dock: Control) -> void:
			dock._create_region(_square(0, 0, 200))
			_mark_clean(dock)
			dock._create_subtraction(dock._document.regions[0].id, _square(50, 50, 40)),
		"delete a region": func(dock: Control) -> void:
			dock._create_region(_square(0, 0, 100))
			_mark_clean(dock)
			dock._canvas.select_region(dock._document.regions[0].id)
			dock._delete_selected_region(),
		"rename a group": func(dock: Control) -> void: dock._rename_group(dock._document.groups[0].id, "Renamed"),
		"create a group": func(dock: Control) -> void: dock._create_group_named("Second"),
		"place a template": func(dock: Control) -> void: dock._create_scale_anchor(Vector2(50, 50), 80.0),
		"change the calibration": func(dock: Control) -> void: dock._set_calibration_fov(70.0),
	}
	for label in edits:
		var dock := _make_dock()
		await get_tree().process_frame
		assert_bool(dock.is_dirty()).override_failure_message("%s: starts clean" % label).is_false()
		edits[label].call(dock)
		assert_bool(dock.is_dirty()).override_failure_message("%s: modified after the edit" % label).is_true()
		# Each case is exactly one action after a clean point, so one undo returns to it.
		dock._undo()
		assert_bool(dock.is_dirty()).override_failure_message("%s: clean after one undo" % label).is_false()
		dock.queue_free()


## Treats the current state as saved, without touching the disk, so a test can start from it.
func _mark_clean(dock: Control) -> void:
	dock._history.mark_saved()


func test_importing_an_illustration_marks_the_document_modified_until_saved() -> void:
	# The first import of a document has no picture yet. Replacing a picture is undoable and is
	# covered by test_illustration_reimport.gd.
	var document := _make_document()
	document.image_size = Vector2i.ZERO
	var dock := _make_dock(document)
	await get_tree().process_frame
	dock._load_illustration(ProjectSettings.globalize_path("res://assets/img/background.png"))
	assert_bool(dock.is_dirty()).is_true()
	dock._create_region(_square(10, 10, 50))
	dock._undo()
	assert_bool(dock.is_dirty()).override_failure_message("import cannot be undone, so undo does not clear it").is_true()
	dock._history.mark_saved()
	assert_bool(dock.is_dirty()).is_false()
	dock.queue_free()


func test_changing_the_default_template_height_marks_the_document_modified() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._set_selected_template_height(210.0)
	assert_bool(dock.is_dirty()).is_true()
	dock.queue_free()


# ---- Prompts before data could be lost ---------------------------------------------------


func _saved_document_on_disk(file_name: String, group_name: String) -> String:
	var document := _make_document(group_name)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "region_%s" % group_name
	region.name = group_name
	region.group_id = document.groups[0].id
	region.points = _square(0, 0, 30)
	document.add_region(region)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	assert_int(ResourceSaver.save(document, _path(file_name))).is_equal(OK)
	return _path(file_name)


func test_opening_another_document_while_clean_does_not_ask() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	var other_path := _saved_document_on_disk("other.tres", "Other")
	dock._request_open_document(other_path)
	assert_object(dock._unsaved_dialog).is_null()
	assert_str(dock._document.document_path).is_equal(other_path)
	dock.queue_free()


func test_opening_another_document_with_changes_asks_and_cancel_keeps_everything() -> void:
	var document_a := _make_document("A")
	var dock := _make_dock(document_a)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	var other_path := _saved_document_on_disk("other.tres", "Other")
	dock._request_open_document(other_path)
	assert_object(dock._unsaved_dialog).is_not_null()
	assert_object(dock.get_document()).is_same(document_a)
	dock._unsaved_choice("cancel")
	await get_tree().process_frame
	assert_object(dock.get_document()).is_same(document_a)
	assert_int(document_a.regions.size()).is_equal(1)
	assert_bool(dock.is_dirty()).is_true()
	assert_object(dock._unsaved_dialog).is_null()
	# The undo history was kept too.
	dock._undo()
	assert_int(document_a.regions.size()).is_equal(0)
	dock.queue_free()


func test_discard_changes_opens_the_other_document_and_drops_the_old_edits() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	var other_path := _saved_document_on_disk("other.tres", "Other")
	dock._request_open_document(other_path)
	dock._unsaved_choice("discard")
	assert_str(dock._document.document_path).is_equal(other_path)
	assert_bool(dock.is_dirty()).is_false()
	assert_int(dock._document.regions.size()).is_equal(1)
	dock.queue_free()


func test_save_then_open_writes_the_current_document_first() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	_save_to(dock, "first.tres")
	dock._create_region(_square(100, 10, 50))
	var other_path := _saved_document_on_disk("other.tres", "Other")
	dock._request_open_document(other_path)
	dock._unsaved_choice("save")
	await get_tree().process_frame
	await get_tree().process_frame
	var saved: Resource = ResourceLoader.load(_path("first.tres"), "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(saved.regions.size()).is_equal(2)
	assert_str(dock._document.document_path).is_equal(other_path)
	dock.queue_free()


func test_creating_a_new_document_with_changes_asks_and_cancel_preserves_the_document() -> void:
	var document_a := _make_document("A")
	var dock := _make_dock(document_a)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	dock._request_new_document()
	assert_object(dock._unsaved_dialog).is_not_null()
	dock._unsaved_choice("cancel")
	assert_object(dock.get_document()).is_same(document_a)
	assert_bool(dock.is_dirty()).is_true()
	dock._request_new_document()
	dock._unsaved_choice("discard")
	assert_object(dock.get_document()).is_not_same(document_a)
	assert_bool(dock.is_dirty()).is_false()
	dock.queue_free()


func test_save_on_a_document_without_a_path_asks_where_and_cancelling_that_cancels_the_action() -> void:
	var document_a := _make_document("A")
	var dock := _make_dock(document_a)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	dock._request_new_document()
	dock._unsaved_choice("save")
	assert_bool(dock._save_dialog.visible).is_true()
	assert_object(dock.get_document()).is_same(document_a)
	dock._save_dialog.hide()
	dock._save_dialog.canceled.emit()
	await get_tree().process_frame
	assert_object(dock.get_document()).is_same(document_a)
	assert_bool(dock.is_dirty()).is_true()
	assert_bool(dock._pending_unsaved_action.is_valid()).is_false()
	dock.queue_free()


# ---- Failed saves ------------------------------------------------------------------------


func test_a_failed_save_keeps_the_document_modified_reports_it_and_does_not_run_the_action() -> void:
	var document_a := _make_document("A")
	var dock := _make_dock(document_a)
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	_save_to(dock, "good.tres")
	dock._create_region(_square(100, 10, 50))
	var path_before: String = document_a.document_path
	dock._request_new_document()
	# A disk that refuses to write.
	dock._resource_saver = func(_resource: Resource, _target: String) -> int: return ERR_FILE_NO_PERMISSION
	dock._pending_document_path = _path("never_written.tres")
	var result := [true]
	var expected := "IWE: Could not save %s (%s)" % [_path("never_written.tres"), error_string(ERR_FILE_NO_PERMISSION)]
	await assert_error(func() -> void: result[0] = dock._write_document()).is_push_error(expected)
	assert_bool(result[0]).is_false()
	assert_bool(FileAccess.file_exists(_path("never_written.tres"))).is_false()
	assert_bool(dock.is_dirty()).is_true()
	assert_str(document_a.document_path).is_equal(path_before)
	assert_str(dock._status_label.text).starts_with("Save failed")
	assert_bool(dock._pending_unsaved_action.is_valid()).is_false()
	await get_tree().process_frame
	assert_object(dock.get_document()).is_same(document_a)
	dock.queue_free()


# ---- The two EditorPlugin hooks ----------------------------------------------------------


func test_unsaved_status_is_empty_when_clean_and_describes_the_document_when_modified() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	assert_str(dock.get_unsaved_status("")).is_empty()
	dock._create_region(_square(10, 10, 50))
	assert_str(dock.get_unsaved_status("")).contains("never been saved")
	_save_to(dock, "my_level.tres")
	assert_str(dock.get_unsaved_status("")).is_empty()
	dock._create_region(_square(100, 10, 50))
	assert_str(dock.get_unsaved_status("")).contains("my_level")
	dock.queue_free()


func test_closing_an_unrelated_scene_never_reports_the_iwe_document() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	assert_str(dock.get_unsaved_status("res://some_scene.tscn")).is_empty()
	assert_str(dock.get_unsaved_status("")).is_not_empty()
	dock.queue_free()


func test_save_external_data_writes_a_document_that_has_a_path() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	_save_to(dock, "my_level.tres")
	dock._create_region(_square(100, 10, 50))
	dock.save_external_data()
	assert_bool(dock.is_dirty()).is_false()
	var saved: Resource = ResourceLoader.load(_path("my_level.tres"), "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(saved.regions.size()).is_equal(2)
	dock.queue_free()


func test_save_external_data_never_asks_and_writes_a_recovery_copy_for_a_document_without_a_path() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	dock.save_external_data()
	assert_bool(dock._save_dialog.visible).is_false()
	assert_bool(dock.is_dirty()).override_failure_message("a recovery copy is not a real save").is_true()
	var files := DirAccess.get_files_at(ProjectSettings.globalize_path("user://iwe_recovery"))
	assert_int(files.size()).is_equal(1)
	var recovered: Resource = ResourceLoader.load("user://iwe_recovery/%s" % files[0], "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(recovered.regions.size()).is_equal(1)
	dock.save_external_data()
	assert_int(DirAccess.get_files_at(ProjectSettings.globalize_path("user://iwe_recovery")).size()).override_failure_message("repeated saves overwrite one file").is_equal(1)
	dock.queue_free()


func test_save_external_data_on_a_clean_document_writes_nothing() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock.save_external_data()
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://iwe_recovery"))).is_false()
	dock.queue_free()


func test_save_external_data_does_not_write_when_the_write_in_place_would_fail() -> void:
	var dock := _make_dock()
	await get_tree().process_frame
	dock._create_region(_square(10, 10, 50))
	_save_to(dock, "my_level.tres")
	dock._create_region(_square(100, 10, 50))
	dock._resource_saver = func(_resource: Resource, _target: String) -> int: return ERR_FILE_NO_PERMISSION
	await assert_error(func() -> void: dock.save_external_data()).is_push_error("IWE: Could not save %s (%s)" % [_path("my_level.tres"), error_string(ERR_FILE_NO_PERMISSION)])
	assert_bool(dock.is_dirty()).is_true()
	dock.queue_free()

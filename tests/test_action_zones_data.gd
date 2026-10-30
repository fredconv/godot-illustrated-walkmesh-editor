extends GdUnitTestSuite
## The action zones and entry points of a document (format version 3): saved and loaded back, kept when
## the action is unknown, validated, and the older formats still open unchanged.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const WORK_FOLDER := "user://iwe_action_data"
const V1_FIXTURE := "res://tests/fixtures/iwe_document_old_panel_reference.tres"
const V2_FIXTURE := "res://tests/fixtures/iwe_document_schema2_village.tres"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_FOLDER))


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(WORK_FOLDER))


func _square(x: float, y: float, size := 100.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)])


func _document_with_actions() -> IWEDocument:
	var document := IWEDocument.new()
	document.set_illustration("res://assets/img/background.png", Vector2i(1672, 941))
	var door := IWEActionZone.create_zone("Door to the forest", _square(100, 600))
	door.target_scene = "res://levels/forest.tscn"
	door.entry_id = "from_village"
	door.params = {"fade": 0.5, "sound": "door"}
	document.action_zones.append(door)
	var shortcut := IWEActionZone.create_zone("Shortcut", _square(400, 600))
	shortcut.action = IWEActionZone.ACTION_WARP
	shortcut.entry_id = "top"
	shortcut.enabled = false
	document.action_zones.append(shortcut)
	var entry := IWEEntryPoint.create_entry("top", Vector2(900, 400))
	entry.is_default = true
	entry.facing_degrees = 90.0
	document.entry_points.append(entry)
	document.entry_points.append(IWEEntryPoint.create_entry("from_forest", Vector2(300, 700)))
	return document


func _save_and_load(document: IWEDocument, file_name: String) -> IWEDocument:
	document.prepare_for_save()
	var path := WORK_FOLDER.path_join(file_name)
	assert_int(ResourceSaver.save(document, path)).is_equal(OK)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as IWEDocument


func test_the_current_format_is_version_three() -> void:
	assert_int(IWEDocument.CURRENT_SCHEMA_VERSION).is_equal(3)


func test_zones_and_entry_points_survive_a_save_and_reload() -> void:
	var original := _document_with_actions()
	var loaded := _save_and_load(original, "actions.tres")
	assert_int(loaded.schema_version).is_equal(3)
	assert_int(loaded.action_zones.size()).is_equal(2)
	var door := loaded.action_zones[0]
	assert_str(door.id).is_equal(original.action_zones[0].id)
	assert_str(door.name).is_equal("Door to the forest")
	assert_str(door.action).is_equal(IWEActionZone.ACTION_SCENE_TRANSITION)
	assert_str(door.target_scene).is_equal("res://levels/forest.tscn")
	assert_str(door.entry_id).is_equal("from_village")
	assert_bool(door.enabled).is_true()
	assert_dict(door.params).is_equal({"fade": 0.5, "sound": "door"})
	assert_array(Array(door.points)).is_equal(Array(_square(100, 600)))
	var shortcut := loaded.action_zones[1]
	assert_str(shortcut.action).is_equal(IWEActionZone.ACTION_WARP)
	assert_bool(shortcut.enabled).is_false()
	assert_int(loaded.entry_points.size()).is_equal(2)
	var top := loaded.find_entry_by_name("top")
	assert_bool(top.is_default).is_true()
	assert_float(top.facing_degrees).is_equal(90.0)
	assert_vector(top.position).is_equal(Vector2(900, 400))
	assert_bool(loaded.find_entry_by_name("from_forest").has_facing()).override_failure_message("no facing was chosen").is_false()


func test_an_action_this_plugin_does_not_know_is_kept_with_its_settings() -> void:
	var document := IWEDocument.new()
	var zone := IWEActionZone.create_zone("Cutscene", _square(0, 0))
	zone.action = "play_cutscene"
	zone.params = {"cutscene": "intro"}
	document.action_zones.append(zone)
	var loaded := _save_and_load(document, "unknown_action.tres")
	assert_str(loaded.action_zones[0].action).is_equal("play_cutscene")
	assert_dict(loaded.action_zones[0].params).is_equal({"cutscene": "intro"})
	var problems := loaded.validate_references()
	assert_bool(" ".join(problems).contains("does not know")).override_failure_message("the unknown action is reported, not dropped").is_true()


func test_a_version_one_document_opens_with_no_zones_and_is_not_changed() -> void:
	var before := FileAccess.get_file_as_bytes(V1_FIXTURE)
	var loaded := ResourceLoader.load(V1_FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE) as IWEDocument
	assert_int(loaded.schema_version).is_equal(1)
	assert_str(IWEDocument.schema_problem(loaded)).is_empty()
	var regions_before := loaded.regions.size()
	loaded.migrate_to_current()
	assert_int(loaded.schema_version).is_equal(3)
	assert_int(loaded.regions.size()).is_equal(regions_before)
	assert_int(loaded.action_zones.size()).is_equal(0)
	assert_int(loaded.entry_points.size()).is_equal(0)
	assert_array(Array(FileAccess.get_file_as_bytes(V1_FIXTURE))).override_failure_message("opening must not write the file").is_equal(Array(before))


func test_a_version_two_document_published_with_alpha_two_migrates_without_losing_anything() -> void:
	var before := FileAccess.get_file_as_bytes(V2_FIXTURE)
	var loaded := ResourceLoader.load(V2_FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE) as IWEDocument
	assert_int(loaded.schema_version).is_equal(2)
	assert_str(IWEDocument.schema_problem(loaded)).is_empty()
	var regions := loaded.regions.size()
	var elements := loaded.visual_elements.size()
	var layers := loaded.layers.size()
	var anchors := loaded.scale_anchors.size()
	var first_region_points := loaded.regions[0].points.duplicate()
	loaded.migrate_to_current()
	loaded.migrate_to_current()
	assert_int(loaded.schema_version).override_failure_message("the migration can run twice").is_equal(3)
	assert_int(loaded.regions.size()).is_equal(regions)
	assert_int(loaded.visual_elements.size()).is_equal(elements)
	assert_int(loaded.layers.size()).is_equal(layers)
	assert_int(loaded.scale_anchors.size()).is_equal(anchors)
	assert_array(Array(loaded.regions[0].points)).is_equal(Array(first_region_points))
	assert_array(Array(FileAccess.get_file_as_bytes(V2_FIXTURE))).override_failure_message("opening must not write the file").is_equal(Array(before))
	# Saving it as version 3 and reading it back keeps everything and adds the empty lists.
	var reloaded := _save_and_load(loaded, "migrated.tres")
	assert_int(reloaded.regions.size()).is_equal(regions)
	assert_int(reloaded.visual_elements.size()).is_equal(elements)
	assert_int(reloaded.action_zones.size()).is_equal(0)


func test_a_version_four_document_is_refused_and_left_alone() -> void:
	var document := IWEDocument.new()
	document.schema_version = IWEDocument.CURRENT_SCHEMA_VERSION + 1
	assert_str(IWEDocument.schema_problem(document)).contains("format version %d" % (IWEDocument.CURRENT_SCHEMA_VERSION + 1))


func test_validation_reports_a_zone_without_a_scene_and_a_warp_to_nowhere() -> void:
	var document := IWEDocument.new()
	var door := IWEActionZone.create_zone("Door", _square(0, 0))
	document.action_zones.append(door)
	var warp := IWEActionZone.create_zone("Warp", _square(200, 0))
	warp.action = IWEActionZone.ACTION_WARP
	warp.entry_id = "nowhere"
	document.action_zones.append(warp)
	var text := " ".join(document.validate_references())
	assert_str(text).contains("changes the scene but no scene is chosen")
	assert_str(text).contains("warps to an entry point (nowhere)")


func test_validation_reports_duplicate_entry_names_and_several_defaults() -> void:
	var document := IWEDocument.new()
	var first := IWEEntryPoint.create_entry("door", Vector2(10, 10))
	first.is_default = true
	var second := IWEEntryPoint.create_entry("door", Vector2(50, 10))
	second.is_default = true
	var nameless := IWEEntryPoint.create_entry("", Vector2(90, 10))
	document.entry_points.append_array([first, second, nameless])
	var text := " ".join(document.validate_references())
	assert_str(text).contains("used by more than one entry point")
	assert_str(text).contains("More than one entry point is marked as the default")
	assert_str(text).contains("has no name")


func test_a_clean_document_has_no_action_problems() -> void:
	var document := _document_with_actions()
	document.action_zones[1].entry_id = "top"
	assert_array(Array(document.validate_references())).is_empty()


func test_the_zone_describes_itself_for_lists() -> void:
	var zone := IWEActionZone.create_zone("Door", _square(0, 0))
	assert_str(zone.describe()).contains("no scene chosen")
	zone.target_scene = "res://levels/forest.tscn"
	zone.entry_id = "from_village"
	assert_str(zone.describe()).is_equal("Door: forest.tscn at from_village")

extends GdUnitTestSuite
## The default path of IWEStageTravel: a real SceneTree.change_scene_to_file between two scenes saved
## on disk, with no custom scene changer.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const FOLDER := "user://iwe_real_scene_change"


func before_test() -> void:
	IWEStageTravel.reset()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))


func after_test() -> void:
	IWEStageTravel.reset()
	var current := get_tree().current_scene
	if current != null and current.name == "ArrivalStage":
		get_tree().root.remove_child(current)
		current.free()
		get_tree().current_scene = null
	VILLAGE.remove_folder(ProjectSettings.globalize_path(FOLDER))


func _save_arrival_scene(path: String) -> void:
	var root := Node3D.new()
	root.name = "ArrivalStage"
	var marker := IWEEntryMarker.new()
	marker.name = "Spot"
	marker.entry_id = "here"
	marker.position = Vector3(3, 0, 4)
	root.add_child(marker)
	marker.owner = root
	var hero := CharacterBody3D.new()
	hero.name = "Hero"
	hero.add_to_group(IWEStageTravel.TRAVELLER_GROUP, true)
	root.add_child(hero)
	hero.owner = root
	var runtime := IWEStageRuntime.new()
	runtime.name = "StageRuntime"
	root.add_child(runtime)
	runtime.owner = root
	var packed := PackedScene.new()
	assert_int(packed.pack(root)).is_equal(OK)
	root.free()
	assert_int(ResourceSaver.save(packed, path)).is_equal(OK)


func test_the_default_scene_change_loads_the_scene_and_places_the_traveller() -> void:
	var path := FOLDER.path_join("arrival.tscn")
	_save_arrival_scene(path)
	assert_bool(IWEStageTravel.request(get_tree(), path, "here")).is_true()
	var frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "ArrivalStage") and frames < 120:
		await get_tree().process_frame
		frames += 1
	assert_object(get_tree().current_scene).override_failure_message("the scene was loaded (%d frames)" % frames).is_not_null()
	for _frame in 3:
		await get_tree().process_frame
	var hero := get_tree().current_scene.get_node("Hero") as Node3D
	assert_vector(hero.global_position).is_equal(Vector3(3, 0, 4))
	assert_bool(IWEStageTravel.is_traveling).override_failure_message("the travel ended once the arrival was applied").is_false()


func test_a_scene_file_that_is_not_a_scene_leaves_nothing_locked() -> void:
	var path := FOLDER.path_join("broken.tscn")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("this is not a scene")
	file.close()
	var before := get_tree().current_scene
	IWEStageTravel.request(get_tree(), path, "here")
	for _frame in 10:
		await get_tree().process_frame
	assert_bool(IWEStageTravel.is_traveling).override_failure_message("a failed load must not lock the next transition").is_false()
	assert_object(get_tree().current_scene).override_failure_message("the current scene is still there").is_same(before)

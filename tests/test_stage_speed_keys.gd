extends GdUnitTestSuite
## Speed in a running game: PageUp / PageDown / Home on the stage's test player, and what they change.
## The dock's own speed controls act on the preview character and are covered by test_preview_walk.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_the_keys_do_nothing_unless_the_character_asks_for_them() -> void:
	var character := IWEWalkmeshCharacter.new()
	get_tree().root.add_child(character)
	assert_bool(character.debug_speed_keys).override_failure_message("off by default: a game must opt in").is_false()
	character._unhandled_key_input(_key(KEY_PAGEUP))
	assert_float(character.speed_multiplier).is_equal(1.0)
	character.free()


func test_page_up_and_page_down_step_through_the_presets_and_home_goes_back() -> void:
	var character := IWEWalkmeshCharacter.new()
	character.debug_speed_keys = true
	get_tree().root.add_child(character)
	var seen: Array[float] = []
	character.speed_multiplier_changed.connect(func(multiplier: float) -> void: seen.append(multiplier))
	for expected in [2.0, 5.0, 10.0, 10.0]:
		character._unhandled_key_input(_key(KEY_PAGEUP))
		assert_float(character.speed_multiplier).is_equal(expected)
	for expected in [5.0, 2.0, 1.0, 1.0]:
		character._unhandled_key_input(_key(KEY_PAGEDOWN))
		assert_float(character.speed_multiplier).is_equal(expected)
	character.set_speed_multiplier(7.0)
	character._unhandled_key_input(_key(KEY_HOME))
	assert_float(character.speed_multiplier).is_equal(1.0)
	assert_array(seen).override_failure_message("the signal fires on every real change and not on a repeated value").is_equal([2.0, 5.0, 10.0, 5.0, 2.0, 1.0, 7.0, 1.0])
	character.free()


func test_the_nearest_preset_is_used_when_the_multiplier_is_between_two() -> void:
	var character := IWEWalkmeshCharacter.new()
	get_tree().root.add_child(character)
	# 3.4 is nearest to x2, so up goes to x5 and down goes to x1.
	character.set_speed_multiplier(3.4)
	character.step_speed_preset(1)
	assert_float(character.speed_multiplier).is_equal(5.0)
	character.set_speed_multiplier(3.4)
	character.step_speed_preset(-1)
	assert_float(character.speed_multiplier).is_equal(1.0)
	character.free()


func test_an_echo_or_a_key_release_changes_nothing() -> void:
	var character := IWEWalkmeshCharacter.new()
	character.debug_speed_keys = true
	get_tree().root.add_child(character)
	var held := _key(KEY_PAGEUP)
	held.echo = true
	character._unhandled_key_input(held)
	var released := _key(KEY_PAGEUP)
	released.pressed = false
	character._unhandled_key_input(released)
	assert_float(character.speed_multiplier).is_equal(1.0)
	character.free()


func test_the_exported_test_player_has_the_keys_on_and_they_speed_up_a_walk_in_progress() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var document: IWEDocument = dock._document
	dock.queue_free()
	var stage: Array = await VILLAGE.start_stage(get_tree(), document)
	var root: Node3D = stage[0]
	var player: IWEWalkmeshCharacter = stage[1]
	assert_bool(player.debug_speed_keys).override_failure_message("the exporter turns the keys on for its test player").is_true()
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	player.global_position = VILLAGE.floor_world(Vector2(150, 880), calibration)
	await get_tree().physics_frame
	player.move_to(VILLAGE.floor_world(Vector2(480, 320), calibration))
	for _frame in 15:
		await get_tree().physics_frame
	var start := player.global_position
	for _frame in 20:
		await get_tree().physics_frame
	var normal_step := start.distance_to(player.global_position)
	player._unhandled_key_input(_key(KEY_PAGEUP))
	player._unhandled_key_input(_key(KEY_PAGEUP))
	assert_float(player.speed_multiplier).is_equal(5.0)
	assert_float(player.get_effective_speed()).is_equal_approx(player.move_speed * 5.0, 0.0001)
	var middle := player.global_position
	for _frame in 20:
		await get_tree().physics_frame
	var fast_step := middle.distance_to(player.global_position)
	assert_float(normal_step).override_failure_message("the character was walking at x1").is_greater(0.0)
	assert_float(fast_step / normal_step).override_failure_message("x5 in the middle of the walk: %.3f vs %.3f" % [fast_step, normal_step]).is_between(4.0, 5.5)
	assert_bool(player.is_moving_along_path() or fast_step > 0.0).is_true()
	root.free()


func test_the_multiplier_is_not_part_of_the_exported_scene_but_the_key_option_is() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var document: IWEDocument = dock._document
	dock.queue_free()
	var root: Node3D = VILLAGE.SCENE_GENERATOR.build_perspective_scene(document, load(VILLAGE.BACKGROUND) as Texture2D, document.perspective_calibration, VILLAGE.WORLD_SCALE, true)
	var packed := PackedScene.new()
	assert_int(packed.pack(root)).is_equal(OK)
	root.free()
	var text := ""
	var path := "user://iwe_speed_scene.tscn"
	assert_int(ResourceSaver.save(packed, path)).is_equal(OK)
	text = FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_bool(text.contains("speed_multiplier")).override_failure_message("a testing multiplier is never saved").is_false()
	assert_bool(text.contains("debug_speed_keys = true")).is_true()

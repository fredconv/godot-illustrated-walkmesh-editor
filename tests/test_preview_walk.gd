extends GdUnitTestSuite

## Test walk in the dock preview: a character on the generated floor with a base speed, the
## presets x1, x2, x5 and x10, pause and resume, and reset. These are tools for trying a stage: none
## of it is saved in the document or written to an export.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const EXPORT_PATH := "res://tests/_preview_walk_export.tscn"
const SETTLE_FRAME_LIMIT := 600


func after_test() -> void:
	if FileAccess.file_exists(EXPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPORT_PATH))


func _authored_dock_in_perspective() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	dock._set_perspective_mode(true)
	return dock


func _start_test_walk(dock: Control) -> IWEWalkmeshCharacter:
	dock._test_walk_button.button_pressed = true
	var player: IWEWalkmeshCharacter = dock._perspective_preview.get_test_character()
	var frames := 0
	while (player == null or not player._navigation_settled) and frames < SETTLE_FRAME_LIMIT:
		await get_tree().physics_frame
		frames += 1
		player = dock._perspective_preview.get_test_character()
	return player


## Frames the character needs to arrive at an image pixel, or -1 if it never does.
func _frames_to_walk(dock: Control, player: IWEWalkmeshCharacter, target: Vector2, limit: int = 4000) -> int:
	assert_bool(dock._perspective_preview.walk_to_image_point(target)).is_true()
	var frames := 0
	while player.is_moving_along_path() and frames < limit:
		await get_tree().physics_frame
		frames += 1
	return frames if not player.is_moving_along_path() else -1


func _place_at(dock: Control, player: IWEWalkmeshCharacter, image_point: Vector2) -> void:
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	player.global_position = VILLAGE.floor_world(image_point, calibration)
	await get_tree().physics_frame


func test_there_is_no_character_until_test_walk_is_turned_on() -> void:
	var dock := await _authored_dock_in_perspective()
	assert_object(dock._perspective_preview.get_test_character()).is_null()
	assert_bool(dock._test_walk_controls.visible).is_false()
	dock._test_walk_button.button_pressed = true
	assert_object(dock._perspective_preview.get_test_character()).is_not_null()
	assert_bool(dock._test_walk_controls.visible).is_true()
	dock._test_walk_button.button_pressed = false
	assert_object(dock._perspective_preview.get_test_character()).is_null()
	dock.queue_free()


func test_the_preview_character_is_driven_by_the_preview_only() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	assert_bool(player.editor_preview).is_true()
	assert_bool(player.kinematic).is_true()
	assert_bool(player.keyboard_control).override_failure_message("arrow keys must not move it while editing").is_false()
	assert_bool(player.click_to_move).is_false()
	dock.queue_free()


func test_the_base_speed_field_shows_the_characters_own_speed() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	assert_float(dock._base_speed_input.value).is_equal_approx(player.move_speed, 0.11)
	dock.queue_free()


func test_a_click_in_test_walk_sends_the_character_instead_of_placing_a_reference() -> void:
	var dock := await _authored_dock_in_perspective()
	var anchors_before: int = dock._document.scale_anchors.size()
	var player := await _start_test_walk(dock)
	await _place_at(dock, player, Vector2(300, 600))
	dock._create_perspective_anchor(Vector2(700, 600))
	assert_int(dock._document.scale_anchors.size()).override_failure_message("no height reference while testing").is_equal(anchors_before)
	assert_bool(player.is_moving_along_path()).is_true()
	dock._test_walk_button.button_pressed = false
	dock._create_perspective_anchor(Vector2(700, 600))
	assert_int(dock._document.scale_anchors.size()).override_failure_message("a click places a reference again").is_equal(anchors_before + 1)
	dock.queue_free()


func test_the_character_arrives_where_it_was_sent() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	dock._speed_buttons[3].pressed.emit()
	await _place_at(dock, player, Vector2(300, 600))
	var frames := await _frames_to_walk(dock, player, Vector2(450, 700))
	assert_int(frames).override_failure_message("did not arrive").is_greater(0)
	var arrived := VILLAGE.world_to_image(player.global_position, dock._document.perspective_calibration)
	assert_float(arrived.distance_to(Vector2(450, 700))).is_less(25.0)
	dock.queue_free()


func test_the_preset_buttons_set_the_multiplier_and_scale_the_walking_time() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	var expected := [1.0, 2.0, 5.0, 10.0]
	var frames_by_preset := []
	for index in 4:
		dock._speed_buttons[index].button_pressed = true
		dock._speed_buttons[index].pressed.emit()
		assert_float(player.speed_multiplier).is_equal(expected[index])
		assert_float(player.get_effective_speed()).is_equal_approx(player.move_speed * expected[index], 0.0001)
		await _place_at(dock, player, Vector2(300, 600))
		frames_by_preset.append(await _frames_to_walk(dock, player, Vector2(450, 700)))
	assert_float(float(frames_by_preset[0]) / float(frames_by_preset[1])).is_equal_approx(2.0, 0.4)
	assert_float(float(frames_by_preset[0]) / float(frames_by_preset[2])).is_equal_approx(5.0, 1.0)
	assert_float(float(frames_by_preset[0]) / float(frames_by_preset[3])).is_equal_approx(10.0, 2.5)
	dock.queue_free()


func test_the_multiplier_can_change_while_the_character_is_walking() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	await _place_at(dock, player, Vector2(300, 600))
	dock._perspective_preview.walk_to_image_point(Vector2(450, 700))
	for _frame in 5:
		await get_tree().physics_frame
	var before := player.global_position
	await get_tree().physics_frame
	var slow_step := before.distance_to(player.global_position)
	dock._speed_buttons[3].pressed.emit()
	var middle := player.global_position
	await get_tree().physics_frame
	var fast_step := middle.distance_to(player.global_position)
	assert_float(fast_step).override_failure_message("slow %.5f fast %.5f" % [slow_step, fast_step]).is_greater(slow_step * 5.0)
	dock.queue_free()


func test_perspective_makes_the_same_world_speed_look_slower_far_away() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	var calibration: IWEPerspectiveCalibration = dock._document.perspective_calibration
	var near_start := Vector2(300, 850)
	var far_start := Vector2(900, 340)
	var world_steps := []
	var screen_steps := []
	for start in [near_start, far_start]:
		await _place_at(dock, player, start)
		var before_world := player.global_position
		var before_screen := VILLAGE.world_to_image(before_world, calibration)
		dock._perspective_preview.walk_to_image_point(start + Vector2(120, 0))
		for _frame in 6:
			await get_tree().physics_frame
		world_steps.append(before_world.distance_to(player.global_position))
		screen_steps.append(before_screen.distance_to(VILLAGE.world_to_image(player.global_position, calibration)))
		player.stop()
	assert_float(world_steps[0]).override_failure_message("same speed in the world at every depth").is_equal_approx(world_steps[1], world_steps[0] * 0.15)
	assert_float(screen_steps[0]).override_failure_message("near %.2f px, far %.2f px" % [screen_steps[0], screen_steps[1]]).is_greater(screen_steps[1] * 1.5)
	dock.queue_free()


func test_a_new_base_speed_changes_the_walking_speed() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	var default_speed := player.move_speed
	dock._base_speed_input.value = default_speed * 2.0
	assert_float(player.move_speed).is_equal_approx(default_speed * 2.0, 0.11)
	assert_float(player.get_effective_speed()).is_equal_approx(player.move_speed * player.speed_multiplier, 0.0001)
	dock.queue_free()


func test_pause_stops_the_character_and_resume_continues_the_same_walk() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	await _place_at(dock, player, Vector2(300, 600))
	dock._perspective_preview.walk_to_image_point(Vector2(450, 700))
	for _frame in 5:
		await get_tree().physics_frame
	dock._pause_button.button_pressed = true
	assert_str(dock._pause_button.text).is_equal("Resume")
	var frozen := player.global_position
	for _frame in 30:
		await get_tree().physics_frame
	assert_vector(player.global_position).override_failure_message("moved while paused").is_equal_approx(frozen, Vector3.ONE * 0.00001)
	dock._pause_button.button_pressed = false
	assert_str(dock._pause_button.text).is_equal("Pause")
	var frames := 0
	while player.is_moving_along_path() and frames < 4000:
		await get_tree().physics_frame
		frames += 1
	var arrived := VILLAGE.world_to_image(player.global_position, dock._document.perspective_calibration)
	assert_float(arrived.distance_to(Vector2(450, 700))).is_less(25.0)
	dock.queue_free()


func test_reset_position_puts_the_character_back_and_cancels_the_walk() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	var start := player.global_position
	await _place_at(dock, player, Vector2(300, 600))
	dock._perspective_preview.walk_to_image_point(Vector2(450, 700))
	for _frame in 5:
		await get_tree().physics_frame
	dock._reset_walker_button.pressed.emit()
	assert_vector(player.global_position).is_equal_approx(start, Vector3.ONE * 0.0001)
	assert_bool(player.is_moving_along_path()).is_false()
	dock.queue_free()


func test_speed_settings_survive_a_rebuild_of_the_preview() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	dock._speed_buttons[2].pressed.emit()
	dock._base_speed_input.value = 4.0
	dock._set_calibration_fov(55.0)
	player = await _start_test_walk(dock)
	assert_float(player.speed_multiplier).is_equal(5.0)
	assert_float(player.move_speed).is_equal_approx(4.0, 0.001)
	dock.queue_free()


func test_the_speed_settings_are_not_saved_in_the_document_or_the_export() -> void:
	var dock := await _authored_dock_in_perspective()
	var player := await _start_test_walk(dock)
	var default_speed := player.move_speed
	dock._speed_buttons[3].pressed.emit()
	dock._base_speed_input.value = 77.7
	for property in dock._document.get_property_list():
		var property_name := String(property["name"]).to_lower()
		assert_bool(property_name.contains("speed")).override_failure_message("the document has a %s property" % property_name).is_false()
	dock._pending_export_dimension = 4
	dock._add_player_input.button_pressed = true
	dock._export_scene(EXPORT_PATH)
	var text := FileAccess.get_file_as_string(EXPORT_PATH)
	assert_bool(text.contains("speed_multiplier")).override_failure_message("the multiplier reached the export").is_false()
	assert_bool(text.contains("77.7")).override_failure_message("the preview base speed reached the export").is_false()
	assert_bool(text.contains("editor_preview") or text.contains("kinematic")).override_failure_message("preview-only flags reached the export").is_false()
	assert_bool(text.contains("move_speed = %s" % str(snappedf(default_speed, 0.0001))) or text.contains("move_speed")).is_true()
	dock.queue_free()

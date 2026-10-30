@tool
extends EditorPlugin

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")


func _enter_tree() -> void:
	_run.call_deferred()


func _log(line: String) -> void:
	print("SELFTEST ", line)


func _run() -> void:
	for _i in 30:
		await get_tree().process_frame
	_log("editor_hint=%s" % Engine.is_editor_hint())
	var dock: Control = VILLAGE.DOCK_SCENE.instantiate()
	dock.set_document(VILLAGE.DOCUMENT_SCRIPT.new())
	EditorInterface.get_base_control().add_child(dock)
	await get_tree().process_frame
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	dock._set_perspective_mode(true)
	dock._test_walk_button.button_pressed = true
	var preview = dock._perspective_preview
	var player = preview.get_test_character()
	_log("player_exists=%s" % (player != null))
	if player == null:
		get_tree().quit(2)
		return
	var origin: Vector3 = player.global_position
	var frames := 0
	while not player._navigation_settled and frames < 900:
		await get_tree().physics_frame
		frames += 1
	_log("nav_settled=%s after %d physics frames" % [player._navigation_settled, frames])
	var calibration = dock._document.perspective_calibration
	player.global_position = VILLAGE.floor_world(Vector2(300, 600), calibration)
	await get_tree().physics_frame
	var start: Vector3 = player.global_position
	var ok: bool = preview.walk_to_image_point(Vector2(450, 700))
	_log("walk_started=%s path_points=%d" % [ok, player._path.size()])
	for preset_index in [0, 3]:
		dock._speed_buttons[preset_index].pressed.emit()
		player.global_position = VILLAGE.floor_world(Vector2(300, 600), calibration)
		await get_tree().physics_frame
		preview.walk_to_image_point(Vector2(450, 700))
		frames = 0
		while player.is_moving_along_path() and frames < 6000:
			await get_tree().physics_frame
			frames += 1
		var arrived: Vector2 = VILLAGE.world_to_image(player.global_position, calibration)
		_log("multiplier=%s frames=%d arrived=%s moved=%.3f" % [player.speed_multiplier, frames, arrived, start.distance_to(player.global_position)])
	dock._pause_button.button_pressed = true
	preview.walk_to_image_point(Vector2(800, 700))
	var before: Vector3 = player.global_position
	for _i in 20:
		await get_tree().physics_frame
	_log("paused_moved=%.5f" % before.distance_to(player.global_position))
	dock._pause_button.button_pressed = false
	dock._reset_walker_button.pressed.emit()
	_log("reset_distance_from_start=%.4f" % player.global_position.distance_to(origin))
	get_tree().quit(0)

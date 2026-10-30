extends SceneTree
## Renders the two dock tabs on a real GPU window for the README screenshots, with the village example
## document opened the way a person opens it. Run in a copy of the project (see readme_shots.ps1);
## IWE_SHOT_OUT is the folder that receives the PNG files. Nothing but the Godot window is captured.

const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const EXAMPLE := "res://examples/village/village.tres"


func _initialize() -> void:
	_run.call_deferred()


func _shot(file_name: String) -> void:
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(OS.get_environment("IWE_SHOT_OUT").path_join(file_name))
	print("SHOT ", file_name, " ", image.get_size())


func _run() -> void:
	root.size = Vector2i(1400, 900)
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new())
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dock)
	await process_frame
	dock._open_document(EXAMPLE)
	await process_frame
	var element = dock._document.visual_elements[0]
	dock._layer_panel.select("element", element.id)
	await _shot("dock_creation.png")
	dock._set_perspective_mode(true)
	dock.select_tab(1)
	dock._test_walk_button.button_pressed = true
	var preview = dock._perspective_preview
	var player = preview.get_test_character()
	var frames := 0
	while player != null and not player._navigation_settled and frames < 900:
		await physics_frame
		frames += 1
	if player != null:
		dock._speed_buttons[3].pressed.emit()
		preview.walk_to_image_point(Vector2(700, 800))
		frames = 0
		while player.is_moving_along_path() and frames < 3000:
			await physics_frame
			frames += 1
		for _i in 4:
			await physics_frame
	await _shot("dock_test.png")
	quit(0)

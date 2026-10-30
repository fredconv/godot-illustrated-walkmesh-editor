extends SceneTree
## Renders the village stage with the foreground fountain and checks, on real pixels, that the
## character is hidden behind the fountain and shown in front of it. Needs a GPU window (not headless).
## Run it with tests/render_check/run.ps1. Prints RENDER lines and exits 0 when every check passed.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const PLAYER_COLOR := Color("4aa3ff")


func _initialize() -> void:
	_run.call_deferred()


func _count_player_pixels(image: Image, color: Color = PLAYER_COLOR) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - color.r) < 0.03 and absf(pixel.g - color.g) < 0.03 and absf(pixel.b - color.b) < 0.03:
				count += 1
	return count


func _run() -> void:
	var dock: Control = VILLAGE.DOCK_SCENE.instantiate()
	dock.set_document(VILLAGE.DOCUMENT_SCRIPT.new())
	root.add_child(dock)
	await process_frame
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var element = dock.import_element(ProjectSettings.globalize_path(VILLAGE.FOREGROUND))
	dock._set_element_property(element.id, "ground_anchor", Vector2(815, 590))
	var calibration = dock._document.perspective_calibration
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage: Node3D = GENERATOR.build_perspective_scene(dock._document, load(VILLAGE.BACKGROUND), calibration, 0.01, true, dock._export_element_textures())
	viewport.add_child(stage)
	var player: CharacterBody3D = stage.get_node("Player")
	player.set_physics_process(false)
	for _i in 5:
		await process_frame
	var counts := {}
	for key in {"behind": Vector2(815, 440), "front": Vector2(815, 800)}:
		var spot: Vector2 = {"behind": Vector2(815, 440), "front": Vector2(815, 800)}[key]
		player.global_position = VILLAGE.floor_world(spot, calibration)
		for _i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		counts[key] = _count_player_pixels(image)
		print("RENDER ", key, " player pixels=", counts[key])
		if OS.get_environment("IWE_RENDER_OUT") != "":
			image.save_png(OS.get_environment("IWE_RENDER_OUT").path_join("occlusion_%s.png" % key))
	var ok: bool = counts["behind"] < 50 and counts["front"] > 2000
	print("RENDER ", "PASS" if ok else "FAIL", ": behind the fountain the character shows ", counts["behind"], " pixels (expected under 50, the picture has a few similar pixels), in front ", counts["front"], " (expected > 2000)")
	# The same with a character that is not the plugin one: the model of the integration example, drawn
	# flat in its own colour so its pixels can be counted. The pixels of that colour that the picture
	# already has are measured first, with the character hidden, and subtracted.
	player.visible = false
	var hero_scene := load("res://examples/integration/external_character.tscn") as PackedScene
	if hero_scene == null:
		print("RENDER FAIL: the external character scene could not be loaded")
		quit(1)
		return
	var hero := hero_scene.instantiate() as Node3D
	var hero_color := Color("ff7a2e")
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = hero_color
	for mesh in hero.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = flat
	viewport.add_child(hero)
	hero.set_physics_process(false)
	var external := {}
	var spots := {"behind": [Vector2(815, 440), Vector2(815, 400), Vector2(740, 430)], "front": [Vector2(815, 800), Vector2(815, 720), Vector2(900, 780)]}
	for key in spots:
		var shown := 0
		var baseline := 0
		for spot in spots[key]:
			hero.global_position = VILLAGE.floor_world(spot, calibration)
			hero.visible = false
			for _i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			baseline += _count_player_pixels(viewport.get_texture().get_image(), hero_color)
			hero.visible = true
			for _i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			shown += _count_player_pixels(image, hero_color)
			if OS.get_environment("IWE_RENDER_OUT") != "" and spot == spots[key][0]:
				image.save_png(OS.get_environment("IWE_RENDER_OUT").path_join("occlusion_external_%s.png" % key))
		external[key] = shown - baseline
		print("RENDER external ", key, " character pixels=", external[key], " (", spots[key].size(), " depths)")
	var external_ok: bool = external["behind"] < 50 * 3 and external["front"] > 2000 * 3
	print("RENDER ", "PASS" if external_ok else "FAIL", ": the external character is hidden behind the fountain at three depths (", external["behind"], " pixels) and shown in front of it at three depths (", external["front"], ")")
	quit(0 if ok and external_ok else 1)

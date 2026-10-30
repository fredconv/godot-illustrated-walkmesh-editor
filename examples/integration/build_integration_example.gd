@tool
extends SceneTree
## Rebuilds the integration example (docs/INTEGRATION.md) from code, with the same authoring helpers as the
## end-to-end scenario: an external character, two exported stages and the two level scenes that hold
## them. From the repository root:
##   Godot --headless --path . -s examples/integration/build_integration_example.gd
##
## village  --door-->  cellar        a zone at the end of the bridge loads the cellar
## village  <--stairs--  cellar      a zone in the cellar loads the village again
## Each level arrives at the entry point the zone names.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const CHARACTER_SCRIPT := preload("res://examples/integration/external_character.gd")
const FOLDER := "res://examples/integration"
const CELLAR_BACKGROUND := "res://assets/img/background.png"
const WORLD_SCALE := 0.01


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var character_path := FOLDER.path_join("external_character.tscn")
	_save(_make_character(), character_path)

	var village := await _author_village()
	var cellar := await _author_cellar()
	var village_texture := load(VILLAGE.BACKGROUND) as Texture2D
	var cellar_texture := load(CELLAR_BACKGROUND) as Texture2D
	var village_stage := GENERATOR.build_perspective_scene(village, village_texture, village.perspective_calibration, WORLD_SCALE, false)
	village_stage.name = "VillageStage"
	var cellar_stage := GENERATOR.build_perspective_scene(cellar, cellar_texture, cellar.perspective_calibration, WORLD_SCALE, false)
	cellar_stage.name = "CellarStage"
	_save(village_stage, FOLDER.path_join("stage_village.tscn"))
	_save(cellar_stage, FOLDER.path_join("stage_cellar.tscn"))
	_save(_make_level("LevelVillage", FOLDER.path_join("stage_village.tscn"), character_path), FOLDER.path_join("level_village.tscn"))
	_save(_make_level("LevelCellar", FOLDER.path_join("stage_cellar.tscn"), character_path), FOLDER.path_join("level_cellar.tscn"))
	print("INTEGRATION built: ", ", ".join(DirAccess.get_files_at(ProjectSettings.globalize_path(FOLDER))))
	quit(0)


func _save(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error != OK:
		push_error("Could not pack %s (%s)" % [path, error_string(error)])
		quit(1)
		return
	error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("Could not save %s (%s)" % [path, error_string(error)])
		quit(1)
	root.free()


## A capsule body, a head and a nose that shows where it faces, lit like a real model. It is a test
## model with no rig and no animation: it validates size and depth, not skeletal animation.
func _make_character() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "ExternalCharacter"
	body.set_script(CHARACTER_SCRIPT)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.3
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	collision.position.y = 0.9
	body.add_child(collision)
	collision.owner = body
	var model := Node3D.new()
	model.name = "Model"
	body.add_child(model)
	model.owner = body
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("ff7a2e")
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.3
	torso_mesh.height = 1.5
	torso.mesh = torso_mesh
	torso.material_override = skin
	torso.position.y = 0.75
	model.add_child(torso)
	torso.owner = body
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.material_override = skin
	head.position.y = 1.58
	model.add_child(head)
	head.owner = body
	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.1, 0.1, 0.2)
	nose.mesh = nose_mesh
	nose.material_override = skin
	nose.position = Vector3(0.0, 1.58, -0.26)
	model.add_child(nose)
	nose.owner = body
	return body


func _new_dock_with(illustration: String) -> Control:
	var dock: Control = await VILLAGE.new_dock(self)
	dock._load_illustration(ProjectSettings.globalize_path(illustration))
	return dock


func _author_village() -> IWEDocument:
	var dock: Control = await VILLAGE.new_dock(self)
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	# The end-to-end scenario also cuts out a bench beside the fountain, which leaves a corridor under a
	# metre wide in front of the bridge. A character with a body needs more room than that, so this
	# example keeps only the fountain.
	var crossroads: IWERegion = dock._document.regions[1]
	while crossroads.subtraction_polygons.size() > 1:
		crossroads.subtraction_polygons.remove_at(crossroads.subtraction_polygons.size() - 1)
		if crossroads.subtraction_names.size() > crossroads.subtraction_polygons.size():
			crossroads.subtraction_names.resize(crossroads.subtraction_polygons.size())
		if crossroads.subtraction_ids.size() > crossroads.subtraction_polygons.size():
			crossroads.subtraction_ids.resize(crossroads.subtraction_polygons.size())
	dock._fit_camera_to_references()
	var document: IWEDocument = dock._document
	document.resource_name = "VillageStage"
	var door := IWEActionZone.create_zone("Door to the cellar", _square(Vector2(1440, 590), 60.0))
	door.target_scene = FOLDER.path_join("level_cellar.tscn")
	door.entry_id = "from_village"
	document.action_zones.append(door)
	var start := IWEEntryPoint.create_entry("start", Vector2(300, 800))
	start.is_default = true
	document.entry_points.append(start)
	var from_cellar := IWEEntryPoint.create_entry("from_cellar", Vector2(1330, 590))
	from_cellar.facing_degrees = 90.0
	document.entry_points.append(from_cellar)
	dock.queue_free()
	return document


func _author_cellar() -> IWEDocument:
	var dock: Control = await _new_dock_with(CELLAR_BACKGROUND)
	dock._create_group_named("Floor")
	dock._canvas.region_created.emit(PackedVector2Array([Vector2(180, 640), Vector2(1500, 640), Vector2(1600, 900), Vector2(80, 900)]))
	dock._canvas.scale_anchor_created.emit(Vector2(300, 880), 230.0)
	dock._canvas.scale_anchor_created.emit(Vector2(1000, 660), 130.0)
	dock._fit_camera_to_references()
	var document: IWEDocument = dock._document
	document.resource_name = "CellarStage"
	var stairs := IWEActionZone.create_zone("Stairs up", _square(Vector2(1380, 720), 60.0))
	stairs.target_scene = FOLDER.path_join("level_village.tscn")
	stairs.entry_id = "from_cellar"
	document.action_zones.append(stairs)
	var from_village := IWEEntryPoint.create_entry("from_village", Vector2(420, 800))
	from_village.is_default = true
	document.entry_points.append(from_village)
	dock.queue_free()
	return document


## A level is the exported stage plus the character: the scene a game loads for one place.
func _make_level(level_name: String, stage_path: String, character_path: String) -> Node3D:
	var level := Node3D.new()
	level.name = level_name
	var stage := (load(stage_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	stage.name = "Stage"
	level.add_child(stage)
	stage.owner = level
	# An exported stage has no lights (its illustration is flat and unshaded), so a character with a lit
	# material needs the lighting of your own game: a sun and some ambient light, as here.
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(1, 1, 1)
	environment.environment.ambient_light_energy = 0.6
	level.add_child(environment)
	environment.owner = level
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	level.add_child(sun)
	sun.owner = level
	var hero := (load(character_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	hero.name = "Hero"
	level.add_child(hero)
	hero.owner = level
	# Start on the default entry point so the level also works when it is the first scene of the game.
	var default_marker: Node3D = null
	for marker in stage.find_children("*", "Marker3D", true, false):
		if marker.get("is_default") == true:
			default_marker = marker
	if default_marker != null:
		# The level is not in a tree yet, so the global position is computed from the parents' transforms.
		var spot := default_marker.position
		var node: Node = default_marker.get_parent()
		while node != null and node != level:
			if node is Node3D:
				spot = (node as Node3D).transform * spot
			node = node.get_parent()
		hero.position = spot
	return level


func _square(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half), center + Vector2(half, half), center + Vector2(-half, half)])

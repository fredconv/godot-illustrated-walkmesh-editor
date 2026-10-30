extends GdUnitTestSuite
## Action zones and entry points in the exported scenes, and the whole trip from one exported stage to
## another: a character walks into a zone, the scene changes, the character appears at the entry point.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const ZONE_SPOT := Vector2(1440, 590)
const ENTRY_SPOT := Vector2(700, 800)


func before_test() -> void:
	IWEStageTravel.reset()


func after_test() -> void:
	IWEStageTravel.reset()


func _calibrated_document() -> IWEDocument:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var document: IWEDocument = dock._document
	dock.queue_free()
	return document


func _square(center: Vector2, half := 60.0) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half), center + Vector2(half, half), center + Vector2(-half, half)])


func _add_door(document: IWEDocument) -> IWEActionZone:
	var door := IWEActionZone.create_zone("Door to the cellar", _square(ZONE_SPOT))
	door.target_scene = "res://levels/cellar.tscn"
	door.entry_id = "from_village"
	door.params = {"fade": 0.4}
	document.action_zones.append(door)
	return door


func _add_entries(document: IWEDocument) -> void:
	var start := IWEEntryPoint.create_entry("start", ENTRY_SPOT)
	start.is_default = true
	document.entry_points.append(start)
	var from_village := IWEEntryPoint.create_entry("from_village", Vector2(300, 800))
	from_village.facing_degrees = 45.0
	document.entry_points.append(from_village)


func _perspective(document: IWEDocument, with_player := false) -> Node3D:
	return GENERATOR.build_perspective_scene(document, load(VILLAGE.BACKGROUND) as Texture2D, document.perspective_calibration, VILLAGE.WORLD_SCALE, with_player)


func test_a_document_without_actions_exports_exactly_what_it_did_before() -> void:
	var document := await _calibrated_document()
	var perspective := _perspective(document, true)
	var flat_3d := GENERATOR.build_3d_scene(document, load(VILLAGE.BACKGROUND) as Texture2D)
	var flat_2d := GENERATOR.build_2d_scene(document, load(VILLAGE.BACKGROUND) as Texture2D)
	for root in [perspective, flat_3d, flat_2d]:
		assert_bool(root.find_child("ActionZones", true, false) == null).is_true()
		assert_bool(root.find_child("EntryPoints", true, false) == null).is_true()
		assert_bool(root.get_node_or_null("StageRuntime") == null).override_failure_message("no runtime node is added when the document has no zone or entry point").is_true()
		root.free()


func test_the_perspective_export_holds_a_zone_node_with_the_settings_of_the_document() -> void:
	var document := await _calibrated_document()
	var door := _add_door(document)
	var root := _perspective(document)
	var zone := root.find_child("Door to the cellar", true, false) as Area3D
	assert_object(zone).is_not_null()
	assert_bool(zone is IWETransitionZone).is_true()
	assert_str(zone.get("zone_id")).is_equal(door.id)
	assert_str(zone.get("action")).is_equal(IWEActionZone.ACTION_SCENE_TRANSITION)
	assert_str(zone.get("target_scene")).is_equal("res://levels/cellar.tscn")
	assert_str(zone.get("entry_id")).is_equal("from_village")
	assert_bool(zone.get("enabled")).is_true()
	assert_dict(zone.get("params")).is_equal({"fade": 0.4})
	assert_str(zone.get_meta("iwe_action_zone_id")).is_equal(door.id)
	var shape := zone.get_node("Shape") as CollisionPolygon3D
	assert_int(shape.polygon.size()).is_equal(4)
	assert_bool(root.get_node_or_null("StageRuntime") is IWEStageRuntime).override_failure_message("the exported stage can receive an arrival").is_true()
	root.free()


func test_the_zone_covers_the_floor_where_it_is_drawn_on_the_illustration() -> void:
	var document := await _calibrated_document()
	_add_door(document)
	var root := _perspective(document)
	get_tree().root.add_child(root)
	var zone := root.find_child("Door to the cellar", true, false) as Area3D
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	var centre := VILLAGE.floor_world(ZONE_SPOT, calibration)
	var shape := zone.get_node("Shape") as CollisionPolygon3D
	# The polygon is flat on the floor: every vertex sits at the floor height once the node is placed.
	var local_to_world: Transform3D = shape.global_transform
	var inside := 0
	var bottom := INF
	for vertex in shape.polygon:
		# The polygon sits in the middle of the extrusion, so the volume starts half its depth lower.
		var world := local_to_world * Vector3(vertex.x, vertex.y, 0.0)
		bottom = minf(bottom, world.y - shape.depth * 0.5 * VILLAGE.WORLD_SCALE)
		if Vector2(world.x, world.z).distance_to(Vector2(centre.x, centre.z)) < 1.5:
			inside += 1
	assert_float(bottom).override_failure_message("the volume stands on the floor").is_equal_approx(calibration.floor_height * VILLAGE.WORLD_SCALE, 0.0001)
	assert_int(inside).override_failure_message("the vertices surround the spot the zone was drawn around").is_equal(4)
	root.free()


func test_the_entry_points_are_exported_as_markers_at_their_floor_position() -> void:
	var document := await _calibrated_document()
	_add_entries(document)
	var root := _perspective(document)
	get_tree().root.add_child(root)
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	var start := root.find_child("start", true, false) as IWEEntryMarker
	var arrival := root.find_child("from_village", true, false) as IWEEntryMarker
	assert_object(start).is_not_null()
	assert_bool(start.is_default).is_true()
	assert_vector(start.global_position).is_equal_approx(VILLAGE.floor_world(ENTRY_SPOT, calibration), Vector3(0.001, 0.001, 0.001))
	assert_float(arrival.facing_degrees).is_equal(45.0)
	assert_bool(start.is_in_group(IWEStageTravel.ENTRY_GROUP)).is_true()
	assert_bool(is_nan(start.facing_degrees)).is_true()
	root.free()


func test_a_zone_that_cannot_be_projected_is_reported_not_silently_dropped() -> void:
	var document := await _calibrated_document()
	_add_door(document)
	document.perspective_calibration.floor_height = document.perspective_calibration.camera_position.y + 50.0
	var root := _perspective(document)
	var warnings := GENERATOR.take_warnings(root)
	assert_bool(" ".join(warnings).contains("Action zone \"Door to the cellar\" was not exported")).is_true()
	assert_bool(root.find_child("Door to the cellar", true, false) == null).is_true()
	root.free()


func test_the_stage_player_is_a_traveller_even_when_the_scene_is_saved_and_reloaded() -> void:
	var document := await _calibrated_document()
	_add_door(document)
	var root := _perspective(document, true)
	var packed := PackedScene.new()
	assert_int(packed.pack(root)).is_equal(OK)
	root.free()
	var copy := packed.instantiate()
	get_tree().root.add_child(copy)
	var player := copy.get_node("Player")
	assert_bool(player.is_in_group(IWEStageTravel.TRAVELLER_GROUP)).is_true()
	var zone := copy.find_child("Door to the cellar", true, false)
	assert_str(zone.get("target_scene")).override_failure_message("the settings are saved in the scene").is_equal("res://levels/cellar.tscn")
	assert_dict(zone.get("params")).is_equal({"fade": 0.4})
	copy.free()


func test_the_flat_exports_hold_the_zones_and_markers_too() -> void:
	var document := await _calibrated_document()
	_add_door(document)
	_add_entries(document)
	var texture := load(VILLAGE.BACKGROUND) as Texture2D
	var flat_3d := GENERATOR.build_3d_scene(document, texture)
	var zone_3d := flat_3d.find_child("Door to the cellar", true, false)
	assert_bool(zone_3d is IWETransitionZone).is_true()
	assert_bool(flat_3d.find_child("start", true, false) is IWEEntryMarker).is_true()
	assert_bool(flat_3d.get_node_or_null("StageRuntime") != null).is_true()
	flat_3d.free()
	var flat_2d := GENERATOR.build_2d_scene(document, texture)
	var zone_2d := flat_2d.find_child("Door to the cellar", true, false)
	assert_bool(zone_2d is IWETransitionZone2D).is_true()
	assert_str(zone_2d.get("target_scene")).is_equal("res://levels/cellar.tscn")
	var marker_2d := flat_2d.find_child("from_village", true, false) as IWEEntryMarker2D
	assert_vector(marker_2d.position).is_equal(Vector2(300, 800))
	assert_bool(flat_2d.get_node_or_null("StageRuntime") != null).is_true()
	flat_2d.free()


# ---- the whole trip ------------------------------------------------------------------------------


func test_a_character_walks_into_a_zone_the_scene_changes_and_it_arrives_at_the_entry_point() -> void:
	var village := await _calibrated_document()
	_add_door(village)
	# The cellar is another document: same illustration, its own entry points, no zone.
	var cellar := await _calibrated_document()
	_add_entries(cellar)
	var cellar_root: Array = []
	var arrivals: Array = []
	var requested: Array[String] = []
	IWEStageTravel.scene_changer = func(path: String) -> void:
		requested.append(path)
		var current := get_tree().root.get_node_or_null("VillageStage")
		if current != null:
			current.free()
		var next := GENERATOR.build_perspective_scene(cellar, load(VILLAGE.BACKGROUND) as Texture2D, cellar.perspective_calibration, VILLAGE.WORLD_SCALE, true)
		next.name = "CellarStage"
		(next.get_node("StageRuntime") as IWEStageRuntime).arrival_applied.connect(func(entry: String, fallback: String, placed: int) -> void: arrivals.append([entry, fallback, placed]))
		get_tree().root.add_child(next)
		cellar_root.append(next)
	var stage: Array = await VILLAGE.start_stage(get_tree(), village)
	var village_root: Node3D = stage[0]
	village_root.name = "VillageStage"
	var player: CharacterBody3D = stage[1]
	assert_bool(player.is_in_group(IWEStageTravel.TRAVELLER_GROUP)).is_true()
	# Walk in: put the character in front of the zone and let the physics carry it into it.
	var calibration: IWEPerspectiveCalibration = village.perspective_calibration
	player.global_position = VILLAGE.floor_world(Vector2(1300, 590), calibration)
	player.set_move_input(Vector3.ZERO)
	var frames := 0
	player.move_to(VILLAGE.floor_world(ZONE_SPOT, calibration))
	while requested.is_empty() and frames < 900:
		await get_tree().physics_frame
		frames += 1
	assert_array(requested).override_failure_message("walking into the zone requested the scene (after %d frames)" % frames).is_equal(["res://levels/cellar.tscn"])
	for _frame in 6:
		await get_tree().physics_frame
	assert_int(cellar_root.size()).is_equal(1)
	assert_array(requested).override_failure_message("exactly one scene change").is_equal(["res://levels/cellar.tscn"])
	assert_array(arrivals).is_equal([["from_village", "none", 1]])
	var arrived_player := (cellar_root[0] as Node).get_node("Player") as CharacterBody3D
	var marker := (cellar_root[0] as Node).find_child("from_village", true, false) as Node3D
	assert_vector(arrived_player.global_position).override_failure_message("the character may settle a few millimetres on the navigation, not more").is_equal_approx(marker.global_position, Vector3(0.05, 0.05, 0.05))
	assert_float(arrived_player.rotation.y).is_equal_approx(deg_to_rad(45.0), 0.001)
	assert_bool(IWEStageTravel.is_traveling).is_false()
	(cellar_root[0] as Node).free()

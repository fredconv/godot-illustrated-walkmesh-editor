extends GdUnitTestSuite
## Custom events: a zone that tells the game "explosion" or "open_gate" when a character walks into it, and
## nothing else. Authoring in the dock, saving, export, and the runtime.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const CANVAS_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_canvas.gd")
const GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")


func before_test() -> void:
	IWEStageTravel.reset()


func after_test() -> void:
	IWEStageTravel.reset()


func _square(x: float, y: float, size := 100.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)])


func _event_zone(event_name: String, repeating := false) -> IWETransitionZone:
	var zone := IWETransitionZone.new()
	zone.action = IWEActionZone.ACTION_EVENT
	zone.event_name = event_name
	zone.repeat = repeating
	get_tree().root.add_child(zone)
	return zone


func _traveller() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.add_to_group(IWEStageTravel.TRAVELLER_GROUP)
	get_tree().root.add_child(body)
	return body


# ---- data ----------------------------------------------------------------------------------------


func test_the_event_name_and_repeat_live_in_the_params_and_survive_a_save() -> void:
	var document := IWEDocument.new()
	var zone := IWEActionZone.create_zone("Mine", _square(0, 0))
	zone.action = IWEActionZone.ACTION_EVENT
	zone.params = {"event": "explosion", "repeat": true}
	document.action_zones.append(zone)
	document.prepare_for_save()
	var path := "user://iwe_event_data.tres"
	assert_int(ResourceSaver.save(document, path)).is_equal(OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as IWEDocument
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_str(loaded.action_zones[0].get_event_name()).is_equal("explosion")
	assert_bool(loaded.action_zones[0].repeats()).is_true()
	assert_str(loaded.action_zones[0].describe()).is_equal("Mine: event explosion")


func test_an_event_zone_without_a_name_is_reported() -> void:
	var document := IWEDocument.new()
	var zone := IWEActionZone.create_zone("Nameless", _square(0, 0))
	zone.action = IWEActionZone.ACTION_EVENT
	document.action_zones.append(zone)
	assert_str(" ".join(document.validate_references())).contains("triggers a custom event but has no event name")
	zone.params = {"event": "boom"}
	assert_array(Array(document.validate_references())).is_empty()


func test_an_event_is_a_built_in_action_so_no_unknown_action_warning() -> void:
	assert_bool(IWEActionZone.is_known_action(IWEActionZone.ACTION_EVENT)).is_true()


# ---- runtime -------------------------------------------------------------------------------------


func test_walking_into_an_event_zone_tells_the_game_its_name_and_loads_nothing() -> void:
	var zone := _event_zone("explosion")
	var body := _traveller()
	var received: Array = []
	zone.event_fired.connect(func(event_name: String, the_zone: Node, the_body: Node) -> void: received.append([event_name, the_zone, the_body]))
	zone._on_body_entered(body)
	assert_int(received.size()).is_equal(1)
	assert_str(received[0][0]).is_equal("explosion")
	assert_object(received[0][1]).is_same(zone)
	assert_object(received[0][2]).is_same(body)
	assert_bool(IWEStageTravel.is_traveling).override_failure_message("an event never changes the scene").is_false()
	zone.free()
	body.free()


func test_an_event_fires_once_unless_it_repeats() -> void:
	var once := _event_zone("once")
	var many := _event_zone("many", true)
	var body := _traveller()
	var counts := {"once": 0, "many": 0}
	once.event_fired.connect(func(_n: String, _z: Node, _b: Node) -> void: counts.once += 1)
	many.event_fired.connect(func(_n: String, _z: Node, _b: Node) -> void: counts.many += 1)
	for _round in 3:
		once._on_body_entered(body)
		once._on_body_exited(body)
		many._on_body_entered(body)
		many._on_body_exited(body)
	assert_int(counts.once).override_failure_message("a one-shot event fires once, even after leaving and coming back").is_equal(1)
	assert_int(counts.many).override_failure_message("a repeating event fires on every entry").is_equal(3)
	once.free()
	many.free()
	body.free()


func test_a_repeating_event_does_not_fire_twice_while_the_character_stays_inside() -> void:
	var zone := _event_zone("steady", true)
	var body := _traveller()
	var count := [0]
	zone.event_fired.connect(func(_n: String, _z: Node, _b: Node) -> void: count[0] += 1)
	zone._on_body_entered(body)
	zone._on_body_entered(body)
	assert_int(count[0]).is_equal(1)
	zone.free()
	body.free()


func test_a_disabled_event_zone_is_silent_until_the_game_enables_it() -> void:
	var zone := _event_zone("gate")
	zone.enabled = false
	var body := _traveller()
	var count := [0]
	zone.event_fired.connect(func(_n: String, _z: Node, _b: Node) -> void: count[0] += 1)
	zone._on_body_entered(body)
	assert_int(count[0]).is_equal(0)
	zone.enabled = true
	zone._on_body_entered(body)
	assert_int(count[0]).override_failure_message("the game opens the gate by enabling the zone").is_equal(1)
	zone.free()
	body.free()


func test_a_body_that_is_not_a_traveller_does_not_fire_an_event() -> void:
	var zone := _event_zone("boom")
	var stranger := CharacterBody3D.new()
	get_tree().root.add_child(stranger)
	var count := [0]
	zone.event_fired.connect(func(_n: String, _z: Node, _b: Node) -> void: count[0] += 1)
	zone._on_body_entered(stranger)
	assert_int(count[0]).is_equal(0)
	zone.free()
	stranger.free()


func test_a_game_can_listen_to_every_zone_through_one_group() -> void:
	var first := _event_zone("one")
	var second := _event_zone("two")
	var names: Array[String] = []
	for zone in get_tree().get_nodes_in_group("iwe_action_zone"):
		zone.event_fired.connect(func(event_name: String, _z: Node, _b: Node) -> void: names.append(event_name))
	var body := _traveller()
	first._on_body_entered(body)
	second._on_body_entered(body)
	assert_array(names).is_equal(["one", "two"])
	first.free()
	second.free()
	body.free()


func test_two_zones_two_events_two_names() -> void:
	var left := _event_zone("explosion")
	var right := _event_zone("open_gate")
	var body := _traveller()
	var seen: Array[String] = []
	left.event_fired.connect(func(event_name: String, _z: Node, _b: Node) -> void: seen.append(event_name))
	right.event_fired.connect(func(event_name: String, _z: Node, _b: Node) -> void: seen.append(event_name))
	right._on_body_entered(body)
	left._on_body_entered(body)
	assert_array(seen).is_equal(["open_gate", "explosion"])
	left.free()
	right.free()
	body.free()


# ---- export ----------------------------------------------------------------------------------------


func _document_with_event() -> IWEDocument:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var document: IWEDocument = dock._document
	dock.queue_free()
	var zone := IWEActionZone.create_zone("Trap", PackedVector2Array([Vector2(1340, 560), Vector2(1440, 560), Vector2(1440, 620), Vector2(1340, 620)]))
	zone.action = IWEActionZone.ACTION_EVENT
	zone.params = {"event": "explosion", "repeat": true}
	document.action_zones.append(zone)
	return document


func test_the_exports_carry_the_event_name_and_repeat() -> void:
	var document := await _document_with_event()
	var texture := load(VILLAGE.BACKGROUND) as Texture2D
	var perspective := GENERATOR.build_perspective_scene(document, texture, document.perspective_calibration, VILLAGE.WORLD_SCALE, false)
	var node := perspective.find_child("Trap", true, false)
	assert_bool(node is IWETransitionZone).is_true()
	assert_str(node.get("event_name")).is_equal("explosion")
	assert_bool(node.get("repeat")).is_true()
	assert_str(node.get("action")).is_equal(IWEActionZone.ACTION_EVENT)
	perspective.free()
	var flat_2d := GENERATOR.build_2d_scene(document, texture)
	assert_str(flat_2d.find_child("Trap", true, false).get("event_name")).is_equal("explosion")
	flat_2d.free()


func test_the_event_fires_when_a_character_really_walks_into_the_exported_zone() -> void:
	var document := await _document_with_event()
	var stage: Array = await VILLAGE.start_stage(get_tree(), document)
	var root: Node3D = stage[0]
	var player: IWEWalkmeshCharacter = stage[1]
	var zone := root.find_child("Trap", true, false) as IWETransitionZone
	var received: Array = []
	zone.event_fired.connect(func(event_name: String, _z: Node, body: Node) -> void: received.append([event_name, body]))
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	player.global_position = VILLAGE.floor_world(Vector2(1290, 590), calibration)
	await get_tree().physics_frame
	player.move_to(VILLAGE.floor_world(Vector2(1390, 590), calibration))
	var frames := 0
	while received.is_empty() and frames < 900:
		await get_tree().physics_frame
		frames += 1
	assert_int(received.size()).override_failure_message("no event after %d frames" % frames).is_equal(1)
	assert_str(received[0][0]).is_equal("explosion")
	assert_object(received[0][1]).is_same(player)
	assert_bool(IWEStageTravel.is_traveling).is_false()
	root.free()


# ---- the dock --------------------------------------------------------------------------------------


func test_the_panel_offers_the_event_action_with_a_name_and_a_repeat_option() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._canvas.action_zone_created.emit(_square(300, 600))
	var zone: IWEActionZone = dock._document.action_zones[0]
	var panel: IWEActionPanel = dock._action_panel
	panel.zone_property_requested.emit(zone.id, "action", IWEActionZone.ACTION_EVENT)
	assert_bool(panel._zone_event.visible).override_failure_message("the event name field shows for an event").is_true()
	assert_bool(panel._zone_repeat.visible).is_true()
	assert_bool(panel._scene_row.visible).override_failure_message("there is no scene to choose for an event").is_false()
	assert_bool(panel._zone_entry.visible).is_false()
	panel.zone_property_requested.emit(zone.id, "event_name", "explosion")
	panel.zone_property_requested.emit(zone.id, "repeat", true)
	assert_str(zone.get_event_name()).is_equal("explosion")
	assert_bool(zone.repeats()).is_true()
	assert_str(zone.describe()).contains("event explosion")
	assert_str(panel._zone_hint.text).contains("event_fired")
	dock._undo()
	assert_bool(zone.repeats()).is_false()
	dock._undo()
	assert_str(zone.get_event_name()).override_failure_message("undo takes the name back").is_empty()
	panel.zone_property_requested.emit(zone.id, "action", IWEActionZone.ACTION_SCENE_TRANSITION)
	assert_bool(panel._zone_event.visible).is_false()
	assert_bool(panel._scene_row.visible).is_true()
	dock.queue_free()


func test_the_export_check_names_an_event_zone_that_has_no_name() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	dock._canvas.action_zone_created.emit(_square(1340, 560, 80))
	dock._action_panel.zone_property_requested.emit(dock._document.action_zones[0].id, "action", IWEActionZone.ACTION_EVENT)
	dock._check_export()
	assert_str(dock._validation_label.text).contains("has no event name")
	dock.queue_free()

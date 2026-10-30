extends GdUnitTestSuite
## The runtime that lets a character cross from one scene to another: transition zones, the entry
## markers of the scene that is reached, and the guard against double triggers. Nothing here needs the
## plugin's own character: the traveller is a plain CharacterBody3D that joined the group.

var _requests: Array[String] = []


func before_test() -> void:
	IWEStageTravel.reset()
	_requests.clear()
	IWEStageTravel.scene_changer = func(path: String) -> void: _requests.append(path)


func after_test() -> void:
	IWEStageTravel.reset()


func _traveller(position := Vector3.ZERO) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.add_to_group(IWEStageTravel.TRAVELLER_GROUP)
	body.position = position
	get_tree().root.add_child(body)
	return body


func _zone(action := IWEActionZone.ACTION_SCENE_TRANSITION, scene := "res://levels/forest.tscn", entry := "from_village") -> IWETransitionZone:
	var zone := IWETransitionZone.new()
	zone.action = action
	zone.target_scene = scene
	zone.entry_id = entry
	get_tree().root.add_child(zone)
	return zone


func _marker(entry_name: String, position: Vector3, is_default := false, facing := NAN) -> IWEEntryMarker:
	var marker := IWEEntryMarker.new()
	marker.entry_id = entry_name
	marker.is_default = is_default
	marker.facing_degrees = facing
	marker.position = position
	get_tree().root.add_child(marker)
	return marker


func _free_all(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.free()


# ---- the zone ------------------------------------------------------------------------------------


func test_a_traveller_entering_the_zone_requests_the_scene_and_the_entry_point() -> void:
	var zone := _zone()
	var body := _traveller()
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_array(_requests).is_equal(["res://levels/forest.tscn"])
	assert_bool(IWEStageTravel.is_traveling).is_true()
	assert_str(IWEStageTravel.pending_entry_id).is_equal("from_village")
	_free_all([zone, body])


func test_a_body_outside_the_traveller_group_does_not_trigger_the_zone() -> void:
	var zone := _zone()
	var stranger := CharacterBody3D.new()
	get_tree().root.add_child(stranger)
	zone._on_body_entered(stranger)
	await get_tree().process_frame
	assert_array(_requests).is_empty()
	assert_bool(zone.has_fired()).is_false()
	_free_all([zone, stranger])


func test_an_empty_trigger_group_reacts_to_any_body() -> void:
	var zone := _zone()
	zone.trigger_group = ""
	var stranger := CharacterBody3D.new()
	get_tree().root.add_child(stranger)
	zone._on_body_entered(stranger)
	await get_tree().process_frame
	assert_array(_requests).is_equal(["res://levels/forest.tscn"])
	_free_all([zone, stranger])


func test_a_disabled_zone_does_nothing_until_it_is_enabled() -> void:
	var zone := _zone()
	zone.enabled = false
	var body := _traveller()
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_array(_requests).is_empty()
	zone.enabled = true
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_array(_requests).is_equal(["res://levels/forest.tscn"])
	_free_all([zone, body])


func test_a_zone_fires_once_even_if_the_body_enters_it_twice() -> void:
	var zone := _zone()
	var body := _traveller()
	zone._on_body_entered(body)
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_int(_requests.size()).override_failure_message("a double trigger loaded the scene twice").is_equal(1)
	_free_all([zone, body])


func test_two_touching_zones_do_not_load_two_scenes() -> void:
	var first := _zone(IWEActionZone.ACTION_SCENE_TRANSITION, "res://levels/forest.tscn", "a")
	var second := _zone(IWEActionZone.ACTION_SCENE_TRANSITION, "res://levels/cave.tscn", "b")
	var body := _traveller()
	first._on_body_entered(body)
	second._on_body_entered(body)
	await get_tree().process_frame
	assert_array(_requests).is_equal(["res://levels/forest.tscn"])
	assert_bool(second.has_fired()).override_failure_message("the second zone saw a travel under way and stayed armed").is_false()
	_free_all([first, second, body])


func test_a_zone_can_be_armed_again() -> void:
	var zone := _zone(IWEActionZone.ACTION_SCENE_TRANSITION, "res://levels/forest.tscn", "a")
	var body := _traveller()
	zone._on_body_entered(body)
	IWEStageTravel.finish()
	zone.rearm()
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_int(_requests.size()).is_equal(2)
	_free_all([zone, body])


func test_the_triggered_signal_lets_the_game_handle_the_event_itself() -> void:
	var zone := _zone()
	zone.auto_handle = false
	var received: Array = []
	zone.triggered.connect(func(the_zone: IWETransitionZone, the_body: Node3D) -> void: received.append([the_zone, the_body]))
	var body := _traveller()
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_int(received.size()).is_equal(1)
	assert_object(received[0][1]).is_same(body)
	assert_array(_requests).override_failure_message("auto_handle is off, so no scene was requested").is_empty()
	assert_bool(IWEStageTravel.is_traveling).is_false()
	_free_all([zone, body])


func test_an_action_the_plugin_does_not_know_only_fires_the_signal() -> void:
	var zone := _zone("play_cutscene", "", "")
	var received: Array = []
	zone.triggered.connect(func(_z: IWETransitionZone, _b: Node3D) -> void: received.append(zone.action))
	var body := _traveller()
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_array(received).is_equal(["play_cutscene"])
	assert_array(_requests).is_empty()
	assert_bool(IWEStageTravel.is_traveling).is_false()
	_free_all([zone, body])


# ---- refused travels -----------------------------------------------------------------------------


func test_a_missing_scene_leaves_the_character_where_it_is_and_the_zone_armed() -> void:
	IWEStageTravel.scene_changer = Callable()
	var zone := _zone(IWEActionZone.ACTION_SCENE_TRANSITION, "res://levels/does_not_exist.tscn", "x")
	var body := _traveller(Vector3(1, 2, 3))
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_bool(IWEStageTravel.is_traveling).override_failure_message("a refused travel must not lock the next one").is_false()
	assert_str(IWEStageTravel.last_error).contains("scene not found")
	assert_vector(body.position).is_equal(Vector3(1, 2, 3))
	assert_bool(zone.has_fired()).is_false()
	_free_all([zone, body])


func test_a_zone_without_a_scene_is_refused_without_crashing() -> void:
	var zone := _zone(IWEActionZone.ACTION_SCENE_TRANSITION, "", "x")
	var body := _traveller()
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_str(IWEStageTravel.last_error).is_equal("no target scene")
	assert_bool(IWEStageTravel.is_traveling).is_false()
	_free_all([zone, body])


func test_a_travel_that_nobody_acknowledges_is_dropped_after_the_safety_delay() -> void:
	IWEStageTravel.safety_frames = 3
	assert_bool(IWEStageTravel.request(get_tree(), "res://levels/forest.tscn", "a")).is_true()
	for _frame in 6:
		await get_tree().process_frame
	assert_bool(IWEStageTravel.is_traveling).is_false()
	assert_bool(IWEStageTravel.arrival_pending).is_false()
	IWEStageTravel.safety_frames = 600


# ---- arriving ------------------------------------------------------------------------------------


func test_the_traveller_appears_at_the_requested_entry_point() -> void:
	var near := _marker("near", Vector3(1, 0, 1))
	var wanted := _marker("from_village", Vector3(5, 0, 7), false, 90.0)
	var body := _traveller(Vector3(100, 100, 100))
	var result := IWEStageTravel.place_travellers(get_tree(), "from_village")
	assert_int(result["placed"]).is_equal(1)
	assert_str(result["entry_id"]).is_equal("from_village")
	assert_str(result["fallback"]).is_equal("none")
	assert_vector(body.global_position).is_equal(Vector3(5, 0, 7))
	assert_float(body.rotation.y).is_equal_approx(deg_to_rad(90.0), 0.0001)
	_free_all([near, wanted, body])


func test_an_unknown_entry_point_falls_back_to_the_default_one() -> void:
	var other := _marker("other", Vector3(1, 0, 1))
	var default_entry := _marker("start", Vector3(9, 0, 9), true)
	var body := _traveller()
	var result := IWEStageTravel.place_travellers(get_tree(), "nope")
	assert_str(result["fallback"]).is_equal("default")
	assert_str(result["entry_id"]).is_equal("start")
	assert_vector(body.global_position).is_equal(Vector3(9, 0, 9))
	_free_all([other, default_entry, body])


func test_with_no_default_the_first_entry_point_is_used() -> void:
	var first := _marker("first", Vector3(2, 0, 2))
	var second := _marker("second", Vector3(8, 0, 8))
	var body := _traveller()
	var result := IWEStageTravel.place_travellers(get_tree(), "")
	assert_str(result["fallback"]).is_equal("first")
	assert_vector(body.global_position).is_equal(Vector3(2, 0, 2))
	_free_all([first, second, body])


func test_a_scene_without_entry_points_leaves_the_traveller_in_place() -> void:
	var body := _traveller(Vector3(4, 0, 4))
	var result := IWEStageTravel.place_travellers(get_tree(), "from_village")
	assert_str(result["fallback"]).is_equal("missing")
	assert_int(result["placed"]).is_equal(0)
	assert_vector(body.global_position).is_equal(Vector3(4, 0, 4))
	_free_all([body])


func test_every_traveller_of_the_scene_is_placed_and_others_are_not() -> void:
	var marker := _marker("here", Vector3(3, 0, 3))
	var one := _traveller()
	var two := _traveller()
	var bystander := Node3D.new()
	get_tree().root.add_child(bystander)
	var result := IWEStageTravel.place_travellers(get_tree(), "here")
	assert_int(result["placed"]).is_equal(2)
	assert_vector(bystander.global_position).is_equal(Vector3.ZERO)
	_free_all([marker, one, two, bystander])


func test_a_teleported_character_drops_the_path_it_had() -> void:
	var character := IWEWalkmeshCharacter.new()
	get_tree().root.add_child(character)
	await get_tree().process_frame
	assert_bool(character.is_in_group(IWEStageTravel.TRAVELLER_GROUP)).override_failure_message("the stage character joins the group on its own").is_true()
	character._path = PackedVector3Array([Vector3(1, 0, 1), Vector3(2, 0, 2)])
	character._pending_target = Vector3(5, 0, 5)
	var marker := _marker("here", Vector3(3, 0, 3))
	IWEStageTravel.place_travellers(get_tree(), "here")
	assert_vector(character.global_position).is_equal(Vector3(3, 0, 3))
	assert_int(character._path.size()).is_equal(0)
	assert_bool(character.is_moving_along_path()).is_false()
	_free_all([character, marker])


func test_the_runtime_node_applies_the_arrival_once_and_clears_the_travel() -> void:
	var marker := _marker("from_village", Vector3(6, 0, 6))
	var body := _traveller()
	IWEStageTravel.request(get_tree(), "res://levels/forest.tscn", "from_village")
	var runtime := IWEStageRuntime.new()
	var applied: Array = []
	runtime.arrival_applied.connect(func(entry: String, fallback: String, placed: int) -> void: applied.append([entry, fallback, placed]))
	get_tree().root.add_child(runtime)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(applied).is_equal([["from_village", "none", 1]])
	assert_vector(body.global_position).is_equal(Vector3(6, 0, 6))
	assert_bool(IWEStageTravel.is_traveling).is_false()
	assert_bool(IWEStageTravel.arrival_pending).is_false()
	assert_bool(runtime.apply_arrival()).override_failure_message("nothing is pending any more").is_false()
	_free_all([marker, body, runtime])


func test_a_scene_that_was_not_reached_by_a_transition_is_left_alone() -> void:
	var marker := _marker("start", Vector3(6, 0, 6), true)
	var body := _traveller(Vector3(1, 1, 1))
	var runtime := IWEStageRuntime.new()
	get_tree().root.add_child(runtime)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(body.global_position).override_failure_message("the first scene of a game keeps its own spawn point").is_equal(Vector3(1, 1, 1))
	_free_all([marker, body, runtime])


# ---- warp ----------------------------------------------------------------------------------------


func test_a_warp_zone_moves_the_traveller_inside_the_scene() -> void:
	var marker := _marker("top", Vector3(10, 0, 10))
	var zone := _zone(IWEActionZone.ACTION_WARP, "", "top")
	var body := _traveller(Vector3(1, 0, 1))
	zone._on_body_entered(body)
	await get_tree().process_frame
	assert_vector(body.global_position).is_equal(Vector3(10, 0, 10))
	assert_array(_requests).override_failure_message("a warp never changes the scene").is_empty()
	assert_bool(IWEStageTravel.is_traveling).is_false()
	_free_all([marker, zone, body])

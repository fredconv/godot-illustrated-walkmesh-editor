extends GdUnitTestSuite

## M2: cutouts carry stable identifiers, exported nodes carry the identifier of the region they come
## from, and a validator reports broken references without changing anything.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const WORK_FOLDER := "user://iwe_stable_ids"
const IMAGE_SIZE := Vector2i(1000, 700)


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(WORK_FOLDER))


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _dock_with_cutouts() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Paths")
	dock._canvas.region_created.emit(VILLAGE.points(VILLAGE.CROSSROADS))
	var region: Resource = dock._document.regions[0]
	dock._canvas.subtraction_created.emit(region.id, VILLAGE.fountain_footprint())
	dock._canvas.subtraction_created.emit(region.id, VILLAGE.points(VILLAGE.BENCH_CUTOUT))
	return dock


func test_each_new_cutout_gets_its_own_identifier() -> void:
	var dock := await _dock_with_cutouts()
	var region: Resource = dock._document.regions[0]
	assert_int(region.subtraction_ids.size()).is_equal(2)
	assert_str(region.subtraction_ids[0]).starts_with("cutout_")
	assert_str(region.subtraction_ids[0]).is_not_equal(region.subtraction_ids[1])
	dock.queue_free()


func test_undo_and_redo_give_the_same_cutout_back_with_the_same_identifier() -> void:
	var dock := await _dock_with_cutouts()
	var region: Resource = dock._document.regions[0]
	var second_id: String = region.subtraction_ids[1]
	dock._undo()
	assert_int(region.subtraction_ids.size()).is_equal(1)
	assert_int(region.subtraction_polygons.size()).is_equal(1)
	dock._redo()
	assert_array(region.subtraction_ids).is_equal(PackedStringArray([region.subtraction_ids[0], second_id]))
	dock.queue_free()


func test_renaming_a_cutout_keeps_its_identifier() -> void:
	var dock := await _dock_with_cutouts()
	var region: Resource = dock._document.regions[0]
	var first_id: String = region.subtraction_ids[0]
	dock._rename_cutout(region.id, 0, "Fountain")
	assert_str(region.subtraction_ids[0]).is_equal(first_id)
	assert_str(region.subtraction_names[0]).is_equal("Fountain")
	dock.queue_free()


func test_identifiers_survive_a_save_and_reopen() -> void:
	var dock := await _dock_with_cutouts()
	var ids: PackedStringArray = dock._document.regions[0].subtraction_ids.duplicate()
	var target := WORK_FOLDER.path_join("doc.tres")
	dock._save_document(target)
	dock.queue_free()
	await get_tree().process_frame
	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(target)
	assert_array(reopened._document.regions[0].subtraction_ids).is_equal(ids)
	reopened.queue_free()


func test_a_document_saved_before_identifiers_existed_gets_them_when_opened() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	var region: Resource = REGION_SCRIPT.new()
	region.id = "old"
	region.points = _rect(0, 0, 100, 100)
	region.subtraction_polygons.append(_rect(10, 10, 20, 20))
	region.subtraction_polygons.append(_rect(50, 50, 20, 20))
	document.add_region(region)
	assert_bool(region.subtraction_ids.is_empty()).is_true()
	var dock: Control = await VILLAGE.new_dock(get_tree())
	dock._replace_document(document)
	assert_int(region.subtraction_ids.size()).is_equal(2)
	assert_str(region.subtraction_ids[0]).is_not_equal(region.subtraction_ids[1])
	dock.queue_free()


func test_a_duplicated_region_gets_new_cutout_identifiers() -> void:
	var dock := await _dock_with_cutouts()
	var original: Resource = dock._document.regions[0]
	dock._select_region(original.id)
	dock._duplicate_selected_region()
	assert_int(dock._document.regions.size()).is_equal(2)
	var copy: Resource = dock._document.regions[1]
	assert_int(copy.subtraction_ids.size()).is_equal(2)
	for id in copy.subtraction_ids:
		assert_bool(original.subtraction_ids.has(id)).override_failure_message("the copy reuses %s" % id).is_false()
	assert_array(dock._document.validate_references()).is_empty()
	dock.queue_free()


func _export_perspective(document: Resource) -> Node3D:
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0))
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, Vector2i(1280, 720))
	calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)
	var texture := ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))
	return SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, false)


func _document_with_a_cutout() -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	var region: Resource = REGION_SCRIPT.new()
	region.id = "yard"
	region.name = "Yard"
	region.points = _rect(100, 380, 600, 250)
	region.subtraction_polygons.append(_rect(300, 450, 100, 80))
	region.subtraction_names.append("Pond")
	region.ensure_cutout_ids()
	document.add_region(region)
	return document


func test_exported_perspective_nodes_carry_the_region_and_cutout_identifiers() -> void:
	var document := _document_with_a_cutout()
	var root := _export_perspective(document)
	var node := root.find_child("Yard", true, false)
	assert_object(node).is_not_null()
	assert_str(node.get_meta("iwe_region_id")).is_equal("yard")
	var pond := node.find_child("Pond", true, false)
	assert_object(pond).is_not_null()
	assert_str(pond.get_meta("iwe_cutout_id")).is_equal(document.regions[0].subtraction_ids[0])
	root.free()


func test_exported_flat_scenes_carry_the_region_identifier() -> void:
	var document := _document_with_a_cutout()
	var texture := ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))
	var flat: Node = SCENE_GENERATOR.build_2d_scene(document, texture)
	assert_str(flat.find_child("Region_Yard", true, false).get_meta("iwe_region_id")).is_equal("yard")
	flat.free()
	var solid: Node = SCENE_GENERATOR.build_3d_scene(document, texture)
	var node: Node = solid.find_child("Yard", true, false)
	assert_str(node.get_meta("iwe_region_id")).is_equal("yard")
	assert_str(node.find_child("Pond", true, false).get_meta("iwe_cutout_id")).is_equal(document.regions[0].subtraction_ids[0])
	solid.free()


func test_a_consistent_document_has_no_reference_problems() -> void:
	var document := _document_with_a_cutout()
	var group: Resource = GROUP_SCRIPT.create_group("Paths")
	document.add_group(group)
	document.regions[0].group_id = group.id
	assert_array(document.validate_references()).is_empty()


func test_the_validator_names_each_broken_reference_and_changes_nothing() -> void:
	var document := _document_with_a_cutout()
	document.regions[0].group_id = "missing_group"
	var twin: Resource = REGION_SCRIPT.new()
	twin.id = "yard"
	twin.name = "Twin"
	document.add_region(twin)
	var anchor_a: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(1, 1))
	var anchor_b: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(2, 2))
	anchor_b.id = anchor_a.id
	document.scale_anchors.append(anchor_a)
	document.scale_anchors.append(anchor_b)
	var before := var_to_str(document.regions[0].group_id)
	var problems: PackedStringArray = document.validate_references()
	var text := " | ".join(problems)
	assert_str(text).contains("missing_group")
	assert_str(text).contains("Region identifier \"yard\"")
	assert_str(text).contains("Height reference identifier")
	assert_int(problems.size()).is_equal(3)
	assert_str(var_to_str(document.regions[0].group_id)).is_equal(before)
	assert_int(document.regions.size()).is_equal(2)

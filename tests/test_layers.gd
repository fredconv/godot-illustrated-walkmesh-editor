extends GdUnitTestSuite

## Layers and visual elements: the version 2 data, the migration of version 1 documents, the dock
## operations with undo, and the export of background and foreground pictures with depth occlusion.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const OLD_FIXTURE := "res://tests/fixtures/iwe_document_old_panel_reference.tres"
const WORK_FOLDER := "user://iwe_layers"
const IMAGE_SIZE := Vector2i(1000, 700)
const VIEWPORT_SIZE := Vector2i(1280, 720)


func after_test() -> void:
	VILLAGE.remove_folder(ProjectSettings.globalize_path(WORK_FOLDER))


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _texture(width: int = 200, height: int = 120) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 0.3, 1.0))
	return ImageTexture.create_from_image(image)


func _element(element_name: String, layer: String, mode: int, position: Vector2 = Vector2(400, 300)) -> IWEVisualElement:
	var element: IWEVisualElement = IWEVisualElement.create_element(element_name, "res://assets/img/foreground_template.png", Vector2i(200, 120), layer, mode)
	element.position = position
	return element


# ---- data and migration -------------------------------------------------------------------------


func test_a_version_one_document_gets_a_background_and_a_foreground_layer() -> void:
	var document: Resource = ResourceLoader.load(OLD_FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(document.layers.size()).is_equal(0)
	document.migrate_to_current()
	assert_int(document.layers.size()).is_equal(2)
	assert_str(document.layers[0].id).is_equal(IWELayer.BACKGROUND_ID)
	assert_str(document.layers[1].id).is_equal(IWELayer.FOREGROUND_ID)
	assert_int(document.layers[0].kind).is_equal(IWELayer.Kind.BACKGROUND)
	assert_int(document.schema_version).is_equal(DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION)


func test_the_migration_changes_nothing_else_and_never_reorders_regions() -> void:
	var document: Resource = ResourceLoader.load(OLD_FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE)
	var before := var_to_str([document.regions, document.groups, document.scale_anchors, document.perspective_calibration, document.image_size, document.illustration_path])
	var order_before: Array = document.regions.map(func(region: Resource) -> String: return region.id)
	document.migrate_to_current()
	var after := var_to_str([document.regions, document.groups, document.scale_anchors, document.perspective_calibration, document.image_size, document.illustration_path])
	assert_str(after).is_equal(before)
	assert_array(document.regions.map(func(region: Resource) -> String: return region.id)).is_equal(order_before)


func test_the_migration_is_repeatable() -> void:
	var document: Resource = ResourceLoader.load(OLD_FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE)
	document.migrate_to_current()
	var once := var_to_str(document.layers)
	document.migrate_to_current()
	document.migrate_to_current()
	assert_str(var_to_str(document.layers)).is_equal(once)
	assert_int(document.layers.size()).is_equal(2)


func test_opening_a_version_one_file_does_not_change_the_file() -> void:
	var before := FileAccess.get_md5(OLD_FIXTURE)
	var dock: Control = await VILLAGE.new_dock(get_tree())
	dock._open_document(OLD_FIXTURE)
	assert_int(dock._document.layers.size()).is_equal(2)
	assert_str(FileAccess.get_md5(OLD_FIXTURE)).override_failure_message("the file on disk is untouched until a save").is_equal(before)
	assert_bool(dock.is_dirty()).override_failure_message("a migrated document is not modified").is_false()
	dock.queue_free()


func test_an_element_without_a_layer_goes_to_the_foreground() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.visual_elements.append(_element("Orphan", "no_such_layer", IWEVisualElement.DepthMode.DEPTH))
	document.migrate_to_current()
	assert_str(document.visual_elements[0].layer_id).is_equal(IWELayer.FOREGROUND_ID)


func test_layers_and_elements_round_trip_through_a_saved_file() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.migrate_to_current()
	document.layers[1].opacity = 0.5
	document.layers[1].locked = true
	var element := _element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH)
	element.scale = Vector2(1.5, 1.5)
	element.opacity = 0.75
	element.ground_anchor = Vector2(480, 410)
	var plain := _element("Banner", IWELayer.BACKGROUND_ID, IWEVisualElement.DepthMode.BEHIND)
	document.visual_elements.append(element)
	document.visual_elements.append(plain)
	document.prepare_for_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_FOLDER))
	var path := WORK_FOLDER.path_join("round_trip.tres")
	assert_int(ResourceSaver.save(document, path)).is_equal(OK)
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(loaded.layers.size()).is_equal(2)
	assert_float(loaded.layers[1].opacity).is_equal(0.5)
	assert_bool(loaded.layers[1].locked).is_true()
	assert_int(loaded.visual_elements.size()).is_equal(2)
	var fountain: IWEVisualElement = loaded.visual_elements[0]
	assert_str(fountain.name).is_equal("Fountain")
	assert_vector(fountain.scale).is_equal(Vector2(1.5, 1.5))
	assert_float(fountain.opacity).is_equal(0.75)
	assert_vector(fountain.ground_anchor).is_equal(Vector2(480, 410))
	assert_int(fountain.depth_mode).is_equal(IWEVisualElement.DepthMode.DEPTH)
	var banner: IWEVisualElement = loaded.visual_elements[1]
	assert_bool(is_nan(banner.ground_anchor.x)).override_failure_message("an unset ground point stays unset").is_true()
	assert_int(banner.depth_mode).is_equal(IWEVisualElement.DepthMode.BEHIND)
	assert_array(loaded.validate_references()).is_empty()


func test_the_ground_point_defaults_to_the_bottom_centre_of_the_picture() -> void:
	var element := _element("Tree", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(100, 50))
	element.scale = Vector2(2.0, 2.0)
	assert_vector(element.get_effective_ground_anchor()).is_equal(Vector2(300, 290))
	element.ground_anchor = Vector2(10, 20)
	assert_vector(element.get_effective_ground_anchor()).is_equal(Vector2(10, 20))


func test_the_validator_reports_an_element_on_a_missing_layer() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.migrate_to_current()
	var element := _element("Lost", "gone", IWEVisualElement.DepthMode.DEPTH)
	document.visual_elements.append(element)
	assert_str(" ".join(document.validate_references())).contains("Lost").contains("layer that does not exist")


# ---- the dock -----------------------------------------------------------------------------------


func _dock_with_background() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	return dock


func _foreground_file() -> String:
	return ProjectSettings.globalize_path(VILLAGE.FOREGROUND)


func test_a_picture_is_placed_on_the_foreground_and_draws_by_depth() -> void:
	var dock := await _dock_with_background()
	var element: IWEVisualElement = dock.import_element(_foreground_file())
	assert_object(element).is_not_null()
	assert_str(element.layer_id).is_equal(IWELayer.FOREGROUND_ID)
	assert_int(element.depth_mode).is_equal(IWEVisualElement.DepthMode.DEPTH)
	assert_vector(element.position).override_failure_message("a picture as large as the illustration sits at its corner").is_equal(Vector2.ZERO)
	assert_vector(Vector2(element.texture_size)).is_equal(Vector2(VILLAGE.IMAGE_SIZE))
	assert_int(dock._document.visual_elements.size()).is_equal(1)
	dock.queue_free()


func test_a_picture_on_the_background_layer_stays_behind_the_character() -> void:
	var dock := await _dock_with_background()
	var element: IWEVisualElement = dock.import_element(_foreground_file(), IWELayer.BACKGROUND_ID)
	assert_int(element.depth_mode).is_equal(IWEVisualElement.DepthMode.BEHIND)
	dock.queue_free()


func test_adding_a_picture_is_one_undo_step() -> void:
	var dock := await _dock_with_background()
	dock.import_element(_foreground_file())
	dock._undo()
	assert_int(dock._document.visual_elements.size()).is_equal(0)
	dock._redo()
	assert_int(dock._document.visual_elements.size()).is_equal(1)
	dock.queue_free()


func test_a_picture_cannot_be_added_before_there_is_an_illustration() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	assert_object(dock.import_element(_foreground_file())).is_null()
	dock.queue_free()


func test_an_unreadable_picture_is_refused() -> void:
	var dock := await _dock_with_background()
	assert_object(dock.import_element("res://does_not_exist.png")).is_null()
	assert_int(dock._document.visual_elements.size()).is_equal(0)
	dock.queue_free()


func test_saving_copies_the_picture_once_beside_the_document_and_reopening_restores_it() -> void:
	var dock := await _dock_with_background()
	var first: IWEVisualElement = dock.import_element(_foreground_file())
	var second: IWEVisualElement = dock.import_element(_foreground_file())
	var target := WORK_FOLDER.path_join("save").path_join("doc.tres")
	dock._save_document(target)
	assert_str(first.texture_path).starts_with("assets/elements/")
	assert_str(second.texture_path).is_equal(first.texture_path)
	assert_bool(first.texture_path.is_absolute_path()).is_false()
	var files := DirAccess.get_files_at(ProjectSettings.globalize_path(target.get_base_dir().path_join("assets/elements")))
	assert_int(files.size()).override_failure_message("the same picture is stored once").is_equal(1)
	dock.queue_free()
	await get_tree().process_frame
	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(target)
	assert_int(reopened._document.visual_elements.size()).is_equal(2)
	assert_int(reopened._element_textures.size()).override_failure_message("the pictures load again").is_equal(2)
	assert_int(reopened._document.schema_version).is_equal(DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION)
	reopened.queue_free()


func test_moving_the_project_folder_keeps_the_pictures() -> void:
	var dock := await _dock_with_background()
	dock.import_element(_foreground_file())
	var folder := WORK_FOLDER.path_join("before")
	dock._save_document(folder.path_join("doc.tres"))
	dock.queue_free()
	await get_tree().process_frame
	var moved := WORK_FOLDER.path_join("after")
	assert_int(DirAccess.rename_absolute(ProjectSettings.globalize_path(folder), ProjectSettings.globalize_path(moved))).is_equal(OK)
	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(moved.path_join("doc.tres"))
	assert_int(reopened._element_textures.size()).is_equal(1)
	reopened.queue_free()


func test_a_missing_picture_is_kept_reported_and_never_removed() -> void:
	var dock := await _dock_with_background()
	dock.import_element(_foreground_file())
	var target := WORK_FOLDER.path_join("missing").path_join("doc.tres")
	dock._save_document(target)
	var stored: String = dock._document.visual_elements[0].texture_path
	dock.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target.get_base_dir().path_join(stored)))
	var before := FileAccess.get_md5(target)
	var reopened: Control = await VILLAGE.new_dock(get_tree())
	reopened._open_document(target)
	assert_int(reopened._document.visual_elements.size()).override_failure_message("the element stays in the document").is_equal(1)
	assert_int(reopened._element_textures.size()).is_equal(0)
	assert_str(FileAccess.get_md5(target)).override_failure_message("the document file is not rewritten").is_equal(before)
	reopened.queue_free()


func test_editing_a_picture_is_undoable_and_a_run_of_edits_is_one_step() -> void:
	var dock := await _dock_with_background()
	var element: IWEVisualElement = dock.import_element(_foreground_file(), IWELayer.FOREGROUND_ID)
	var start := element.position
	dock._set_element_property(element.id, "position", Vector2(10, 10))
	dock._set_element_property(element.id, "position", Vector2(20, 30))
	dock._set_element_property(element.id, "position", Vector2(40, 50))
	assert_vector(element.position).is_equal(Vector2(40, 50))
	dock._undo()
	assert_vector(element.position).override_failure_message("three position edits undo together").is_equal(start)
	dock._redo()
	assert_vector(element.position).is_equal(Vector2(40, 50))
	dock._set_element_property(element.id, "depth_mode", IWEVisualElement.DepthMode.IN_FRONT)
	assert_int(element.depth_mode).is_equal(IWEVisualElement.DepthMode.IN_FRONT)
	dock._undo()
	assert_int(element.depth_mode).is_equal(IWEVisualElement.DepthMode.DEPTH)
	dock.queue_free()


func test_a_new_layer_can_be_renamed_hidden_and_removed_with_undo() -> void:
	var dock := await _dock_with_background()
	dock._add_new_layer()
	assert_int(dock._document.layers.size()).is_equal(3)
	var layer: IWELayer = dock._document.layers[2]
	dock._set_layer_property(layer.id, "name", "Trees")
	assert_str(layer.name).is_equal("Trees")
	dock._set_layer_property(layer.id, "visible", false)
	assert_bool(layer.visible).is_false()
	dock._undo()
	assert_bool(layer.visible).is_true()
	var element: IWEVisualElement = dock.import_element(_foreground_file(), layer.id)
	dock._remove_layer_item("layer", layer.id)
	assert_object(dock._document.find_layer(layer.id)).is_null()
	assert_str(element.layer_id).override_failure_message("a removed layer hands its pictures to the default layer").is_equal(IWELayer.FOREGROUND_ID)
	dock._undo()
	assert_object(dock._document.find_layer(layer.id)).is_not_null()
	assert_str(element.layer_id).is_equal(layer.id)
	dock.queue_free()


func test_the_default_layers_cannot_be_removed() -> void:
	var dock := await _dock_with_background()
	dock._remove_layer_item("layer", IWELayer.BACKGROUND_ID)
	dock._remove_layer_item("layer", IWELayer.FOREGROUND_ID)
	assert_int(dock._document.layers.size()).is_equal(2)
	dock.queue_free()


func test_a_locked_layer_refuses_edits_to_its_pictures() -> void:
	var dock := await _dock_with_background()
	var element: IWEVisualElement = dock.import_element(_foreground_file(), IWELayer.FOREGROUND_ID)
	dock._set_layer_property(IWELayer.FOREGROUND_ID, "locked", true)
	dock._set_element_property(element.id, "position", Vector2(99, 99))
	assert_vector(element.position).is_equal(Vector2.ZERO)
	dock._remove_layer_item("element", element.id)
	assert_int(dock._document.visual_elements.size()).is_equal(1)
	assert_object(dock.import_element(_foreground_file(), IWELayer.FOREGROUND_ID)).override_failure_message("nothing is added to a locked layer").is_null()
	dock._set_layer_property(IWELayer.FOREGROUND_ID, "locked", false)
	dock._set_element_property(element.id, "position", Vector2(99, 99))
	assert_vector(element.position).is_equal(Vector2(99, 99))
	dock.queue_free()


func test_the_layer_panel_lists_layers_and_pictures_and_asks_the_dock_for_changes() -> void:
	var dock := await _dock_with_background()
	var element: IWEVisualElement = dock.import_element(_foreground_file())
	var tree: Tree = dock._layer_panel.get_node("LayerTree")
	assert_int(tree.get_root().get_child_count()).is_equal(2)
	var foreground_item := tree.get_root().get_child(1)
	assert_int(foreground_item.get_child_count()).is_equal(1)
	assert_str(foreground_item.get_child(0).get_text(0)).is_equal(element.name)
	dock._layer_panel._element_x.value = 55.0
	assert_float(element.position.x).override_failure_message("a field edit reaches the document through the dock").is_equal(55.0)
	dock._layer_panel._element_depth.select(IWEVisualElement.DepthMode.BEHIND)
	dock._layer_panel._element_depth.item_selected.emit(IWEVisualElement.DepthMode.BEHIND)
	assert_int(element.depth_mode).is_equal(IWEVisualElement.DepthMode.BEHIND)
	dock.queue_free()


# ---- navigation is never touched by layers ------------------------------------------------------


func _navigation_signature(document: Resource) -> String:
	var parts := []
	for region in document.regions:
		var mesh: NavigationMesh = GENERATOR._make_navigation_mesh(region, document.regions)
		parts.append([region.id, var_to_str(mesh.get_vertices()), mesh.get_polygon_count()])
	return var_to_str(parts)


func test_layers_and_pictures_never_change_navigation() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	var zone: Resource = REGION_SCRIPT.new()
	zone.id = "ground"
	zone.name = "Ground"
	zone.points = _rect(100, 380, 600, 250)
	zone.subtraction_polygons.append(_rect(300, 450, 100, 80))
	document.add_region(zone)
	var before := _navigation_signature(document)
	document.migrate_to_current()
	document.visual_elements.append(_element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(250, 400)))
	document.layers[1].visible = false
	document.layers[0].opacity = 0.2
	assert_str(_navigation_signature(document)).is_equal(before)


func _perspective(document: Resource, textures: Dictionary, add_player: bool = false) -> Node3D:
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0))
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)
	var texture := _texture(IMAGE_SIZE.x, IMAGE_SIZE.y)
	return GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, add_player, textures)


func _document_with_ground() -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	var zone: Resource = REGION_SCRIPT.new()
	zone.id = "ground"
	zone.name = "Ground"
	zone.points = _rect(100, 380, 700, 250)
	document.add_region(zone)
	document.migrate_to_current()
	return document


func test_no_navigation_or_collision_comes_from_a_picture() -> void:
	var document := _document_with_ground()
	var element := _element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH)
	document.visual_elements.append(element)
	var root := _perspective(document, {element.id: _texture()})
	var container := root.find_child("VisualElements", true, false)
	assert_object(container).is_not_null()
	assert_int(container.find_children("*", "NavigationRegion3D", true, false).size()).is_equal(0)
	assert_int(container.find_children("*", "CollisionShape3D", true, false).size()).is_equal(0)
	assert_int(container.find_children("*", "StaticBody3D", true, false).size()).is_equal(0)
	root.free()


# ---- perspective export and occlusion -----------------------------------------------------------


func _quad_for(root: Node, element: IWEVisualElement) -> MeshInstance3D:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("iwe_element_id") and node.get_meta("iwe_element_id") == element.id:
			return node
	return null


func test_a_depth_picture_sits_at_the_camera_distance_of_its_ground_point() -> void:
	var document := _document_with_ground()
	var element := _element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(400, 300))
	element.ground_anchor = Vector2(500, 500)
	document.visual_elements.append(element)
	var root := _perspective(document, {element.id: _texture()})
	var quad := _quad_for(root, element)
	assert_object(quad).is_not_null()
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)
	var floor_point: Vector3 = PROJECTOR.image_point_to_floor(Vector2(500, 500), IMAGE_SIZE, VIEWPORT_SIZE, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	var camera_basis := Basis.from_euler(Vector3(deg_to_rad(calibration.camera_rotation_degrees.x), deg_to_rad(calibration.camera_rotation_degrees.y), deg_to_rad(calibration.camera_rotation_degrees.z)))
	var expected_depth: float = -(camera_basis.inverse() * (floor_point - calibration.camera_position)).z * 0.01
	assert_float(-quad.position.z).is_equal_approx(expected_depth, expected_depth * 0.001)
	assert_float(quad.get_meta("iwe_depth_world_units")).is_equal_approx(expected_depth, expected_depth * 0.001)
	root.free()


func test_the_picture_covers_the_same_pixels_as_on_the_illustration_whatever_its_depth() -> void:
	var document := _document_with_ground()
	var near_element := _element("Near", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(300, 250))
	near_element.ground_anchor = Vector2(400, 600)
	var far_element := _element("Far", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(300, 250))
	far_element.ground_anchor = Vector2(400, 420)
	var behind := _element("Behind", IWELayer.BACKGROUND_ID, IWEVisualElement.DepthMode.BEHIND, Vector2(300, 250))
	var front := _element("Front", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.IN_FRONT, Vector2(300, 250))
	for item in [near_element, far_element, behind, front]:
		document.visual_elements.append(item)
	var textures := {}
	for item in document.visual_elements:
		textures[item.id] = _texture()
	var root := _perspective(document, textures)
	var fit_scale: float = PROJECTOR.image_scale_in_viewport(IMAGE_SIZE, VIEWPORT_SIZE)
	var expected_screen: Vector2 = PROJECTOR.image_to_viewport(Vector2(400, 310), IMAGE_SIZE, VIEWPORT_SIZE)
	var half_tan := tan(deg_to_rad(CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE).field_of_view_degrees) * 0.5)
	var aspect := float(VIEWPORT_SIZE.x) / float(VIEWPORT_SIZE.y)
	for item in document.visual_elements:
		var quad := _quad_for(root, item)
		assert_object(quad).override_failure_message("%s has a quad" % item.name).is_not_null()
		var depth := -quad.position.z
		var half_height := depth * half_tan
		var screen_x := (quad.position.x / (half_height * aspect) + 1.0) * 0.5 * VIEWPORT_SIZE.x
		var screen_y := (1.0 - quad.position.y / half_height) * 0.5 * VIEWPORT_SIZE.y
		assert_float(screen_x).override_failure_message("%s x" % item.name).is_equal_approx(expected_screen.x, 0.01)
		assert_float(screen_y).override_failure_message("%s y" % item.name).is_equal_approx(expected_screen.y, 0.01)
		var size := (quad.mesh as QuadMesh).size
		var pixels := size * float(VIEWPORT_SIZE.y) / (2.0 * half_height)
		assert_float(pixels.x).override_failure_message("%s width" % item.name).is_equal_approx(200.0 * fit_scale, 0.01)
		assert_float(pixels.y).override_failure_message("%s height" % item.name).is_equal_approx(120.0 * fit_scale, 0.01)
	root.free()


func test_behind_and_in_front_pictures_bracket_every_character_depth() -> void:
	var document := _document_with_ground()
	var behind := _element("Behind", IWELayer.BACKGROUND_ID, IWEVisualElement.DepthMode.BEHIND)
	var front := _element("Front", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.IN_FRONT)
	var by_depth := _element("ByDepth", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH)
	by_depth.ground_anchor = Vector2(450, 500)
	for item in [behind, front, by_depth]:
		document.visual_elements.append(item)
	var textures := {behind.id: _texture(), front.id: _texture(), by_depth.id: _texture()}
	var root := _perspective(document, textures)
	var depth_behind: float = _quad_for(root, behind).get_meta("iwe_depth_world_units")
	var depth_front: float = _quad_for(root, front).get_meta("iwe_depth_world_units")
	var depth_middle: float = _quad_for(root, by_depth).get_meta("iwe_depth_world_units")
	assert_float(depth_front).is_less(depth_middle)
	assert_float(depth_middle).is_less(depth_behind)
	assert_float(depth_front).is_greater(0.05)
	assert_float(depth_behind).is_less(GENERATOR.PERSPECTIVE_CAMERA_FAR * 0.9)
	root.free()


func test_a_character_nearer_than_the_ground_point_is_in_front_and_a_farther_one_is_behind() -> void:
	var document := _document_with_ground()
	var fountain := _element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(400, 300))
	fountain.ground_anchor = Vector2(500, 500)
	document.visual_elements.append(fountain)
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0))
	calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)
	var root: Node3D = GENERATOR.build_perspective_scene(document, _texture(IMAGE_SIZE.x, IMAGE_SIZE.y), calibration, 0.01, false, {fountain.id: _texture()})
	var quad_depth: float = _quad_for(root, fountain).get_meta("iwe_depth_world_units")
	var camera_basis := Basis.from_euler(Vector3(deg_to_rad(calibration.camera_rotation_degrees.x), deg_to_rad(calibration.camera_rotation_degrees.y), deg_to_rad(calibration.camera_rotation_degrees.z)))
	var depth_of := func(image_point: Vector2) -> float:
		var floor_point: Vector3 = PROJECTOR.image_point_to_floor(image_point, IMAGE_SIZE, VIEWPORT_SIZE, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		return -(camera_basis.inverse() * (floor_point - calibration.camera_position)).z * 0.01
	assert_float(depth_of.call(Vector2(500, 600))).override_failure_message("a character lower in the picture is nearer, so in front").is_less(quad_depth)
	assert_float(depth_of.call(Vector2(500, 420))).override_failure_message("a character higher in the picture is farther, so hidden").is_greater(quad_depth)
	root.free()


func test_pictures_are_hidden_from_the_top_camera() -> void:
	var document := _document_with_ground()
	var element := _element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH)
	document.visual_elements.append(element)
	var root := _perspective(document, {element.id: _texture()})
	var quad := _quad_for(root, element)
	var top_camera: Camera3D = root.find_child("TopCamera", true, false)
	assert_bool((top_camera.cull_mask & quad.layers) != 0).override_failure_message("the top view must not show a camera-attached quad").is_false()
	var game_camera: Camera3D = root.find_child("PerspectiveCamera", true, false)
	assert_bool((game_camera.cull_mask & quad.layers) != 0).is_true()
	root.free()


func test_a_hidden_layer_exports_nothing_and_opacity_selects_the_material() -> void:
	var document := _document_with_ground()
	var solid := _element("Solid", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.IN_FRONT)
	var faded := _element("Faded", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.IN_FRONT)
	faded.opacity = 0.5
	var hidden := _element("Hidden", IWELayer.BACKGROUND_ID, IWEVisualElement.DepthMode.BEHIND)
	for item in [solid, faded, hidden]:
		document.visual_elements.append(item)
	document.layers[0].visible = false
	var textures := {solid.id: _texture(), faded.id: _texture(), hidden.id: _texture()}
	var root := _perspective(document, textures)
	assert_object(_quad_for(root, hidden)).is_null()
	var solid_material := _quad_for(root, solid).material_override as StandardMaterial3D
	assert_int(solid_material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	var faded_material := _quad_for(root, faded).material_override as StandardMaterial3D
	assert_int(faded_material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_float(faded_material.albedo_color.a).is_equal_approx(0.5, 0.001)
	root.free()


func test_layer_opacity_multiplies_the_picture_opacity() -> void:
	var document := _document_with_ground()
	var element := _element("Faded", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.IN_FRONT)
	element.opacity = 0.5
	document.visual_elements.append(element)
	document.layers[1].opacity = 0.5
	var root := _perspective(document, {element.id: _texture()})
	var material := _quad_for(root, element).material_override as StandardMaterial3D
	assert_float(material.albedo_color.a).is_equal_approx(0.25, 0.001)
	root.free()


func test_a_picture_standing_above_the_horizon_is_reported_and_drawn_behind() -> void:
	var document := _document_with_ground()
	var element := _element("Sky", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(400, 0))
	element.ground_anchor = Vector2(500, 5)
	document.visual_elements.append(element)
	var root := _perspective(document, {element.id: _texture()})
	var warnings := GENERATOR.take_warnings(root)
	assert_str(" ".join(warnings)).contains("Sky").contains("horizon")
	assert_int(_quad_for(root, element).get_meta("iwe_depth_mode")).is_equal(IWEVisualElement.DepthMode.BEHIND)
	root.free()


func test_a_picture_without_a_texture_is_reported_not_silently_dropped() -> void:
	var document := _document_with_ground()
	var element := _element("Lost", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH)
	document.visual_elements.append(element)
	var root := _perspective(document, {})
	assert_str(" ".join(GENERATOR.take_warnings(root))).contains("Lost").contains("could not be loaded")
	assert_object(_quad_for(root, element)).is_null()
	root.free()


func test_the_character_can_walk_behind_a_picture_it_is_not_blocked_by_it() -> void:
	var document := _document_with_ground()
	var element := _element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(350, 400))
	element.ground_anchor = Vector2(450, 520)
	document.visual_elements.append(element)
	var root := _perspective(document, {element.id: _texture()}, true)
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(root)
	var player := root.get_node("Player") as CharacterBody3D
	var frames := 0
	while (frames < 12 or not player._navigation_settled) and frames < 600:
		await scene_tree.physics_frame
		frames += 1
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	calibration.fit_to_scale_anchors(document.scale_anchors, IMAGE_SIZE)
	var from_point: Variant = PROJECTOR.image_point_to_floor(Vector2(450, 400), IMAGE_SIZE, VIEWPORT_SIZE, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	var to_point: Variant = PROJECTOR.image_point_to_floor(Vector2(450, 600), IMAGE_SIZE, VIEWPORT_SIZE, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	player.global_position = Vector3(from_point.x, calibration.floor_height, from_point.z) * 0.01
	await scene_tree.physics_frame
	player.set_speed_multiplier(10.0)
	player.move_to(Vector3(to_point.x, calibration.floor_height, to_point.z) * 0.01)
	frames = 0
	while player.is_moving_along_path() and frames < 3000:
		await scene_tree.physics_frame
		frames += 1
	assert_bool(player.is_moving_along_path()).override_failure_message("the picture must not block the walk").is_false()
	var arrived := global_to_image(player.global_position, calibration)
	assert_float(arrived.y).is_greater(560.0)
	root.queue_free()
	await scene_tree.process_frame


func global_to_image(world_position: Vector3, calibration: IWEPerspectiveCalibration) -> Vector2:
	var floor_point := world_position / 0.01
	var screen: Variant = PROJECTOR.world_to_viewport(Vector3(floor_point.x, calibration.floor_height, floor_point.z), VIEWPORT_SIZE, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	var image: Variant = PROJECTOR.viewport_to_image(screen, IMAGE_SIZE, VIEWPORT_SIZE)
	return image if image != null else Vector2.INF


# ---- 2D export ----------------------------------------------------------------------------------


func test_the_2d_export_places_pictures_above_the_illustration_in_layer_order() -> void:
	var document := _document_with_ground()
	var behind := _element("Banner", IWELayer.BACKGROUND_ID, IWEVisualElement.DepthMode.BEHIND, Vector2(10, 20))
	var front := _element("Fountain", IWELayer.FOREGROUND_ID, IWEVisualElement.DepthMode.DEPTH, Vector2(400, 300))
	front.scale = Vector2(2.0, 2.0)
	front.opacity = 0.5
	document.visual_elements.append(front)
	document.visual_elements.append(behind)
	var root: Node2D = GENERATOR.build_2d_scene(document, _texture(IMAGE_SIZE.x, IMAGE_SIZE.y), 1.0, false, {behind.id: _texture(), front.id: _texture()})
	var container := root.find_child("VisualElements", true, false)
	assert_int(container.get_child_count()).is_equal(2)
	assert_str(container.get_child(0).name).override_failure_message("the background layer comes first").is_equal("Banner")
	var banner := container.get_child(0) as Sprite2D
	var fountain := container.get_child(1) as Sprite2D
	assert_int(banner.z_index).is_less(fountain.z_index)
	assert_vector(fountain.position).is_equal(Vector2(400, 300))
	assert_vector(fountain.scale).is_equal(Vector2(2.0, 2.0))
	assert_float(fountain.modulate.a).is_equal_approx(0.5, 0.001)
	assert_int(root.find_children("*", "NavigationRegion2D", true, false).size()).is_equal(1)
	root.free()


func test_an_export_from_the_dock_references_the_picture_of_a_project_file() -> void:
	var dock := await _dock_with_background()
	dock.import_element(_foreground_file())
	dock._pending_export_dimension = 4
	var path := "res://tests/_layers_export.tscn"
	dock._export_scene(path)
	var text := FileAccess.get_file_as_string(path)
	var size := FileAccess.open(path, FileAccess.READ).get_length()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_bool(text.contains("foreground_template.png")).override_failure_message("the scene points at the picture file").is_true()
	assert_int(size).override_failure_message("exported scene is %d bytes" % size).is_less(1000000)
	dock.queue_free()

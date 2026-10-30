extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const ILLUSTRATION := "res://assets/img/background.png"
const WORK_FOLDER := "res://iwdock_test_workflow"
const IMAGE_SIZE := Vector2i(1672, 941)
const VIEWPORT_SIZE := Vector2i(1152, 648)


func after_test() -> void:
	_remove_folder_recursive(ProjectSettings.globalize_path(WORK_FOLDER))


func _remove_folder_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in DirAccess.get_directories_at(path):
		_remove_folder_recursive(path.path_join(directory_name))
	DirAccess.remove_absolute(path)


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _build_document() -> Resource:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration(ILLUSTRATION, IMAGE_SIZE)
	var group: Resource = GROUP_SCRIPT.create_group("Chemin")
	document.add_group(group)

	# Left path: one walkable zone with two cutouts (a rock and a bush).
	var left: Resource = REGION_SCRIPT.new()
	left.id = "left_path"
	left.name = "Chemin gauche"
	left.group_id = group.id
	left.points = PackedVector2Array([Vector2(0, 560), Vector2(520, 500), Vector2(700, 640), Vector2(260, 941), Vector2(0, 941)])
	left.subtraction_polygons.append(_rect(180, 700, 90, 60))
	left.subtraction_names.append("Rocher")
	left.subtraction_polygons.append(_rect(40, 820, 70, 50))
	left.subtraction_names.append("Buisson")
	document.add_region(left)

	# Right bank: a second zone with one cutout (water).
	var right: Resource = REGION_SCRIPT.new()
	right.id = "right_bank"
	right.name = "Rive droite"
	right.group_id = group.id
	right.points = PackedVector2Array([Vector2(900, 480), Vector2(1400, 470), Vector2(1672, 600), Vector2(1672, 760), Vector2(1100, 700)])
	right.subtraction_polygons.append(_rect(1200, 560, 120, 50))
	right.subtraction_names.append("Eau")
	document.add_region(right)

	# Overlapping zone on the bridge: shares area with the left path.
	var bridge: Resource = REGION_SCRIPT.new()
	bridge.id = "bridge"
	bridge.name = "Pont"
	bridge.group_id = group.id
	bridge.points = _rect(420, 560, 200, 90)
	document.add_region(bridge)

	# Three templates of different apparent heights at different depths.
	var near: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(260, 900), 260.0)
	near.name = "Proche"
	var middle: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(800, 680), 160.0)
	middle.name = "Milieu"
	var far: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(1300, 520), 80.0)
	far.name = "Lointain"
	document.scale_anchors.append(near)
	document.scale_anchors.append(middle)
	document.scale_anchors.append(far)
	document.perspective_calibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	return document


func _load_texture() -> Texture2D:
	return load(ILLUSTRATION) as Texture2D


func test_full_workflow_regions_cutouts_templates_round_trip() -> void:
	var document := _build_document()

	assert_int(document.groups.size()).is_equal(1)
	assert_int(document.regions.size()).is_equal(3)
	assert_int(document.scale_anchors.size()).is_equal(3)

	# Cutouts: the left path keeps outer + 2 holes, the right bank outer + 1 hole.
	var left_contours: Array[PackedVector2Array] = document.regions[0].get_walkable_contours()
	assert_int(left_contours.size()).is_equal(3)
	var right_contours: Array[PackedVector2Array] = document.regions[1].get_walkable_contours()
	assert_int(right_contours.size()).is_equal(2)

	# Overlapping zones stay separate regions; both keep their walkable contours.
	assert_int(document.regions[2].get_walkable_contours().size()).is_equal(1)

	# Save, reopen from disk, and compare everything that matters.
	var target := WORK_FOLDER.path_join("full_workflow.tres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_FOLDER))
	assert_int(ResourceSaver.save(document, target)).is_equal(OK)
	var loaded: Resource = ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_object(loaded).is_not_null()
	assert_int(loaded.schema_version).is_equal(1)
	assert_int(loaded.regions.size()).is_equal(3)
	assert_int(loaded.regions[0].subtraction_polygons.size()).is_equal(2)
	assert_str(loaded.regions[0].subtraction_names[1]).is_equal("Buisson")
	assert_str(loaded.regions[1].subtraction_names[0]).is_equal("Eau")
	assert_str(loaded.regions[0].group_id).is_equal(loaded.groups[0].id)
	assert_int(loaded.scale_anchors.size()).is_equal(3)
	assert_float(loaded.scale_anchors[0].apparent_height_px).is_equal(260.0)
	assert_float(loaded.scale_anchors[2].apparent_height_px).is_equal(80.0)
	assert_int(loaded.regions[0].get_walkable_contours().size()).is_equal(3)


func test_full_workflow_exports_2d_3d_and_perspective_scenes() -> void:
	var document := _build_document()
	var texture := _load_texture()
	assert_object(texture).is_not_null()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_FOLDER))

	var scene_2d := SCENE_GENERATOR.build_2d_scene(document, texture, 1.0, true)
	assert_object(scene_2d).is_not_null()
	var scene_3d := SCENE_GENERATOR.build_3d_scene(document, texture, 0.01, true)
	assert_object(scene_3d).is_not_null()
	var scene_persp := SCENE_GENERATOR.build_perspective_scene(document, texture, document.perspective_calibration, 0.01, true)
	assert_object(scene_persp).is_not_null()

	# 3D and perspective exports must contain the scale templates. The 2D export has no
	# templates by design (its scale is already pixels), so it is not checked here.
	assert_int(_count_names_containing(scene_3d, "Proche") + _count_names_containing(scene_3d, "Lointain")).is_greater_equal(2)
	assert_int(_count_names_containing(scene_persp, "Proche") + _count_names_containing(scene_persp, "Lointain")).is_greater_equal(2)

	# Camera option: the 3D export must include a camera.
	assert_int(_count_class(scene_3d, "Camera3D")).is_greater_equal(1)
	assert_int(_count_class(scene_persp, "Camera3D")).is_greater_equal(1)

	# Pack and reload each scene to be sure it saves cleanly as a Godot scene.
	for pair in [["2d", scene_2d], ["3d", scene_3d], ["persp", scene_persp]]:
		var packed := PackedScene.new()
		assert_int(packed.pack(pair[1])).is_equal(OK)
		var path := WORK_FOLDER.path_join("export_%s.tscn" % pair[0])
		assert_int(ResourceSaver.save(packed, path)).is_equal(OK)
		var reloaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_object(reloaded).is_not_null()
		var instance := reloaded.instantiate()
		assert_int(instance.get_child_count()).is_greater(0)
		instance.free()
		pair[1].free()


func _count_names_containing(node: Node, fragment: String) -> int:
	var count := 1 if node.name.contains(fragment) else 0
	for child in node.get_children():
		count += _count_names_containing(child, fragment)
	return count


func _count_class(node: Node, class_name_text: String) -> int:
	var count := 1 if node.is_class(class_name_text) else 0
	for child in node.get_children():
		count += _count_class(child, class_name_text)
	return count

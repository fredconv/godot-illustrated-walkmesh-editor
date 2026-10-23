extends SceneTree

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")


func _initialize() -> void:
	var illustration_path := "res://assets/img/background.png"
	var texture := load(illustration_path) as Texture2D
	if texture == null:
		push_error("Perspective demo illustration is missing: %s" % illustration_path)
		quit(1)
		return

	var document: Resource = DOCUMENT_SCRIPT.new()
	document.resource_name = "IWE Perspective Calibration Demo"
	document.set_illustration(illustration_path, texture.get_size())
	var image_size: Vector2 = Vector2(document.image_size)
	var group: Resource = GROUP_SCRIPT.create_group("Walkable ground")
	document.add_group(group)

	var left_path: Resource = _make_region(
		"Left path",
		group.id,
		PackedVector2Array([
			Vector2(image_size.x * 0.00, image_size.y * 0.47),
			Vector2(image_size.x * 0.27, image_size.y * 0.43),
			Vector2(image_size.x * 0.40, image_size.y * 0.59),
			Vector2(image_size.x * 0.48, image_size.y * 0.76),
			Vector2(image_size.x * 0.36, image_size.y * 0.83),
			Vector2(image_size.x * 0.13, image_size.y * 0.66),
			Vector2(image_size.x * 0.00, image_size.y * 0.63),
		])
	)
	left_path.subtraction_polygons.append(PackedVector2Array([
		Vector2(image_size.x * 0.17, image_size.y * 0.57),
		Vector2(image_size.x * 0.23, image_size.y * 0.55),
		Vector2(image_size.x * 0.26, image_size.y * 0.62),
		Vector2(image_size.x * 0.20, image_size.y * 0.65),
	]))
	left_path.subtraction_names.append("Rock cutout")
	document.add_region(left_path)

	var right_path: Resource = _make_region(
		"Right path",
		group.id,
		PackedVector2Array([
			Vector2(image_size.x * 0.44, image_size.y * 0.48),
			Vector2(image_size.x * 0.77, image_size.y * 0.46),
			Vector2(image_size.x, image_size.y * 0.53),
			Vector2(image_size.x, image_size.y * 0.70),
			Vector2(image_size.x * 0.69, image_size.y * 0.65),
			Vector2(image_size.x * 0.50, image_size.y * 0.58),
		])
	)
	right_path.subtraction_polygons.append(PackedVector2Array([
		Vector2(image_size.x * 0.75, image_size.y * 0.52),
		Vector2(image_size.x * 0.82, image_size.y * 0.53),
		Vector2(image_size.x * 0.80, image_size.y * 0.59),
		Vector2(image_size.x * 0.74, image_size.y * 0.57),
	]))
	right_path.subtraction_names.append("Water cutout")
	document.add_region(right_path)

	var near_anchor: IWEScaleAnchor = ANCHOR_SCRIPT.create_anchor(Vector2(image_size.x * 0.28, image_size.y * 0.72), 105.0)
	near_anchor.name = "Near reference"
	document.scale_anchors.append(near_anchor)
	var far_anchor: IWEScaleAnchor = ANCHOR_SCRIPT.create_anchor(Vector2(image_size.x * 0.63, image_size.y * 0.48), 48.0)
	far_anchor.name = "Far reference"
	document.scale_anchors.append(far_anchor)

	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(document.image_size)
	calibration.character_height_units = 180.0
	calibration.floor_height = 0.0
	var stage: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01)
	if stage == null:
		push_error("Unable to build the perspective demo stage.")
		quit(1)
		return
	var packed := PackedScene.new()
	var pack_error := packed.pack(stage)
	stage.free()
	if pack_error != OK:
		push_error("Unable to pack perspective demo stage: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, "res://examples/perspective_calibration_demo.tscn")
	if save_error != OK:
		push_error("Unable to save perspective demo stage: %s" % error_string(save_error))
		quit(1)
		return
	print("Generated res://examples/perspective_calibration_demo.tscn")
	quit(0)


func _make_region(region_name: String, group_id: String, polygon: PackedVector2Array) -> Resource:
	var region: Resource = REGION_SCRIPT.new()
	region.id = "demo_%s" % region_name.to_snake_case()
	region.name = region_name
	region.group_id = group_id
	region.points = polygon
	return region

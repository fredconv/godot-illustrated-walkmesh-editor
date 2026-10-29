extends GdUnitTestSuite

## Audit P1-3: geometry that the perspective export cannot project (at or above the horizon of the
## calibrated camera) is reported by name instead of being dropped silently.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const SCALE_ANCHOR_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scale_anchor.gd")
const CALIBRATION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_calibration.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")
const IMAGE_SIZE := Vector2i(1000, 700)
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _zone(zone_name: String, points: PackedVector2Array) -> Resource:
	var region: Resource = REGION_SCRIPT.new()
	region.id = zone_name.to_lower()
	region.name = zone_name
	region.points = points
	return region


func _export(regions: Array, extra_anchor: Resource = null) -> Node3D:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://assets/img/background.png", IMAGE_SIZE)
	for region in regions:
		document.add_region(region)
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(250, 570), 200.0))
	document.scale_anchors.append(SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(750, 400), 100.0))
	if extra_anchor != null:
		document.scale_anchors.append(extra_anchor)
	var texture := ImageTexture.create_from_image(Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8))
	var calibration: IWEPerspectiveCalibration = CALIBRATION_SCRIPT.for_image(IMAGE_SIZE, VIEWPORT_SIZE)
	calibration.fit_to_scale_anchors(document.scale_anchors.slice(0, 2), IMAGE_SIZE)
	return SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, 0.01, false)


func test_a_zone_above_the_horizon_is_reported_by_name_and_left_out() -> void:
	var root := _export([_zone("Ground", _rect(100, 380, 400, 200)), _zone("Sky patch", _rect(100, 10, 200, 40))])
	var warnings := SCENE_GENERATOR.take_warnings(root)
	assert_int(warnings.size()).is_equal(1)
	assert_str(warnings[0]).contains("Sky patch").contains("horizon")
	assert_object(root.find_child("Sky patch", true, false)).is_null()
	assert_object(root.find_child("Ground", true, false)).is_not_null()
	root.free()


func test_every_dropped_zone_gets_its_own_warning() -> void:
	var root := _export([_zone("Ground", _rect(100, 380, 400, 200)), _zone("Cloud A", _rect(100, 10, 100, 30)), _zone("Cloud B", _rect(300, 10, 100, 30))])
	var warnings := SCENE_GENERATOR.take_warnings(root)
	assert_int(warnings.size()).is_equal(2)
	assert_str(warnings[0]).contains("Cloud A")
	assert_str(warnings[1]).contains("Cloud B")
	root.free()


func test_a_zone_that_only_reaches_up_to_the_horizon_is_dropped_whole() -> void:
	# A zone that crosses the horizon cannot be projected in part; it is reported, not clipped.
	var root := _export([_zone("Tall", _rect(100, 10, 200, 500))])
	var warnings := SCENE_GENERATOR.take_warnings(root)
	assert_int(warnings.size()).is_equal(1)
	assert_str(warnings[0]).contains("Tall")
	root.free()


func test_a_template_above_the_horizon_is_reported() -> void:
	var anchor: Resource = SCALE_ANCHOR_SCRIPT.create_anchor(Vector2(500, 20), 30.0)
	anchor.name = "Bird"
	var root := _export([_zone("Ground", _rect(100, 380, 400, 200))], anchor)
	var warnings := SCENE_GENERATOR.take_warnings(root)
	assert_int(warnings.size()).is_equal(1)
	assert_str(warnings[0]).contains("Bird")
	root.free()


func test_a_clean_export_has_no_warnings_and_warnings_are_not_saved_with_the_scene() -> void:
	var clean := _export([_zone("Ground", _rect(100, 380, 400, 200))])
	assert_int(SCENE_GENERATOR.take_warnings(clean).size()).is_equal(0)
	clean.free()
	var root := _export([_zone("Ground", _rect(100, 380, 400, 200)), _zone("Sky patch", _rect(100, 10, 200, 40))])
	assert_bool(root.has_meta(SCENE_GENERATOR.WARNINGS_META)).is_true()
	SCENE_GENERATOR.take_warnings(root)
	assert_bool(root.has_meta(SCENE_GENERATOR.WARNINGS_META)).override_failure_message("taking the warnings removes them from the scene").is_false()
	assert_int(SCENE_GENERATOR.take_warnings(root).size()).override_failure_message("a second call finds nothing").is_equal(0)
	root.free()


func test_take_warnings_accepts_a_missing_scene() -> void:
	assert_int(SCENE_GENERATOR.take_warnings(null).size()).is_equal(0)


func _two_rooms_with_a_door(door_height: float) -> Array:
	# A corridor touches the middle of a room's right wall: the doorway is door_height wide.
	var room := _zone("Room", _rect(100, 380, 300, 250))
	var corridor := _zone("Corridor", _rect(400, 500, 350, door_height))
	return [room, corridor]


func test_a_doorway_narrower_than_the_character_is_reported() -> void:
	var root := _export(_two_rooms_with_a_door(3.0))
	var warnings := SCENE_GENERATOR.take_warnings(root)
	assert_int(warnings.size()).is_equal(1)
	assert_str(warnings[0]).contains("Room").contains("narrower than the character")
	root.free()


func test_a_doorway_the_character_fits_through_is_not_reported() -> void:
	var root := _export(_two_rooms_with_a_door(60.0))
	assert_int(SCENE_GENERATOR.take_warnings(root).size()).is_equal(0)
	root.free()


func test_a_fully_shared_edge_is_not_judged_as_a_doorway() -> void:
	var left := _zone("Left", _rect(100, 380, 300, 250))
	var right := _zone("Right", _rect(400, 380, 300, 250))
	var root := _export([left, right])
	assert_int(SCENE_GENERATOR.take_warnings(root).size()).is_equal(0)
	root.free()

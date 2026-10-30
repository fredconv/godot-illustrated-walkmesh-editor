extends RefCounted
## Shared data and helpers of the "village + fountain" end-to-end scenario.
##
## Everything is authored from an empty document through the same signals the canvas emits when
## a person draws, so no saved sample and no cached state is involved. The image coordinates
## follow the art of background_template.png (1672x941); the fountain of foreground_template.png
## sits in the middle of the crossroads.

const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const SCENE_GENERATOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_scene_generator.gd")

const BACKGROUND := "res://assets/img/background_template.png"
const FOREGROUND := "res://assets/img/foreground_template.png"
const SCENE := "res://tests/e2e/e2e_village_fountain.tscn"
const OUTPUT_FOLDER := "res://tests/e2e/_output"
const IMAGE_SIZE := Vector2i(1672, 941)
const WORLD_SCALE := 0.01

## Left yard and crossroads share the full edge x = 500.
const YARD := [Vector2(60, 300), Vector2(500, 300), Vector2(500, 900), Vector2(60, 900)]
## The crossroads has a short tab on its right side. The tab's far edge (x = 1260) is shared in full
## with the bridge, which is what makes a doorway: a partly shared edge stays a wall.
const CROSSROADS := [Vector2(500, 300), Vector2(1200, 300), Vector2(1200, 540), Vector2(1260, 540), Vector2(1260, 640), Vector2(1200, 640), Vector2(1200, 900), Vector2(500, 900)]
const BRIDGE := [Vector2(1260, 540), Vector2(1520, 540), Vector2(1520, 640), Vector2(1260, 640)]
## A plain crossroads and a bridge that touches only part of its right edge (not a doorway).
const PLAIN_CROSSROADS := [Vector2(500, 300), Vector2(1200, 300), Vector2(1200, 900), Vector2(500, 900)]
const PARTIAL_BRIDGE := [Vector2(1200, 540), Vector2(1520, 540), Vector2(1520, 640), Vector2(1200, 640)]
## Straddles the yard and the crossroads without sharing an edge with either.
const OVERLAP_PATCH := [Vector2(400, 700), Vector2(700, 700), Vector2(700, 860), Vector2(400, 860)]
## Second cutout, overlapping the right side of the fountain footprint.
const BENCH_CUTOUT := [Vector2(1000, 480), Vector2(1130, 480), Vector2(1130, 660), Vector2(1000, 660)]
const FOUNTAIN_CENTER := Vector2(815, 515)
const FOUNTAIN_RADIUS := Vector2(290, 150)

const NEAR_TEMPLATE := [Vector2(300, 880), 230.0]
const FAR_TEMPLATE := [Vector2(1000, 330), 105.0]


static func points(source: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in source:
		result.append(point)
	return result


static func fountain_footprint(scale := 1.0, count := 16) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in count:
		var angle := TAU * float(index) / float(count)
		result.append(FOUNTAIN_CENTER + Vector2(cos(angle) * FOUNTAIN_RADIUS.x, sin(angle) * FOUNTAIN_RADIUS.y) * scale)
	return result


## A dock on an empty, never-saved document, in the scene tree and ready.
static func new_dock(tree: SceneTree) -> Control:
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new())
	tree.root.add_child(dock)
	await tree.process_frame
	return dock


static func import_background(dock: Control) -> void:
	dock._load_illustration(ProjectSettings.globalize_path(BACKGROUND))


## Draws the three connected zones, the overlapping patch, and the two cutouts, like a person would.
static func author_regions(dock: Control) -> void:
	dock._create_group_named("Chemins")
	dock._canvas.region_created.emit(points(YARD))
	dock._canvas.region_created.emit(points(CROSSROADS))
	dock._canvas.region_created.emit(points(BRIDGE))
	dock._canvas.region_created.emit(points(OVERLAP_PATCH))
	var crossroads: Resource = dock._document.regions[1]
	dock._canvas.subtraction_created.emit(crossroads.id, fountain_footprint())
	dock._canvas.subtraction_created.emit(crossroads.id, points(BENCH_CUTOUT))


static func author_templates(dock: Control) -> void:
	dock._canvas.scale_anchor_created.emit(NEAR_TEMPLATE[0], NEAR_TEMPLATE[1])
	dock._canvas.scale_anchor_created.emit(FAR_TEMPLATE[0], FAR_TEMPLATE[1])


## World position (metres at WORLD_SCALE) of an image pixel on the calibrated floor.
static func floor_world(image_point: Vector2, calibration: IWEPerspectiveCalibration) -> Vector3:
	var floor_point: Variant = PROJECTOR.image_point_to_floor(image_point, IMAGE_SIZE, calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	return Vector3(floor_point.x, calibration.floor_height, floor_point.z) * WORLD_SCALE


## Image pixel under a world position, or Vector2.INF if it is not on screen.
static func world_to_image(world_position: Vector3, calibration: IWEPerspectiveCalibration) -> Vector2:
	var floor_point := world_position / WORLD_SCALE
	var screen: Variant = PROJECTOR.world_to_viewport(Vector3(floor_point.x, calibration.floor_height, floor_point.z), calibration.reference_viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees)
	if screen == null:
		return Vector2.INF
	var image: Variant = PROJECTOR.viewport_to_image(screen, IMAGE_SIZE, calibration.reference_viewport_size)
	return image if image != null else Vector2.INF


## The perspective stage with its test character, in the tree, with navigation settled.
static func start_stage(tree: SceneTree, document: Resource, element_textures: Dictionary = {}) -> Array:
	var calibration: IWEPerspectiveCalibration = document.perspective_calibration
	var texture := load(BACKGROUND) as Texture2D
	var root: Node3D = SCENE_GENERATOR.build_perspective_scene(document, texture, calibration, WORLD_SCALE, true, element_textures)
	var player := root.get_node("Player") as CharacterBody3D
	tree.root.add_child(root)
	# A fixed number of frames is not enough on a busy machine: the navigation map can take longer
	# to settle, and a path asked for before that is empty. Wait for the character's own signal.
	var frames := 0
	while (frames < 12 or not player._navigation_settled) and frames < 600:
		await tree.physics_frame
		frames += 1
	return [root, player]


static func remove_folder(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in DirAccess.get_directories_at(path):
		remove_folder(path.path_join(directory_name))
	DirAccess.remove_absolute(path)

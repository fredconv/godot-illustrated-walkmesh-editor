## Builds the occlusion prototype scene.
##
## Four columns, one per transparency mode Godot offers for StandardMaterial3D:
## Alpha Scissor, Alpha Blend, Alpha Hash, and Alpha Depth Pre-Pass.
## In each column a transparent barrier stands between a character placed in front of it
## (camera side) and a character placed behind it. Compare what is hidden in each column.
##
## Run headless to regenerate the scene:
##   godot --headless --path . -s prototypes/occlusion/build_occlusion_prototype.gd
extends SceneTree

const OUTPUT_SCENE := "res://prototypes/occlusion/occlusion_prototype.tscn"
const MODES := [
	{"name": "Alpha Scissor", "mode": BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR},
	{"name": "Alpha Blend", "mode": BaseMaterial3D.TRANSPARENCY_ALPHA},
	{"name": "Alpha Hash", "mode": BaseMaterial3D.TRANSPARENCY_ALPHA_HASH},
	{"name": "Depth Pre-Pass", "mode": BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS},
]
const COLUMN_SPACING := 4.0


func _initialize() -> void:
	var stage := Node3D.new()
	stage.name = "OcclusionPrototype"

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 3.2, 8.5)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	stage.add_child(camera)
	camera.owner = stage

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -30, 0)
	stage.add_child(sun)
	sun.owner = stage

	var ground := _make_ground()
	stage.add_child(ground)
	ground.owner = stage
	var barrier_texture := _make_barrier_texture()
	for index in MODES.size():
		var column_x := (index - (MODES.size() - 1) * 0.5) * COLUMN_SPACING
		_add_column(stage, MODES[index], column_x, barrier_texture)

	var packed := PackedScene.new()
	var pack_error := packed.pack(stage)
	if pack_error != OK:
		push_error("Could not pack occlusion prototype (%s)" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_SCENE)
	if save_error != OK:
		push_error("Could not save occlusion prototype (%s)" % error_string(save_error))
		quit(1)
		return
	print("Generated ", OUTPUT_SCENE)
	quit(0)


func _add_column(stage: Node3D, config: Dictionary, column_x: float, texture: Texture2D) -> void:
	var label := Label3D.new()
	label.name = "Label_%s" % config.name.replace(" ", "")
	label.text = config.name
	label.font_size = 48
	label.pixel_size = 0.01
	label.position = Vector3(column_x, 3.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage.add_child(label)
	label.owner = stage

	# Barrier: a transparent PNG-like texture on a vertical quad.
	var barrier := MeshInstance3D.new()
	barrier.name = "Barrier_%s" % config.name.replace(" ", "")
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 2.4)
	barrier.mesh = quad
	barrier.position = Vector3(column_x, 1.2, 0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = config.mode
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	barrier.material_override = material
	stage.add_child(barrier)
	barrier.owner = stage

	# In front of the barrier (camera side): always visible.
	_add_character(stage, "Front", Vector3(column_x + 1.4, 0.9, 2.2), Color("3b82f6"))
	# Behind the barrier: should be hidden wherever the barrier is opaque.
	_add_character(stage, "Behind", Vector3(column_x, 0.9, -2.0), Color("ef4444"))


func _add_character(stage: Node3D, role: String, position: Vector3, color: Color) -> void:
	var body := MeshInstance3D.new()
	body.name = "Character_%s_%d" % [role, stage.get_child_count()]
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body.mesh = capsule
	body.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	body.material_override = material
	stage.add_child(body)
	body.owner = stage


func _make_ground() -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6aa84f")
	ground.material_override = material
	return ground


## A fence-like texture: opaque wooden slats over a fully transparent background, with a
## semi-transparent haze band so the modes can also be compared on partial transparency.
func _make_barrier_texture() -> ImageTexture:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var in_slat_row := y > 60 and y < 120 or y > 150 and y < 210
			var in_post := x % 64 < 20
			if in_slat_row or in_post:
				image.set_pixel(x, y, Color("8b5a2b"))
			elif y <= 60:
				# Upper band: a soft haze, partially transparent (for alpha blend/hash checks).
				image.set_pixel(x, y, Color(0.9, 0.95, 1.0, 0.35))
	return ImageTexture.create_from_image(image)

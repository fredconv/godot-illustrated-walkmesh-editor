@tool
extends RefCounted

const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const PERSPECTIVE_PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")


static func build_2d_scene(document: Resource, texture: Texture2D, world_scale: float = 1.0, add_camera: bool = false) -> Node2D:
	if document == null or texture == null or document.image_size.x <= 0 or document.image_size.y <= 0 or world_scale <= 0.0:
		return null
	var root := Node2D.new()
	root.name = _safe_node_name(document.resource_name if not document.resource_name.is_empty() else "IWEStage2D")
	var template := Node2D.new()
	template.name = "Template"
	template.scale = Vector2.ONE * world_scale
	root.add_child(template)
	template.owner = root
	var illustration := Sprite2D.new()
	illustration.name = "Illustration"
	illustration.centered = false
	illustration.texture = texture
	template.add_child(illustration)
	illustration.owner = root
	var navigation := Node2D.new()
	navigation.name = "WalkableRegions"
	template.add_child(navigation)
	navigation.owner = root
	for region in document.regions:
		if not region.visible or region.points.size() < 3:
			continue
		var nav_region := NavigationRegion2D.new()
		nav_region.name = "Region_%s" % _safe_node_name(region.name)
		nav_region.navigation_polygon = _make_navigation_polygon(region)
		navigation.add_child(nav_region)
		nav_region.owner = root
	if add_camera:
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		camera.position = Vector2(document.image_size) * 0.5
		camera.enabled = true
		template.add_child(camera)
		camera.owner = root
	return root


static func build_3d_scene(document: Resource, texture: Texture2D, world_scale: float = 0.01, add_camera: bool = true) -> Node3D:
	if document == null or texture == null or document.image_size.x <= 0 or document.image_size.y <= 0 or world_scale <= 0.0:
		return null
	var root := Node3D.new()
	root.name = _safe_node_name(document.resource_name if not document.resource_name.is_empty() else "IWEStage3D")
	var template := Node3D.new()
	template.name = "Template"
	template.scale = Vector3.ONE * world_scale
	root.add_child(template)
	template.owner = root
	var illustration := Sprite3D.new()
	illustration.name = "IllustrationPlane"
	illustration.texture = texture
	illustration.centered = true
	illustration.pixel_size = 1.0
	illustration.rotation.x = -PI * 0.5
	# Keep the illustration behind the walkable overlay in the top camera view.
	illustration.position = Vector3(document.image_size.x * 0.5, -0.25, document.image_size.y * 0.5)
	template.add_child(illustration)
	illustration.owner = root
	var navigation := Node3D.new()
	navigation.name = "WalkableRegions"
	template.add_child(navigation)
	navigation.owner = root
	var group_nodes: Dictionary = {}
	for group in document.groups:
		var group_node := Node3D.new()
		group_node.name = _safe_node_name(group.name)
		navigation.add_child(group_node)
		group_node.owner = root
		group_nodes[group.id] = group_node
	for region in document.regions:
		if not region.visible or region.points.size() < 3:
			continue
		var nav_region := NavigationRegion3D.new()
		nav_region.name = _safe_node_name(region.name)
		nav_region.navigation_mesh = _make_navigation_mesh(region)
		var parent: Node3D = group_nodes.get(region.group_id, navigation)
		parent.add_child(nav_region)
		nav_region.owner = root
		_add_walkable_surface(nav_region, nav_region.navigation_mesh)
		_add_authored_contour_guides(nav_region, region)
	var scale_templates := Node3D.new()
	scale_templates.name = "ScaleTemplates"
	template.add_child(scale_templates)
	scale_templates.owner = root
	for anchor_index in document.scale_anchors.size():
		var anchor: IWEScaleAnchor = document.scale_anchors[anchor_index]
		var anchor_node := Node3D.new()
		anchor_node.name = _safe_node_name(anchor.name if not anchor.name.strip_edges().is_empty() else "Template %d" % (anchor_index + 1))
		anchor_node.position = Vector3(anchor.position.x, 0.0, anchor.position.y)
		anchor_node.set_meta("iwe_anchor_id", anchor.id)
		anchor_node.set_meta("iwe_apparent_height_px", anchor.apparent_height_px)
		scale_templates.add_child(anchor_node)
		anchor_node.owner = root
		var capsule := CapsuleMesh.new()
		var height_px: float = maxf(anchor.apparent_height_px, 2.0)
		capsule.radius = height_px * 0.16
		capsule.height = height_px
		var mannequin := MeshInstance3D.new()
		mannequin.name = "3D height template"
		mannequin.mesh = capsule
		mannequin.position.y = height_px * 0.5
		var mannequin_material := StandardMaterial3D.new()
		mannequin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mannequin_material.albedo_color = Color("ffbd4a")
		mannequin.material_override = mannequin_material
		anchor_node.add_child(mannequin)
		mannequin.owner = root
	if add_camera:
		var camera := Camera3D.new()
		camera.name = "Camera3D"
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		# Lock the image width so a narrow editor-camera preview still shows the
		# complete illustration instead of cropping its sides.
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		# Camera3D.size is expressed in world units; Template scales pixels into those units.
		camera.size = float(document.image_size.x) * world_scale
		camera.position = Vector3(document.image_size.x * 0.5, maxf(document.image_size.x, document.image_size.y), document.image_size.y * 0.5)
		# Image-space X grows right and Y grows down; from above, screen up must point toward -Z.
		camera.look_at_from_position(camera.position, Vector3(document.image_size.x * 0.5, 0.0, document.image_size.y * 0.5), Vector3.FORWARD)
		camera.current = true
		template.add_child(camera)
		camera.owner = root
	return root


static func build_perspective_scene(document: Resource, texture: Texture2D, calibration: IWEPerspectiveCalibration, world_scale: float = 0.01) -> Node3D:
	if document == null or texture == null or calibration == null or document.image_size.x <= 0 or document.image_size.y <= 0 or world_scale <= 0.0:
		return null
	var viewport_size := calibration.reference_viewport_size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return null
	var root := Node3D.new()
	root.name = _safe_node_name(document.resource_name if not document.resource_name.is_empty() else "IWEPerspectiveStage")
	root.set_meta("iwe_projection_source", "image-space")
	var template := Node3D.new()
	template.name = "PerspectiveStage"
	template.scale = Vector3.ONE * world_scale
	root.add_child(template)
	template.owner = root
	var camera_rig := Node3D.new()
	camera_rig.name = "CameraRig"
	template.add_child(camera_rig)
	camera_rig.owner = root
	var game_camera := Camera3D.new()
	game_camera.name = "PerspectiveCamera"
	game_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	game_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	game_camera.fov = calibration.field_of_view_degrees
	game_camera.position = calibration.camera_position
	game_camera.rotation_degrees = calibration.camera_rotation_degrees
	game_camera.current = true
	camera_rig.add_child(game_camera)
	game_camera.owner = root
	var top_camera := Camera3D.new()
	top_camera.name = "TopCamera"
	top_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	top_camera.keep_aspect = Camera3D.KEEP_WIDTH
	top_camera.size = float(document.image_size.x) * world_scale
	top_camera.position = Vector3(float(document.image_size.x) * 0.5, maxf(calibration.camera_position.y, float(document.image_size.y)) + 10.0, float(document.image_size.y) * 0.5)
	top_camera.look_at_from_position(top_camera.position, Vector3(float(document.image_size.x) * 0.5, calibration.floor_height, float(document.image_size.y) * 0.5), Vector3.FORWARD)
	camera_rig.add_child(top_camera)
	top_camera.owner = root
	var image_plane := MeshInstance3D.new()
	image_plane.name = "PerspectiveProjectedIllustration"
	image_plane.mesh = _make_projected_image_mesh(document.image_size, viewport_size, calibration)
	var image_material := StandardMaterial3D.new()
	image_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	image_material.albedo_texture = texture
	image_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	image_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	image_plane.material_override = image_material
	image_plane.position.y = calibration.floor_height
	template.add_child(image_plane)
	image_plane.owner = root
	var navigation := Node3D.new()
	navigation.name = "ProjectedWalkableRegions"
	template.add_child(navigation)
	navigation.owner = root
	var group_nodes: Dictionary = {}
	for group in document.groups:
		var group_node := Node3D.new()
		group_node.name = _safe_node_name(group.name)
		navigation.add_child(group_node)
		group_node.owner = root
		group_nodes[group.id] = group_node
	for region in document.regions:
		if not region.visible or region.points.size() < 3:
			continue
		var projected_region := _make_projected_navigation_region(region, document.image_size, viewport_size, calibration)
		if projected_region == null:
			continue
		var parent: Node3D = group_nodes.get(region.group_id, navigation)
		parent.add_child(projected_region)
		projected_region.owner = root
		for child in projected_region.get_children():
			child.owner = root
	for anchor_index in document.scale_anchors.size():
		var anchor: IWEScaleAnchor = document.scale_anchors[anchor_index]
		var ground_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(anchor.position, document.image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		if ground_point == null:
			continue
		var anchor_node := Node3D.new()
		anchor_node.name = _safe_node_name(anchor.name if not anchor.name.strip_edges().is_empty() else "Calibration %d" % (anchor_index + 1))
		anchor_node.position = Vector3(ground_point.x, calibration.floor_height, ground_point.z)
		anchor_node.set_meta("iwe_anchor_id", anchor.id)
		anchor_node.set_meta("iwe_image_position", anchor.position)
		anchor_node.set_meta("iwe_reference_apparent_height_px", anchor.apparent_height_px)
		template.add_child(anchor_node)
		anchor_node.owner = root
		var capsule := CapsuleMesh.new()
		var character_height := maxf(calibration.character_height_units, 2.0)
		capsule.radius = character_height * 0.16
		capsule.height = character_height
		var mannequin := MeshInstance3D.new()
		mannequin.name = "Known-height character template"
		mannequin.mesh = capsule
		mannequin.position.y = character_height * 0.5
		var mannequin_material := StandardMaterial3D.new()
		mannequin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mannequin_material.albedo_color = Color("ffbd4a")
		mannequin.material_override = mannequin_material
		anchor_node.add_child(mannequin)
		mannequin.owner = root
	return root


static func _make_projected_image_mesh(image_size: Vector2i, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration) -> ArrayMesh:
	const SUBDIVISIONS := 48
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var projected := PackedVector3Array()
	var valid := PackedByteArray()
	for y in range(SUBDIVISIONS + 1):
		for x in range(SUBDIVISIONS + 1):
			var image_point := Vector2(float(x) * image_size.x / SUBDIVISIONS, float(y) * image_size.y / SUBDIVISIONS)
			var world_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(image_point, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
			valid.append(1 if world_point != null else 0)
			projected.append(Vector3(world_point.x, 0.0, world_point.z) if world_point != null else Vector3.ZERO)
			uvs.append(Vector2(float(x) / SUBDIVISIONS, float(y) / SUBDIVISIONS))
	var indices := PackedInt32Array()
	var row_width := SUBDIVISIONS + 1
	for y in SUBDIVISIONS:
		for x in SUBDIVISIONS:
			var a := y * row_width + x
			var b := a + 1
			var c := a + row_width
			var d := c + 1
			if valid[a] == 1 and valid[b] == 1 and valid[c] == 1 and valid[d] == 1:
				indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	if indices.is_empty():
		return ArrayMesh.new()
	vertices = projected
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _make_projected_navigation_region(region: Resource, image_size: Vector2i, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration) -> NavigationRegion3D:
	var source_mesh := _make_navigation_mesh(region)
	var source_vertices := source_mesh.get_vertices()
	var projected_vertices := PackedVector3Array()
	for point in source_vertices:
		var world_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(Vector2(point.x, point.z), image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		if world_point == null:
			return null
		projected_vertices.append(Vector3(world_point.x, 0.0, world_point.z))
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.0
	navigation_mesh.set_vertices(projected_vertices)
	for polygon_index in source_mesh.get_polygon_count():
		navigation_mesh.add_polygon(source_mesh.get_polygon(polygon_index))
	var nav_region := NavigationRegion3D.new()
	nav_region.name = _safe_node_name(region.name)
	nav_region.position.y = calibration.floor_height
	nav_region.navigation_mesh = navigation_mesh
	_add_walkable_surface(nav_region, navigation_mesh)
	_add_projected_contour_guides(nav_region, region, image_size, viewport_size, calibration)
	return nav_region


static func _add_projected_contour_guides(nav_region: NavigationRegion3D, region: Resource, image_size: Vector2i, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration) -> void:
	var outer := _make_projected_contour_guide("Walkable outline", region.points, Color("45d483"), image_size, viewport_size, calibration)
	nav_region.add_child(outer)
	outer.owner = nav_region.owner
	for index in region.subtraction_polygons.size():
		var name := "Cutout %d" % (index + 1)
		if index < region.subtraction_names.size() and not region.subtraction_names[index].strip_edges().is_empty():
			name = region.subtraction_names[index]
		var cutout := _make_projected_contour_guide(name, region.subtraction_polygons[index], Color("ff5263"), image_size, viewport_size, calibration)
		nav_region.add_child(cutout)
		cutout.owner = nav_region.owner


static func _make_projected_contour_guide(guide_name: String, points: PackedVector2Array, color: Color, image_size: Vector2i, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration) -> MeshInstance3D:
	var guide := MeshInstance3D.new()
	guide.name = _safe_node_name(guide_name)
	if points.size() < 2:
		return guide
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	mesh.surface_set_color(color)
	for point in points:
		var projected: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(point, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		if projected == null:
			mesh.surface_end()
			return guide
		mesh.surface_add_vertex(Vector3(projected.x, 0.2, projected.z))
	var first: Vector2 = points[0]
	var first_projected: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(first, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	if first_projected != null:
		mesh.surface_add_vertex(Vector3(first_projected.x, 0.2, first_projected.z))
	mesh.surface_end()
	guide.mesh = mesh
	return guide


static func _make_navigation_polygon(region: Resource) -> NavigationPolygon:
	var navigation_polygon := NavigationPolygon.new()
	# Exported walkable boundaries must match the authored polygons. Runtime agent
	# clearance belongs to NavigationAgent, not this geometry conversion.
	navigation_polygon.agent_radius = 0.0
	for contour in region.get_walkable_contours():
		var points: PackedVector2Array = contour.duplicate()
		var is_hole := Geometry2D.is_polygon_clockwise(points) != Geometry2D.is_polygon_clockwise(region.points)
		# Godot navigation outlines use clockwise outer contours and counter-clockwise holes.
		if Geometry2D.is_polygon_clockwise(points) == is_hole:
			points.reverse()
		navigation_polygon.add_outline(points)
	NavigationServer2D.bake_from_source_geometry_data(navigation_polygon, NavigationMeshSourceGeometryData2D.new())
	return navigation_polygon


static func _make_navigation_mesh(region: Resource) -> NavigationMesh:
	# Use Godot's 2D-to-flat-3D conversion to preserve the baked contours and holes.
	var navigation_mesh := _make_navigation_polygon(region).get_navigation_mesh()
	# get_navigation_mesh() creates a NavigationMesh with its own default radius;
	# it does not inherit NavigationPolygon.agent_radius. Zero it explicitly to
	# prevent the 3D bake from eroding contours a second time.
	navigation_mesh.agent_radius = 0.0
	return navigation_mesh


static func _add_authored_contour_guides(nav_region: NavigationRegion3D, region: Resource) -> void:
	# Navigation meshes are convex-partitioned by Godot for pathfinding. Keep the
	# exact authored outer contour and named cutout loops visible in the scene tree
	# so the generated partition is not mistaken for the original drawing.
	var outer := _make_contour_guide("Walkable outline", region.points, Color("45d483"))
	nav_region.add_child(outer)
	outer.owner = nav_region.owner
	for index in region.subtraction_polygons.size():
		var cutout_name := "Cutout %d" % (index + 1)
		if index < region.subtraction_names.size() and not region.subtraction_names[index].strip_edges().is_empty():
			cutout_name = region.subtraction_names[index]
		var guide := _make_contour_guide(cutout_name, region.subtraction_polygons[index], Color("ff5263"))
		nav_region.add_child(guide)
		guide.owner = nav_region.owner


static func _add_walkable_surface(nav_region: NavigationRegion3D, navigation_mesh: NavigationMesh) -> void:
	var vertices := navigation_mesh.get_vertices()
	if vertices.is_empty() or navigation_mesh.get_polygon_count() == 0:
		return
	var mesh_vertices := PackedVector3Array()
	var mesh_indices := PackedInt32Array()
	for polygon_index in navigation_mesh.get_polygon_count():
		var polygon := navigation_mesh.get_polygon(polygon_index)
		if polygon.size() < 3:
			continue
		var first_index := mesh_vertices.size()
		for vertex_index in polygon:
			var vertex := vertices[vertex_index]
			mesh_vertices.append(Vector3(vertex.x, 0.1, vertex.z))
		for index in range(1, polygon.size() - 1):
			mesh_indices.append(first_index)
			mesh_indices.append(first_index + index)
			mesh_indices.append(first_index + index + 1)
	if mesh_indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_vertices
	arrays[Mesh.ARRAY_INDEX] = mesh_indices
	var surface_mesh := ArrayMesh.new()
	surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("45d483", 0.28)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	var surface := MeshInstance3D.new()
	surface.name = "Walkable surface"
	surface.mesh = surface_mesh
	surface.material_override = material
	nav_region.add_child(surface)
	surface.owner = nav_region.owner


static func _make_contour_guide(guide_name: String, points: PackedVector2Array, color: Color) -> MeshInstance3D:
	var guide := MeshInstance3D.new()
	guide.name = _safe_node_name(guide_name)
	if points.size() < 2:
		return guide
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	line_mesh.surface_set_color(color)
	for point in points:
		line_mesh.surface_add_vertex(Vector3(point.x, 0.25, point.y))
	line_mesh.surface_add_vertex(Vector3(points[0].x, 0.25, points[0].y))
	line_mesh.surface_end()
	guide.mesh = line_mesh
	return guide


static func _safe_node_name(value: String) -> String:
	var safe_name := value.strip_edges().replace("/", "_").replace("\\", "_").replace(":", "_")
	return safe_name if not safe_name.is_empty() else "IWEStage"

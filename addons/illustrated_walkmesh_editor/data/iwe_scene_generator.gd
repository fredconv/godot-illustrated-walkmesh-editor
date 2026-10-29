@tool
extends RefCounted

const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const PERSPECTIVE_PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
const CHARACTER_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/runtime/iwe_walkmesh_character.gd")

## Render layers used by perspective stages. The game camera shows the illustration as a
## screen-aligned backdrop (exact pixels, including sky above the horizon); the top camera
## shows the floor-warped copy instead.
const LAYER_FLOOR_ILLUSTRATION := 1 << 1
const LAYER_CAMERA_BACKDROP := 1 << 2
const PERSPECTIVE_CAMERA_FAR := 2000.0
## Metadata key a perspective export uses to hand its warnings to the caller. See take_warnings.
const WARNINGS_META := "iwe_export_warnings"


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
		nav_region.navigation_polygon = _make_navigation_polygon(region, document.regions)
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
		nav_region.navigation_mesh = _make_navigation_mesh(region, document.regions)
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


## Warnings recorded while a scene was built (geometry that could not be exported), one sentence
## each. The list is removed from the scene so that it is not saved with it. Empty when nothing
## was dropped.
static func take_warnings(root: Node) -> PackedStringArray:
	if root == null or not root.has_meta(WARNINGS_META):
		return PackedStringArray()
	var warnings: PackedStringArray = root.get_meta(WARNINGS_META)
	root.remove_meta(WARNINGS_META)
	return warnings


static func build_perspective_scene(document: Resource, texture: Texture2D, calibration: IWEPerspectiveCalibration, world_scale: float = 0.01, add_player: bool = false) -> Node3D:
	if document == null or texture == null or calibration == null or document.image_size.x <= 0 or document.image_size.y <= 0 or world_scale <= 0.0:
		return null
	var viewport_size := calibration.reference_viewport_size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return null
	var warnings := PackedStringArray()
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
	# Camera clip distances are measured in world units (Godot orthonormalizes camera transforms).
	game_camera.near = 0.05
	game_camera.far = PERSPECTIVE_CAMERA_FAR
	game_camera.cull_mask = 0xFFFFF & ~LAYER_FLOOR_ILLUSTRATION
	game_camera.current = true
	camera_rig.add_child(game_camera)
	game_camera.owner = root
	var backdrop := _make_camera_backdrop(document.image_size, viewport_size, calibration, texture)
	game_camera.add_child(backdrop)
	backdrop.owner = root
	var top_camera := Camera3D.new()
	top_camera.name = "TopCamera"
	top_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	top_camera.keep_aspect = Camera3D.KEEP_WIDTH
	var floor_bounds := _projected_floor_bounds(document, viewport_size, calibration)
	var floor_center := floor_bounds.get_center()
	var reference_aspect := float(viewport_size.x) / float(viewport_size.y)
	top_camera.size = maxf(floor_bounds.size.x, floor_bounds.size.y * reference_aspect) * 1.1 * world_scale
	var top_height := maxf(calibration.camera_position.y, calibration.floor_height) + maxf(floor_bounds.size.x, floor_bounds.size.y)
	top_camera.position = Vector3(floor_center.x, top_height, floor_center.y)
	top_camera.look_at_from_position(top_camera.position, Vector3(floor_center.x, calibration.floor_height, floor_center.y), Vector3.FORWARD)
	top_camera.far = maxf((top_height - calibration.floor_height) * world_scale * 2.0, 100.0)
	top_camera.cull_mask = 0xFFFFF & ~LAYER_CAMERA_BACKDROP
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
	image_plane.layers = LAYER_FLOOR_ILLUSTRATION
	image_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		var projected_region := _make_projected_navigation_region(region, document.image_size, viewport_size, calibration, document.regions)
		if projected_region == null:
			warnings.append("Zone \"%s\" was not exported: part of it lies at or above the horizon of the calibrated camera, where the floor cannot be projected. Move it below the horizon or recalibrate the camera." % region.name)
			continue
		var parent: Node3D = group_nodes.get(region.group_id, navigation)
		parent.add_child(projected_region)
		projected_region.owner = root
		_assign_owner_recursive(projected_region, root)
	for anchor_index in document.scale_anchors.size():
		var anchor: IWEScaleAnchor = document.scale_anchors[anchor_index]
		var ground_point: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(anchor.position, document.image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		if ground_point == null:
			warnings.append("Template \"%s\" was not exported: it lies at or above the horizon of the calibrated camera." % anchor.name)
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
	if not warnings.is_empty():
		root.set_meta(WARNINGS_META, warnings)
	if add_player:
		var player := _make_player(document, calibration, viewport_size, world_scale)
		if player:
			root.add_child(player)
			player.owner = root
			for child in player.get_children():
				child.owner = root
	return root


## Builds the playable character. It lives directly under the stage root (unscaled) so
## physics shapes are not inside the pixel-to-world scaled PerspectiveStage node.
static func _make_player(document: Resource, calibration: IWEPerspectiveCalibration, viewport_size: Vector2i, world_scale: float) -> CharacterBody3D:
	var start: Variant = _player_start_point(document, calibration, viewport_size)
	if start == null:
		return null
	var height := maxf(calibration.character_height_units, 2.0) * world_scale
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(CHARACTER_SCRIPT)
	player.position = Vector3(start.x, calibration.floor_height, start.z) * world_scale
	player.set("move_speed", height * 1.5)
	# Walls sit on the boundary, so the character's centre stops one radius inside them. The
	# navigation snap tolerance must exceed that radius or the character gets pulled to the edge.
	player.set("snap_tolerance", height * 0.16 * 3.0)
	var shape := CapsuleShape3D.new()
	shape.radius = height * 0.16
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	collision.position.y = height * 0.5
	player.add_child(collision)
	var capsule := CapsuleMesh.new()
	capsule.radius = height * 0.16
	capsule.height = height
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("4aa3ff")
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = capsule
	visual.material_override = material
	visual.position.y = height * 0.5
	player.add_child(visual)
	return player


## Start on the first scale anchor that lies on a walkable region, otherwise at the centre
## of the largest navigation polygon of the first visible region.
static func _player_start_point(document: Resource, calibration: IWEPerspectiveCalibration, viewport_size: Vector2i) -> Variant:
	var visible_regions: Array = document.regions.filter(func(region: Resource) -> bool: return region.visible and region.points.size() >= 3)
	for anchor in document.scale_anchors:
		for region in visible_regions:
			if _region_contains(region, anchor.position):
				return PERSPECTIVE_PROJECTOR.image_point_to_floor(anchor.position, document.image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
	for region in visible_regions:
		var mesh := _make_navigation_mesh(region)
		var vertices := mesh.get_vertices()
		var best := Vector2.ZERO
		var best_area := -1.0
		for polygon_index in mesh.get_polygon_count():
			var polygon := mesh.get_polygon(polygon_index)
			var points := PackedVector2Array()
			for vertex_index in polygon:
				points.append(Vector2(vertices[vertex_index].x, vertices[vertex_index].z))
			var area := absf(_polygon_area(points))
			if area > best_area:
				best_area = area
				best = _polygon_centroid(points)
		if best_area > 0.0:
			var projected: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(best, document.image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
			if projected != null:
				return projected
	return null


static func _region_contains(region: Resource, image_point: Vector2) -> bool:
	var inside := false
	for contour in region.get_walkable_contours():
		if Geometry2D.is_point_in_polygon(image_point, contour):
			inside = not inside
	return inside


static func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in points.size():
		area += points[index].cross(points[(index + 1) % points.size()])
	return area * 0.5


static func _polygon_centroid(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / maxf(points.size(), 1)


## A quad parented to the perspective camera that shows the illustration exactly as the
## reference viewport frames it. It sits far away so every 3D object draws in front of it.
static func _make_camera_backdrop(image_size: Vector2i, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration, texture: Texture2D) -> MeshInstance3D:
	# Camera children are placed in world units, so this distance must stay inside the camera's far plane.
	var distance := PERSPECTIVE_CAMERA_FAR * 0.9
	var fit_scale: float = PERSPECTIVE_PROJECTOR.image_scale_in_viewport(image_size, viewport_size)
	var units_per_viewport_pixel := 2.0 * distance * tan(deg_to_rad(clampf(calibration.field_of_view_degrees, 1.0, 179.0)) * 0.5) / float(viewport_size.y)
	var quad := QuadMesh.new()
	quad.size = Vector2(image_size) * fit_scale * units_per_viewport_pixel
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var backdrop := MeshInstance3D.new()
	backdrop.name = "IllustrationBackdrop"
	backdrop.mesh = quad
	backdrop.material_override = material
	backdrop.position = Vector3(0.0, 0.0, -distance)
	backdrop.layers = LAYER_CAMERA_BACKDROP
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return backdrop


## Floor-space (x, z) bounds of everything authored: walkable regions and anchors. Falls
## back to the projected lower half of the image when nothing is authored yet.
static func _projected_floor_bounds(document: Resource, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration) -> Rect2:
	var image_points := PackedVector2Array()
	for region in document.regions:
		if region.visible:
			image_points.append_array(region.points)
	for anchor in document.scale_anchors:
		image_points.append(anchor.position)
	if image_points.is_empty():
		var size := Vector2(document.image_size)
		image_points = PackedVector2Array([Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), size, Vector2(0, size.y)])
	var bounds := Rect2()
	var has_point := false
	for point in image_points:
		var projected: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(point, document.image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		if projected == null:
			continue
		var floor_point := Vector2(projected.x, projected.z)
		if has_point:
			bounds = bounds.expand(floor_point)
		else:
			bounds = Rect2(floor_point, Vector2.ZERO)
			has_point = true
	if not has_point:
		return Rect2(Vector2(calibration.camera_position.x, calibration.camera_position.z) - Vector2.ONE * 500.0, Vector2.ONE * 1000.0)
	return bounds.grow(maxf(bounds.size.x, bounds.size.y) * 0.05 + 1.0)


## Packed scenes only keep nodes whose owner is the packed root, at any depth.
static func _assign_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_assign_owner_recursive(child, owner)


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


static func _make_projected_navigation_region(region: Resource, image_size: Vector2i, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration, all_regions: Array = []) -> NavigationRegion3D:
	var source_mesh := _make_navigation_mesh(region, all_regions)
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
	_add_projected_collision(nav_region, region, navigation_mesh, image_size, viewport_size, calibration, all_regions)
	return nav_region


## Physics for a walkable region: a floor shaped like the walkable triangles, and invisible
## walls along every boundary edge (outer contour and each cutout). Walls rise to the
## character height so a character cannot step over them.
static func _add_projected_collision(nav_region: NavigationRegion3D, region: Resource, navigation_mesh: NavigationMesh, image_size: Vector2i, viewport_size: Vector2i, calibration: IWEPerspectiveCalibration, all_regions: Array = []) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	nav_region.add_child(body)
	body.owner = nav_region.owner
	var floor_shape := ConcavePolygonShape3D.new()
	floor_shape.backface_collision = true
	floor_shape.set_faces(_triangulate_navigation_mesh(navigation_mesh))
	var floor_collision := CollisionShape3D.new()
	floor_collision.name = "Floor"
	floor_collision.shape = floor_shape
	body.add_child(floor_collision)
	floor_collision.owner = nav_region.owner
	var wall_height := maxf(calibration.character_height_units, 2.0)
	var wall_faces := PackedVector3Array()
	for contour in region.get_walkable_contours():
		var floor_points := PackedVector2Array()
		for point in contour:
			var projected: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(point, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
			if projected == null:
				return
			floor_points.append(Vector2(projected.x, projected.z))
		for index in floor_points.size():
			# A part of an edge shared with another walkable zone is a passage, not a wall. Only
			# the parts that no other zone covers get a wall, so a bridge that touches half of an
			# edge opens half of it.
			var edge_start: Vector2 = contour[index]
			var edge_end: Vector2 = contour[(index + 1) % contour.size()]
			for piece in _uncovered_edge_pieces(edge_start, edge_end, region, all_regions):
				var piece_start: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(edge_start.lerp(edge_end, piece.x), image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
				var piece_end: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(edge_start.lerp(edge_end, piece.y), image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
				if piece_start == null or piece_end == null:
					continue
				var a := Vector2(piece_start.x, piece_start.z)
				var b := Vector2(piece_end.x, piece_end.z)
				var a_base := Vector3(a.x, 0.0, a.y)
				var b_base := Vector3(b.x, 0.0, b.y)
				var a_top := Vector3(a.x, wall_height, a.y)
				var b_top := Vector3(b.x, wall_height, b.y)
				wall_faces.append_array(PackedVector3Array([a_base, b_base, b_top, a_base, b_top, a_top]))
	if wall_faces.is_empty():
		return
	var wall_shape := ConcavePolygonShape3D.new()
	wall_shape.backface_collision = true
	wall_shape.set_faces(wall_faces)
	var wall_collision := CollisionShape3D.new()
	wall_collision.name = "Walls"
	wall_collision.shape = wall_shape
	body.add_child(wall_collision)
	wall_collision.owner = nav_region.owner


## The parts of the edge a-b (image space) that no other walkable zone covers, as (start, end)
## pairs of parameters in 0..1. A part is covered when it lies on another zone's outline (shared
## border) or inside its walkable area (overlap). The edge is cut wherever another zone's outline
## or cutout crosses or ends on it, and each piece is judged by its middle.
static func _uncovered_edge_pieces(a: Vector2, b: Vector2, region: Resource, all_regions: Array) -> Array[Vector2]:
	var breaks: Array[float] = [0.0, 1.0]
	var length := a.distance_to(b)
	if length < 0.001:
		return []
	for other in all_regions:
		if other == region or other.points.size() < 3 or not other.visible:
			continue
		var outlines: Array = [other.points]
		outlines.append_array(other.subtraction_polygons)
		for outline in outlines:
			for index in outline.size():
				var c: Vector2 = outline[index]
				var d: Vector2 = outline[(index + 1) % outline.size()]
				var crossing: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
				if crossing != null:
					breaks.append(clampf((crossing - a).dot(b - a) / (length * length), 0.0, 1.0))
				for end_point in [c, d]:
					var closest := Geometry2D.get_closest_point_to_segment(end_point, a, b)
					if closest.distance_to(end_point) <= 0.5:
						breaks.append(clampf((closest - a).dot(b - a) / (length * length), 0.0, 1.0))
	breaks.sort()
	var pieces: Array[Vector2] = []
	var run_start := -1.0
	for index in range(breaks.size() - 1):
		var piece_start := breaks[index]
		var piece_end := breaks[index + 1]
		if piece_end - piece_start < 0.0005:
			continue
		var covered := _point_is_covered_by_other_zone(a.lerp(b, (piece_start + piece_end) * 0.5), region, all_regions)
		if not covered and run_start < 0.0:
			run_start = piece_start
		elif covered and run_start >= 0.0:
			pieces.append(Vector2(run_start, piece_start))
			run_start = -1.0
	if run_start >= 0.0:
		pieces.append(Vector2(run_start, 1.0))
	return pieces


static func _point_is_covered_by_other_zone(point: Vector2, region: Resource, all_regions: Array) -> bool:
	for other in all_regions:
		if other == region or other.points.size() < 3 or not other.visible:
			continue
		if _is_on_outline(point, other.points) or _is_walkable_in(point, other):
			return true
	return false


static func _is_on_outline(point: Vector2, polygon: PackedVector2Array) -> bool:
	for index in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		if closest.distance_to(point) <= 0.5:
			return true
	return false


static func _is_walkable_in(point: Vector2, zone: Resource) -> bool:
	if not Geometry2D.is_point_in_polygon(point, zone.points):
		return false
	for cutout in zone.subtraction_polygons:
		if cutout.size() >= 3 and Geometry2D.is_point_in_polygon(point, cutout):
			return false
	return true


static func _triangulate_navigation_mesh(navigation_mesh: NavigationMesh) -> PackedVector3Array:
	var vertices := navigation_mesh.get_vertices()
	var faces := PackedVector3Array()
	for polygon_index in navigation_mesh.get_polygon_count():
		var polygon := navigation_mesh.get_polygon(polygon_index)
		for index in range(1, polygon.size() - 1):
			faces.append(vertices[polygon[0]])
			faces.append(vertices[polygon[index]])
			faces.append(vertices[polygon[index + 1]])
	return faces


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
	var line_points := PackedVector3Array()
	for point in points:
		var projected: Variant = PERSPECTIVE_PROJECTOR.image_point_to_floor(point, image_size, viewport_size, calibration.camera_position, calibration.camera_rotation_degrees, calibration.field_of_view_degrees, calibration.floor_height)
		if projected == null:
			return guide
		line_points.append(Vector3(projected.x, 0.2, projected.z))
	line_points.append(line_points[0])
	_assign_line_mesh(guide, line_points, color)
	return guide


static func _make_navigation_polygon(region: Resource, all_regions: Array = []) -> NavigationPolygon:
	var navigation_polygon := NavigationPolygon.new()
	# Exported walkable boundaries must match the authored polygons. Runtime agent
	# clearance belongs to NavigationAgent, not this geometry conversion.
	navigation_polygon.agent_radius = 0.0
	var contours := _navigation_contours(region, all_regions)
	var reference_is_clockwise := false
	var largest_area := 0.0
	for contour in contours:
		var area := absf(_polygon_area(contour))
		if area > largest_area:
			largest_area = area
			reference_is_clockwise = Geometry2D.is_polygon_clockwise(contour)
	for contour in contours:
		var points: PackedVector2Array = contour.duplicate()
		var is_hole := Geometry2D.is_polygon_clockwise(points) != reference_is_clockwise
		# Godot navigation outlines use clockwise outer contours and counter-clockwise holes.
		if Geometry2D.is_polygon_clockwise(points) == is_hole:
			points.reverse()
		navigation_polygon.add_outline(points)
	if not contours.is_empty():
		NavigationServer2D.bake_from_source_geometry_data(navigation_polygon, NavigationMeshSourceGeometryData2D.new())
	return navigation_polygon


static func _make_navigation_mesh(region: Resource, all_regions: Array = []) -> NavigationMesh:
	# Use Godot's 2D-to-flat-3D conversion to preserve the baked contours and holes.
	var navigation_mesh := _make_navigation_polygon(region, all_regions).get_navigation_mesh()
	# get_navigation_mesh() creates a NavigationMesh with its own default radius;
	# it does not inherit NavigationPolygon.agent_radius. Zero it explicitly to
	# prevent the 3D bake from eroding contours a second time.
	navigation_mesh.agent_radius = 0.0
	return navigation_mesh


## The contours of the area this zone contributes to navigation. Zones that overlap are drawn in
## document order and the earlier zone keeps the shared area, so the navigation meshes never cover
## the same ground twice. The later zone's mesh then ends exactly on the earlier zone's outline,
## where Godot connects the two meshes along the shared border, as for touching zones. Without
## other zones this is the zone's own walkable contours.
static func _navigation_contours(region: Resource, all_regions: Array) -> Array[PackedVector2Array]:
	var own_contours: Array[PackedVector2Array] = region.get_walkable_contours()
	var earlier: Array = []
	for other in all_regions:
		if other == region:
			break
		if other.visible and other.points.size() >= 3:
			earlier.append(other)
	if earlier.is_empty() or own_contours.is_empty():
		return own_contours
	var covers: Array[PackedVector2Array] = []
	for other in earlier:
		covers.append_array(_convex_walkable_pieces(other))
	var pieces := _convex_walkable_pieces(region)
	for cover in covers:
		var cover_bounds := _bounds_of(cover)
		var remaining: Array[PackedVector2Array] = []
		for piece in pieces:
			if not _bounds_of(piece).intersects(cover_bounds):
				remaining.append(piece)
			else:
				remaining.append_array(_difference(piece, cover))
		pieces = remaining
	return _union_of_pieces(pieces)


## The walkable area of a zone as the polygons Godot bakes for it, without holes.
static func _convex_walkable_pieces(region: Resource) -> Array[PackedVector2Array]:
	var mesh := _make_navigation_mesh(region)
	var vertices := mesh.get_vertices()
	var pieces: Array[PackedVector2Array] = []
	for polygon_index in mesh.get_polygon_count():
		var piece := PackedVector2Array()
		for vertex_index in mesh.get_polygon(polygon_index):
			piece.append(Vector2(vertices[vertex_index].x, vertices[vertex_index].z))
		if piece.size() >= 3:
			pieces.append(piece)
	return pieces


## `piece` minus `cover`, as polygons without holes. When the cover sits strictly inside the piece
## the clip leaves a hole; the piece is then cut in two through the cover so that each half touches it.
static func _difference(piece: PackedVector2Array, cover: PackedVector2Array, depth: int = 0) -> Array[PackedVector2Array]:
	var results := Geometry2D.clip_polygons(piece, cover)
	var kept: Array[PackedVector2Array] = []
	var has_hole := false
	for result in results:
		if absf(_polygon_area(result)) <= 0.01:
			continue
		if not kept.is_empty() and Geometry2D.is_polygon_clockwise(result) != Geometry2D.is_polygon_clockwise(kept[0]):
			has_hole = true
		kept.append(result)
	if not has_hole or depth > 0:
		return kept
	var cut_x := _bounds_of(cover).get_center().x
	var piece_bounds := _bounds_of(piece).grow(1.0)
	var halves: Array[PackedVector2Array] = []
	for half_rect in [Rect2(piece_bounds.position, Vector2(cut_x - piece_bounds.position.x, piece_bounds.size.y)), Rect2(Vector2(cut_x, piece_bounds.position.y), Vector2(piece_bounds.end.x - cut_x, piece_bounds.size.y))]:
		var half_polygon := PackedVector2Array([half_rect.position, Vector2(half_rect.end.x, half_rect.position.y), half_rect.end, Vector2(half_rect.position.x, half_rect.end.y)])
		for half in Geometry2D.intersect_polygons(piece, half_polygon):
			halves.append_array(_difference(half, cover, depth + 1))
	return halves


## Joins pieces that touch into larger contours. Pieces that cannot be joined into one polygon
## (the union would have a hole or stay in two parts) are kept as they are.
static func _union_of_pieces(pieces: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var open: Array[PackedVector2Array] = pieces.duplicate()
	var done: Array[PackedVector2Array] = []
	while not open.is_empty():
		var current: PackedVector2Array = open.pop_back()
		var grew := true
		while grew:
			grew = false
			for index in open.size():
				if not _bounds_of(current).grow(0.01).intersects(_bounds_of(open[index])):
					continue
				var merged := Geometry2D.merge_polygons(current, open[index])
				if merged.size() == 1:
					current = merged[0]
					open.remove_at(index)
					grew = true
					break
		done.append(current)
	return done


static func _bounds_of(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


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
	var line_points := PackedVector3Array()
	for point in points:
		line_points.append(Vector3(point.x, 0.25, point.y))
	line_points.append(line_points[0])
	_assign_line_mesh(guide, line_points, color)
	return guide


## ArrayMesh line strip. Unlike ImmediateMesh, ArrayMesh surfaces are saved in .tscn files.
static func _assign_line_mesh(guide: MeshInstance3D, line_points: PackedVector3Array, color: Color) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = line_points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	guide.mesh = mesh
	guide.material_override = material


static func _safe_node_name(value: String) -> String:
	var safe_name := value.strip_edges().replace("/", "_").replace("\\", "_").replace(":", "_")
	return safe_name if not safe_name.is_empty() else "IWEStage"

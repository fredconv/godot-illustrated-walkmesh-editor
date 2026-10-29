@tool
extends RefCounted


static func image_to_viewport(image_point: Vector2, image_size: Vector2i, viewport_size: Vector2i) -> Vector2:
	if image_size.x <= 0 or image_size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
		return Vector2.ZERO
	var fit_scale := minf(float(viewport_size.x) / image_size.x, float(viewport_size.y) / image_size.y)
	var displayed_size := Vector2(image_size) * fit_scale
	var offset := (Vector2(viewport_size) - displayed_size) * 0.5
	return offset + image_point * fit_scale


static func viewport_to_image(viewport_point: Vector2, image_size: Vector2i, viewport_size: Vector2i) -> Variant:
	if image_size.x <= 0 or image_size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
		return null
	var fit_scale := minf(float(viewport_size.x) / image_size.x, float(viewport_size.y) / image_size.y)
	var displayed_size := Vector2(image_size) * fit_scale
	var offset := (Vector2(viewport_size) - displayed_size) * 0.5
	var image_point := (viewport_point - offset) / fit_scale
	if image_point.x < 0.0 or image_point.y < 0.0 or image_point.x > image_size.x or image_point.y > image_size.y:
		return null
	return image_point


static func image_point_to_floor(image_point: Vector2, image_size: Vector2i, viewport_size: Vector2i, camera_position: Vector3, camera_rotation_degrees: Vector3, fov_degrees: float, floor_y: float) -> Variant:
	if image_size.x <= 0 or image_size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
		return null
	var screen_point := image_to_viewport(image_point, image_size, viewport_size)
	var aspect := float(viewport_size.x) / float(viewport_size.y)
	var half_height := tan(deg_to_rad(clampf(fov_degrees, 1.0, 179.0)) * 0.5)
	var normalized_x := (screen_point.x / viewport_size.x) * 2.0 - 1.0
	var normalized_y := 1.0 - (screen_point.y / viewport_size.y) * 2.0
	var local_direction := Vector3(normalized_x * half_height * aspect, normalized_y * half_height, -1.0).normalized()
	var world_direction := Basis.from_euler(Vector3(deg_to_rad(camera_rotation_degrees.x), deg_to_rad(camera_rotation_degrees.y), deg_to_rad(camera_rotation_degrees.z))) * local_direction
	if absf(world_direction.y) <= 0.00001:
		return null
	var distance := (floor_y - camera_position.y) / world_direction.y
	if distance <= 0.0:
		return null
	return camera_position + world_direction * distance


## Inverse of the camera ray: returns the reference-viewport pixel where a world point appears, or null when it is behind the camera.
static func world_to_viewport(world_point: Vector3, viewport_size: Vector2i, camera_position: Vector3, camera_rotation_degrees: Vector3, fov_degrees: float) -> Variant:
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return null
	var basis := Basis.from_euler(Vector3(deg_to_rad(camera_rotation_degrees.x), deg_to_rad(camera_rotation_degrees.y), deg_to_rad(camera_rotation_degrees.z)))
	var local := basis.inverse() * (world_point - camera_position)
	if local.z >= -0.00001:
		return null
	var aspect := float(viewport_size.x) / float(viewport_size.y)
	var half_height := tan(deg_to_rad(clampf(fov_degrees, 1.0, 179.0)) * 0.5)
	var normalized_x := (local.x / -local.z) / (half_height * aspect)
	var normalized_y := (local.y / -local.z) / half_height
	return Vector2((normalized_x + 1.0) * 0.5 * viewport_size.x, (1.0 - normalized_y) * 0.5 * viewport_size.y)


static func image_scale_in_viewport(image_size: Vector2i, viewport_size: Vector2i) -> float:
	if image_size.x <= 0 or image_size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
		return 0.0
	return minf(float(viewport_size.x) / image_size.x, float(viewport_size.y) / image_size.y)


## --- Display transform (editor only) -------------------------------------------------------
## The projection above works in the *reference viewport*: the frame the calibration was made
## for. Only its aspect ratio matters, never its pixel size. The editor shows that frame inside
## a panel of any size; these two functions convert between panel pixels and reference pixels.
## They never touch the calibration, so resizing or detaching the panel cannot change it.

## Scale that fits the whole reference frame inside the panel, and the offset that centres it.
static func panel_fit(panel_size: Vector2, reference_size: Vector2i) -> Dictionary:
	if panel_size.x <= 0.0 or panel_size.y <= 0.0 or reference_size.x <= 0 or reference_size.y <= 0:
		return {"scale": 0.0, "offset": Vector2.ZERO}
	var fit_scale := minf(panel_size.x / reference_size.x, panel_size.y / reference_size.y)
	return {"scale": fit_scale, "offset": (panel_size - Vector2(reference_size) * fit_scale) * 0.5}


## Panel pixel -> reference-viewport pixel. The result may lie outside the reference frame when
## the point is in the letterbox bars. Returns Vector2.ZERO for an unusable panel or reference.
static func panel_to_reference(panel_point: Vector2, panel_size: Vector2, reference_size: Vector2i) -> Vector2:
	var fit := panel_fit(panel_size, reference_size)
	if fit.scale <= 0.0:
		return Vector2.ZERO
	return (panel_point - fit.offset) / fit.scale


## Reference-viewport pixel -> panel pixel.
static func reference_to_panel(reference_point: Vector2, panel_size: Vector2, reference_size: Vector2i) -> Vector2:
	var fit := panel_fit(panel_size, reference_size)
	return fit.offset + reference_point * fit.scale

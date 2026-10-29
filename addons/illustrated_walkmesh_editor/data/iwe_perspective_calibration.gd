@tool
class_name IWEPerspectiveCalibration
extends Resource

@export_range(1.0, 179.0, 0.1) var field_of_view_degrees := 45.0
@export var camera_position := Vector3(768.0, 1200.0, -614.4)
@export var camera_rotation_degrees := Vector3(-44.6, 0.0, 0.0)
@export var floor_height := 0.0
@export_range(1.0, 10000.0, 1.0) var character_height_units := 180.0
## The projection frame this calibration was made for. It is part of the calibration, like the
## camera: only its aspect ratio matters (the pixel size does not), and changing it changes how
## every image point lands on the floor. It is set when the document is created (from the
## project's game window) and edited on purpose, never by the size of an editor panel.
@export var reference_viewport_size := Vector2i(1280, 720)


static func for_image(image_size: Vector2i, viewport_size: Vector2i = Vector2i(1280, 720)) -> IWEPerspectiveCalibration:
	var calibration := IWEPerspectiveCalibration.new()
	calibration.reference_viewport_size = viewport_size
	if image_size.x <= 0 or image_size.y <= 0:
		return calibration
	var image_center_x := float(image_size.x) * 0.5
	var target_z := float(image_size.y) * 0.5
	var camera_y := float(maxi(image_size.x, image_size.y)) * 0.85
	var camera_z := float(image_size.y) * 1.55
	calibration.camera_position = Vector3(image_center_x, camera_y, camera_z)
	# The camera looks along local -Z, so it sits on the positive Z side of the illustration.
	calibration.camera_rotation_degrees = Vector3(-rad_to_deg(atan2(camera_y - calibration.floor_height, camera_z - target_z)), 0.0, 0.0)
	calibration.character_height_units = maxf(float(image_size.y) * 0.16, 1.0)
	return calibration


## Aspect ratio of the reference frame.
func get_reference_aspect() -> float:
	return float(reference_viewport_size.x) / maxf(float(reference_viewport_size.y), 1.0)


## True when two frames have the same aspect ratio within a relative tolerance.
static func aspects_match(first: Vector2i, second: Vector2i, tolerance := 0.01) -> bool:
	var first_aspect := float(first.x) / maxf(float(first.y), 1.0)
	var second_aspect := float(second.x) / maxf(float(second.y), 1.0)
	return absf(first_aspect - second_aspect) <= tolerance * second_aspect


## Game window size from Project Settings; exported cameras are calibrated for this aspect ratio.
static func project_viewport_size() -> Vector2i:
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	return Vector2i(maxi(width, 1), maxi(height, 1))


## Solves camera pitch and height so a character of character_height_units appears at the
## apparent pixel heights of the given scale anchors. On a flat floor, apparent height grows
## linearly with the distance of the feet below the horizon, so two or more anchors at
## different image rows define both the horizon and the camera height. Field of view,
## yaw, roll, and the camera's X/Z floor position are kept. Returns an error message, or
## an empty string on success.
func fit_to_scale_anchors(anchors: Array, image_size: Vector2i) -> String:
	const PROJECTOR := preload("res://addons/illustrated_walkmesh_editor/data/iwe_perspective_projector.gd")
	var viewport_size := reference_viewport_size
	var fit_scale: float = PROJECTOR.image_scale_in_viewport(image_size, viewport_size)
	if fit_scale <= 0.0:
		return "Import an illustration first."
	var rows := PackedFloat64Array()
	var columns := PackedFloat64Array()
	var heights := PackedFloat64Array()
	for anchor in anchors:
		if anchor == null or anchor.apparent_height_px <= 0.0:
			continue
		var screen_point: Vector2 = PROJECTOR.image_to_viewport(anchor.position, image_size, viewport_size)
		rows.append(screen_point.y)
		columns.append(screen_point.x)
		heights.append(anchor.apparent_height_px * fit_scale)
	if rows.size() < 2:
		return "Place at least two height references at different depths."
	# Least-squares line: height = slope * row + intercept.
	var count := float(rows.size())
	var mean_row := 0.0
	var mean_height := 0.0
	for index in rows.size():
		mean_row += rows[index] / count
		mean_height += heights[index] / count
	var covariance := 0.0
	var variance := 0.0
	for index in rows.size():
		covariance += (rows[index] - mean_row) * (heights[index] - mean_height)
		variance += (rows[index] - mean_row) * (rows[index] - mean_row)
	if variance < 1.0:
		return "Height references must be placed at different heights in the image."
	var slope := covariance / variance
	if slope <= 0.0:
		return "Nearer (lower) references must look taller than farther ones."
	var horizon_row := mean_row - mean_height / slope
	var half_height := float(viewport_size.y) * 0.5
	var focal := half_height / tan(deg_to_rad(clampf(field_of_view_degrees, 1.0, 179.0)) * 0.5)
	var pitch := atan((half_height - horizon_row) / focal)
	camera_rotation_degrees = Vector3(-rad_to_deg(pitch), camera_rotation_degrees.y, camera_rotation_degrees.z)
	var character := maxf(character_height_units, 0.001)
	var camera_height := character / slope
	# The linear model is exact for a level camera; refine for pitched cameras by
	# measuring the projected character directly.
	for _iteration in 12:
		camera_position.y = floor_height + camera_height
		var ratio_sum := 0.0
		var samples := 0
		for index in rows.size():
			var predicted := _apparent_height_at(Vector2(columns[index], rows[index]), viewport_size, PROJECTOR)
			if predicted <= 0.0:
				continue
			ratio_sum += predicted / heights[index]
			samples += 1
		if samples == 0:
			return "The references lie above the computed horizon."
		camera_height *= ratio_sum / samples
	camera_position.y = floor_height + camera_height
	return ""


## Apparent height, in reference-viewport pixels, of a character whose feet appear at the
## given reference-viewport point. Returns 0 when that point does not hit the floor.
func _apparent_height_at(screen_point: Vector2, viewport_size: Vector2i, projector: GDScript) -> float:
	# Using the viewport as its own "image" makes image_point_to_floor an identity mapping.
	var feet: Variant = projector.image_point_to_floor(screen_point, viewport_size, viewport_size, camera_position, camera_rotation_degrees, field_of_view_degrees, floor_height)
	if feet == null:
		return 0.0
	var head: Variant = projector.world_to_viewport(feet + Vector3.UP * character_height_units, viewport_size, camera_position, camera_rotation_degrees, field_of_view_degrees)
	if head == null:
		return 0.0
	return screen_point.y - head.y

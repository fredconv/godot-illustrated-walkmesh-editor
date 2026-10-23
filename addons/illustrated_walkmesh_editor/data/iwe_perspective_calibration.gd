@tool
class_name IWEPerspectiveCalibration
extends Resource

@export_range(1.0, 179.0, 0.1) var field_of_view_degrees := 45.0
@export var camera_position := Vector3(768.0, 1200.0, -614.4)
@export var camera_rotation_degrees := Vector3(-44.6, 0.0, 0.0)
@export var floor_height := 0.0
@export_range(1.0, 10000.0, 1.0) var character_height_units := 180.0
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

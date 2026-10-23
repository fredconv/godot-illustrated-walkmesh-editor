@tool
class_name IWEDocument
extends Resource

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var illustration_path := ""
@export var image_size := Vector2i.ZERO
@export var groups: Array[IWERegionGroup] = []
@export var regions: Array[IWERegion] = []
@export var scale_anchors: Array[IWEScaleAnchor] = []
@export_range(1.0, 10000.0, 1.0) var default_template_height_px := 160.0
@export var perspective_calibration: IWEPerspectiveCalibration = IWEPerspectiveCalibration.new()
@export var document_path := ""


func set_illustration(path: String, size: Vector2i) -> void:
	illustration_path = path
	image_size = size


func add_region(region: IWERegion) -> void:
	regions.append(region)


func add_group(group: IWERegionGroup) -> void:
	groups.append(group)


func remove_group(group_id: String) -> void:
	groups = groups.filter(func(group: IWERegionGroup) -> bool: return group.id != group_id)


func remove_region(region_id: String) -> void:
	regions = regions.filter(func(region: IWERegion) -> bool: return region.id != region_id)


func replace_region_points(region_id: String, points: PackedVector2Array) -> void:
	for region in regions:
		if region.id == region_id:
			region.points = points.duplicate()
			return

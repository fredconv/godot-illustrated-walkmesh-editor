@tool
class_name IWEDocument
extends Resource

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var illustration_path := ""
@export var image_size := Vector2i.ZERO
@export var regions: Array[IWERegion] = []
@export var document_path := ""


func set_illustration(path: String, size: Vector2i) -> void:
	illustration_path = path
	image_size = size


func add_region(region: IWERegion) -> void:
	regions.append(region)


func remove_region(region_id: String) -> void:
	regions = regions.filter(func(region: IWERegion) -> bool: return region.id != region_id)


func replace_region_points(region_id: String, points: PackedVector2Array) -> void:
	for region in regions:
		if region.id == region_id:
			region.points = points.duplicate()
			return

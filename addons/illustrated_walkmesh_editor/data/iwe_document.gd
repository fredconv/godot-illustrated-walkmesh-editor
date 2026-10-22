@tool
class_name IWEDocument
extends Resource

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var illustration_path := ""
@export var image_size := Vector2i.ZERO
@export var regions: Array[PackedVector2Array] = []


func set_illustration(path: String, size: Vector2i) -> void:
	illustration_path = path
	image_size = size

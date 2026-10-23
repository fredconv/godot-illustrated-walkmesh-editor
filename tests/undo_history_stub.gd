extends RefCounted

var target: Object
var region_id := ""
var before := PackedVector2Array()
var after := PackedVector2Array()


func record(target_object: Object, target_id: String, before_points: PackedVector2Array, after_points: PackedVector2Array) -> void:
	target = target_object
	region_id = target_id
	before = before_points
	after = after_points


func undo() -> void:
	target.set_region_points(region_id, before)


func redo() -> void:
	target.set_region_points(region_id, after)

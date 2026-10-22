@tool
class_name IWERegion
extends Resource

@export var id := ""
@export var group_id := ""
@export var name := "Region"
@export var points := PackedVector2Array()
## Each polygon removes walkable space from this region. The source polygons stay editable.
@export var subtraction_polygons: Array[PackedVector2Array] = []
@export var color := Color("45d483")
@export var visible := true
@export var locked := false


func duplicate_region() -> IWERegion:
	var copy := duplicate(true) as IWERegion
	copy.id = _new_id()
	copy.name = "%s Copy" % name
	return copy


func get_walkable_contours() -> Array[PackedVector2Array]:
	if points.size() < 3:
		return []
	var contours: Array[PackedVector2Array] = [points.duplicate()]
	var base_is_clockwise := Geometry2D.is_polygon_clockwise(points)
	for cutout in subtraction_polygons:
		if cutout.size() < 3:
			continue
		var next_contours: Array[PackedVector2Array] = []
		for contour in contours:
			if Geometry2D.is_polygon_clockwise(contour) != base_is_clockwise:
				next_contours.append(contour)
				continue
			for result in Geometry2D.clip_polygons(contour, cutout):
				next_contours.append(result)
		contours = next_contours
	return contours


static func _new_id() -> String:
	return "region_%s" % Crypto.new().generate_random_bytes(8).hex_encode()

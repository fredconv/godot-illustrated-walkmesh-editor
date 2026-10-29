@tool
class_name IWERegion
extends Resource

@export var id := ""
@export var group_id := ""
@export var name := "Region"
@export var points := PackedVector2Array()
## Each polygon removes walkable space from this region. The source polygons stay editable.
@export var subtraction_polygons: Array[PackedVector2Array] = []
## User-facing names aligned by index with subtraction_polygons.
@export var subtraction_names := PackedStringArray()
## Stable identifiers aligned by index with subtraction_polygons. Names and order may change;
## an identifier does not. Documents saved before they existed get them on load (ensure_cutout_ids).
@export var subtraction_ids := PackedStringArray()
@export var color := Color("45d483")
@export var visible := true
@export var locked := false


func duplicate_region() -> IWERegion:
	var copy := duplicate(true) as IWERegion
	copy.id = _new_id()
	copy.name = "%s Copy" % name
	# The copy's cutouts are new cutouts: they must not share identifiers with the original's.
	copy.subtraction_ids = PackedStringArray()
	copy.ensure_cutout_ids()
	return copy


## Gives every cutout an identifier and drops identifiers that have no cutout. Returns true when
## something changed.
func ensure_cutout_ids() -> bool:
	var changed := subtraction_ids.size() != subtraction_polygons.size()
	if subtraction_ids.size() > subtraction_polygons.size():
		subtraction_ids.resize(subtraction_polygons.size())
	while subtraction_ids.size() < subtraction_polygons.size():
		subtraction_ids.append(new_cutout_id())
	return changed


func get_cutout_id(index: int) -> String:
	return subtraction_ids[index] if index >= 0 and index < subtraction_ids.size() else ""


static func new_cutout_id() -> String:
	return "cutout_%s" % Crypto.new().generate_random_bytes(8).hex_encode()


func get_walkable_contours() -> Array[PackedVector2Array]:
	if points.size() < 3:
		return []
	var contours: Array[PackedVector2Array] = [points.duplicate()]
	var base_is_clockwise := Geometry2D.is_polygon_clockwise(points)
	# Subtracting overlapping cutouts one after another counts their intersection twice.
	# Subtract their union instead, built from disjoint pieces.
	for cutout in _merged_cutouts():
		var next_contours: Array[PackedVector2Array] = []
		for contour in contours:
			if Geometry2D.is_polygon_clockwise(contour) != base_is_clockwise:
				next_contours.append(contour)
				continue
			for result in Geometry2D.clip_polygons(contour, cutout):
				next_contours.append(result)
		contours = next_contours
	return _without_degenerate(contours)


## Union of the cutouts as pairwise-disjoint polygons. Cutouts that only touch along an edge
## are left as they are, because clipping by touching pieces is already exact. Source cutouts
## are not modified.
func _merged_cutouts() -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	for cutout in subtraction_polygons:
		if cutout.size() >= 3:
			pieces.append(cutout.duplicate())
	var guard := 0
	var merged_pair := true
	while merged_pair and guard < 10000:
		guard += 1
		merged_pair = false
		for first in pieces.size():
			for second in range(first + 1, pieces.size()):
				if Geometry2D.intersect_polygons(pieces[first], pieces[second]).is_empty():
					continue
				var union := Geometry2D.merge_polygons(pieces[first], pieces[second])
				pieces.remove_at(second)
				pieces.remove_at(first)
				pieces.append_array(union)
				merged_pair = true
				break
			if merged_pair:
				break
	return pieces


## Drops contours that cannot bound an area: fewer than three points or zero area.
func _without_degenerate(contours: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var kept: Array[PackedVector2Array] = []
	for contour in contours:
		if contour.size() < 3 or absf(_signed_area(contour)) <= 0.001:
			continue
		kept.append(contour)
	return kept


static func _signed_area(points_to_measure: PackedVector2Array) -> float:
	var total := 0.0
	for index in points_to_measure.size():
		total += points_to_measure[index].cross(points_to_measure[(index + 1) % points_to_measure.size()])
	return total * 0.5


static func _new_id() -> String:
	return "region_%s" % Crypto.new().generate_random_bytes(8).hex_encode()

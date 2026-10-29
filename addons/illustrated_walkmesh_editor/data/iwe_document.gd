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
## Version of the saved document format, independent from the plugin version. Every document
## starts at CURRENT_SCHEMA_VERSION (set in _init), so a save always writes it. The stored default
## is 0 because Godot leaves a property out of the file when it equals the default: a default of 1
## would hide the version of every version-1 file. A file without the field is a version-1 file
## saved before the field existed, and loads as 1.
@export var schema_version := 0

## The document format this plugin writes and understands.
const CURRENT_SCHEMA_VERSION := 1


func _init() -> void:
	schema_version = CURRENT_SCHEMA_VERSION


## Empty when the plugin can open a document of this version, otherwise the reason it cannot. A
## newer document is never opened silently: opening and saving it would drop what this plugin
## does not know.
static func schema_problem(document: Resource) -> String:
	var version: int = document.schema_version
	if version > CURRENT_SCHEMA_VERSION:
		return "This document was saved with format version %d, but this plugin only understands up to version %d. Update the plugin to open it. The file was not changed." % [version, CURRENT_SCHEMA_VERSION]
	if version < 1:
		return "This document has an invalid format version (%d). The file was not changed." % version
	return ""


## Problems in the references between the parts of the document, one sentence each: a region
## that names a group that does not exist, an identifier used twice, a cutout without a polygon.
## Nothing is repaired or removed; the document is reported as it is.
func validate_references() -> PackedStringArray:
	var problems := PackedStringArray()
	var group_ids := {}
	for group in groups:
		if group.id.is_empty():
			problems.append("A group has no identifier.")
		elif group_ids.has(group.id):
			problems.append("Group identifier \"%s\" is used by more than one group." % group.id)
		group_ids[group.id] = true
	var region_ids := {}
	var cutout_ids := {}
	for region in regions:
		if region.id.is_empty():
			problems.append("Region \"%s\" has no identifier." % region.name)
		elif region_ids.has(region.id):
			problems.append("Region identifier \"%s\" is used by more than one region." % region.id)
		region_ids[region.id] = true
		if not region.group_id.is_empty() and not group_ids.has(region.group_id):
			problems.append("Region \"%s\" belongs to a group that does not exist (%s)." % [region.name, region.group_id])
		if region.subtraction_names.size() > region.subtraction_polygons.size():
			problems.append("Region \"%s\" has more cutout names than cutouts." % region.name)
		for cutout_id in region.subtraction_ids:
			if cutout_id.is_empty():
				continue
			if cutout_ids.has(cutout_id):
				problems.append("Cutout identifier \"%s\" is used more than once." % cutout_id)
			cutout_ids[cutout_id] = true
	var anchor_ids := {}
	for anchor in scale_anchors:
		if anchor.id.is_empty():
			problems.append("Height reference \"%s\" has no identifier." % anchor.name)
		elif anchor_ids.has(anchor.id):
			problems.append("Height reference identifier \"%s\" is used more than once." % anchor.id)
		anchor_ids[anchor.id] = true
	return problems


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

@tool
class_name IWEDocument
extends Resource

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var illustration_path := ""
@export var image_size := Vector2i.ZERO
@export var groups: Array[IWERegionGroup] = []
@export var regions: Array[IWERegion] = []
## Version 2: visual layers and the transparent pictures placed on them. Empty in a version 1 file.
@export var layers: Array[IWELayer] = []
@export var visual_elements: Array[IWEVisualElement] = []
## Version 3: zones that do something when a character walks into them, and the places where a
## character appears when it arrives. Empty in a version 1 or 2 file.
@export var action_zones: Array[IWEActionZone] = []
@export var entry_points: Array[IWEEntryPoint] = []
@export var scale_anchors: Array[IWEScaleAnchor] = []
@export_range(1.0, 10000.0, 1.0) var default_template_height_px := 160.0
@export var perspective_calibration: IWEPerspectiveCalibration = IWEPerspectiveCalibration.new()
@export var document_path := ""
## Version of the saved document format, independent from the plugin version. A file without the
## field is a version-1 file saved before the field existed, so 1 is the stored default and a file
## that lacks the field loads as 1. Godot leaves a property out of the file when it equals its
## default, so a save of version 1 omits it and a save of version 2 writes it. prepare_for_save()
## stamps the current version.
@export var schema_version := 1

## The document format this plugin writes and understands.
## Version 2 added layers and visual elements, version 3 added action zones and entry points
## (docs/DATA_FORMAT.md).
const CURRENT_SCHEMA_VERSION := 3


## Brings an older document up to the current format, in memory only. The file on disk is not
## touched until the author saves. Repeatable: running it again changes nothing. Regions, groups,
## cutouts, templates, the calibration, layers and pictures are never modified or reordered. Version 3
## adds two lists that are empty in an older file, so it needs no data of its own.
func migrate_to_current() -> void:
	ensure_default_layers()
	if schema_version < CURRENT_SCHEMA_VERSION:
		schema_version = CURRENT_SCHEMA_VERSION


## Every document has a Background layer and a Foreground layer. Adds the ones that are missing
## (by their fixed identifiers) and gives elements without a layer to the foreground.
func ensure_default_layers() -> void:
	var has_background := false
	var has_foreground := false
	for layer in layers:
		has_background = has_background or layer.id == IWELayer.BACKGROUND_ID
		has_foreground = has_foreground or layer.id == IWELayer.FOREGROUND_ID
	if not has_background:
		layers.insert(0, IWELayer.create_default_background())
	if not has_foreground:
		layers.append(IWELayer.create_default_foreground())
	for element in visual_elements:
		if find_layer(element.layer_id) == null:
			element.layer_id = IWELayer.FOREGROUND_ID


## Call before writing the document to disk.
func prepare_for_save() -> void:
	migrate_to_current()
	schema_version = CURRENT_SCHEMA_VERSION


func find_layer(layer_id: String) -> IWELayer:
	for layer in layers:
		if layer.id == layer_id:
			return layer
	return null


func find_action_zone(zone_id: String) -> IWEActionZone:
	for zone in action_zones:
		if zone.id == zone_id:
			return zone
	return null


func find_entry_point(entry_point_id: String) -> IWEEntryPoint:
	for entry in entry_points:
		if entry.id == entry_point_id:
			return entry
	return null


## The entry point other scenes reach by this name, or null.
func find_entry_by_name(entry_name: String) -> IWEEntryPoint:
	for entry in entry_points:
		if entry.entry_id == entry_name:
			return entry
	return null


func find_element(element_id: String) -> IWEVisualElement:
	for element in visual_elements:
		if element.id == element_id:
			return element
	return null


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
	var layer_ids := {}
	for layer in layers:
		if layer.id.is_empty():
			problems.append("A layer has no identifier.")
		elif layer_ids.has(layer.id):
			problems.append("Layer identifier \"%s\" is used by more than one layer." % layer.id)
		layer_ids[layer.id] = true
	var element_ids := {}
	for element in visual_elements:
		if element.id.is_empty():
			problems.append("Element \"%s\" has no identifier." % element.name)
		elif element_ids.has(element.id):
			problems.append("Element identifier \"%s\" is used by more than one element." % element.id)
		element_ids[element.id] = true
		if not layer_ids.has(element.layer_id):
			problems.append("Element \"%s\" is on a layer that does not exist (%s)." % [element.name, element.layer_id])
		if element.texture_path.is_empty():
			problems.append("Element \"%s\" has no picture." % element.name)
	var anchor_ids := {}
	for anchor in scale_anchors:
		if anchor.id.is_empty():
			problems.append("Height reference \"%s\" has no identifier." % anchor.name)
		elif anchor_ids.has(anchor.id):
			problems.append("Height reference identifier \"%s\" is used more than once." % anchor.id)
		anchor_ids[anchor.id] = true
	var zone_ids := {}
	for zone in action_zones:
		if zone.id.is_empty():
			problems.append("Action zone \"%s\" has no identifier." % zone.name)
		elif zone_ids.has(zone.id):
			problems.append("Action zone identifier \"%s\" is used more than once." % zone.id)
		zone_ids[zone.id] = true
		if zone.points.size() < 3:
			problems.append("Action zone \"%s\" has fewer than three points." % zone.name)
		if not IWEActionZone.is_known_action(zone.action):
			problems.append("Action zone \"%s\" has an action this plugin does not know (%s); it is kept and exported as it is." % [zone.name, zone.action])
		if zone.needs_target_scene() and zone.target_scene.is_empty():
			problems.append("Action zone \"%s\" changes the scene but no scene is chosen." % zone.name)
		if zone.action == IWEActionZone.ACTION_WARP and (zone.entry_id.is_empty() or find_entry_by_name(zone.entry_id) == null):
			problems.append("Action zone \"%s\" warps to an entry point (%s) that this document does not have." % [zone.name, zone.entry_id])
	var entry_ids := {}
	var entry_names := {}
	var default_count := 0
	for entry in entry_points:
		if entry.id.is_empty():
			problems.append("An entry point has no identifier.")
		elif entry_ids.has(entry.id):
			problems.append("Entry point identifier \"%s\" is used more than once." % entry.id)
		entry_ids[entry.id] = true
		if entry.entry_id.strip_edges().is_empty():
			problems.append("An entry point has no name; transitions cannot reach it.")
		elif entry_names.has(entry.entry_id):
			problems.append("Entry point name \"%s\" is used by more than one entry point; a transition would reach the first." % entry.entry_id)
		entry_names[entry.entry_id] = true
		if entry.is_default:
			default_count += 1
	if default_count > 1:
		problems.append("More than one entry point is marked as the default; the first one is used.")
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

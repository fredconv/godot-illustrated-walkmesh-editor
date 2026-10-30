@tool
extends Tree


## Structure signature of the last full rebuild. A selection change alone does not rebuild
## the tree, so items that are currently inside a signal callback are never freed.
var _structure_signature := ""


func refresh(groups: Array[IWERegionGroup], regions: Array[IWERegion], selected_group_id: String, selected_region_id: String, selected_cutout_index: int = -1) -> void:
	var signature := _build_signature(groups, regions)
	if signature == _structure_signature and get_root() != null:
		_select_matching(selected_group_id, selected_region_id, selected_cutout_index)
		return
	_structure_signature = signature
	set_block_signals(true)
	clear()
	var root := create_item()
	var group_items: Dictionary = {}
	var selected_item: TreeItem
	for group in groups:
		var item := create_item(root)
		item.set_text(0, group.name)
		item.set_metadata(0, {"kind": "group", "id": group.id})
		item.set_selectable(0, true)
		item.set_collapsed(false)
		group_items[group.id] = item
		if group.id == selected_group_id:
			selected_item = item
	for region in regions:
		var parent: TreeItem = group_items.get(region.group_id)
		if parent == null:
			continue
		var item := create_item(parent)
		var item_label := region.name
		if not region.subtraction_polygons.is_empty():
			item_label += "  (%d cutouts)" % region.subtraction_polygons.size()
		if not region.visible:
			item_label += "  (hidden)"
		item.set_text(0, item_label)
		item.set_metadata(0, {"kind": "region", "id": region.id, "group_id": region.group_id})
		item.set_selectable(0, true)
		if region.id == selected_region_id:
			selected_item = item
		for cutout_index in region.subtraction_polygons.size():
			var cutout := create_item(item)
			var cutout_name := "Cutout %d" % (cutout_index + 1)
			if cutout_index < region.subtraction_names.size() and not region.subtraction_names[cutout_index].strip_edges().is_empty():
				cutout_name = region.subtraction_names[cutout_index]
			cutout.set_text(0, cutout_name)
			cutout.set_metadata(0, {"kind": "cutout", "region_id": region.id, "group_id": region.group_id, "index": cutout_index})
			cutout.set_selectable(0, true)
			if region.id == selected_region_id and cutout_index == selected_cutout_index:
				selected_item = cutout
	if selected_item:
		selected_item.select(0)
		if selected_item.get_parent() != root:
			selected_item.get_parent().set_collapsed(false)
	set_block_signals(false)


## Everything that changes the visible structure: group and region names and order, visibility,
## cutout count and names. Selection is deliberately not part of it.
func _build_signature(groups: Array[IWERegionGroup], regions: Array[IWERegion]) -> String:
	var parts := PackedStringArray()
	for group in groups:
		parts.append("g|%s|%s" % [group.id, group.name])
	for region in regions:
		parts.append("r|%s|%s|%s|%s|%d" % [region.id, region.group_id, region.name, region.visible, region.subtraction_polygons.size()])
		for cutout_index in region.subtraction_polygons.size():
			var cutout_name := region.subtraction_names[cutout_index] if cutout_index < region.subtraction_names.size() else ""
			parts.append("c|%d|%s" % [cutout_index, cutout_name])
	return "\n".join(parts)


## Moves the selection to the item that matches the requested group, region, or cutout,
## without rebuilding any item. Missing targets clear the selection.
func _select_matching(selected_group_id: String, selected_region_id: String, selected_cutout_index: int) -> void:
	var target: TreeItem = _find_item(selected_region_id, selected_cutout_index, selected_group_id)
	set_block_signals(true)
	deselect_all()
	if target:
		target.select(0)
		if target.get_parent() != get_root():
			target.get_parent().set_collapsed(false)
	set_block_signals(false)


func _find_item(region_id: String, cutout_index: int, group_id: String) -> TreeItem:
	var root := get_root()
	if root == null:
		return null
	var group_item: TreeItem = root.get_first_child()
	while group_item != null:
		var group_metadata: Dictionary = group_item.get_metadata(0) if group_item.get_metadata(0) is Dictionary else {}
		if region_id.is_empty() and group_metadata.get("id", "") == group_id:
			return group_item
		var region_item: TreeItem = group_item.get_first_child()
		while region_item != null:
			var region_metadata: Dictionary = region_item.get_metadata(0) if region_item.get_metadata(0) is Dictionary else {}
			if region_metadata.get("id", "") == region_id:
				if cutout_index < 0:
					return region_item
				var cutout_item: TreeItem = region_item.get_first_child()
				while cutout_item != null:
					var cutout_metadata: Dictionary = cutout_item.get_metadata(0) if cutout_item.get_metadata(0) is Dictionary else {}
					if cutout_metadata.get("index", -1) == cutout_index:
						return cutout_item
					cutout_item = cutout_item.get_next()
				return region_item
			region_item = region_item.get_next()
		group_item = group_item.get_next()
	return null


func get_selected_metadata() -> Dictionary:
	var item := get_selected()
	if item == null:
		return {}
	var metadata: Variant = item.get_metadata(0)
	return metadata if metadata is Dictionary else {}

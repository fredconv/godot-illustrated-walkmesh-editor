@tool
extends Tree


func refresh(groups: Array[IWERegionGroup], regions: Array[IWERegion], selected_group_id: String, selected_region_id: String, selected_cutout_index: int = -1) -> void:
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


func get_selected_metadata() -> Dictionary:
	var item := get_selected()
	if item == null:
		return {}
	var metadata: Variant = item.get_metadata(0)
	return metadata if metadata is Dictionary else {}

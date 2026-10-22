@tool
extends ItemList


func refresh(regions: Array[IWERegion], selected_id: String) -> void:
	clear()
	for index in regions.size():
		var region := regions[index]
		var item_label := region.name
		if not region.subtraction_polygons.is_empty():
			item_label += "  (%d cutouts)" % region.subtraction_polygons.size()
		add_item(item_label)
		set_item_metadata(index, region.id)
		if region.id == selected_id:
			select(index)


func get_region_id(index: int) -> String:
	return get_item_metadata(index)

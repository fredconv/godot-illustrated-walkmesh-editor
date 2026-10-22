@tool
extends ItemList


func refresh(regions: Array[IWERegion], selected_id: String) -> void:
	clear()
	for index in regions.size():
		var region := regions[index]
		add_item(region.name)
		set_item_metadata(index, region.id)
		if region.id == selected_id:
			select(index)


func get_region_id(index: int) -> String:
	return get_item_metadata(index)

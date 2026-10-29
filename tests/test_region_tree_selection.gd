extends GdUnitTestSuite

## Regression tests for the region tree. A selection used to rebuild the whole tree from
## inside its own item_selected callback, which freed the item that was being selected.

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const REGION_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region.gd")
const GROUP_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_region_group.gd")
const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


## Two regions: "Left" has two cutouts, "Right" has none.
func _make_dock_with_regions() -> Control:
	var document: Resource = DOCUMENT_SCRIPT.new()
	var group: Resource = GROUP_SCRIPT.create_group("Path")
	document.add_group(group)
	var left: Resource = REGION_SCRIPT.new()
	left.id = "left"
	left.name = "Left"
	left.group_id = group.id
	left.points = _rect(0, 0, 200, 200)
	left.subtraction_polygons.append(_rect(20, 20, 30, 30))
	left.subtraction_names.append("Rock")
	left.subtraction_polygons.append(_rect(120, 120, 30, 30))
	left.subtraction_names.append("Bush")
	document.add_region(left)
	var right: Resource = REGION_SCRIPT.new()
	right.id = "right"
	right.name = "Right"
	right.group_id = group.id
	right.points = _rect(300, 0, 200, 200)
	document.add_region(right)
	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(document)
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	return dock


func _settle() -> void:
	# Two frames: one for the deferred item_selected callback, one for anything it queued.
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame


func _find_item(dock: Control, kind: String, id: String, index: int = -1) -> TreeItem:
	var root: TreeItem = dock._region_list.get_root()
	var stack: Array[TreeItem] = [root]
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		var metadata: Variant = item.get_metadata(0)
		if metadata is Dictionary and metadata.get("kind", "") == kind:
			if kind == "cutout" and metadata.get("region_id", "") == id and metadata.get("index", -1) == index:
				return item
			if kind != "cutout" and metadata.get("id", "") == id:
				return item
		var child: TreeItem = item.get_first_child()
		while child != null:
			stack.append(child)
			child = child.get_next()
	return null


func _count_items(dock: Control) -> int:
	var count := 0
	var stack: Array[TreeItem] = [dock._region_list.get_root()]
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		if item != dock._region_list.get_root():
			count += 1
		var child: TreeItem = item.get_first_child()
		while child != null:
			stack.append(child)
			child = child.get_next()
	return count


func test_selecting_a_region_updates_the_dock_without_freeing_the_item() -> void:
	var dock := _make_dock_with_regions()
	await _settle()
	var item := _find_item(dock, "region", "right")
	assert_object(item).is_not_null()
	item.select(0)
	await _settle()
	assert_str(dock._canvas.get_selected_region().id).is_equal("right")
	assert_str(dock._region_list.get_selected_metadata().get("id", "")).is_equal("right")
	dock.queue_free()


func test_selecting_a_cutout_selects_that_cutout() -> void:
	var dock := _make_dock_with_regions()
	await _settle()
	var cutout := _find_item(dock, "cutout", "left", 1)
	assert_object(cutout).is_not_null()
	cutout.select(0)
	await _settle()
	var metadata: Dictionary = dock._region_list.get_selected_metadata()
	assert_str(metadata.get("kind", "")).is_equal("cutout")
	assert_int(metadata.get("index", -1)).is_equal(1)
	assert_int(dock._selected_cutout_index).is_equal(1)
	dock.queue_free()


func test_rapid_selection_changes_never_leave_a_dangling_item() -> void:
	var dock := _make_dock_with_regions()
	await _settle()
	var targets := [
		["cutout", "left", 0],
		["region", "right", -1],
		["cutout", "left", 1],
		["region", "left", -1],
		["cutout", "left", 0],
	]
	# Many quick selections without waiting between them, then a final settle.
	for step in 120:
		var target: Array = targets[step % targets.size()]
		var item := _find_item(dock, target[0], target[1], target[2])
		assert_object(item).is_not_null()
		item.select(0)
		await (Engine.get_main_loop() as SceneTree).process_frame
	await _settle()
	var last: Array = targets[(120 - 1) % targets.size()]
	var metadata: Dictionary = dock._region_list.get_selected_metadata()
	assert_str(metadata.get("kind", "")).is_equal(last[0])
	dock.queue_free()


func test_tree_is_rebuilt_when_regions_change() -> void:
	var dock := _make_dock_with_regions()
	await _settle()
	var count_before := _count_items(dock)
	var extra: Resource = REGION_SCRIPT.new()
	extra.id = "extra"
	extra.name = "Extra"
	extra.group_id = dock._document.groups[0].id
	extra.points = _rect(0, 300, 100, 100)
	dock._add_region(extra)
	dock._refresh_regions("extra")
	await _settle()
	assert_int(_count_items(dock)).is_equal(count_before + 1)
	assert_object(_find_item(dock, "region", "extra")).is_not_null()
	dock.queue_free()


func test_no_dangling_references_after_a_region_is_removed() -> void:
	var dock := _make_dock_with_regions()
	await _settle()
	_find_item(dock, "cutout", "left", 0).select(0)
	await _settle()
	dock._remove_region("left")
	dock._refresh_regions()
	await _settle()
	assert_object(_find_item(dock, "region", "left")).is_null()
	assert_object(_find_item(dock, "cutout", "left", 0)).is_null()
	var still_selected = dock._canvas.get_selected_region()
	assert_bool(still_selected == null or still_selected.id != "left").is_true()
	# Selecting what remains must still work after the removal.
	_find_item(dock, "region", "right").select(0)
	await _settle()
	assert_str(dock._canvas.get_selected_region().id).is_equal("right")
	dock.queue_free()


func test_selected_item_stays_consistent_after_a_structural_refresh() -> void:
	var dock := _make_dock_with_regions()
	await _settle()
	_find_item(dock, "cutout", "left", 1).select(0)
	await _settle()
	# Renaming the region changes the structure signature, so the tree is rebuilt.
	dock._document.regions[0].name = "Left renamed"
	dock._refresh_regions("left", 1)
	await _settle()
	var metadata: Dictionary = dock._region_list.get_selected_metadata()
	assert_str(metadata.get("kind", "")).is_equal("cutout")
	assert_int(metadata.get("index", -1)).is_equal(1)
	assert_str(_find_item(dock, "region", "left").get_text(0)).is_equal("Left renamed  (2 cutouts)")
	dock.queue_free()

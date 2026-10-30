extends GdUnitTestSuite
## The order of the regions is data: the zone drawn first keeps ground that two zones share, and the
## export follows the list. Undoing a deletion must put the region back where it was.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")


func _rect(x: float, y: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + 100, y), Vector2(x + 100, y + 100), Vector2(x, y + 100)])


func _dock_with_three_regions() -> Control:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	VILLAGE.import_background(dock)
	dock._create_group_named("Ground")
	for index in 3:
		dock._canvas.region_created.emit(_rect(100.0 + index * 300.0, 300.0))
	return dock


func _ids(dock: Control) -> PackedStringArray:
	var ids := PackedStringArray()
	for region in dock._document.regions:
		ids.append(region.id)
	return ids


func test_undoing_the_deletion_of_the_first_region_puts_it_back_first() -> void:
	var dock := await _dock_with_three_regions()
	var before := _ids(dock)
	dock._canvas.select_region(before[0])
	dock._delete_selected_region()
	assert_array(Array(_ids(dock))).is_equal([before[1], before[2]])
	dock._undo()
	assert_array(Array(_ids(dock))).override_failure_message("the region came back at the end of the list").is_equal(Array(before))
	dock._redo()
	assert_array(Array(_ids(dock))).is_equal([before[1], before[2]])
	dock.queue_free()


func test_undoing_the_deletion_of_a_middle_region_keeps_the_others_in_order() -> void:
	var dock := await _dock_with_three_regions()
	var before := _ids(dock)
	dock._canvas.select_region(before[1])
	dock._delete_selected_region()
	dock._undo()
	assert_array(Array(_ids(dock))).is_equal(Array(before))
	assert_str(dock._document.regions[1].name).is_equal("Region 2")
	dock.queue_free()

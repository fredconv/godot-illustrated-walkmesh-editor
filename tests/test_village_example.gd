extends GdUnitTestSuite
## The shipped example document must keep opening with the plugin as it is.

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const EXAMPLE := "res://examples/village/village.tres"


func test_the_village_example_opens_with_its_zones_pictures_and_calibration() -> void:
	var dock: Control = await VILLAGE.new_dock(get_tree())
	dock._open_document(EXAMPLE)
	var document: IWEDocument = dock._document
	assert_str(document.document_path).is_equal(EXAMPLE)
	assert_int(document.regions.size()).is_equal(4)
	assert_int(document.visual_elements.size()).is_equal(1)
	assert_int(document.scale_anchors.size()).is_equal(2)
	assert_int(document.schema_version).is_equal(IWEDocument.CURRENT_SCHEMA_VERSION)
	assert_bool(IWEDocument.schema_problem(document).is_empty()).is_true()
	assert_array(document.validate_references()).is_empty()
	assert_bool(FileAccess.file_exists(dock._pending_image_source)).is_true()
	assert_bool(FileAccess.file_exists(dock._element_source_path(document.visual_elements[0]))).is_true()
	dock.queue_free()

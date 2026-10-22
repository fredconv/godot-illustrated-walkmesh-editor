extends GdUnitTestSuite

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")


func test_document_serializes_illustration_coordinates() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://demo.png", Vector2i(1920, 1080))
	var save_error := ResourceSaver.save(document, "user://iwe_document_test.tres")
	assert_int(save_error).is_equal(OK)
	var loaded: Resource = ResourceLoader.load("user://iwe_document_test.tres")
	assert_object(loaded).is_not_null()
	assert_str(loaded.illustration_path).is_equal("res://demo.png")
	assert_vector(loaded.image_size).is_equal(Vector2i(1920, 1080))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://iwe_document_test.tres"))

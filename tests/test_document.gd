extends SceneTree

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")


func _initialize() -> void:
	var document: Resource = DOCUMENT_SCRIPT.new()
	document.set_illustration("res://demo.png", Vector2i(1920, 1080))
	var save_error := ResourceSaver.save(document, "user://iwe_document_test.tres")
	assert(save_error == OK, "Document resource should save")
	var loaded: Resource = ResourceLoader.load("user://iwe_document_test.tres")
	assert(loaded != null, "Document resource should reload")
	assert(loaded.illustration_path == "res://demo.png", "Illustration path should round-trip")
	assert(loaded.image_size == Vector2i(1920, 1080), "Image dimensions should round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://iwe_document_test.tres"))
	print("IWE document serialization test passed")
	quit(0)

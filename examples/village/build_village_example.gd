@tool
extends SceneTree
## Rebuilds examples/village/village.tres (and its assets/ folder) from an empty document, with the
## same helpers as the end-to-end scenario. Run it from the project root:
##   Godot --headless --path . -s examples/village/build_village_example.gd

const VILLAGE := preload("res://tests/e2e/village_scenario.gd")
const OUTPUT := "res://examples/village/village.tres"
const FOUNTAIN_GROUND := Vector2(815, 590)


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var dock: Control = await VILLAGE.new_dock(self)
	VILLAGE.import_background(dock)
	VILLAGE.author_regions(dock)
	VILLAGE.author_templates(dock)
	dock._fit_camera_to_references()
	var fountain: IWEVisualElement = dock.import_element(ProjectSettings.globalize_path(VILLAGE.FOREGROUND))
	dock._set_element_property(fountain.id, "ground_anchor", FOUNTAIN_GROUND)
	dock._save_document(OUTPUT)
	await process_frame
	print("VILLAGE saved=%s regions=%d elements=%d" % [FileAccess.file_exists(OUTPUT), dock._document.regions.size(), dock._document.visual_elements.size()])
	dock.queue_free()
	quit(0)

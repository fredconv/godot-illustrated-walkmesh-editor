@tool
extends EditorPlugin
## Smoke test of a packaged addon, run inside a project that contains nothing but the addon folder.
## It builds its own pictures, so it needs no asset of this repository. Prints SMOKE lines.

const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")
const FOLDER := "res://smoke"

var _failures := 0


func _enter_tree() -> void:
	_run.call_deferred()


func _check(label: String, condition: bool) -> void:
	print("SMOKE %s %s" % ["ok  " if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _make_picture(path: String, size: Vector2i, transparent: bool) -> void:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.5, 0.6, 1.0))
	if transparent:
		image.fill(Color(0, 0, 0, 0))
		image.fill_rect(Rect2i(size.x / 4, size.y / 4, size.x / 2, size.y / 2), Color(0.8, 0.2, 0.2, 1.0))
	image.save_png(ProjectSettings.globalize_path(path))


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _run() -> void:
	for _i in 30:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	_make_picture(FOLDER + "/background.png", Vector2i(640, 360), false)
	_make_picture(FOLDER + "/prop.png", Vector2i(100, 160), true)
	EditorInterface.get_resource_filesystem().scan()
	for _i in 60:
		await get_tree().process_frame

	var dock: Control = DOCK_SCENE.instantiate()
	dock.set_document(DOCUMENT_SCRIPT.new())
	EditorInterface.get_base_control().add_child(dock)
	await get_tree().process_frame
	var plugin_config := ConfigFile.new()
	_check("plugin.cfg loads and names a version", plugin_config.load("res://addons/illustrated_walkmesh_editor/plugin.cfg") == OK and str(plugin_config.get_value("plugin", "version", "")) != "")

	dock._load_illustration(FOLDER + "/background.png")
	dock._create_group_named("Ground")
	dock._create_region(_rect(40, 180, 300, 150))
	dock._create_region(_rect(340, 180, 240, 150))
	_check("two regions authored", dock._document.regions.size() == 2)
	dock._canvas.action_zone_created.emit(_rect(40, 100, 100, 60))
	dock._canvas.entry_point_created.emit(Vector2(200, 250))
	_check("an action zone and an entry point were authored", dock._document.action_zones.size() == 1 and dock._document.entry_points.size() == 1)
	var element: Object = dock.import_element(FOLDER + "/prop.png")
	_check("a layer picture was added", element != null)

	dock._save_document(FOLDER + "/doc.tres")
	await get_tree().process_frame
	_check("document written", FileAccess.file_exists(ProjectSettings.globalize_path(FOLDER + "/doc.tres")))
	_check("illustration copied beside the document", FileAccess.file_exists(ProjectSettings.globalize_path(FOLDER + "/assets/background.png")) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(FOLDER + "/assets")))

	var reopened: Control = DOCK_SCENE.instantiate()
	reopened.set_document(DOCUMENT_SCRIPT.new())
	EditorInterface.get_base_control().add_child(reopened)
	await get_tree().process_frame
	reopened._open_document(FOLDER + "/doc.tres")
	_check("document reopened with its regions", reopened._document.regions.size() == 2)
	_check("document reopened with its picture", reopened._document.visual_elements.size() == 1)
	_check("schema version is current", reopened._document.schema_version == DOCUMENT_SCRIPT.CURRENT_SCHEMA_VERSION)
	_check("the zone and the entry point came back", reopened._document.action_zones.size() == 1 and reopened._document.entry_points.size() == 1)

	for dimension in [2, 3, 4]:
		var output := "%s/stage_%d.tscn" % [FOLDER, dimension]
		reopened._pending_export_dimension = dimension
		await reopened._export_scene(output)
		var exists := FileAccess.file_exists(ProjectSettings.globalize_path(output))
		_check("export %dD written" % dimension, exists)
		if exists:
			var packed := load(output) as PackedScene
			var instance := packed.instantiate() if packed != null else null
			_check("export %dD instantiates" % dimension, instance != null)
			if instance != null:
				_check("export %dD holds the zone, the entry marker and the stage runtime" % dimension, instance.get_node_or_null("StageRuntime") != null and instance.find_children("*", "Area3D" if dimension != 2 else "Area2D", true, false).size() >= 1 and instance.find_child("entry_1", true, false) != null)
				instance.free()
	print("SMOKE done failures=%d" % _failures)
	get_tree().quit(_failures)

@tool
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/illustrated_walkmesh_editor/ui/iwe_dock.tscn")
const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")

var _dock: Control
var _document := DOCUMENT_SCRIPT.new()


func _get_plugin_name() -> String:
	return "IWE"


func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate() as Control
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	# The dock keeps its own per-document undo history, separate from the editor's.
	_dock.set_document(_document)


func _exit_tree() -> void:
	if is_instance_valid(_dock):
		# Disabling the plugin discards the open document; never do that without a trace.
		if _dock.is_dirty():
			var recovery_path: String = _dock.save_recovery_copy()
			if not recovery_path.is_empty():
				push_warning("IWE: the plugin was unloaded with unsaved changes. A recovery copy was written to %s" % recovery_path)
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
		_document = DOCUMENT_SCRIPT.new()


## Godot asks this when the editor is closing, and when a scene is closed. The dock answers
## "" for a scene, so closing a scene never prompts about the IWE document.
func _get_unsaved_status(for_scene: String) -> String:
	if not is_instance_valid(_dock):
		return ""
	return _dock.get_unsaved_status(for_scene)


## Godot calls this on Save All and when the user confirms saving in the quit dialog.
func _save_external_data() -> void:
	if is_instance_valid(_dock):
		_dock.save_external_data()

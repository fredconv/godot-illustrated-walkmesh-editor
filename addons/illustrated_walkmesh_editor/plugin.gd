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
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
		_document = DOCUMENT_SCRIPT.new()

@tool
extends VBoxContainer

const DOCUMENT_SCRIPT := preload("res://addons/illustrated_walkmesh_editor/data/iwe_document.gd")

@onready var _import_button: Button = %ImportButton
@onready var _zoom_out_button: Button = %ZoomOutButton
@onready var _zoom_in_button: Button = %ZoomInButton
@onready var _zoom_label: Label = %ZoomLabel
@onready var _file_dialog: FileDialog = $ImageFileDialog
@onready var _canvas: Control = $ImageScroll/Canvas

var _zoom := 1.0
var _document: Resource


func _ready() -> void:
	_document = DOCUMENT_SCRIPT.new()
	_import_button.pressed.connect(_file_dialog.popup_centered)
	_file_dialog.file_selected.connect(_load_illustration)
	_zoom_out_button.pressed.connect(_change_zoom.bind(1.0 / 1.2))
	_zoom_in_button.pressed.connect(_change_zoom.bind(1.2))
	_canvas.zoom_requested.connect(_change_zoom)


func _load_illustration(path: String) -> void:
	var image := Image.load_from_file(path)
	if image.is_empty():
		push_error("IWE: Could not load illustration at %s" % path)
		return
	var texture := ImageTexture.create_from_image(image)
	_canvas.set_texture(texture)
	_document.set_illustration(path, image.get_size())


func _change_zoom(factor: float) -> void:
	_zoom = clampf(_zoom * factor, 0.1, 8.0)
	_canvas.set_zoom(_zoom)
	_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)


func get_document() -> Resource:
	return _document

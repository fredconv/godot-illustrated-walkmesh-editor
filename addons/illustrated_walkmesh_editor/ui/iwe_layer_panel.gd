@tool
class_name IWELayerPanel
extends VBoxContainer
## The Layers section of the dock: layers and their transparent pictures, with the properties of the
## selected one. The panel only shows the document and reports what the person asks for. The dock
## makes every change, through its undo history.

signal add_image_requested(layer_id: String)
signal add_layer_requested
signal remove_requested(kind: String, id: String)
signal layer_property_requested(layer_id: String, property: String, value: Variant)
signal element_property_requested(element_id: String, property: String, value: Variant)
signal selection_changed(kind: String, id: String)

const KIND_LAYER := "layer"
const KIND_ELEMENT := "element"
const DEPTH_LABELS := ["Behind the character", "In front of the character", "By depth (walk behind and in front)"]

var _document: IWEDocument
var _tree: Tree
var _add_image_button: Button
var _add_layer_button: Button
var _remove_button: Button
var _properties: VBoxContainer
var _layer_box: VBoxContainer
var _element_box: VBoxContainer
var _layer_name: LineEdit
var _layer_visible: CheckBox
var _layer_locked: CheckBox
var _layer_opacity: SpinBox
var _element_name: LineEdit
var _element_layer: OptionButton
var _element_depth: OptionButton
var _element_x: SpinBox
var _element_y: SpinBox
var _element_scale: SpinBox
var _element_opacity: SpinBox
var _ground_x: SpinBox
var _ground_y: SpinBox
var _ground_reset: Button
var _ground_row: HBoxContainer
var _selected_kind := ""
var _selected_id := ""
var _refreshing := false


func _init() -> void:
	name = "LayerPanel"
	add_theme_constant_override("separation", 4)
	_tree = Tree.new()
	_tree.name = "LayerTree"
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(0, 120)
	_tree.select_mode = Tree.SELECT_SINGLE
	add_child(_tree)
	var buttons := HFlowContainer.new()
	add_child(buttons)
	_add_image_button = _button(buttons, "AddImageButton", "Add image…", "Place a transparent picture (PNG) on the selected layer.")
	_add_layer_button = _button(buttons, "AddLayerButton", "Add layer", "Create an empty layer.")
	_remove_button = _button(buttons, "RemoveLayerItemButton", "Remove", "Remove the selected picture or layer. The default layers cannot be removed.")
	_properties = VBoxContainer.new()
	_properties.name = "LayerProperties"
	add_child(_properties)
	_layer_box = VBoxContainer.new()
	_properties.add_child(_layer_box)
	_layer_name = _line(_layer_box, "Name")
	_layer_visible = _check(_layer_box, "Visible")
	_layer_locked = _check(_layer_box, "Locked")
	_layer_opacity = _spin(_layer_box, "Opacity", 0.0, 1.0, 0.05)
	_element_box = VBoxContainer.new()
	_properties.add_child(_element_box)
	_element_name = _line(_element_box, "Name")
	_element_layer = _option(_element_box, "Layer")
	_element_depth = _option(_element_box, "Drawn")
	for label in DEPTH_LABELS:
		_element_depth.add_item(label)
	_element_depth.tooltip_text = "Behind: always behind. In front: always in front. By depth: the character walks behind the picture when it is farther than the ground point, and in front when it is nearer."
	var position_row := _row(_element_box, "Position")
	_element_x = _spin_in(position_row, -100000.0, 100000.0, 1.0)
	_element_y = _spin_in(position_row, -100000.0, 100000.0, 1.0)
	_element_scale = _spin(_element_box, "Scale", 0.05, 20.0, 0.05)
	_element_opacity = _spin(_element_box, "Opacity", 0.0, 1.0, 0.05)
	_ground_row = _row(_element_box, "Ground point")
	_ground_row.tooltip_text = "Where the picture touches the floor, in illustration pixels. The distance of this point to the camera decides who is in front."
	_ground_x = _spin_in(_ground_row, -100000.0, 100000.0, 1.0)
	_ground_y = _spin_in(_ground_row, -100000.0, 100000.0, 1.0)
	_ground_reset = Button.new()
	_ground_reset.text = "Bottom centre"
	_ground_row.add_child(_ground_reset)
	_describe_controls()
	_connect_controls()
	_update_visibility()


## Short explanations for the fields of the selected layer or picture.
func _describe_controls() -> void:
	_layer_name.tooltip_text = "The name of the layer."
	_layer_visible.tooltip_text = "A hidden layer is not drawn on the illustration or in the exports."
	_layer_locked.tooltip_text = "A locked layer refuses edits to itself and to its pictures."
	_layer_opacity.tooltip_text = "How opaque the whole layer is (1 is fully visible)."
	_element_name.tooltip_text = "The name of the picture."
	_element_layer.tooltip_text = "The layer the picture is on."
	_element_x.tooltip_text = "Position of the picture's left edge on the illustration, in illustration pixels."
	_element_y.tooltip_text = "Position of the picture's top edge on the illustration, in illustration pixels."
	_element_scale.tooltip_text = "Size of the picture (1 keeps its own size). In V1 a picture is prepared at the right size beforehand; use this for small corrections."
	_element_opacity.tooltip_text = "How opaque this picture is (1 is fully visible)."
	_ground_x.tooltip_text = "Ground point, horizontal position, in illustration pixels."
	_ground_y.tooltip_text = "Ground point, vertical position, in illustration pixels."
	_ground_reset.tooltip_text = "Put the ground point back at the bottom centre of the picture."


func _button(parent: Control, node_name: String, text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tooltip
	parent.add_child(button)
	return button


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)
	parent.add_child(row)
	return row


func _line(parent: Control, label_text: String) -> LineEdit:
	var row := _row(parent, label_text)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


func _check(parent: Control, text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	parent.add_child(box)
	return box


func _option(parent: Control, label_text: String) -> OptionButton:
	var row := _row(parent, label_text)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.fit_to_longest_item = false
	row.add_child(option)
	return option


func _spin(parent: Control, label_text: String, min_value: float, max_value: float, step: float) -> SpinBox:
	return _spin_in(_row(parent, label_text), min_value, max_value, step)


func _spin_in(row: HBoxContainer, min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _connect_controls() -> void:
	_tree.item_selected.connect(_on_tree_selected)
	_add_image_button.pressed.connect(func() -> void: add_image_requested.emit(_target_layer_id()))
	_add_layer_button.pressed.connect(func() -> void: add_layer_requested.emit())
	_remove_button.pressed.connect(func() -> void: remove_requested.emit(_selected_kind, _selected_id))
	_layer_name.text_submitted.connect(func(text: String) -> void: _ask_layer("name", text))
	_layer_name.focus_exited.connect(func() -> void: _ask_layer("name", _layer_name.text))
	_layer_visible.toggled.connect(func(on: bool) -> void: _ask_layer("visible", on))
	_layer_locked.toggled.connect(func(on: bool) -> void: _ask_layer("locked", on))
	_layer_opacity.value_changed.connect(func(value: float) -> void: _ask_layer("opacity", value))
	_element_name.text_submitted.connect(func(text: String) -> void: _ask_element("name", text))
	_element_name.focus_exited.connect(func() -> void: _ask_element("name", _element_name.text))
	_element_layer.item_selected.connect(func(index: int) -> void: _ask_element("layer_id", _element_layer.get_item_metadata(index)))
	_element_depth.item_selected.connect(func(index: int) -> void: _ask_element("depth_mode", index))
	_element_x.value_changed.connect(func(_value: float) -> void: _ask_element("position", Vector2(_element_x.value, _element_y.value)))
	_element_y.value_changed.connect(func(_value: float) -> void: _ask_element("position", Vector2(_element_x.value, _element_y.value)))
	_element_scale.value_changed.connect(func(value: float) -> void: _ask_element("scale", Vector2(value, value)))
	_element_opacity.value_changed.connect(func(value: float) -> void: _ask_element("opacity", value))
	_ground_x.value_changed.connect(func(_value: float) -> void: _ask_element("ground_anchor", Vector2(_ground_x.value, _ground_y.value)))
	_ground_y.value_changed.connect(func(_value: float) -> void: _ask_element("ground_anchor", Vector2(_ground_x.value, _ground_y.value)))
	_ground_reset.pressed.connect(func() -> void: _ask_element("ground_anchor", Vector2(NAN, NAN)))


func _ask_layer(property: String, value: Variant) -> void:
	if not _refreshing and _selected_kind == KIND_LAYER and _document != null:
		layer_property_requested.emit(_selected_id, property, value)


func _ask_element(property: String, value: Variant) -> void:
	if not _refreshing and _selected_kind == KIND_ELEMENT and _document != null:
		element_property_requested.emit(_selected_id, property, value)


## The layer a new picture goes to: the selected layer, the layer of the selected picture, or the
## foreground.
func _target_layer_id() -> String:
	if _document == null:
		return ""
	if _selected_kind == KIND_LAYER:
		return _selected_id
	if _selected_kind == KIND_ELEMENT:
		var element := _document.find_element(_selected_id)
		if element != null:
			return element.layer_id
	return IWELayer.FOREGROUND_ID


func get_selected() -> Dictionary:
	return {"kind": _selected_kind, "id": _selected_id}


func select(kind: String, id: String) -> void:
	_selected_kind = kind
	_selected_id = id
	refresh(_document)
	selection_changed.emit(kind, id)


## Rebuilds the list and the property fields from the document.
func refresh(document: IWEDocument) -> void:
	_document = document
	_refreshing = true
	_tree.clear()
	var root := _tree.create_item()
	var selected_item: TreeItem = null
	if _document != null:
		for layer in _document.layers:
			var layer_item := _tree.create_item(root)
			layer_item.set_text(0, "%s%s%s" % [layer.name, "" if layer.visible else "  (hidden)", "  (locked)" if layer.locked else ""])
			layer_item.set_metadata(0, {"kind": KIND_LAYER, "id": layer.id})
			if _selected_kind == KIND_LAYER and _selected_id == layer.id:
				selected_item = layer_item
			for element in _document.visual_elements:
				if element.layer_id != layer.id:
					continue
				var element_item := _tree.create_item(layer_item)
				element_item.set_text(0, element.name)
				element_item.set_metadata(0, {"kind": KIND_ELEMENT, "id": element.id})
				if _selected_kind == KIND_ELEMENT and _selected_id == element.id:
					selected_item = element_item
	if selected_item != null:
		selected_item.select(0)
	else:
		_selected_kind = ""
		_selected_id = ""
	_fill_properties()
	_update_visibility()
	_refreshing = false


func _fill_properties() -> void:
	if _document == null:
		return
	if _selected_kind == KIND_LAYER:
		var layer := _document.find_layer(_selected_id)
		if layer == null:
			return
		_layer_name.text = layer.name
		_layer_visible.set_pressed_no_signal(layer.visible)
		_layer_locked.set_pressed_no_signal(layer.locked)
		_layer_opacity.set_value_no_signal(layer.opacity)
	elif _selected_kind == KIND_ELEMENT:
		var element := _document.find_element(_selected_id)
		if element == null:
			return
		var layer := _document.find_layer(element.layer_id)
		var locked := layer != null and layer.locked
		_element_name.text = element.name
		_element_layer.clear()
		for candidate in _document.layers:
			_element_layer.add_item(candidate.name)
			_element_layer.set_item_metadata(_element_layer.item_count - 1, candidate.id)
			if candidate.id == element.layer_id:
				_element_layer.select(_element_layer.item_count - 1)
		_element_depth.select(element.depth_mode)
		_element_x.set_value_no_signal(element.position.x)
		_element_y.set_value_no_signal(element.position.y)
		_element_scale.set_value_no_signal(element.scale.x)
		_element_opacity.set_value_no_signal(element.opacity)
		var ground := element.get_effective_ground_anchor()
		_ground_x.set_value_no_signal(ground.x)
		_ground_y.set_value_no_signal(ground.y)
		_ground_row.visible = element.depth_mode == IWEVisualElement.DepthMode.DEPTH
		for control in [_element_name, _element_layer, _element_depth, _element_x, _element_y, _element_scale, _element_opacity, _ground_x, _ground_y, _ground_reset]:
			if control is LineEdit:
				control.editable = not locked
			elif control is SpinBox:
				control.editable = not locked
			else:
				control.disabled = locked


func _update_visibility() -> void:
	_layer_box.visible = _selected_kind == KIND_LAYER
	_element_box.visible = _selected_kind == KIND_ELEMENT
	_properties.visible = _selected_kind != ""
	var removable := _selected_kind == KIND_ELEMENT
	if _selected_kind == KIND_LAYER:
		removable = _selected_id != IWELayer.BACKGROUND_ID and _selected_id != IWELayer.FOREGROUND_ID
	_remove_button.disabled = not removable


func _on_tree_selected() -> void:
	if _refreshing:
		return
	var item := _tree.get_selected()
	if item == null:
		return
	var meta: Dictionary = item.get_metadata(0)
	_selected_kind = meta.kind
	_selected_id = meta.id
	_refreshing = true
	_fill_properties()
	_update_visibility()
	_refreshing = false
	selection_changed.emit(_selected_kind, _selected_id)

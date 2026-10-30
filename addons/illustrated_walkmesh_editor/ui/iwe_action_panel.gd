@tool
class_name IWEActionPanel
extends VBoxContainer
## The "Action zones" and "Entry points" sections of the dock. A zone does something when a character walks
## into it (change the scene, jump to an entry point); an entry point is where a character appears when it
## arrives. The panel shows the document and reports what the person asks for; the dock makes every
## change through its undo history (same split as IWELayerPanel).

signal draw_zone_toggled(enabled: bool)
signal select_zone_toggled(enabled: bool)
signal place_entry_toggled(enabled: bool)
signal remove_requested(kind: String, id: String)
signal zone_property_requested(zone_id: String, property: String, value: Variant)
signal entry_property_requested(entry_id: String, property: String, value: Variant)
signal selection_changed(kind: String, id: String)

const KIND_ZONE := "zone"
const KIND_ENTRY := "entry"
const ACTION_LABELS := {
	IWEActionZone.ACTION_SCENE_TRANSITION: "Change scene",
	IWEActionZone.ACTION_WARP: "Jump to an entry point of this scene",
	IWEActionZone.ACTION_EVENT: "Trigger a custom event",
}

var _document: IWEDocument
var _zone_list: ItemList
var _entry_list: ItemList
var _draw_zone_button: Button
var _select_zone_button: Button
var _remove_zone_button: Button
var _place_entry_button: Button
var _remove_entry_button: Button
var _zone_box: VBoxContainer
var _entry_box: VBoxContainer
var _zone_name: LineEdit
var _zone_action: OptionButton
var _scene_row: HBoxContainer
var _zone_scene: LineEdit
var _browse_scene_button: Button
var _scene_dialog: FileDialog
var _zone_entry: LineEdit
var _zone_entry_label: Label
var _zone_entry_pick: OptionButton
var _zone_enabled: CheckBox
var _event_label: Label
var _zone_event: LineEdit
var _zone_repeat: CheckBox
var _zone_hint: Label
var _entry_name: LineEdit
var _entry_default: CheckBox
var _entry_facing_set: CheckBox
var _entry_facing: SpinBox
var _zone_ids: PackedStringArray = []
var _entry_ids: PackedStringArray = []
var _selected_kind := ""
var _selected_id := ""
var _refreshing := false


func _init() -> void:
	name = "ActionPanel"
	add_theme_constant_override("separation", 4)
	_build_zone_part()
	_build_entry_part()
	_update_enabled_state()


func _build_zone_part() -> void:
	var title := Label.new()
	title.text = "Action zones"
	title.add_theme_font_size_override("font_size", 13)
	add_child(title)
	var hint := Label.new()
	hint.name = "ZoneIntro"
	hint.text = "Draw an area of the floor. When the character walks into it, the game changes scene or jumps to an entry point."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.7)
	add_child(hint)
	_zone_list = ItemList.new()
	_zone_list.name = "ZoneList"
	_zone_list.custom_minimum_size = Vector2(0, 70)
	_zone_list.select_mode = ItemList.SELECT_SINGLE
	_zone_list.item_selected.connect(_on_zone_item_selected)
	add_child(_zone_list)
	var buttons := HFlowContainer.new()
	add_child(buttons)
	_draw_zone_button = _toggle(buttons, "DrawZoneButton", "Draw zone", "Click to place the corners of a zone on the floor, then click the first corner or press Enter to close it.")
	_draw_zone_button.toggled.connect(func(pressed: bool) -> void: draw_zone_toggled.emit(pressed))
	_select_zone_button = _toggle(buttons, "SelectZoneButton", "Select zone", "Click a zone on the illustration to select it; drag it to move it.")
	_select_zone_button.toggled.connect(func(pressed: bool) -> void: select_zone_toggled.emit(pressed))
	_remove_zone_button = _button(buttons, "RemoveZoneButton", "Remove", "Remove the selected zone.")
	_remove_zone_button.pressed.connect(func() -> void: remove_requested.emit(KIND_ZONE, _selected_id))
	_zone_box = VBoxContainer.new()
	_zone_box.name = "ZoneProperties"
	_zone_box.add_theme_constant_override("separation", 3)
	add_child(_zone_box)
	_zone_name = _line(_zone_box, "Name")
	_zone_name.text_submitted.connect(func(text: String) -> void: _request_zone("name", text))
	_zone_name.focus_exited.connect(func() -> void: _request_zone("name", _zone_name.text))
	_zone_action = _option(_zone_box, "When walked into")
	for action in ACTION_LABELS:
		_zone_action.add_item(ACTION_LABELS[action])
		_zone_action.set_item_metadata(_zone_action.item_count - 1, action)
	_zone_action.tooltip_text = "What happens when a character walks into the zone."
	_zone_action.item_selected.connect(func(index: int) -> void: _request_zone("action", _zone_action.get_item_metadata(index)))
	var scene_label := _label(_zone_box, "Scene to load")
	scene_label.name = "SceneLabel"
	_scene_row = HBoxContainer.new()
	_scene_row.name = "SceneRow"
	_zone_box.add_child(_scene_row)
	_zone_scene = LineEdit.new()
	_zone_scene.name = "ZoneSceneInput"
	_zone_scene.placeholder_text = "res://levels/forest.tscn"
	_zone_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_scene.text_submitted.connect(func(text: String) -> void: _request_zone("target_scene", text.strip_edges()))
	_zone_scene.focus_exited.connect(func() -> void: _request_zone("target_scene", _zone_scene.text.strip_edges()))
	_scene_row.add_child(_zone_scene)
	_browse_scene_button = Button.new()
	_browse_scene_button.name = "BrowseSceneButton"
	_browse_scene_button.text = "…"
	_browse_scene_button.tooltip_text = "Choose the scene in the project."
	_browse_scene_button.pressed.connect(_on_browse_scene)
	_scene_row.add_child(_browse_scene_button)
	_scene_dialog = FileDialog.new()
	_scene_dialog.name = "SceneFileDialog"
	_scene_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_scene_dialog.access = FileDialog.ACCESS_RESOURCES
	_scene_dialog.title = "Choose the scene to load"
	_scene_dialog.filters = PackedStringArray(["*.tscn, *.scn ; Scenes"])
	_scene_dialog.file_selected.connect(func(path: String) -> void: _request_zone("target_scene", path))
	add_child(_scene_dialog)
	_zone_entry_label = _label(_zone_box, "Arrive at entry point")
	_zone_entry = LineEdit.new()
	_zone_entry.name = "ZoneEntryInput"
	_zone_entry.placeholder_text = "from_village (empty = the scene's default)"
	_zone_entry.text_submitted.connect(func(text: String) -> void: _request_zone("entry_id", text.strip_edges()))
	_zone_entry.focus_exited.connect(func() -> void: _request_zone("entry_id", _zone_entry.text.strip_edges()))
	_zone_box.add_child(_zone_entry)
	_zone_entry_pick = OptionButton.new()
	_zone_entry_pick.name = "ZoneEntryPick"
	_zone_entry_pick.tooltip_text = "Pick one of the entry points of this document."
	_zone_entry_pick.item_selected.connect(func(index: int) -> void: _request_zone("entry_id", _zone_entry_pick.get_item_metadata(index)))
	_zone_box.add_child(_zone_entry_pick)
	_event_label = _label(_zone_box, "Event name")
	_zone_event = LineEdit.new()
	_zone_event.name = "ZoneEventInput"
	_zone_event.placeholder_text = "explosion"
	_zone_event.tooltip_text = "The name your game receives when a character walks into the zone (for example explosion or open_gate)."
	_zone_event.text_submitted.connect(func(text: String) -> void: _request_zone("event_name", text.strip_edges()))
	_zone_event.focus_exited.connect(func() -> void: _request_zone("event_name", _zone_event.text.strip_edges()))
	_zone_box.add_child(_zone_event)
	_zone_repeat = CheckBox.new()
	_zone_repeat.name = "ZoneRepeatInput"
	_zone_repeat.text = "Every time it is entered"
	_zone_repeat.tooltip_text = "Off: the event fires once. On: it fires again each time the character walks back into the zone."
	_zone_repeat.toggled.connect(func(pressed: bool) -> void: _request_zone("repeat", pressed))
	_zone_box.add_child(_zone_repeat)
	_zone_enabled = CheckBox.new()
	_zone_enabled.name = "ZoneEnabledInput"
	_zone_enabled.text = "Enabled"
	_zone_enabled.tooltip_text = "A disabled zone is exported but does nothing until the game enables it."
	_zone_enabled.toggled.connect(func(pressed: bool) -> void: _request_zone("enabled", pressed))
	_zone_box.add_child(_zone_enabled)
	_zone_hint = Label.new()
	_zone_hint.name = "ZoneHint"
	_zone_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_hint.modulate = Color(1, 1, 1, 0.7)
	_zone_box.add_child(_zone_hint)


func _build_entry_part() -> void:
	var separator := HSeparator.new()
	add_child(separator)
	var title := Label.new()
	title.text = "Entry points"
	title.add_theme_font_size_override("font_size", 13)
	add_child(title)
	var hint := Label.new()
	hint.name = "EntryIntro"
	hint.text = "Where a character appears when it arrives in this scene. A zone of another scene names it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.7)
	add_child(hint)
	_entry_list = ItemList.new()
	_entry_list.name = "EntryList"
	_entry_list.custom_minimum_size = Vector2(0, 60)
	_entry_list.select_mode = ItemList.SELECT_SINGLE
	_entry_list.item_selected.connect(_on_entry_item_selected)
	add_child(_entry_list)
	var buttons := HFlowContainer.new()
	add_child(buttons)
	_place_entry_button = _toggle(buttons, "PlaceEntryButton", "Place entry point", "Click the floor where the character should appear. Click a marker to select it; drag it to move it.")
	_place_entry_button.toggled.connect(func(pressed: bool) -> void: place_entry_toggled.emit(pressed))
	_remove_entry_button = _button(buttons, "RemoveEntryButton", "Remove", "Remove the selected entry point.")
	_remove_entry_button.pressed.connect(func() -> void: remove_requested.emit(KIND_ENTRY, _selected_id))
	_entry_box = VBoxContainer.new()
	_entry_box.name = "EntryProperties"
	_entry_box.add_theme_constant_override("separation", 3)
	add_child(_entry_box)
	_entry_name = _line(_entry_box, "Name")
	_entry_name.tooltip_text = "The name a zone uses to arrive here. Keep it unique; it is part of your game's contract."
	_entry_name.text_submitted.connect(func(text: String) -> void: _request_entry("entry_id", text.strip_edges()))
	_entry_name.focus_exited.connect(func() -> void: _request_entry("entry_id", _entry_name.text.strip_edges()))
	_entry_default = CheckBox.new()
	_entry_default.name = "EntryDefaultInput"
	_entry_default.text = "Default entry point"
	_entry_default.tooltip_text = "Used when a zone names no entry point, or one this scene does not have."
	_entry_default.toggled.connect(func(pressed: bool) -> void: _request_entry("is_default", pressed))
	_entry_box.add_child(_entry_default)
	_entry_facing_set = CheckBox.new()
	_entry_facing_set.name = "EntryFacingSetInput"
	_entry_facing_set.text = "Face a direction on arrival"
	_entry_facing_set.tooltip_text = "Turn the character to a direction when it arrives here. Otherwise it keeps its own direction."
	_entry_facing_set.toggled.connect(func(pressed: bool) -> void: _request_entry("facing_degrees", _entry_facing.value if pressed else NAN))
	_entry_box.add_child(_entry_facing_set)
	_entry_facing = SpinBox.new()
	_entry_facing.name = "EntryFacingInput"
	_entry_facing.min_value = -360.0
	_entry_facing.max_value = 360.0
	_entry_facing.step = 1.0
	_entry_facing.suffix = "°"
	_entry_facing.tooltip_text = "Direction in degrees around the vertical axis: 0 faces away from the camera, 90 faces left, 180 faces the camera, 270 faces right."
	_entry_facing.value_changed.connect(func(value: float) -> void: _request_entry("facing_degrees", value))
	_entry_box.add_child(_entry_facing)


# ---- showing the document ------------------------------------------------------------------------


## Rebuilds the lists from the document, keeping the selection when it still exists.
func refresh(document: IWEDocument) -> void:
	_document = document
	_refreshing = true
	_zone_list.clear()
	_zone_ids.clear()
	_entry_list.clear()
	_entry_ids.clear()
	if document != null:
		for zone in document.action_zones:
			_zone_list.add_item(zone.describe())
			_zone_ids.append(zone.id)
			if not zone.enabled:
				_zone_list.set_item_custom_fg_color(_zone_list.item_count - 1, Color(1, 1, 1, 0.5))
		for entry in document.entry_points:
			_entry_list.add_item("%s%s" % ["★ " if entry.is_default else "", entry.entry_id])
			_entry_ids.append(entry.id)
	if _selected_kind == KIND_ZONE and not _zone_ids.has(_selected_id):
		_selected_kind = ""
		_selected_id = ""
	if _selected_kind == KIND_ENTRY and not _entry_ids.has(_selected_id):
		_selected_kind = ""
		_selected_id = ""
	_show_selection()
	_refreshing = false
	_update_enabled_state()


func get_selected() -> Dictionary:
	return {"kind": _selected_kind, "id": _selected_id}


## Selects a zone or an entry point from outside (the canvas). Pass "" to clear.
func select(kind: String, id: String) -> void:
	_selected_kind = kind if not id.is_empty() else ""
	_selected_id = id
	_refreshing = true
	_show_selection()
	_refreshing = false
	_update_enabled_state()


func set_tool_pressed(tool_name: String) -> void:
	_draw_zone_button.set_pressed_no_signal(tool_name == "zone_draw")
	_select_zone_button.set_pressed_no_signal(tool_name == "zone_select")
	_place_entry_button.set_pressed_no_signal(tool_name == "entry")


func _show_selection() -> void:
	_zone_list.deselect_all()
	_entry_list.deselect_all()
	_zone_box.visible = false
	_entry_box.visible = false
	if _document == null:
		return
	if _selected_kind == KIND_ZONE:
		var index := _zone_ids.find(_selected_id)
		var zone := _document.find_action_zone(_selected_id)
		if index >= 0 and zone != null:
			_zone_list.select(index)
			_zone_box.visible = true
			_fill_zone(zone)
	elif _selected_kind == KIND_ENTRY:
		var index := _entry_ids.find(_selected_id)
		var entry := _document.find_entry_point(_selected_id)
		if index >= 0 and entry != null:
			_entry_list.select(index)
			_entry_box.visible = true
			_fill_entry(entry)


func _fill_zone(zone: IWEActionZone) -> void:
	_zone_name.text = zone.name
	var found := false
	for index in _zone_action.item_count:
		if _zone_action.get_item_metadata(index) == zone.action:
			_zone_action.select(index)
			found = true
	if not found:
		# An action this plugin does not know is kept as it is and shown by its name.
		_zone_action.add_item("Custom action: %s" % zone.action)
		_zone_action.set_item_metadata(_zone_action.item_count - 1, zone.action)
		_zone_action.select(_zone_action.item_count - 1)
	var changes_scene := zone.needs_target_scene()
	var warps := zone.action == IWEActionZone.ACTION_WARP
	var is_event := zone.action == IWEActionZone.ACTION_EVENT
	_scene_row.visible = changes_scene
	_zone_box.get_node("SceneLabel").visible = changes_scene
	_zone_entry_label.visible = not is_event
	_zone_entry.visible = not is_event
	_event_label.visible = is_event
	_zone_event.visible = is_event
	_zone_repeat.visible = is_event
	_zone_event.text = zone.get_event_name()
	_zone_repeat.set_pressed_no_signal(zone.repeats())
	_zone_scene.text = zone.target_scene
	_zone_entry.text = zone.entry_id
	_zone_entry_label.text = "Arrive at entry point" if changes_scene else ("Jump to entry point" if warps else "Entry point")
	_zone_entry_pick.visible = warps and not _document.entry_points.is_empty()
	if warps:
		_zone_entry_pick.clear()
		for entry in _document.entry_points:
			_zone_entry_pick.add_item(entry.entry_id)
			_zone_entry_pick.set_item_metadata(_zone_entry_pick.item_count - 1, entry.entry_id)
			if entry.entry_id == zone.entry_id:
				_zone_entry_pick.select(_zone_entry_pick.item_count - 1)
	_zone_enabled.set_pressed_no_signal(zone.enabled)
	_zone_hint.text = _hint_for(zone)


func _hint_for(zone: IWEActionZone) -> String:
	if zone.action == IWEActionZone.ACTION_SCENE_TRANSITION:
		if zone.target_scene.is_empty():
			return "Choose the scene this zone loads."
		if not zone.target_scene.begins_with("res://"):
			return "The scene should be a resource path (res://…) so the exported game finds it."
		if not FileAccess.file_exists(zone.target_scene) and not ResourceLoader.exists(zone.target_scene):
			return "This scene file was not found in the project; the character would stay where it is."
		return "The scene must hold an IWEStageRuntime node and an IWEEntryMarker with this name (see the user guide)."
	if zone.action == IWEActionZone.ACTION_WARP:
		if zone.entry_id.is_empty() or _document.find_entry_by_name(zone.entry_id) == null:
			return "Choose an entry point of this document to jump to."
		return "The character jumps to this entry point in the same scene."
	if zone.action == IWEActionZone.ACTION_EVENT:
		if zone.get_event_name().is_empty():
			return "Give the event a name."
		return "Your game receives this name from the zone's event_fired signal (or from every zone through the group iwe_action_zone). Nothing else happens by itself."
	return "This action is not built in: the exported zone emits a signal with its settings and your game decides what to do."


func _fill_entry(entry: IWEEntryPoint) -> void:
	_entry_name.text = entry.entry_id
	_entry_default.set_pressed_no_signal(entry.is_default)
	_entry_facing_set.set_pressed_no_signal(entry.has_facing())
	_entry_facing.set_value_no_signal(entry.facing_degrees if entry.has_facing() else 0.0)
	_entry_facing.editable = entry.has_facing()


func _update_enabled_state() -> void:
	_remove_zone_button.disabled = _selected_kind != KIND_ZONE
	_remove_entry_button.disabled = _selected_kind != KIND_ENTRY


# ---- reporting what the person asks for -------------------------------------------------------------


func _on_zone_item_selected(index: int) -> void:
	if _refreshing or index < 0 or index >= _zone_ids.size():
		return
	select(KIND_ZONE, _zone_ids[index])
	selection_changed.emit(KIND_ZONE, _selected_id)


func _on_entry_item_selected(index: int) -> void:
	if _refreshing or index < 0 or index >= _entry_ids.size():
		return
	select(KIND_ENTRY, _entry_ids[index])
	selection_changed.emit(KIND_ENTRY, _selected_id)


func _request_zone(property: String, value: Variant) -> void:
	if _refreshing or _selected_kind != KIND_ZONE:
		return
	zone_property_requested.emit(_selected_id, property, value)


func _request_entry(property: String, value: Variant) -> void:
	if _refreshing or _selected_kind != KIND_ENTRY:
		return
	entry_property_requested.emit(_selected_id, property, value)


func _on_browse_scene() -> void:
	if _selected_kind != KIND_ZONE:
		return
	_scene_dialog.popup_centered_ratio(0.6)


# ---- small builders ------------------------------------------------------------------------------


func _button(parent: Control, node_name: String, text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tooltip
	parent.add_child(button)
	return button


func _toggle(parent: Control, node_name: String, text: String, tooltip: String) -> Button:
	var button := _button(parent, node_name, text, tooltip)
	button.toggle_mode = true
	return button


func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _line(parent: Control, label_text: String) -> LineEdit:
	_label(parent, label_text)
	var line := LineEdit.new()
	line.name = label_text.replace(" ", "") + "Input"
	parent.add_child(line)
	return line


func _option(parent: Control, label_text: String) -> OptionButton:
	_label(parent, label_text)
	var option := OptionButton.new()
	option.name = label_text.replace(" ", "") + "Input"
	option.fit_to_longest_item = false
	option.clip_text = true
	parent.add_child(option)
	return option

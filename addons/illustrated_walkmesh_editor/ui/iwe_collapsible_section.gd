@tool
class_name IWECollapsibleSection
extends VBoxContainer
## A titled block of the dock that can be folded to save room. The header is a toggle button; the
## controls live in `content`, which is hidden while the section is folded.

signal expanded_changed(expanded: bool)

var content: VBoxContainer
var _header: Button
var _title := ""
var _expanded := true
var _badge := ""


func _init(section_title: String = "", start_expanded: bool = true) -> void:
	_title = section_title
	_expanded = start_expanded
	name = "Section" + section_title.replace(" ", "").replace("&", "And")
	add_theme_constant_override("separation", 2)
	_header = Button.new()
	_header.name = "Header"
	_header.toggle_mode = true
	_header.flat = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.focus_mode = Control.FOCUS_ALL
	_header.add_theme_font_size_override("font_size", 14)
	_header.toggled.connect(_on_header_toggled)
	add_child(_header)
	content = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 4)
	add_child(content)
	_apply()


func get_title() -> String:
	return _title


func is_expanded() -> bool:
	return _expanded


## A short note after the title that stays visible when the section is folded, such as a count.
func set_badge(text: String) -> void:
	if text == _badge:
		return
	_badge = text
	_apply()


func get_badge() -> String:
	return _badge


func set_expanded(expanded: bool) -> void:
	if expanded == _expanded:
		return
	_expanded = expanded
	_apply()
	expanded_changed.emit(_expanded)


## Moves an existing control into the section.
func adopt(control: Control) -> void:
	if control == null:
		return
	if control.get_parent() == null:
		content.add_child(control)
	else:
		control.reparent(content, false)


func _on_header_toggled(pressed: bool) -> void:
	set_expanded(pressed)


func _apply() -> void:
	_header.set_pressed_no_signal(_expanded)
	_header.text = "%s  %s%s" % ["▾" if _expanded else "▸", _title, ("  ·  " + _badge) if not _badge.is_empty() else ""]
	content.visible = _expanded

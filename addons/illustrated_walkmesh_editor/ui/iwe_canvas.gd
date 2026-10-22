@tool
extends Control

signal zoom_requested(factor: float)

var _texture: Texture2D
var _zoom := 1.0
var _dragging := false


func set_texture(texture: Texture2D) -> void:
	_texture = texture
	_update_minimum_size()
	queue_redraw()


func set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.1, 8.0)
	_update_minimum_size()
	queue_redraw()


func _update_minimum_size() -> void:
	if _texture:
		custom_minimum_size = Vector2(_texture.get_size()) * _zoom
	else:
		custom_minimum_size = Vector2(320.0, 240.0)
	update_minimum_size()


func _draw() -> void:
	if _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(_texture.get_size()) * _zoom), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("252a33"), true)
		draw_string(ThemeDB.fallback_font, Vector2(16, 32), "Import an illustration to begin", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c5ccd8"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var scroll := get_parent() as ScrollContainer
		if scroll:
			scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal - roundi(event.relative.x))
			scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - roundi(event.relative.y))
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_requested.emit(1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
		accept_event()

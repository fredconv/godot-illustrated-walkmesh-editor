class_name IWETransitionZone2D
extends Area2D
## The 2D twin of IWETransitionZone, for scenes exported as flat 2D. Same group, same signals, same
## rules: see IWETransitionZone and IWEStageTravel.

signal triggered(zone: IWETransitionZone2D, body: Node2D)

@export var zone_id := ""
@export var action := IWEActionZone.ACTION_SCENE_TRANSITION
@export_file("*.tscn", "*.scn") var target_scene := ""
@export var entry_id := ""
@export var enabled := true
@export var trigger_group := "iwe_traveller"
@export var auto_handle := true
@export var params: Dictionary = {}

var _fired := false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func rearm() -> void:
	_fired = false


func has_fired() -> bool:
	return _fired


func _on_body_entered(body: Node2D) -> void:
	if not enabled or _fired:
		return
	if not trigger_group.is_empty() and not body.is_in_group(trigger_group):
		return
	if IWEStageTravel.is_traveling:
		return
	_fired = true
	triggered.emit(self, body)
	if auto_handle:
		if not IWEStageTravel.handle_action(get_tree(), action, target_scene, entry_id) and IWEActionZone.is_known_action(action):
			_fired = false

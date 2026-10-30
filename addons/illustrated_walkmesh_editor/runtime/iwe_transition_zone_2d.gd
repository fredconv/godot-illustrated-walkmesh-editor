class_name IWETransitionZone2D
extends Area2D
## The 2D twin of IWETransitionZone, for scenes exported as flat 2D. Same group, same signals, same
## rules: see IWETransitionZone and IWEStageTravel.

signal triggered(zone: IWETransitionZone2D, body: Node2D)
## Emitted, after `triggered`, by a zone whose action is `event`: the name chosen in the editor, the zone and
## the body that entered. This is how a game reacts to "explosion" or "open_gate".
signal event_fired(event_name: String, zone: IWETransitionZone2D, body: Node2D)

@export var zone_id := ""
@export var action := IWEActionZone.ACTION_SCENE_TRANSITION
@export_file("*.tscn", "*.scn") var target_scene := ""
@export var entry_id := ""
@export var enabled := true
@export var trigger_group := "iwe_traveller"
## The name of the event of an `event` zone (copied from the document).
@export var event_name := ""
## An event zone fires once by default; with this on it fires again every time a traveller enters it.
@export var repeat := false
@export var auto_handle := true
@export var params: Dictionary = {}

var _fired := false


func _ready() -> void:
	# Every zone is findable by a game that wants to listen to all of them:
	#   for zone in get_tree().get_nodes_in_group("iwe_action_zone"): zone.event_fired.connect(...)
	add_to_group(&"iwe_action_zone")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


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
	if action == IWEActionZone.ACTION_EVENT:
		event_fired.emit(event_name, self, body)
	elif auto_handle:
		if not IWEStageTravel.handle_action(get_tree(), action, target_scene, entry_id) and IWEActionZone.is_known_action(action):
			_fired = false


func _on_body_exited(body: Node2D) -> void:
	# A repeating event is armed again once the traveller has left.
	if repeat and action == IWEActionZone.ACTION_EVENT and (trigger_group.is_empty() or body.is_in_group(trigger_group)):
		_fired = false

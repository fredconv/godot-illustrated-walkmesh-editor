class_name IWETransitionZone
extends Area3D
## Detects a traveller walking into a zone and runs the zone's action. An exported IWE stage holds one
## per action zone of the document; you can also add one by hand to any 3D scene.
##
## The zone reacts to nodes of the group `iwe_traveller` (see IWEStageTravel). It does not care what
## the character is: a CharacterBody3D with any controller works once it joins that group. To react to
## every body instead, empty `trigger_group`. To handle the event yourself (a fade, a confirmation, a
## cutscene), connect `triggered` and turn `auto_handle` off.
##
## A zone fires once. It is armed again by `rearm()`, and a second zone cannot fire while a travel is
## under way, so walking along two touching zones never loads two scenes.

signal triggered(zone: IWETransitionZone, body: Node3D)

## Identifier of the action zone in the IWE document, "" for a zone added by hand.
@export var zone_id := ""
## IWEActionZone.ACTION_SCENE_TRANSITION ("scene_transition"), ACTION_WARP ("warp"), or an action of
## your own: only `triggered` fires for those.
@export var action := IWEActionZone.ACTION_SCENE_TRANSITION
@export_file("*.tscn", "*.scn") var target_scene := ""
@export var entry_id := ""
@export var enabled := true
@export var trigger_group := "iwe_traveller"
## Run the action when triggered. Turn it off to handle `triggered` yourself.
@export var auto_handle := true
## Free-form settings of the action (copied from the document).
@export var params: Dictionary = {}

var _fired := false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


## Arms the zone again after it fired (a zone that stays in the scene after a warp, for example).
func rearm() -> void:
	_fired = false


func has_fired() -> bool:
	return _fired


func _on_body_entered(body: Node3D) -> void:
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
			# The action could not start (no scene, missing file): the zone may be tried again.
			_fired = false

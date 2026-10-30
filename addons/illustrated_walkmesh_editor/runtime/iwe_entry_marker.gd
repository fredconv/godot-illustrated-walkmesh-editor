@tool
class_name IWEEntryMarker
extends Marker3D
## A place where travellers appear when they arrive in this scene (docs/STAGE_TRANSITIONS.md). A
## transition zone of another scene names it by `entry_id`. Exported IWE stages hold one per entry
## point of the document; add one by hand to any 3D scene of your game to make it a destination.

## The name a transition zone uses to arrive here. Keep it unique inside the scene.
@export var entry_id := "entry"
## Used when a transition names no entry point or one this scene does not have.
@export var is_default := false
## Direction the traveller faces on arrival, in degrees around the vertical axis. NAN keeps its own.
@export var facing_degrees := NAN


func _enter_tree() -> void:
	add_to_group(IWEStageTravel.ENTRY_GROUP)

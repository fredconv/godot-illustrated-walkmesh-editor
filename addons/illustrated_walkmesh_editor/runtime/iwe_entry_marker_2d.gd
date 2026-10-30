@tool
class_name IWEEntryMarker2D
extends Marker2D
## The 2D twin of IWEEntryMarker, for scenes exported as flat 2D.

@export var entry_id := "entry"
@export var is_default := false
@export var facing_degrees := NAN


func _enter_tree() -> void:
	add_to_group(IWEStageTravel.ENTRY_GROUP)

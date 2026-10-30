@tool
class_name IWEEntryPoint
extends Resource
## A place where a character appears when it arrives in this scene: the far end of a door, the
## bottom of a staircase. A transition zone of another scene names it by `entry_id`.
##
## `id` identifies the entry point inside the document (stable, never shown); `entry_id` is the name
## other scenes use, so it is the part of the contract that must not change once a game refers to it.

@export var id := ""
## The name a transition zone uses to arrive here ("from_village"). Unique in a document.
@export var entry_id := "entry"
## Position on the illustration, in illustration pixels (the floor point where the feet appear).
@export var position := Vector2.ZERO
## Direction the traveller faces on arrival, in degrees around the vertical axis. NAN keeps the
## traveller's own direction.
@export var facing_degrees := NAN
## The entry point used when a transition names none, or names one that does not exist.
@export var is_default := false


static func create_entry(entry_name: String, image_position: Vector2) -> IWEEntryPoint:
	var entry := IWEEntryPoint.new()
	entry.id = "entry_%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	entry.entry_id = entry_name
	entry.position = image_position
	return entry


func has_facing() -> bool:
	return not is_nan(facing_degrees)

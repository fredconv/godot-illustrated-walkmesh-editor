@tool
class_name IWERegion
extends Resource

@export var id := ""
@export var name := "Region"
@export var points := PackedVector2Array()
@export var color := Color("45d483")
@export var visible := true
@export var locked := false


func duplicate_region() -> IWERegion:
	var copy := duplicate(true) as IWERegion
	copy.id = _new_id()
	copy.name = "%s Copy" % name
	return copy


static func _new_id() -> String:
	return "region_%s" % Crypto.new().generate_random_bytes(8).hex_encode()

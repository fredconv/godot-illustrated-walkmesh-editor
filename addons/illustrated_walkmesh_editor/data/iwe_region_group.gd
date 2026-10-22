@tool
class_name IWERegionGroup
extends Resource

@export var id := ""
@export var name := "Group"


static func create_group(group_name: String) -> IWERegionGroup:
	var group := IWERegionGroup.new()
	group.id = "group_%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	group.name = group_name
	return group

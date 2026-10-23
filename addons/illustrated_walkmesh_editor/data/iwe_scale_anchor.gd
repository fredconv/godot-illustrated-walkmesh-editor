@tool
class_name IWEScaleAnchor
extends Resource

@export var id := ""
@export var name := "Template"
@export var position := Vector2.ZERO
@export_range(1.0, 10000.0, 1.0) var apparent_height_px := 160.0


static func create_anchor(anchor_position: Vector2, height_px: float = 160.0) -> IWEScaleAnchor:
	var anchor := IWEScaleAnchor.new()
	anchor.id = "scale_%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	anchor.position = anchor_position
	anchor.apparent_height_px = maxf(height_px, 1.0)
	return anchor

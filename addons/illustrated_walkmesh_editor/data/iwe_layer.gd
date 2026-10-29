@tool
class_name IWELayer
extends Resource
## A visual layer: it groups visual elements (transparent pictures) and decides whether they show.
## Layers are about appearance only. Navigation never reads them (docs/LAYER_MANAGER_DESIGN.md 3.2).

enum Kind { BACKGROUND, FOREGROUND }

## Stable identifiers of the two layers every document has. A fixed value keeps the migration of a
## version 1 document repeatable: opening it twice gives the same layers.
const BACKGROUND_ID := "layer_background"
const FOREGROUND_ID := "layer_foreground"

@export var id := ""
@export var name := "Layer"
## What new elements of this layer do by default: stay behind the character, or in front of it.
@export var kind: Kind = Kind.FOREGROUND
@export var visible := true
@export var locked := false
@export_range(0.0, 1.0, 0.01) var opacity := 1.0


static func create_layer(layer_name: String, layer_kind: Kind) -> IWELayer:
	var layer := IWELayer.new()
	layer.id = "layer_%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	layer.name = layer_name
	layer.kind = layer_kind
	return layer


static func create_default_background() -> IWELayer:
	var layer := IWELayer.new()
	layer.id = BACKGROUND_ID
	layer.name = "Background"
	layer.kind = Kind.BACKGROUND
	return layer


static func create_default_foreground() -> IWELayer:
	var layer := IWELayer.new()
	layer.id = FOREGROUND_ID
	layer.name = "Foreground"
	layer.kind = Kind.FOREGROUND
	return layer

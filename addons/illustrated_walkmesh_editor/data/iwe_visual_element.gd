@tool
class_name IWEVisualElement
extends Resource
## A transparent picture placed on the illustration: a fountain, a tree, a railing. It is drawn, never
## walked on: it produces no navigation and no collision (docs/LAYER_MANAGER_DESIGN.md 3.2).
##
## All positions are in pixels of the illustration. The picture is copied into the document's
## assets/elements folder when the document is saved, and texture_path then becomes relative.

## How the element is drawn relative to the character in the perspective stage.
## BEHIND: always behind the character. IN_FRONT: always in front. DEPTH: in front of the character
## when the character stands nearer to the camera than the element's ground anchor, behind it when
## farther (a character walks behind a fountain, then in front of it).
enum DepthMode { BEHIND, IN_FRONT, DEPTH }

@export var id := ""
@export var name := "Element"
@export var layer_id := ""
## Relative to the document once saved (assets/elements/<hash>.png), the source file before that.
@export var texture_path := ""
## Top-left corner of the picture on the illustration, in illustration pixels.
@export var position := Vector2.ZERO
## Size of the picture in its own pixels. Stored so an element can be placed without loading it.
@export var texture_size := Vector2i.ZERO
@export var scale := Vector2.ONE
@export_range(0.0, 1.0, 0.01) var opacity := 1.0
@export var depth_mode: DepthMode = DepthMode.DEPTH
## The point where the element touches the floor, in illustration pixels. Only DEPTH uses it: the
## floor distance of this point to the camera decides who is in front. NAN means "bottom centre".
@export var ground_anchor := Vector2(NAN, NAN)


static func create_element(element_name: String, path: String, size: Vector2i, layer: String, mode: DepthMode) -> IWEVisualElement:
	var element := IWEVisualElement.new()
	element.id = "element_%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	element.name = element_name
	element.texture_path = path
	element.texture_size = size
	element.layer_id = layer
	element.depth_mode = mode
	return element


## Size on the illustration, in illustration pixels.
func get_display_size() -> Vector2:
	return Vector2(texture_size) * scale


func get_rect() -> Rect2:
	return Rect2(position, get_display_size())


## The ground anchor, or the bottom centre of the picture when none was chosen.
func get_effective_ground_anchor() -> Vector2:
	if is_nan(ground_anchor.x) or is_nan(ground_anchor.y):
		var rect := get_rect()
		return Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)
	return ground_anchor

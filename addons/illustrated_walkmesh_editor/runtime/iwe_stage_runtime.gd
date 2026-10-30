class_name IWEStageRuntime
extends Node
## Put one in every scene that can be reached by a transition (exported IWE stages already hold one).
## When the scene is ready it applies the pending arrival: every node of the group `iwe_traveller` is
## moved to the entry point the transition asked for (docs/STAGE_TRANSITIONS.md).
##
## A scene that is not reached by a transition (the first scene of the game) is left as it is.

## `entry_id` is the entry point that was used, `fallback` tells how it was found: "none" (the one that
## was asked for), "default", "first" or "missing" (see IWEStageTravel.place_travellers).
signal arrival_applied(entry_id: String, fallback: String, placed: int)

## Turn off to place the travellers yourself (call `apply_arrival()` when you are ready).
@export var apply_on_ready := true


func _ready() -> void:
	if apply_on_ready:
		# Deferred so every traveller and entry marker of the scene has entered the tree.
		apply_arrival.call_deferred()


## Applies the pending arrival, if a transition asked for one. Returns false when there was none.
func apply_arrival() -> bool:
	if not is_inside_tree() or not IWEStageTravel.arrival_pending:
		return false
	var result := IWEStageTravel.place_travellers(get_tree(), IWEStageTravel.pending_entry_id)
	IWEStageTravel.finish()
	arrival_applied.emit(result["entry_id"], result["fallback"], result["placed"])
	return true


## Moves the travellers to an entry point of this scene without a scene change.
func warp_to(entry_id: String) -> bool:
	return IWEStageTravel.warp(get_tree(), entry_id)

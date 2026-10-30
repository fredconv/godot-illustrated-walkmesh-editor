@tool
class_name IWEDocumentHistory
extends RefCounted
## Undo history of one IWE document, plus the "has it changed since it was saved" state.
##
## Godot's UndoRedo.get_version() goes up on commit and redo and down on undo, so returning to
## the saved version means the document is back at its saved state. That is only true while the
## saved state is still reachable. Saved at version 2, undo to 1, then commit a new action: the
## version is 2 again but the content is different. A new action while a redo is pending
## therefore discards the saved state (_saved_version = UNREACHABLE).

signal changed

const UNREACHABLE := -1

var _undo := UndoRedo.new()
var _saved_version: int = _undo.get_version()
## Changes that do not go through the history (importing an illustration, for example).
## Undo cannot revert them, so they keep the document modified until it is saved.
var _untracked_changes := false


## merge_mode: UndoRedo.MERGE_ENDS folds consecutive actions with the same name into one entry
## (the first undo and the last do are kept), so a run of small steps undoes in one go.
func create_action(action_name: String, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE) -> void:
	_undo.create_action(action_name, merge_mode)


func add_do_method(callable: Callable) -> void:
	_undo.add_do_method(callable)


func add_undo_method(callable: Callable) -> void:
	_undo.add_undo_method(callable)


func commit_action() -> void:
	if _undo.has_redo() and _saved_version > _undo.get_version():
		_saved_version = UNREACHABLE
	_undo.commit_action()
	changed.emit()


func undo() -> void:
	_undo.undo()
	changed.emit()


func redo() -> void:
	_undo.redo()
	changed.emit()


func has_undo() -> bool:
	return _undo.has_undo()


func has_redo() -> bool:
	return _undo.has_redo()


func is_dirty() -> bool:
	return _untracked_changes or _undo.get_version() != _saved_version


## Records a change that is not in the history. The document stays modified until saved.
func note_untracked_change() -> void:
	_untracked_changes = true
	changed.emit()


## Call only after the document was written successfully.
func mark_saved() -> void:
	_saved_version = _undo.get_version()
	_untracked_changes = false
	changed.emit()


## Frees the history and every action it holds, so nothing can run against another document.
func dispose() -> void:
	if _undo != null:
		_undo.free()
		_undo = null


func _notification(what: int) -> void:
	# Do not call dispose() here: the script instance is already being torn down.
	if what == NOTIFICATION_PREDELETE and _undo != null:
		_undo.free()

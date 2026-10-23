extends RefCounted

var _current_do: Callable
var _current_undo: Callable
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []


func create_action(_name: String, _merge_mode: int = 0, _context: Object = null) -> void:
	_current_do = Callable()
	_current_undo = Callable()


func add_do_method(target: Object, method: StringName, argument: Variant = null, second_argument: Variant = null) -> void:
	_current_do = Callable(target, method).bind(argument, second_argument) if second_argument != null else Callable(target, method).bind(argument)


func add_undo_method(target: Object, method: StringName, argument: Variant = null, second_argument: Variant = null) -> void:
	_current_undo = Callable(target, method).bind(argument, second_argument) if second_argument != null else Callable(target, method).bind(argument)


func commit_action() -> void:
	_current_do.call()
	_undo_stack.append({"do": _current_do, "undo": _current_undo})
	_redo_stack.clear()


func undo(_context: Object = null) -> void:
	if _undo_stack.is_empty():
		return
	var action: Dictionary = _undo_stack.pop_back()
	action["undo"].call()
	_redo_stack.append(action)


func redo(_context: Object = null) -> void:
	if _redo_stack.is_empty():
		return
	var action: Dictionary = _redo_stack.pop_back()
	action["do"].call()
	_undo_stack.append(action)

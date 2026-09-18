extends Node
## Autoload "UiStack" — which screen currently owns the keyboard.
##
## The journal, the inventory, the pause board, the fishing minigame, a
## dialogue balloon and a cutscene each used to read input on their own,
## with no idea of one another — so [Esc] over the open journal opened the
## pause board on top of it, and [J] mid-cast opened the journal over the
## minigame. Now each one pushes its name while it is up and pops it when it
## goes, and asks before acting:
##
##   UiStack.is_free()        nothing modal is up — the world has the keys
##   UiStack.is_top("journal") the journal is the topmost thing
##
## Dialogue and cutscenes are tracked here from their signals, so nothing
## else needs to know they exist.

var _stack: Array[String] = []


func push(name: String) -> void:
	_stack.erase(name)
	_stack.append(name)


func pop(name: String) -> void:
	_stack.erase(name)


func top() -> String:
	return _stack.back() if not _stack.is_empty() else ""


func is_free() -> bool:
	return _stack.is_empty()


func is_top(name: String) -> bool:
	return top() == name


func has(name: String) -> bool:
	return _stack.has(name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The other autoloads are not in the tree yet when this one is; hook the
	# dialogue signals once everything is.
	call_deferred("_hook")


func _hook() -> void:
	var dm := get_node_or_null("/root/DialogueManager")
	if dm:
		dm.dialogue_started.connect(func(_r): push("dialogue"))
		dm.dialogue_ended.connect(func(_r): pop("dialogue"))

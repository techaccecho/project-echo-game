extends Node
## Autoload "Flags" — what the player has done to the world.
##
## A flag is a name that is either set or not: "level2.rubble_cleared",
## "blacksmith.axe_given", a felled tree keyed by where it stands. Things that
## change the world set one when they change it and check it when they load,
## so the change survives leaving the level and comes back with a save. Before
## this, every level was rebuilt fresh each time it loaded.
##
## Flags carry no values on purpose; a counter or a choice belongs in the
## save as its own field, not smuggled into a flag name.

signal changed(flag: String)

var _set: Dictionary = {}


func has(flag: String) -> bool:
	return _set.has(flag)


func set_flag(flag: String, value: bool = true) -> void:
	if value == _set.has(flag):
		return
	if value:
		_set[flag] = true
	else:
		_set.erase(flag)
	changed.emit(flag)


func unset(flag: String) -> void:
	set_flag(flag, false)


## Every flag that is set, for the save.
func all() -> Array:
	return _set.keys()


## Replace the lot: loading a save, or a new game with an empty list.
func restore(flags: Array) -> void:
	_set.clear()
	for f in flags:
		_set[str(f)] = true


## A stable name for one node in one level, so a tree or a bush can remember
## its own state: the level's scene file plus the node's path inside it.
func key_for(node: Node) -> String:
	var scene := node.get_tree().current_scene
	var level := scene
	# Inside the shell the level is one down, under LevelHolder.
	if SceneManager.level_holder != null and SceneManager.level_holder.get_child_count() > 0 \
			and SceneManager.level_holder.is_ancestor_of(node):
		level = SceneManager.level_holder.get_child(0)
	return "%s#%s" % [level.scene_file_path.get_file().get_basename(), level.get_path_to(node)]

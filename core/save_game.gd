extends Node
## Autoload "SaveGame" — one save slot on disk.
##
## What a save is: where the player is (which scene, and if it is the shell,
## which level inside it, plus his position), what he is carrying, and which
## of Cedric's pages he has found. That is everything the game keeps between
## scenes today, so it is everything a save needs. What it does not keep —
## trees chopped, a cleared rubble wall, a chest already opened — is rebuilt
## fresh when a level loads, which is also what happens when you walk back
## into a level without saving.
##
## Written with ConfigFile rather than a binary resource so a save can be read
## and hand-fixed in a text editor while the game is still changing shape.

const PATH := "user://save.cfg"
const VERSION := 1
const SHELL := "res://world/game.tscn"

## The inventory the player node's `inv` export points at. Preloaded here for
## the same reason EchoLog does it: it is the one copy, and writing to it is
## writing to the player's.
const PLAYER_INV := preload("res://inventory/player_inv.tres")


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


## When the slot was written, as a unix time, or 0 with no save.
func saved_at() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value("meta", "time", 0))


## Whether saving makes sense right now: there is a player, and he is under
## his own control — not mid-arrival, mid-fall or mid-cutscene.
func can_save() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and p.get("movement_enabled") == true


func save() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "time", int(Time.get_unix_time_from_system()))

	var root := get_tree().current_scene
	var in_shell := root != null and root.scene_file_path == SHELL
	cfg.set_value("where", "scene", root.scene_file_path if root else "")
	cfg.set_value("where", "in_shell", in_shell)
	var level := ""
	if in_shell and SceneManager.level_holder != null \
			and SceneManager.level_holder.get_child_count() > 0:
		level = SceneManager.level_holder.get_child(0).scene_file_path
	cfg.set_value("where", "level", level)
	cfg.set_value("where", "x", p.global_position.x)
	cfg.set_value("where", "y", p.global_position.y)
	cfg.set_value("where", "label", _label_for(root, level))

	var slots := []
	for slot in PLAYER_INV.slots:
		if slot != null and slot.item != null and slot.amount > 0 \
				and slot.item.resource_path != "":
			slots.append({"item": slot.item.resource_path, "amount": slot.amount})
	cfg.set_value("inventory", "slots", slots)
	cfg.set_value("echo", "found", EchoLog.found_ids())
	return cfg.save(PATH) == OK


## Restore the slot and travel to where it was made. Await it.
func load_and_resume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	_restore_inventory(cfg.get_value("inventory", "slots", []))
	EchoLog.restore(cfg.get_value("echo", "found", []))
	var at := Vector2(cfg.get_value("where", "x", 0.0), cfg.get_value("where", "y", 0.0))
	var scene: String = cfg.get_value("where", "scene", "")
	var level: String = cfg.get_value("where", "level", "")
	if scene == "":
		return
	SceneManager.pending_position = at
	if cfg.get_value("where", "in_shell", false) and level != "":
		await SceneManager.enter_shell(level)
	else:
		await SceneManager.exit_to(scene)


## A fresh run: nothing carried, nothing found. Called by start_game() so a
## new game after a loaded one does not inherit its bag.
func new_game() -> void:
	_restore_inventory([])
	EchoLog.restore([])


# --- helpers ----------------------------------------------------------------

func _restore_inventory(saved: Array) -> void:
	for slot in PLAYER_INV.slots:
		if slot != null:
			slot.item = null
			slot.amount = 0
	var i := 0
	for entry in saved:
		if i >= PLAYER_INV.slots.size():
			break
		var item = load(str(entry.get("item", "")))
		if not (item is InvItem):
			continue
		PLAYER_INV.slots[i].item = item
		PLAYER_INV.slots[i].amount = int(entry.get("amount", 1))
		i += 1
	PLAYER_INV.update.emit()


func _label_for(root: Node, level: String) -> String:
	var path := level if level != "" else (root.scene_file_path if root else "")
	match path:
		"res://world/game_world.tscn": return "Hearth Hollow"
		"res://world/blacksmith_interior.tscn": return "The blacksmith's house"
		"res://world/game_level_2.tscn": return "The Cliffside Path"
	return path.get_file().get_basename()

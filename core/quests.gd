extends Node
## Autoload "Quests" — the player's task list, read from the pause menu.
##
## Nothing is stored here. A step is done when the world flag (or fragment
## count) it names says so, so the list follows saves and old runs for free.
## Steps are strictly in order: the list shown is every step up to and
## including the first one not yet done, which is the current quest.

## Each level: a title and its steps. A step is {text, done}, where `done` is
## a Callable returning bool.
var _levels: Array[Dictionary] = [
	{"title": "Level 1", "steps": [
		_step("Talk to Jory", _flag("hollow.greeter_met")),
		_step("Meet the blacksmith", _flag("blacksmith.quest_offered")),
		_step("Find the fishing hut", _flag("visited.fishing_hut_interior")),
		_step("Trade with the blacksmith", _flag("blacksmith.fish_paid")),
		_step("Explore the forest", _flag("forest.key_found")),
		_step("Find the next case to explore", _flag("level2.arrived")),
	]},
	{"title": "Level 2", "steps": [
		_step("Speak to the Forester", _flag("forester.met")),
		_step("Find the next case to explore", _flag("level3.arrived")),
	]},
	{"title": "Level 3", "steps": [
		_step("Find a torch", _flag("pickup.fishing_hut_interior.Lamp")),
		_step("Find oil for the torch", _flag("lamp.oil_found")),
		_step("Find all fragments", _all_fragments),
		_step("Place all fragments", _flag("level3.gate_open")),
	]},
]


## What the menu shows: [{title, steps: [{text, done}]}], cut off after the
## current quest. Levels with nothing visible yet are left out.
func visible_levels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var reached_current := false
	for level in _levels:
		var steps: Array[Dictionary] = []
		for s in level["steps"]:
			if reached_current:
				break
			var done: bool = s["done"].call()
			steps.append({"text": s["text"], "done": done})
			if not done:
				reached_current = true
		if not steps.is_empty():
			out.append({"title": level["title"], "steps": steps})
	return out


## The text of the current quest, or "" when there is nothing left to do.
func current_text() -> String:
	for level in _levels:
		for s in level["steps"]:
			if not s["done"].call():
				return s["text"]
	return ""


## True once every step in every level is done.
func all_done() -> bool:
	for level in _levels:
		for s in level["steps"]:
			if not s["done"].call():
				return false
	return true


func _step(text: String, done: Callable) -> Dictionary:
	return {"text": text, "done": done}


func _flag(name: String) -> Callable:
	return func() -> bool: return Flags.has(name)


func _all_fragments() -> bool:
	return EchoLog.fragments.size() > 0 and EchoLog.found_count() >= EchoLog.fragments.size()

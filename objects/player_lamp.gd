extends NightLight
## The lamp the player carries. A NightLight that only burns while the lamp
## is in his bag — before he finds it, night is night. Hangs off the player
## node, so it goes wherever he goes, indoors included, where DayLight's
## absence keeps it dark.

@export var lamp_item: InvItem


func _process(delta: float) -> void:
	var holder: Node = get_parent()
	var inv = holder.get("inv") if holder else null
	lit = lamp_item != null and inv != null and inv.has(lamp_item)
	super._process(delta)

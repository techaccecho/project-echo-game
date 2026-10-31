extends NightLight
## The lamp the player carries. A NightLight that only burns while the Lamp
## autoload says it is lit: he has it in his bag, he has lit it, and there is
## oil left. Hangs off the player node, so it goes wherever he goes, indoors
## included, where DayLight's absence keeps it dark.
##
## The pool of light shrinks as the oil runs down, and once it is low the flame
## starts guttering — NightLight's `faulty` — which is the warning to top it up.

## Kept for the scenes that still set it; the Lamp autoload has the same item.
@export var lamp_item: InvItem
## How much of the full reach is left when the lamp is all but empty.
@export_range(0.1, 1.0) var min_reach: float = 0.55

var _full_scale := 1.0


func _ready() -> void:
	super._ready()
	_full_scale = texture_scale


func _process(delta: float) -> void:
	lit = Lamp.is_lit()
	var low := lit and Lamp.is_low()
	if faulty and not low:
		# Leaving the guttering mid cut-out would strand the flame dark.
		_lit = 1.0
	faulty = low
	texture_scale = _full_scale * lerpf(min_reach, 1.0, clampf(Lamp.fraction(), 0.0, 1.0))
	super._process(delta)

class_name HurtComponent
extends Area2D

@export var tool : DataTypes.Tools = DataTypes.Tools.NONE

## False while whatever owns this cannot take another hit — felled already, or
## still playing out the one before. A blade that touches it then passes
## through instead of spending its swing on something that will throw the
## damage away. Only the owner knows, so the owner sets it.
var hittable: bool = true

signal hurt


func _on_area_entered(area: Area2D) -> void:
	var hit_component = area as HitComponent
	if not hittable:
		return
	if tool != hit_component.current_tool:
		return
	# Ask before taking it. Every HurtComponent the blade is touching gets this
	# call in the same frame, and the swing only has so many to give — without
	# the question, one stroke fells everything standing in the arc.
	if not hit_component.claim():
		return
	hurt.emit(hit_component.hit_damage)

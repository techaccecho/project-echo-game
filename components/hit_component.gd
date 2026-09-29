class_name HitComponent
extends Area2D

@export var current_tool : DataTypes.Tools = DataTypes.Tools.NONE
@export var hit_damage : int = 1
## How many things one swing is allowed to bite into. 1 is a woodsman's axe:
## it lands on the one tree in front of him, however many are crowded around
## the blade. Raise it for an upgraded axe that clears a thicket in a stroke;
## 0 lifts the limit entirely, which is what every swing did before there was
## one.
@export var max_targets : int = 1

## Targets claimed since the swing began, counted so the limit survives several
## HurtComponents answering the same overlap in the same frame.
var _claimed : int = 0


## Open a fresh swing. Whatever the last one hit stops counting against this
## one, so call it as the blade comes out rather than when it lands.
func begin_swing() -> void:
	_claimed = 0


## Asked by a HurtComponent before it takes the damage. Answers false once the
## swing has bitten as deep as it is allowed to, which is what stops the rest
## of the grove going over with the tree that was aimed at.
func claim() -> bool:
	if max_targets > 0 and _claimed >= max_targets:
		return false
	_claimed += 1
	return true

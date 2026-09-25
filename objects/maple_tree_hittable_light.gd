class_name MapleTreeHittableLight
extends AnimatedSprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent
@onready var collision_shape: CollisionShape2D = $TreeBody/CollisionShape

## Already a stump when the level loads — somebody else cut this one, and a
## long time ago. Dressing, not an obstacle.
@export var starts_felled: bool = false

var being_hit: bool = false
var max_reached: bool = false

func _ready() -> void:
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damage_reached.connect(on_max_damage_reached)
	# Felled on an earlier visit, or cut by whoever came through before him:
	# straight to the stump.
	if starts_felled or Flags.has(Flags.key_for(self)):
		max_reached = true
		# "trunk" is the whole chop-down, and its first frame is the standing
		# tree — so it has to be wound on to the stump, not just selected.
		animation = "trunk"
		frame = sprite_frames.get_frame_count("trunk") - 1
		collision_shape.disabled = true

func on_hurt(hit_damage: int) -> void:
	if being_hit || max_reached:
		return
	
	being_hit = true
	
	var new_damage = damage_component.current_damage + hit_damage
	print("new_damage: ", new_damage)
	if (new_damage >= damage_component.max_damage):
		play("trunk")
	else:
		play("shake")
	await(animation_finished)
	damage_component.apply_damage(hit_damage)
	being_hit = false

func on_max_damage_reached() -> void:
	max_reached = true
	collision_shape.disabled = true
	Flags.set_flag(Flags.key_for(self))

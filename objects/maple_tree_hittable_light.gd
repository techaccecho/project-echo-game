class_name MapleTreeHittableLight
extends AnimatedSprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent
@onready var collision_shape: CollisionShape2D = $TreeBody/CollisionShape

var being_hit: bool = false
var max_reached: bool = false

func _ready() -> void:
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damage_reached.connect(on_max_damage_reached)
	# Felled on an earlier visit: straight to the stump.
	if Flags.has(Flags.key_for(self)):
		max_reached = true
		animation = "trunk"
		# The last frame of it, not the first. "trunk" is the felling itself —
		# it opens on the tree still standing and only reaches the stump at the
		# end — so naming the animation without choosing a frame puts a whole
		# tree back up over the collision that was just taken away.
		frame = sprite_frames.get_frame_count("trunk") - 1
		collision_shape.disabled = true
		hurt_component.hittable = false

func on_hurt(hit_damage: int) -> void:
	if being_hit || max_reached:
		return

	being_hit = true
	# Stand aside for the rest of this animation. The next stroke should find
	# whatever is behind rather than be swallowed by a tree already falling.
	hurt_component.hittable = false

	var new_damage = damage_component.current_damage + hit_damage
	print("new_damage: ", new_damage)
	if (new_damage >= damage_component.max_damage):
		play("trunk")
	else:
		play("shake")
	await(animation_finished)
	damage_component.apply_damage(hit_damage)
	being_hit = false
	# Back to answering the axe — unless that was the stroke that felled it.
	hurt_component.hittable = not max_reached

func on_max_damage_reached() -> void:
	max_reached = true
	collision_shape.disabled = true
	# The stump keeps its hurt box exactly where the standing tree's was. Left
	# answering, it goes on taking hits it cannot use — and now that a swing
	# lands on one thing only, it takes them from the tree still standing next
	# to it.
	hurt_component.hittable = false
	Flags.set_flag(Flags.key_for(self))

class_name BushBreakable
extends AnimatedSprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent
@onready var collision_shape: CollisionShape2D = $Body/Rectangle
@onready var ground_mark: Sprite2D = $OpenGround

var being_hit: bool = false
var max_reached: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damage_reached.connect(on_max_damage_reached)
	ground_mark.visible = false
	# Cleared on an earlier visit: straight to bare ground.
	if Flags.has(Flags.key_for(self)):
		max_reached = true
		animation = "removed"
		frame = sprite_frames.get_frame_count("removed") - 1
		collision_shape.disabled = true
		ground_mark.visible = true
		hurt_component.hittable = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func on_hurt(hit_damage: int) -> void:
	if (being_hit || max_reached):
		return
	
	being_hit = true
	# Stand aside for the rest of this animation, so the next swing reaches
	# past rather than being swallowed by a bush already coming apart.
	hurt_component.hittable = false

	var new_damage = damage_component.current_damage + hit_damage
	if (new_damage >= damage_component.max_damage):
		play("removed")
	else:
		play("shake")
	await(animation_finished)
	damage_component.apply_damage(hit_damage)
	being_hit = false
	# Back to answering the axe — unless that was the blow that cleared it.
	hurt_component.hittable = not max_reached

func on_max_damage_reached() -> void:
	max_reached = true
	collision_shape.disabled = true
	ground_mark.visible = true
	# Bare ground keeps its hurt box where the bush was. Left answering, it
	# goes on taking hits it cannot use — and a swing that lands on one thing
	# only would lose them to it.
	hurt_component.hittable = false
	Flags.set_flag(Flags.key_for(self))

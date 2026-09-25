extends Node2D
class_name ItemPickup
## An inventory item lying on the ground, waiting to be picked up.
##
## The sprite is the item's own inventory icon, so a pickup always looks like
## the thing it puts in the bag — point it at an InvItem and that is all it
## needs. Taking it sets `taken_flag`, so whoever put it here can tell whether
## it is still lying about and knows not to hand out a second one.
##
## Something handed over rather than found gets thrown: see toss_from(), which
## the blacksmith uses to lob his spare axe at your feet.

## The item this hands over.
@export var item: InvItem
## Flag set once it has been taken. Leave empty for a pickup nobody needs to
## remember.
@export var taken_flag: String = ""
## What the prompt says.
@export var prompt: String = "pick up"

const PICKUP_SFX := "res://audio/sfx/page_pickup.wav"
## How long the throw takes, and how high it arcs.
const TOSS_TIME := 0.55
const TOSS_RISE := 18.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: InteractionArea = $InteractionArea

var _taken := false


func _ready() -> void:
	if item == null:
		push_warning("ItemPickup at %s has no item assigned." % position)
		queue_free()
		return
	if taken_flag != "" and Flags.has(taken_flag):
		queue_free()
		return
	sprite.texture = item.texture
	interaction_area.action_name = prompt
	interaction_area.interact = Callable(self, "_on_interact")
	_bob()


## Slow float, so a 16px tool still reads as "pick me up" against busy ground.
func _bob() -> void:
	var base := sprite.position.y
	var t := create_tween().set_loops()
	t.tween_property(sprite, "position:y", base - 3.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sprite, "position:y", base, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Fly in from `from` (a world point) and land here, turning end over end.
## The node is already where it lands; only the sprite travels. Await it.
func toss_from(from: Vector2) -> void:
	if not is_inside_tree():
		return
	# No picking it out of the air.
	interaction_area.monitoring = false
	var start := to_local(from)
	sprite.position = start

	# x straight through, y up fast and down faster — one parallel tween cannot
	# do that, so the two run as separate tweens, as the arrival hop does.
	var across := create_tween()
	across.tween_property(sprite, "position:x", 0.0, TOSS_TIME)
	var up := TOSS_TIME * 0.4
	var arc := create_tween()
	arc.tween_property(sprite, "position:y", start.y - TOSS_RISE, up) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(sprite, "position:y", 0.0, TOSS_TIME - up) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var spin := create_tween()
	spin.tween_property(sprite, "rotation_degrees", 360.0 * signf(-start.x), TOSS_TIME)
	await across.finished

	sprite.rotation_degrees = 0.0
	interaction_area.set_deferred("monitoring", true)
	_bob()


func _on_interact() -> void:
	if _taken:
		return
	_taken = true
	Audio.sfx(PICKUP_SFX, -4.0)
	interaction_area.queue_free()

	var t := create_tween().set_parallel()
	t.tween_property(sprite, "position:y", sprite.position.y - 10.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	await t.finished

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.collect(item)
	if taken_flag != "":
		Flags.set_flag(taken_flag)
	queue_free()

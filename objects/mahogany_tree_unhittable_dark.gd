extends AnimatedSprite2D
## Makes the (normally decorative) mahogany tree interactable.
##
## Mirrors the NPC interaction flow: an InteractionArea child registers with the
## InteractionManager while the player is close, and its `interact` callable is
## wired here. Because the area's input_action is "interact_alt", the player
## triggers it with the B key or a left mouse click. Interacting plays the
## tree's existing "hit" shake animation.

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact() -> void:
	# Play the shake, and stay "busy" (the manager awaits this) until it ends so
	# it can't be re-triggered mid-shake. The non-looping "hit" clip settles back
	# on its resting frame when finished.
	play("hit")
	await animation_finished

class_name MahoganyTreeUnhittableDark
extends AnimatedSprite2D

func _ready() -> void:
	pass

func _on_interact() -> void:
	# Play the shake, and stay "busy" (the manager awaits this) until it ends so
	# it can't be re-triggered mid-shake. The non-looping "hit" clip settles back
	# on its resting frame when finished.
	play("hit")
	await animation_finished

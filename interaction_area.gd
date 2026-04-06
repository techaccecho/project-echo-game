extends Area2D

class_name InteractionArea

# Text that will be shown above an object to show it can be interacted with
@export var action_name: String = "interact"

var interact: Callable = func():
	pass

func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player_josh")):
		InteractionManager.register_area(self)


func _on_body_exited(body: Node2D) -> void:
	if (body.is_in_group("player_josh")):
		InteractionManager.deregister_area(self)

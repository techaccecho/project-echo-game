extends Node2D
## Inside the blacksmith's house. A single room, entered through the front
## door in Level 1 and left by walking back out over the doormat.
##
## Standalone scene, like Level 1: it brings its own player and a camera that
## holds on the room rather than following. SceneManager.exit_to() carries the
## player between here and the level, and the shared inventory resource means
## whatever he is carrying comes with him.

const OUTSIDE := "res://world/game_world.tscn"
## Marker in Level 1 the player is put on when he steps out — the front step.
const OUTSIDE_SPAWN := "FrontDoor"

var _leaving := false


func _ready() -> void:
	SceneManager.on_standalone_ready()
	# He has just come in through the door behind him.
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set("last_direction", Vector2.UP)
		player.call("update_animation", Vector2.ZERO, false)


func _on_exit_body_entered(body: Node2D) -> void:
	if _leaving or not body.is_in_group("player"):
		return
	_leaving = true
	SceneManager.exit_to(OUTSIDE, OUTSIDE_SPAWN)

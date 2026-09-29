extends Node2D
## The Cliffside Path (Level 2). Player, camera and inventory UI belong to
## the shell (game.tscn); this owns the world and its triggers: leaving back
## down the tunnel, the look-at lines along the path, resting at the camp,
## and the first-arrival thought.

const STORY := "res://dialogue/cliffside.dialogue"
const FLAG_ARRIVED := "level2.arrived"

@onready var return_area: InteractionArea = $ReturnArea

var _player: CharacterBody2D
var _busy := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if return_area:
		return_area.interact = Callable(self, "_on_leave")
	for area in $Looks.get_children():
		area.interact = Callable(self, "_say_once").bind(area.name.to_lower())
	$Camp/RestArea.interact = Callable(self, "_rest")
	if not Flags.has(FLAG_ARRIVED):
		Flags.set_flag(FLAG_ARRIVED)
		call_deferred("_arrive")


func _arrive() -> void:
	# After the fade has lifted and he has stepped out of the tunnel.
	await get_tree().create_timer(0.6).timeout
	await _say("arrive")


func _on_leave() -> void:
	# Back down the tunnel to Level 1, onto its ReturnSpawn marker.
	SceneManager.exit_to("res://world/game_world.tscn", "ReturnSpawn")


## A look-at line plays in full the first time and not again.
func _say_once(title: String) -> void:
	var flag := "cliffside." + title
	if Flags.has(flag):
		return
	Flags.set_flag(flag)
	await _say(title)


## Rest by the Forester's fire until morning.
func _rest() -> void:
	if _busy or _player == null:
		return
	_busy = true
	_player.movement_enabled = false
	await _say("rest")
	_player.z_index += 1
	var seat: Vector2 = $Camp/RestArea.global_position + Vector2(0, -6)
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_player, "global_position", seat, 0.3)
	await t.finished
	_player.last_direction = Vector2.DOWN
	_player.hold_pose(_player.POSE_SIT_DOWN)
	await get_tree().create_timer(1.2).timeout
	await SceneManager.fade(1.0)
	await get_tree().create_timer(1.6).timeout
	Clock.sleep_until_morning()
	_player.release_pose()
	_player.z_index -= 1
	_player.global_position = seat + Vector2(0, 16)
	_player.last_direction = Vector2.DOWN
	_player.update_animation(Vector2.ZERO, false)
	await SceneManager.fade(0.0)
	await _say("rest_woke")
	_player.movement_enabled = true
	_busy = false


func _say(title: String) -> void:
	var res = load(STORY)
	if res == null:
		push_warning("GameLevel2: %s has not been imported yet." % STORY)
		return
	DialogueManager.show_dialogue_balloon(res, title, [self, _player])
	await DialogueManager.dialogue_ended

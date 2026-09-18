extends CharacterBody2D
## Jory — the one who stayed in Hearth Hollow. Sits by a patch of grass on
## the meadow up from the landing, playing a flute to nobody, and is the
## first person you meet: the town is empty, the road is shut, the
## Blacksmith is who to ask. Lines in dialogue/greeter.dialogue.
##
## The first meeting starts itself when the player comes near, so it cannot
## be missed; afterwards E gets a one-line reminder.

@export var character_name: String = "Jory"
## How close the player has to come for the first meeting to start.
@export var greet_distance := 84.0
## He only plays when someone is near enough to hear it.
@export var hear_distance := 300.0

const FLAG_MET := "hollow.greeter_met"
const TUNE := "res://audio/sfx/flute_phrase.wav"

@onready var animated_sprite: AnimatedSprite2D = $Movement
@onready var interaction_area: InteractionArea = $InteractionArea

var dialogue_resource = load("res://dialogue/greeter.dialogue")
var player: CharacterBody2D
var talking: bool = false
## Any dialogue at all, ours or not — the greeting must not open over the
## arrival bubble.
var _any_dialogue: bool = false
var _tune_in := 2.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	DialogueManager.dialogue_started.connect(func(_r): _any_dialogue = true)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	interaction_area.interact = Callable(self, "_on_interact")
	animated_sprite.play("flute")


func _process(delta: float) -> void:
	if player == null:
		return
	var d := global_position.distance_to(player.global_position)
	if not talking:
		_tune_in -= delta
		if _tune_in <= 0.0:
			_tune_in = randf_range(7.0, 12.0)
			if d <= hear_distance:
				Audio.sfx_at(TUNE, global_position, -9.0)
				_notes()
	if talking or Flags.has(FLAG_MET) or not player.movement_enabled or _any_dialogue:
		return
	if d <= greet_distance:
		_face_player()
		_talk("start")


func _on_interact() -> void:
	if talking:
		return
	_face_player()
	_talk("start" if not Flags.has(FLAG_MET) else "again")


func _talk(title: String) -> void:
	Flags.set_flag(FLAG_MET)
	DialogueManager.show_dialogue_balloon(dialogue_resource, title, [self, player])


func _face_player() -> void:
	var d := player.global_position - global_position
	if absf(d.x) > absf(d.y):
		animated_sprite.play("idle_side")
		animated_sprite.flip_h = d.x < 0.0
	else:
		animated_sprite.flip_h = false
		animated_sprite.play("idle_up" if d.y < 0.0 else "idle_down")


## A couple of notes drifting up from the flute.
func _notes() -> void:
	for i in 3:
		var n := Label.new()
		n.text = "♪" if i != 1 else "♫"
		n.add_theme_font_size_override("font_size", 7)
		n.add_theme_color_override("font_color", Color(0.96, 0.9, 0.76, 0.95))
		n.add_theme_constant_override("outline_size", 2)
		n.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.07, 0.9))
		n.position = Vector2(6 + i * 3, -18 - i * 2)
		n.z_index = 6
		add_child(n)
		var t := create_tween()
		t.tween_interval(0.35 * i)
		t.tween_property(n, "position", n.position + Vector2(4 - i * 3, -14), 1.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(n, "modulate:a", 0.0, 1.5).set_delay(0.35 * i + 0.6)
		t.tween_callback(n.queue_free)


# --- called from the dialogue --------------------------------------------

func start_talking() -> void:
	talking = true


func stop_talking() -> void:
	talking = false


func _on_dialogue_ended(_resource) -> void:
	_any_dialogue = false
	talking = false
	animated_sprite.flip_h = false
	animated_sprite.play("flute")
	if player:
		player.enable_movement()

extends CharacterBody2D
## The Guardian of the Haven (Level 4).
##
## It wears the same hood as the stones standing round the plain — that is the
## point of it, and the reason it uses their sprite rather than a character
## sheet. What marks it out is that it is lit, and that it is the only one
## that answers. Whether it is an echo of Cedric or something that was here
## long before him is deliberately left open.
##
## It does not walk anywhere. It inhabits one stone at a time, and every so
## often it leaves that one and blows across to another: vacate(), cross_to()
## and settle() are the three beats of that, and world/game_level_4.gd drives
## them so it can hide and show the stone at each end. The body is a
## CharacterBody2D only so it matches the rest of the NPCs and collides the
## same way.

@export var character_name: String = "The Guardian"
## Which line to open on, in dialogue/haven.dialogue.
@export var title: String = "guardian"
## One breath, in seconds. It does not drift: the sprite carries its own
## plinth, and a plinth that floats reads as a bug rather than as a wonder.
## What moves is the light it is standing in.
@export var breath_seconds: float = 5.2
## How long it takes to leave a stone, cross, and settle into the next one.
@export var leave_seconds: float = 0.6
@export var cross_seconds: float = 1.25
@export var arrive_seconds: float = 0.8

const GUST := preload("res://objects/haven/haven_gust.tscn")

@onready var _figure: Sprite2D = $Figure
@onready var _halo: Sprite2D = $Halo
@onready var _light: PointLight2D = $Light

var _dialogue = load("res://dialogue/haven.dialogue")
## False from the moment it starts to leave a stone until it has settled in
## the next one: the level will not ask it to move again, and it cannot be
## spoken to mid-crossing.
var settled := true
var _player: CharacterBody2D
var _t := 0.0
var _halo_rest: Vector2
var _halo_a: float
var _energy: float
var _tint: Color
var _alpha: float
var talking := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	$InteractionArea.interact = Callable(self, "_on_interact")
	_halo_rest = _halo.scale
	_halo_a = _halo.modulate.a
	_energy = _light.energy
	_tint = _figure.modulate
	_alpha = _figure.modulate.a


func _process(delta: float) -> void:
	_t += delta
	var phase := _t / breath_seconds * TAU
	# Halo, lamp and the stone's own brightness on one cycle, each a little
	# behind the last, so it reads as one thing breathing rather than three
	# animations running near each other.
	_halo.scale = _halo_rest * (1.0 + 0.08 * sin(phase))
	_halo.modulate.a = _halo_a * (1.0 + 0.3 * sin(phase - 0.6))
	_light.energy = _energy * (1.0 + 0.18 * sin(phase - 0.3))
	_figure.modulate = _tint * (1.0 + 0.06 * sin(phase - 0.9))
	_figure.modulate.a = _alpha


# --- moving between stones --------------------------------------------------
# Three awaitable beats rather than one call, so the level can show the stone
# it has left at the moment it lets go, and hide the next one only once it has
# arrived — otherwise there is a frame with two of it, or none.

## Fade out of the stone it is in, the halo swelling as it lets go.
func vacate() -> void:
	settled = false
	var t := create_tween().set_parallel()
	t.tween_method(_set_alpha, _alpha, 0.0, leave_seconds)
	t.tween_property(_halo, "scale", _halo_rest * 2.2, leave_seconds)
	await t.finished


## Blow across to `to`, arriving invisible.
func cross_to(to: Vector2) -> void:
	var gust = GUST.instantiate()
	get_parent().add_child(gust)
	gust.travel(global_position, to, cross_seconds)
	await get_tree().create_timer(cross_seconds).timeout
	global_position = to


## Fade into the stone it has arrived at.
func settle() -> void:
	_halo.scale = _halo_rest
	var t := create_tween()
	t.tween_method(_set_alpha, 0.0, 1.0, arrive_seconds)
	await t.finished
	settled = true


func _set_alpha(a: float) -> void:
	_alpha = a
	_figure.modulate.a = a
	_halo.modulate.a = _halo_a * a
	_light.energy = _energy * a


func _on_interact() -> void:
	if talking or not settled:
		return
	DialogueManager.show_dialogue_balloon(_dialogue, title, [self, _player])


func start_talking() -> void:
	talking = true


func stop_talking() -> void:
	talking = false

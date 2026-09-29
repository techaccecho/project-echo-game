extends CharacterBody2D
## The Forester (Level 2 — the Cliffside Path).
##
## By day he stands at his post facing the path, because the beat is that he
## has been expecting whoever finally got through. At night he goes to his
## fire and stays by it — he sleeps by his own fire every night, as Cedric's
## page says — and has less to say. The reveal itself lives in
## dialogue/forester.dialogue; this script owns the interaction, the talking
## state the dialogue toggles, and the walk between the two spots.

@export var character_name: String = "Forester"
## Where he stands by day, and where he keeps the fire at night, in the
## level's coordinates.
@export var post := Vector2(808, 168)
@export var fireside := Vector2(822, 180)
@export var walk_speed := 36.0

@onready var animated_sprite: AnimatedSprite2D = $Movement
@onready var interaction_area: InteractionArea = $InteractionArea

var dialogue_resource = load("res://dialogue/forester.dialogue")
var player: CharacterBody2D
var talking: bool = false
var _target := Vector2.ZERO


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	interaction_area.interact = Callable(self, "_on_interact")
	Clock.phase_changed.connect(func(_p): _pick_spot())
	_pick_spot()
	# Already where he should be when the level loads; no walk on arrival.
	global_position = _target
	_settle()


func _pick_spot() -> void:
	_target = fireside if Clock.is_night() else post


func _physics_process(delta: float) -> void:
	if talking:
		return
	var d := _target - global_position
	if d.length() <= 1.0:
		if velocity != Vector2.ZERO:
			velocity = Vector2.ZERO
			_settle()
		return
	velocity = d.normalized() * walk_speed
	move_and_slide()
	_face(d, true)


## Standing still: face the path by day, the fire by night.
func _settle() -> void:
	if Clock.is_night():
		_face(Vector2.RIGHT, false)
	else:
		_face(Vector2.DOWN, false)


func _face(d: Vector2, walking: bool) -> void:
	var prefix := "walk_" if walking else "idle_"
	if absf(d.x) > absf(d.y):
		animated_sprite.flip_h = d.x < 0.0
		animated_sprite.play(prefix + "side")
	else:
		animated_sprite.flip_h = false
		animated_sprite.play(prefix + ("up" if d.y < 0.0 else "down"))


func _on_interact() -> void:
	if talking:
		return
	if player:
		_face(player.global_position - global_position, false)
	DialogueManager.show_dialogue_balloon(dialogue_resource,
			"night" if Clock.is_night() else "start", [self, player])


# --- called from the dialogue --------------------------------------------

func start_talking() -> void:
	talking = true


func stop_talking() -> void:
	talking = false


func _on_dialogue_ended(_resource) -> void:
	talking = false
	_settle()
	if player:
		player.enable_movement()

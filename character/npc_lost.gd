extends CharacterBody2D
## The lost villager (Level 3 — the Corrupted Grove).
##
## He stands where the grove left him and says the same three things, in a
## slightly different order each time, and never quite to you. One of them
## is a clue if you have read Cedric's page about him. The lines live in
## dialogue/grove.dialogue under "villager".

@export var character_name: String = "Villager"

@onready var animated_sprite: AnimatedSprite2D = $Movement
@onready var interaction_area: InteractionArea = $InteractionArea

var dialogue_resource = load("res://dialogue/grove.dialogue")
var player: CharacterBody2D
var talking: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")
	animated_sprite.play("idle")


func _on_interact() -> void:
	if talking:
		return
	DialogueManager.show_dialogue_balloon(dialogue_resource, "villager", [self, player])


func start_talking() -> void:
	talking = true


func stop_talking() -> void:
	talking = false

extends Control

@onready var inv: Inv = preload("res://inventory/player_inv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()
@onready var player: CharacterBody2D

var is_open = false

func _ready():
	# Whenever inventory is updated, update the inv
	player = get_tree().get_first_node_in_group("player")
	inv.update.connect(update_slots)
	update_slots()
	close()

# Go through all slots (visual) and update with respective item from items array
func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		slots[i].update(inv.slots[i])

func _process(delta):
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
			player.enable_movement()
		else:
			open()
			player.disable_movement()

func open():
	visible = true
	is_open = true

func close():
	visible = false
	is_open = false

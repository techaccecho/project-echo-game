extends Control

@onready var inv: Inv = preload("res://inventory/player_inv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()
@onready var player: CharacterBody2D

var is_open = false

func _ready():
	# Whenever inventory is updated, update the inv
	player = get_tree().get_first_node_in_group("player")
	inv.update.connect(update_slots)
	for slot in slots:
		if slot.has_signal("read_requested"):
			slot.read_requested.connect(_on_read_requested)
	update_slots()
	close()

# Go through all slots (visual) and update with respective item from items array
func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		slots[i].update(inv.slots[i])

func _process(delta):
	# The Echo Log draws over this and owns movement while it is up, so get out
	# of its way rather than stacking two panels.
	if EchoLog.journal_is_open():
		if is_open:
			close()
		return

	# [I] opens the bag only when nothing else is up; [I] or [Esc] closes it
	# while it is the topmost thing.
	if is_open and UiStack.is_top("inventory") \
			and (Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("ui_cancel")):
		close()
		player.enable_movement()
		get_viewport().set_input_as_handled()
	elif not is_open and UiStack.is_free() and Input.is_action_just_pressed("inventory"):
		open()
		player.disable_movement()
		get_viewport().set_input_as_handled()

# Clicking a recovered page reads it: hand off to the Echo Log, which takes over
# input from here. Movement stays disabled throughout, so no need to re-enable.
func _on_read_requested(fragment: Fragment) -> void:
	close()
	EchoLog.open_journal(fragment.id)

func open():
	UiStack.push("inventory")
	visible = true
	is_open = true

func close():
	UiStack.pop("inventory")
	visible = false
	is_open = false

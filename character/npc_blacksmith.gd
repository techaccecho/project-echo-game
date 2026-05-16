extends CharacterBody2D

enum SMITH_STATE { IDLE, SMITHING, TALKING, WALK }
@export var walk_speed: float = 20
@export var idle_duration: float = 3.0
@export var walk_duration: float = 2.0
@export var character_name: String = "NPCBlacksmith"
# Inventory: Blacksmith gives player the axe
@export var axe: InvItem

@onready var animated_sprite = $Movement
@onready var state_timer = $StateTimer
@onready var interaction_area = $InteractionArea

var move_direction: Vector2 = Vector2(0, 1) # Default to down
var current_state: SMITH_STATE = SMITH_STATE.IDLE
# Dialogue
var dialogue_resource = load("res://dialogue/greet.dialogue")
# Player
var player: CharacterBody2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	interaction_area.interact = Callable(self, "_on_interact")

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	pick_new_state()

func _on_interact():
	
	## Code for hitting the smith table
	#if current_state != SMITH_STATE.IDLE && current_state != SMITH_STATE.WALK:
		#return
	#current_state = SMITH_STATE.SMITHING
	#animated_sprite.play("hit")
	#
	#await animated_sprite.animation_finished
	if current_state != SMITH_STATE.IDLE && current_state != SMITH_STATE.SMITHING && current_state != SMITH_STATE.WALK:
		return
	# Player talks to NPC, NPC hands player axe
	#player.collect(axe)
	current_state = SMITH_STATE.TALKING
	DialogueManager.show_dialogue_balloon(dialogue_resource, "start", [self, player])
	current_state = SMITH_STATE.IDLE
	pick_new_state()

func _physics_process(_delta):
	if (current_state == SMITH_STATE.WALK):
		velocity = move_direction * walk_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	if current_state == SMITH_STATE.WALK and get_slide_collision_count() > 0:
		# Reflect direction off the collision normal so NPC bounces away
		var collision = get_slide_collision(0)
		move_direction = move_direction.bounce(collision.get_normal()).normalized()
		update_animation()

# Randomly generate a move direction
# Can be either -1, 0, or 1 for x and for y
func select_new_direction():
	# Keep picking until non-zero direction
	move_direction = Vector2.ZERO
	while (move_direction == Vector2.ZERO):
		move_direction = Vector2(
			randi_range(-1, 1),
			randi_range(-1, 1)
		)

# Switch from walking to idling
func pick_new_state():
	if current_state == SMITH_STATE.SMITHING or current_state == SMITH_STATE.TALKING:
		return
	if (current_state == SMITH_STATE.IDLE):
		current_state = SMITH_STATE.WALK
		select_new_direction()
		state_timer.start(walk_duration)
	elif (current_state == SMITH_STATE.WALK):
		current_state = SMITH_STATE.IDLE
		select_new_direction()
		state_timer.start(idle_duration)
	
	update_animation()

func update_animation():
	var suffix = get_direction_suffix()
	
	if (current_state == SMITH_STATE.IDLE or current_state == SMITH_STATE.TALKING):
		animated_sprite.play("idle_" + suffix)
	elif (current_state == SMITH_STATE.WALK):
		animated_sprite.play("walk_" + suffix)
	
func start_talking():
	state_timer.stop()
	current_state = SMITH_STATE.TALKING
	move_direction = Vector2.DOWN
	velocity = Vector2.ZERO
	update_animation()

func stop_talking():
	current_state = SMITH_STATE.IDLE
	pick_new_state()

func get_direction_suffix():
	if (abs(move_direction.x) > abs(move_direction.y)):
		return "left" if move_direction.x < 0 else "right"
	else:
		return "up" if move_direction.y < 0 else "down"

func _on_state_timer_timeout():
	pick_new_state()

#func _unhandled_input(event: InputEvent):
	#if event.is_action_pressed("talk"):
		#DialogueManager.show_dialogue_balloon(dialogue_resource, "start", [self, player])

func _on_dialogue_ended(_resource):
	if current_state == SMITH_STATE.TALKING:
		stop_talking()
	if player:
		player.enable_movement()

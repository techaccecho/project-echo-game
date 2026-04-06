extends CharacterBody2D

enum SMITH_STATE { IDLE, WALK, SMITHING }
@export var walk_speed: float = 20
@export var idle_duration: float = 3.0
@export var walk_duration: float = 2.0

@onready var animated_sprite = $Movement
@onready var state_timer = $StateTimer
@onready var interaction_area = $InteractionArea

var move_direction: Vector2 = Vector2(0, 1) # Default to down
var current_state: SMITH_STATE = SMITH_STATE.IDLE

func _ready():
	interaction_area.interact = Callable(self, "_on_interact")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	pick_new_state()

func _on_interact():
	if current_state != SMITH_STATE.IDLE && current_state != SMITH_STATE.WALK:
		return
	current_state = SMITH_STATE.SMITHING
	animated_sprite.play("hit")
	
	await animated_sprite.animation_finished
	
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
	
	if (current_state == SMITH_STATE.IDLE):
		animated_sprite.play("idle_" + suffix)
	elif (current_state == SMITH_STATE.WALK):
		animated_sprite.play("walk_" + suffix)

func get_direction_suffix():
	if (abs(move_direction.x) > abs(move_direction.y)):
		return "left" if move_direction.x < 0 else "right"
	else:
		return "up" if move_direction.y < 0 else "down"

func _on_state_timer_timeout():
	pick_new_state()

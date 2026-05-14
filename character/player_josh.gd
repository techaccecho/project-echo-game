extends CharacterBody2D

@export var inv: Inv
@export var walk_speed: float = 100
@export var run_speed: float = 200
@export var character_name: String = "Player"
@onready var animated_sprite = $Movement

# Track last direction so idle plays the correct facing animation
var last_direction: Vector2 = Vector2(0, 1) # default face down
var movement_enabled: bool = true

func _physics_process(_delta):
	if (!movement_enabled):
		return
	var input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()
	
	var is_running = Input.is_action_pressed("run")
	var current_speed = run_speed if is_running else walk_speed
	
	velocity = input_direction * current_speed
	move_and_slide()
	
	if input_direction != Vector2.ZERO:
		last_direction = input_direction
	
	update_animation(input_direction, is_running)

func update_animation(input_direction: Vector2, is_running: bool):
	var state = "idle"
	var dir = last_direction # use last known direction when idle
	
	if input_direction != Vector2.ZERO:
		dir = input_direction
		state = "run" if is_running else "walk"
		
	# Pick dominant axis for the direction suffix
	var anim_suffix = get_direction_suffix(dir)
	
	animated_sprite.play(state + "_" + anim_suffix)

func get_direction_suffix(dir: Vector2) -> String:
	# Flip sprite for left, use right animation
	if abs(dir.x) > abs(dir.y):
		# Horizontal movement is dominant
		if dir.x > 0:
			animated_sprite.flip_h = false
			return "right"
		else:
			animated_sprite.flip_h = true
			return "right"
	else:
		# Vertical movement is dominant
		animated_sprite.flip_h = false
		if dir.y < 0:
			return "up"
		else:
			return "down"

func disable_movement():
	movement_enabled = false
	
	update_animation(Vector2.ZERO, false)  # snap to idle animation immediately

func enable_movement():
	movement_enabled = true

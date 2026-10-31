extends Sprite2D
## The torch on his belt. Once he is carrying it, it hangs at his hip whether
## it is lit or not, so lit and out are told apart at a glance in the same
## spot — and his hands stay free for the axe and the rod.
##
## Follows the body sprite's facing (read off the animation name, so the axe
## swing and fishing poses count too), flames while the Lamp autoload says it
## is lit, and carries the player's light with it so the pool of light sits on
## the flame rather than on his middle.

## The sheet: one charred, unlit frame, then the flame frames.
const FLAME_FRAMES := 4
const FLAME_FPS := 8.0
## Where it hangs from his centre for each facing. Left is right mirrored.
const HIP := {
	"down": Vector2(-7, 5),
	"up": Vector2(7, 5),
	"right": Vector2(-5, 5),
}
## The flame, from this sprite's centre: where the light is put.
const FLAME := Vector2(0, -4)

@export var body_path: NodePath = ^"../Movement"
@export var light_path: NodePath = ^"../Lamp"

@onready var _body: AnimatedSprite2D = get_node_or_null(body_path)
@onready var _light: Node2D = get_node_or_null(light_path)

var _t := 0.0


func _ready() -> void:
	hframes = 1 + FLAME_FRAMES
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	visible = Lamp.has_lamp() and (_body == null or _body.visible)
	if not visible:
		return

	var facing := "down"
	var mirrored := false
	if _body != null:
		facing = String(_body.animation).get_slice("_", String(_body.animation).get_slice_count("_") - 1)
		mirrored = facing == "right" and _body.flip_h
	var at: Vector2 = HIP.get(facing, HIP["down"])
	if mirrored:
		at.x = -at.x
	position = at
	flip_h = mirrored

	frame = 1 + int(_t * FLAME_FPS) % FLAME_FRAMES if Lamp.is_lit() else 0
	if _light != null:
		_light.position = at + FLAME

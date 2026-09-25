extends Node2D
## A few gulls on the water that are only about in the morning. Fades the
## whole group in and out on the Clock's phase, so they arrive with the light
## and are gone by noon.

const GULL := preload("res://objects/seagull.tscn")

## (position, flying?) pairs.
@export var floating: PackedVector2Array = PackedVector2Array()
@export var flying: PackedVector2Array = PackedVector2Array()
@export var fade := 4.0

func _ready() -> void:
	for p in floating:
		_add(p, 1)
	for p in flying:
		_add(p, 0)
	Clock.phase_changed.connect(_on_phase)
	modulate.a = 1.0 if Clock.phase() == Clock.Phase.MORNING else 0.0
	visible = modulate.a > 0.0

func _add(p: Vector2, mode: int) -> void:
	var g: Node2D = GULL.instantiate()
	g.position = p
	g.set("mode", mode)
	g.set("animation", "float" if mode == 1 else "fly")
	add_child(g)

func _on_phase(phase: int) -> void:
	var show := phase == Clock.Phase.MORNING
	visible = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0 if show else 0.0, fade)
	if not show:
		t.tween_callback(func() -> void: visible = false)

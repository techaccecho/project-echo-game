extends Node2D
## The way back out of the Haven: two trunks grown together, with something
## standing in the gap between them.
##
## The arch sprite is ordinary scenery. Everything that makes it read as a
## portal rather than a tree is here — a sheet of light filling the gap, a
## halo behind the canopy, a lamp throwing that light onto the ground, and
## motes drawn up through it. All four breathe on one slow cycle with small
## offsets, so the whole thing pulses as a single object instead of four
## animations happening near each other.

## One breath, in seconds. Slow on purpose: the Haven has no urgency.
@export var period: float = 4.6
## How far the gap's brightness swings either side of its resting value.
@export var swing: float = 0.22

@onready var _veil: Sprite2D = $Veil
@onready var _halo: Sprite2D = $Halo
@onready var _light: PointLight2D = $Light

var _t := 0.0
var _veil_a: float
var _halo_a: float
var _energy: float


func _ready() -> void:
	_veil_a = _veil.modulate.a
	_halo_a = _halo.modulate.a
	_energy = _light.energy


func _process(delta: float) -> void:
	_t += delta
	var phase := _t / period * TAU
	_veil.modulate.a = _veil_a * (1.0 + swing * sin(phase))
	# The veil also stretches a little as it brightens, which is what sells
	# it as a surface under tension rather than a sprite being faded.
	_veil.scale = Vector2(1.0 + 0.05 * sin(phase), 1.0 + 0.03 * sin(phase + 1.1))
	_halo.modulate.a = _halo_a * (1.0 + swing * 0.7 * sin(phase - 0.6))
	_light.energy = _energy * (1.0 + swing * 0.8 * sin(phase - 0.3))

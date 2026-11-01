@tool
class_name GroveProp
extends Node2D
## One piece of Level 3 scenery. Every prop in the grove is an instance of a
## scene built on this script, so a problem with how a kind of prop draws or
## collides is fixed once, in that scene, rather than on hundreds of loose
## sprites.
##
## The node's origin is the prop's footprint line — its y-sort key and the
## bottom edge of its collision. The player is drawn in front of a prop when
## his own origin is below it, which is exactly when he is standing south of
## the footprint. `feet_below` says how far under that line the region's
## bottom edge reaches (shadow, roots, the trees' sort margin).
##
## Collision belongs in the scene, on the footprint only: roots, canopy and
## shadow never get any, so the player walks over them and is drawn over them.

## Crops of the sheet, one per look. `variant` picks one.
@export var regions: Array[Rect2] = []
@export var variant := 0:
	set(v):
		variant = v
		_apply()
## Variants that are flat on the ground (a slab, a patch of roots). They have
## no collision and draw under the player, who just walks over them.
@export var flat_variants := PackedInt32Array()
## How far the bottom of the region sits below the origin.
@export var feet_below := 0.0:
	set(v):
		feet_below = v
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or regions.is_empty():
		return
	var r := regions[clampi(variant, 0, regions.size() - 1)]
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = r
	sprite.offset = Vector2(-r.size.x / 2.0, -r.size.y + feet_below)
	if not flat_variants.is_empty():
		var flat := flat_variants.has(variant)
		z_index = -1 if flat else 0
		for shape in find_children("*", "CollisionShape2D", true, false):
			(shape as CollisionShape2D).disabled = flat

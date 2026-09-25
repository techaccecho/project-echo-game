extends Node2D
## The way east out of the hollow: an iron door cut into a cliff face at the
## back of a clearing, two hooded statues keeping it, and an old stone path
## leading in from the meadow.
##
## Somebody came this way before the player did. The path is laid, the trees
## along it are long-cut stumps, and the gate has been opened before — but the
## forest has grown back across the mouth of the path since, and two young
## maples now stand in it. Chop them and the clearing opens; the key opens the
## gate; the gate opens the road (the portal itself lives in the level, which
## arms it when this gate's `opened` fires).
##
## The two maples are the only standing maples here on purpose: around this
## clearing a maple always means "you can cut this", and every other tree is a
## pine. Their trunks alone would leave gaps a player could slip through, so a
## blocker body closes the whole mouth until both are down — the same trick
## Level 3 uses on its gate gaps.
##
## Walking in. The cliff is ground art, beneath every character, so on its own
## the player would stroll through the arch and out on to the top of the rock.
## Once the gate is open, the Occluder draws the rock and the arch around the
## doorway again — with the dark hole cut out of it — and sorts at the
## threshold: step over it and everything but the hole is in front of him, so
## he is only ever seen through the opening. The deeper in, the darker.

const SRC_CLIFF := 7
const T_FACE := Vector2i(9, 4)
const DOOR_ART := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Exterior/Dungeon/Door.png"
## The open door in the sheet, and a pixel inside its dark hole to fill from.
const OPEN_FRAME := Rect2i(0, 32, 32, 32)
const HOLE_SEED := Vector2i(16, 20)
## How far past the threshold is full dark, and how dark that is.
const DARK_DEPTH := 20.0
const DARKEST := 0.3

@onready var gate: LockedGate = $Gate
@onready var mouth_blocker: CollisionShape2D = $MouthBlocker/CollisionShape2D
@onready var occluder: Sprite2D = $Occluder
@onready var cliff: TileMapLayer = $Cliff

var _player: CharacterBody2D
var _shaded := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	for tree in $PathTrees.get_children():
		tree.damage_component.max_damage_reached.connect(_check_mouth)
	# Felled on an earlier visit: the maples remember, so the mouth must too.
	_check_mouth()
	var stumps_area := get_node_or_null("StumpsLook") as InteractionArea
	if stumps_area != null:
		stumps_area.interact = Callable(self, "_say").bind("stumps")
	occluder.texture = _build_occluder()
	occluder.visible = gate.is_open()
	gate.opened.connect(func() -> void: occluder.visible = true)


## Darker the further into the doorway he goes; back to normal once out.
func _process(_delta: float) -> void:
	if not occluder.visible:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var mouth := gate.global_position + Vector2(16, 0)
	var p := _player.global_position
	var depth := 0.0
	if absf(p.x - mouth.x) < 12.0 and p.y < mouth.y:
		depth = clampf((mouth.y - p.y) / DARK_DEPTH, 0.0, 1.0)
	if depth > 0.0 or _shaded:
		var v := lerpf(1.0, DARKEST, depth)
		_player.modulate = Color(v, v, v, _player.modulate.a)
		_shaded = depth > 0.0


## The rock face over the doorway, two tiles wide and three high, with the open
## door on its lower two thirds and that door's dark hole cut clean out.
func _build_occluder() -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var src := cliff.tile_set.get_source(SRC_CLIFF) as TileSetAtlasSource
	var sheet := src.texture.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	var face := src.get_tile_texture_region(T_FACE)
	for ty in 3:
		for tx in 2:
			img.blit_rect(sheet, face, Vector2i(tx * 16, ty * 16))

	var art := (load(DOOR_ART) as Texture2D).get_image()
	if art.is_compressed():
		art.decompress()
	var door := art.get_region(OPEN_FRAME)
	img.blend_rect(door, Rect2i(Vector2i.ZERO, door.get_size()), Vector2i(0, 16))

	for px in _hole(door):
		img.set_pixelv(px + Vector2i(0, 16), Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## The dark inside the arch. Its outline is the same near-black, but a ring of
## lighter frame separates the two, so a fill from the middle stops at the
## frame. The floor at the bottom is lighter still; it is taken row by row,
## between the dark on either side of it.
func _hole(door: Image) -> Array[Vector2i]:
	var dark := func(p: Vector2i) -> bool:
		var c := door.get_pixelv(p)
		return c.a > 0.5 and c.get_luminance() < 0.12
	var seen := {HOLE_SEED: true}
	var queue: Array[Vector2i] = [HOLE_SEED]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= door.get_width() or n.y >= door.get_height():
				continue
			if seen.has(n) or not dark.call(n):
				continue
			seen[n] = true
			queue.append(n)
	var rows := {}
	for p in seen:
		if not rows.has(p.y):
			rows[p.y] = Vector2i(p.x, p.x)
		rows[p.y] = Vector2i(mini(rows[p.y].x, p.x), maxi(rows[p.y].y, p.x))
	var out: Array[Vector2i] = []
	for y in rows:
		for x in range(rows[y].x, rows[y].y + 1):
			out.append(Vector2i(x, y))
	return out


## Open the path once every tree standing in it is down.
func _check_mouth() -> void:
	for tree in $PathTrees.get_children():
		if not tree.max_reached:
			return
	mouth_blocker.set_deferred("disabled", true)


func _say(title: String) -> void:
	var res = load(gate.story)
	if res == null:
		push_warning("east_gate: %s has not been imported yet." % gate.story)
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	DialogueManager.show_dialogue_balloon(res, title, [self, _player])
	await DialogueManager.dialogue_ended

extends Node2D
class_name CrumbleBridge
## A stretch of cliff path that has gone to sand, where only one lane per
## step is firm.
##
## The path widens here and the ground is deep, dry sand: every step on it is
## slow. The player crosses left to right; at each step exactly one lane
## holds, and the rest is quicksand that pours away into the drop and takes
## the player down the cliff into the sea far below. Firm sand and quicksand
## are visually identical, so the crossing is learnt by dying — which means
## the respawn wants to be the near side of the crossing, not the far side of
## the level. Set `respawn_spawn` to a marker just before it.
##
## The sand covers the whole width of the path, not just the pattern's lanes:
## `extra_rows_below` of quicksand run under the last lane so there is no
## strip of plain ground to edge along. Occupancy is measured at the player's
## FEET (the collision box), not the sprite's origin, for the same reason —
## the origin sits a few pixels up the body, and a player hugging the top of
## the path could stand with his feet on one lane while his origin read as
## another.
##
## The pattern is written the way a level designer reads it, one string per
## lane, left to right:
##     "X O O O X"
##     "O O X O X"
##     "X X X O O"
## O = firm, X = quicksand. Whitespace is ignored. The firm patches must join
## up into a path from the first column to the last, moving up, down or
## across — never diagonally, because a diagonal step has to cross the
## corner of two quicksand patches and there is no way to do that on foot.
## _ready() checks the path exists. Extra firm patches off the path are
## decoys, and welcome.
##
## Occupancy is decided by polling against the grid rather than by per-patch
## Area2Ds: the patches sit edge to edge, so overlapping areas would fire two
## triggers at once on the boundary between them.

const STONE := preload("res://objects/crumble_stone.tscn")
## Sand variants in Beach animations tiles.png: one speckled, two rippled.
const SLABS: Array[Rect2] = [
	Rect2(192, 192, 16, 16), Rect2(208, 192, 16, 16), Rect2(224, 192, 16, 16),
]
## Where the player's feet are, relative to his origin: the centre of his
## collision box.
const FEET := Vector2(0.5, 5.0)
const STORY := "res://dialogue/sand_crossing.dialogue"
const FLAG_SEEN := "level2.sand_seen"

## Top-left corner of the grid, in tiles.
@export var origin_tile: Vector2i = Vector2i(26, 9)
## Size of one panel, in tiles. The paving slabs are a single 16x16 tile.
@export var cell_tiles: Vector2i = Vector2i(1, 1)
## One line per lane; see the class docs.
@export var pattern: Array[String] = [
	"X O O O X",
	"O O X O X",
	"X X X O O",
]
## Rows of quicksand under the pattern, for a path that is taller than the
## pattern. Zero here: the Cliffside path is exactly three lanes, and a row
## below would hang over the cliff.
@export var extra_rows_below: int = 0
## Feet this far outside the top or bottom lane still count as on that lane,
## so there is no seam along the path edge to walk. The player's feet can sit
## a few pixels past the last tile before the fall zone below catches him.
@export var edge_slack: float = 8.0
## Half-alpha sand drawn a little way past the first and last columns, so the
## patch fades into the path instead of stopping dead. Visual only.
@export var feather: bool = true
## Dead zone along patch edges where the feet count as on nothing, in
## pixels. Zero: any margin here is a seam a player could walk along between
## two lanes, and the path only ever asks for straight moves anyway.
@export var edge_forgiveness: float = 0.0
## Walking speed on the sand, as a fraction of normal.
@export_range(0.1, 1.0) var sand_speed: float = 0.45

@export_group("Falling")
## World Y of the sea at the foot of the cliff. The player drops through the
## hole and lands down there, not at path level.
@export var sea_y: float = 320.0
@export_file("*.tscn") var respawn_scene: String = "res://world/game_level_2.tscn"
@export var respawn_spawn: String = "BridgeApproach"

var _safe: Array[Array] = []        ## _safe[lane][step]
var _stones: Array[Array] = []      ## _stones[lane][step]
var _steps: int = 0
var _lanes: int = 0
var _cell: Vector2 = Vector2(32, 32)
var _current := Vector2i(-1, -1)
var _falling: bool = false
var _on_sand: bool = false
var _player: Node2D


func _ready() -> void:
	_cell = Vector2(cell_tiles) * 16.0
	_parse_pattern()
	if _steps == 0:
		return
	_build_stones()
	_player = get_tree().get_first_node_in_group("player")


func _parse_pattern() -> void:
	_safe.clear()
	for line in pattern:
		var row: Array[bool] = []
		for ch in line:
			if ch == "O" or ch == "o":
				row.append(true)
			elif ch == "X" or ch == "x":
				row.append(false)
		_safe.append(row)
	_lanes = _safe.size()
	_steps = 0
	for row in _safe:
		_steps = maxi(_steps, row.size())
	# Pad ragged lines rather than letting them index out of range later.
	for row in _safe:
		while row.size() < _steps:
			row.append(false)
	# The firm patches have to make a 4-connected path across.
	var reach: Array[Vector2i] = []
	for l in _lanes:
		if _safe[l][0]:
			reach.append(Vector2i(0, l))
	var seen := {}
	while not reach.is_empty():
		var c: Vector2i = reach.pop_back()
		if seen.has(c) or c.x < 0 or c.x >= _steps or c.y < 0 or c.y >= _lanes or not _safe[c.y][c.x]:
			continue
		seen[c] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			reach.append(c + d)
	var crossable := false
	for l in _lanes:
		if seen.has(Vector2i(_steps - 1, l)):
			crossable = true
	if not crossable:
		push_warning("CrumbleBridge: no firm path from the first column to the last.")
	for i in extra_rows_below:
		var sink: Array[bool] = []
		for s in _steps:
			sink.append(false)
		_safe.append(sink)
	_lanes = _safe.size()


func _build_stones() -> void:
	var base := Vector2(origin_tile) * 16.0
	for l in _lanes:
		var row: Array[Node] = []
		for s in _steps:
			var stone := STONE.instantiate()
			stone.safe = _safe[l][s]
			# Vary the slab art. Deliberately uncorrelated with safe/unsafe:
			# a tell here would give the puzzle away.
			var ripple := stone.get_node_or_null("Sand/Ripple") as Sprite2D
			if ripple:
				var v: int = abs(int(origin_tile.x) * 7 + s * 5 + l * 3) % SLABS.size()
				ripple.region_rect = SLABS[v]
				ripple.flip_h = (s + l) % 2 == 1
			# Centre of the panel; the sprite is centred.
			stone.position = base + Vector2(s + 0.5, l + 0.5) * _cell
			add_child(stone)
			row.append(stone)
		_stones.append(row)
	if feather:
		for l in _lanes:
			for s in [-1, _steps]:
				var edge := STONE.instantiate()
				edge.position = base + Vector2(s + 0.5, l + 0.5) * _cell
				edge.modulate.a = 0.4
				edge.set_process(false)
				add_child(edge)


## Which panel the point is on, or (-1,-1) for none / too close to an edge.
func _cell_at(p: Vector2) -> Vector2i:
	var local := p - Vector2(origin_tile) * 16.0
	var s := int(floor(local.x / _cell.x))
	var l := int(floor(local.y / _cell.y))
	# Just past the top or bottom edge still counts as that edge lane.
	if local.y < 0.0 and local.y >= -edge_slack:
		l = 0
		local.y = 0.0
	elif local.y >= _lanes * _cell.y and local.y < _lanes * _cell.y + edge_slack:
		l = _lanes - 1
		local.y = _lanes * _cell.y - 0.01
	if s < 0 or s >= _steps or l < 0 or l >= _lanes:
		return Vector2i(-1, -1)
	var inset := Vector2(local.x - s * _cell.x, local.y - l * _cell.y)
	if inset.x < edge_forgiveness or inset.x > _cell.x - edge_forgiveness:
		return Vector2i(-1, -1)
	if inset.y < edge_forgiveness or inset.y > _cell.y - edge_forgiveness:
		return Vector2i(-1, -1)
	return Vector2i(s, l)


func _physics_process(_delta: float) -> void:
	if _falling or _steps == 0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var feet: Vector2 = _player.global_position + FEET
	_set_on_sand(_on_band(feet))
	var c := _cell_at(feet)
	if c == _current:
		return
	_current = c
	if c.x < 0:
		return
	if _safe[c.y][c.x]:
		return
	_give_way(c)


## Anywhere on the sand at all, forgiveness margins included.
func _on_band(p: Vector2) -> bool:
	var local := p - Vector2(origin_tile) * 16.0
	return local.x >= 0.0 and local.x < _steps * _cell.x \
			and local.y >= -edge_slack and local.y < _lanes * _cell.y + edge_slack


func _set_on_sand(on: bool) -> void:
	if on == _on_sand:
		return
	_on_sand = on
	_player.set("terrain_speed", sand_speed if on else 1.0)
	if on and not Flags.has(FLAG_SEEN):
		Flags.set_flag(FLAG_SEEN)
		var res = load(STORY)
		if res != null:
			DialogueManager.show_dialogue_balloon(res, "sand", [_player])


func _exit_tree() -> void:
	# The player outlives the level; do not leave him wading.
	if _on_sand and _player != null and is_instance_valid(_player):
		_player.set("terrain_speed", 1.0)


func _give_way(c: Vector2i) -> void:
	_falling = true
	var stone: Node = _stones[c.y][c.x]
	if stone and stone.has_method("give_way"):
		stone.give_way()
		# Let the shudder play out before the player goes with it.
		await stone.gave_way
	if _player and _player.has_method("fall_through_and_drown"):
		_player.fall_through_and_drown(sea_y, respawn_scene, respawn_spawn)

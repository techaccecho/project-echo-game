class_name WaterCollision
extends StaticBody2D
## Walls off open water, so the river cannot be walked into.
##
## The water is painted as one solid backdrop layer with the banks drawn on
## top of it, so the water tiles themselves cannot simply carry collision the
## way the cliff tiles do — half the bank sits over a water cell and would be
## walled off with it. This works out the difference instead: every cell the
## water layer paints, minus every cell a bank layer paints over it, is open
## water, and open water is what gets a wall.
##
## Built at load rather than authored, so it follows the paint: repaint the
## river, move the bridge, and the collision is right again next run with no
## shapes to drag about.
##
## Where the rule gets a stretch wrong, overrule it by hand instead of
## repainting: box the area out under a child node named "Carve" to open it,
## or "Block" to close it. Each box is an Area2D (monitoring off — it is only
## there for its handles) with one rectangle shape, so it can be dragged and
## resized in the 2D editor against the tinted cells that `debug_draw` shows.
## Block wins where the two overlap. Anything under either node is inert: only
## the cells it covers are read.

## The layer that paints the water itself.
@export var water_layer: NodePath
## Layers that make a cell walkable in spite of the water under it — the banks,
## the sand, the grass-to-water edges the player is meant to stand on.
@export var bank_layers: Array[NodePath] = []
## Layers whose cells are walkable *over* the water: the bridge. Everything
## these paint is cut out of the wall, and the bridge's own rail collisions
## are what keep the player on the deck.
@export var crossing_layers: Array[NodePath] = []
## Tint every walled cell, to see the shape of the wall while playing. The
## shapes are ordinary CollisionShape2D nodes, so Debug > Visible Collision
## Shapes draws them too; this shows the cell grid they were built from, which
## is the thing to compare against the paint.
@export var debug_draw: bool = false

var _blocked: Dictionary = {}
var _cell: Vector2i = Vector2i(16, 16)


func _ready() -> void:
	var water := get_node_or_null(water_layer) as TileMapLayer
	if water == null:
		push_warning("WaterCollision: no water layer at %s." % water_layer)
		return
	if water.tile_set != null:
		_cell = water.tile_set.tile_size

	for c in water.get_used_cells():
		_blocked[c] = true
	for group in [bank_layers, crossing_layers]:
		for path in group:
			var layer := get_node_or_null(path) as TileMapLayer
			if layer == null:
				push_warning("WaterCollision: no layer at %s." % path)
				continue
			for c in layer.get_used_cells():
				_blocked.erase(c)

	# The hand edits, last, so they overrule whatever the paint worked out.
	for rect in _boxes("Carve"):
		for c in _cells_in(rect):
			_blocked.erase(c)
	for rect in _boxes("Block"):
		for c in _cells_in(rect):
			_blocked[c] = true

	for rect in _merge(_blocked.keys()):
		_add_shape(rect)
	if debug_draw:
		queue_redraw()


## Every hand-drawn rectangle under the child node of this name, in this
## node's own space. Any rectangle shape under it counts, however it is
## wrapped, so a box can be an Area2D or a bare CollisionShape2D.
func _boxes(group_name: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var group := get_node_or_null(NodePath(group_name))
	if group == null:
		return out
	for node in group.find_children("*", "CollisionShape2D", true, false):
		var cs := node as CollisionShape2D
		var box := cs.shape as RectangleShape2D
		if box == null:
			push_warning("WaterCollision: %s/%s is not a rectangle, skipped."
					% [group_name, cs.name])
			continue
		var centre: Vector2 = to_local(cs.global_position)
		# global_scale, so a box resized by dragging its parent still reads right.
		var size: Vector2 = box.size * cs.global_scale.abs()
		out.append(Rect2(centre - size / 2.0, size))
	return out


## The cells a rectangle covers. A cell counts once the box reaches into it at
## all, so dragging a box roughly over the water does what it looks like.
func _cells_in(rect: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from := Vector2i(floori(rect.position.x / _cell.x), floori(rect.position.y / _cell.y))
	var to := Vector2i(ceili(rect.end.x / _cell.x), ceili(rect.end.y / _cell.y))
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			out.append(Vector2i(x, y))
	return out


## One box per run of water rather than one per cell: rows first, then rows
## stacked where they line up. Turns ~500 cells into a few dozen shapes.
func _merge(cells: Array) -> Array[Rect2i]:
	var by_row := {}
	for c in cells:
		if not by_row.has(c.y):
			by_row[c.y] = []
		by_row[c.y].append(c.x)

	# Horizontal runs, row by row.
	var runs := {}
	for y in by_row:
		var xs: Array = by_row[y]
		xs.sort()
		runs[y] = []
		var start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			if xs[i] != prev + 1:
				runs[y].append(Vector2i(start, prev))
				start = xs[i]
			prev = xs[i]
		runs[y].append(Vector2i(start, prev))

	# Stack a run onto the one above it when they span the same columns.
	var open := {}      # run -> the rect it is growing
	var done: Array[Rect2i] = []
	var rows := runs.keys()
	rows.sort()
	for y in rows:
		var next := {}
		for run in runs[y]:
			var grown: Rect2i = open.get(run, Rect2i(run.x, y, run.y - run.x + 1, 0))
			grown.size.y += 1
			next[run] = grown
		# Anything that did not continue into this row is finished.
		for run in open:
			if not next.has(run):
				done.append(open[run])
		open = next
	for run in open:
		done.append(open[run])
	return done


func _add_shape(rect: Rect2i) -> void:
	var box := RectangleShape2D.new()
	box.size = Vector2(rect.size.x * _cell.x, rect.size.y * _cell.y)
	var cs := CollisionShape2D.new()
	cs.shape = box
	cs.position = Vector2(rect.position.x * _cell.x, rect.position.y * _cell.y) + box.size / 2.0
	add_child(cs)


func _draw() -> void:
	if not debug_draw:
		return
	for c in _blocked:
		draw_rect(Rect2(c.x * _cell.x, c.y * _cell.y, _cell.x, _cell.y),
				Color(1, 0, 0, 0.25))

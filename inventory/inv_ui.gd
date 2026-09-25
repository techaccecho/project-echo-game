extends Control

## The bag and the hotbar, both drawn from the one shared Inv.
##
## The hotbar is the inventory's first row and is on screen the whole time: the
## wheel moves the highlight along it, and whatever is highlighted is what he is
## holding — which is the question the axe swing and the fishing spots ask. The
## bag is the other two rows and only appears on [I], drawn above the hotbar
## with a gap so the two read as one panel.
##
## Opening the bag is a moment rather than a panel appearing at the edge: the
## world dims behind it and the bag sits in the middle of what is left, while
## the bar stays lit and stays put on the bottom edge. Each panel carries its
## own scale — the bag's slots are drawn larger than the bar's — which is why
## they are placed here rather than parented to a container: layout sizes a
## child by its unscaled rect and ignores scale entirely, so a VBox would stack
## the two from the wrong numbers.

## Clearance from the bottom edge of the window, in screen pixels.
const BOTTOM_MARGIN := 40.0
## How long the world takes to fall away behind the bag.
const FADE := 0.12

@onready var inv: Inv = preload("res://inventory/player_inv.tres")
@onready var bag: NinePatchRect = $Bag
@onready var hotbar: NinePatchRect = $Hotbar
@onready var dim: ColorRect = $Dim
@onready var player: CharacterBody2D

var _fade: Tween

var is_open = false

## Every slot view, indexed to match inv.slots: the hotbar row first, then the
## bag. The two live in separate panels and the bag is the earlier of them in
## the tree, so this is stitched together in inventory order rather than read
## straight off one container.
var _views: Array = []

func _ready():
	player = get_tree().get_first_node_in_group("player")
	_views = $Hotbar/GridContainer.get_children()
	_views.append_array($Bag/GridContainer.get_children())
	for i in _views.size():
		var view = _views[i]
		view.index = i
		if view.has_signal("read_requested"):
			view.read_requested.connect(_on_read_requested)
		if view.has_signal("dropped"):
			view.dropped.connect(_on_dropped)
	# Whenever inventory is updated, update the inv
	inv.update.connect(update_slots)
	inv.selection_changed.connect(update_selection)
	get_viewport().size_changed.connect(_place)
	_place()
	update_slots()
	close()

## The bar sits on the bottom edge of the window; the bag is centred in the room
## left above it. Both are measured at the size they are actually drawn —
## `size * scale`, since a Control's scale is not part of its layout rect.
func _place() -> void:
	var window: Vector2 = get_viewport_rect().size
	var bar: Vector2 = hotbar.size * hotbar.scale
	hotbar.position = Vector2((window.x - bar.x) * 0.5, window.y - bar.y - BOTTOM_MARGIN)
	# Centred above the bar rather than in the window: the bar's own strip along
	# the bottom would otherwise throw the balance off, leaving the bag sitting
	# low with all the empty space stacked over it.
	var opened: Vector2 = bag.size * bag.scale
	bag.position = Vector2((window.x - opened.x) * 0.5,
			(hotbar.position.y - opened.y) * 0.5)

# Go through all slots (visual) and update with respective item from items array
func update_slots():
	for i in range(min(inv.slots.size(), _views.size())):
		_views[i].update(inv.slots[i])
	update_selection()

## Light up the slot he is holding from. Only the hotbar can be selected, so the
## bag's slots are told to sit dark every time.
func update_selection() -> void:
	for i in _views.size():
		_views[i].set_selected(i == inv.selected)

func _process(delta):
	# The Echo Log draws over this and owns movement while it is up, so get out
	# of its way rather than stacking two panels.
	if EchoLog.journal_is_open():
		if is_open:
			close()
		return

	# [I] opens the bag only when nothing else is up; [I] or [Esc] closes it
	# while it is the topmost thing.
	if is_open and UiStack.is_top("inventory") \
			and (Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("ui_cancel")):
		close()
		player.enable_movement()
		get_viewport().set_input_as_handled()
	elif not is_open and UiStack.is_free() and Input.is_action_just_pressed("inventory"):
		open()
		player.disable_movement()
		get_viewport().set_input_as_handled()

## The wheel and the number row pick what he is holding. Read here rather than
## in _unhandled_input(): the slots stop mouse events so they can be dragged,
## and a wheel turn over the panel would never reach the fall-through.
func _input(event: InputEvent) -> void:
	if EchoLog.journal_is_open():
		return
	# Nothing up, or the bag itself: neither the wheel nor the number row should
	# reach past the pause menu or a balloon to change what he is holding.
	if not (UiStack.is_free() or UiStack.is_top("inventory")):
		return
	if event.is_action_pressed("hotbar_next"):
		inv.scroll_selection(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hotbar_prev"):
		inv.scroll_selection(-1)
		get_viewport().set_input_as_handled()
		return
	# [1]-[4] go straight to a slot instead of wheeling round to it. One action
	# per slot, so widening HOTBAR_SIZE means adding "hotbar_5" to the input map
	# to match.
	for i in Inv.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			inv.select(i)
			get_viewport().set_input_as_handled()
			return

# Clicking a recovered page reads it: hand off to the Echo Log, which takes over
# input from here. Movement stays disabled throughout, so no need to re-enable.
func _on_read_requested(fragment: Fragment) -> void:
	close()
	EchoLog.open_journal(fragment.id)

## Dragged from one slot onto another — between the bag and the hotbar, or
## within either.
func _on_dropped(from_index: int, to_index: int) -> void:
	inv.move(from_index, to_index)

func open():
	UiStack.push("inventory")
	bag.visible = true
	is_open = true
	# Fade the world down rather than snapping it: the bag is a pause, and an
	# instant black sheet reads as a glitch at this length.
	if _fade != null:
		_fade.kill()
	dim.visible = true
	dim.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(dim, "modulate:a", 1.0, FADE)

func close():
	UiStack.pop("inventory")
	bag.visible = false
	# Straight out on the way back: he is returning to the world, and waiting on
	# a fade to hand him back his feet is worse than none at all.
	if _fade != null:
		_fade.kill()
		_fade = null
	dim.visible = false
	is_open = false

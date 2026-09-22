extends Panel

## One slot of the bag or the hotbar.
##
## Draws whatever InvSlot it is given, highlights itself when it is the one he
## is holding, and can be dragged onto another slot to rearrange the bag.

## Emitted when the player clicks a recovered page. The inventory UI listens,
## rather than this slot reaching up through the tree to find it.
signal read_requested(fragment: Fragment)
## Emitted when another slot is dropped onto this one. The inventory UI does the
## moving; the slot only reports where the drag started and ended.
signal dropped(from_index: int, to_index: int)

## The hotbar's highlight. The slot art has no selected frame of its own, so the
## backing tile is brightened rather than swapped — point this at a second atlas
## region instead if one ever gets drawn.
const TINT_IDLE := Color(1, 1, 1)
const TINT_SELECTED := Color(1.5, 1.4, 0.8)

@onready var item_visual: Sprite2D = $CenterContainer/Panel/item_display
@onready var amount_text: Label = $CenterContainer/Panel/Label
@onready var background: Sprite2D = $Sprite2D

## Which slot of the inventory this draws, assigned by the inventory UI. -1
## until then, which is what keeps a stray slot out of the drag and drop.
var index: int = -1

var current_slot: InvSlot
var _selected := false

func _ready():
	# Children default to MOUSE_FILTER_STOP and would swallow the click before
	# this Panel ever sees it, so let everything through to the slot itself.
	for child in find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_tint()

func update(slot: InvSlot):
	current_slot = slot
	if !slot.item:
		item_visual.visible = false
		amount_text.visible = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = ""
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		# A "1" in the corner tells the player nothing — the icon already says
		# he has one. The count only earns its place once things stack.
		amount_text.visible = slot.amount > 1
		amount_text.text = str(slot.amount)
		# Pages are readable; everything else is just carried.
		if slot.item is Fragment:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			tooltip_text = "Read \"%s\"" % (slot.item as Fragment).title
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			tooltip_text = slot.item.name

## Mark this as the slot he is holding from.
func set_selected(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	_apply_tint()

func _apply_tint() -> void:
	# Called from _ready() as well, for a slot told to highlight before its
	# children existed.
	if background != null:
		background.modulate = TINT_SELECTED if _selected else TINT_IDLE

func _gui_input(event: InputEvent) -> void:
	if current_slot == null or not (current_slot.item is Fragment):
		return
	# On release rather than press: a press is also the start of a drag, and a
	# page that opened the journal on the way past would tear it open mid-drag.
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		read_requested.emit(current_slot.item as Fragment)

# --- drag and drop ----------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if index < 0 or current_slot == null or current_slot.item == null:
		return null
	# The preview is parented to the viewport, outside this panel's scale, so it
	# is built at the size the slot actually covers on screen instead of the
	# 18px the layout thinks it is.
	var on_screen: Vector2 = size * get_global_transform_with_canvas().get_scale()
	var preview := TextureRect.new()
	preview.texture = current_slot.item.texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = on_screen
	preview.size = on_screen
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {"inv_index": index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return index >= 0 and data is Dictionary and data.has("inv_index")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(int(data["inv_index"]), index)

extends CanvasLayer
## Autoload "ItemHint" — the small plank that points at the guide the first time
## an item is picked up. Keyed on the item's name rather than its resource, so
## the torn pages, which are six resources, count as one item. The record is a
## flag, which makes it part of the save.

## How long the plank stays up, before its fade.
const HOLD_TIME := 4.0

var _panel: PanelContainer
var _tween: Tween


func _ready() -> void:
	# Below the pause menu (150) and bag, level with the quest banner.
	layer = 90
	_build()
	_panel.visible = false
	EchoLog.collected.connect(note)


## Quitting to the title can leave the plank mid-hold.
func _process(_delta: float) -> void:
	if _panel.visible and get_tree().current_scene is MainMenu:
		_panel.visible = false


## Called with whatever was just picked up. Silent from the second time on.
func note(item: InvItem) -> void:
	var flag := "seen_item.%s" % item.name
	if Flags.has(flag):
		return
	Flags.set_flag(flag)
	_show()


func _show() -> void:
	if _tween:
		_tween.kill()
	_panel.visible = true
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(_panel.hide)


func _build() -> void:
	_panel = PanelContainer.new()
	var sb := WoodUI.plank(WoodUI.WOOD, WoodUI.FRAME)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 24
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var col := VBoxContainer.new()
	_panel.add_child(col)
	col.add_child(WoodUI.label("NEW ITEM", 14, WoodUI.FRAME))
	col.add_child(WoodUI.label("Press G to open the guide", 22, WoodUI.BONE))

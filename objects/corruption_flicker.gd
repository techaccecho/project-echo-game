extends CanvasLayer
## The grove's glitch: every so often the whole picture inverts for a few
## frames, sometimes twice in a row, then goes back. Sells the "something is
## wrong with this place" fiction without touching collision or the player.
## Sits above the world and below the HUD.

@export var every_min := 7.0
@export var every_max := 22.0
@export var hold := 0.08
## Chance the flicker stutters into a second, shorter one.
@export var double_chance := 0.45

var _rect: ColorRect
var _timer := 0.0


func _ready() -> void:
	layer = 20
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
void fragment() {
	vec4 c = texture(screen, SCREEN_UV);
	COLOR = vec4(1.0 - c.rgb, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_rect.material = mat
	_rect.visible = false
	add_child(_rect)
	_timer = randf_range(3.0, every_min)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(every_min, every_max)
		_flicker()


func _flicker() -> void:
	_rect.visible = true
	await get_tree().create_timer(hold).timeout
	_rect.visible = false
	if randf() < double_chance:
		await get_tree().create_timer(randf_range(0.08, 0.2)).timeout
		_rect.visible = true
		await get_tree().create_timer(hold * 0.6).timeout
		_rect.visible = false

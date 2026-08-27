extends CanvasLayer

# Letters used for the QTE, minus anything already bound to movement/interaction
# (W, A, S, D, E, I, B, T) so the prompt never collides with normal controls.
const LETTER_POOL := "CFGHJKLMNOPQRUVXYZ"
const LETTER_DURATION := 0.8
const FEEDBACK_DURATION := 0.35

@onready var label: Label = $Label

var waiting_letter: String = ""
var hit_this_letter: bool = false

func _ready() -> void:
	label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if waiting_letter == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if char(event.unicode).to_upper() == waiting_letter:
			hit_this_letter = true

# Shows `length` random letters one at a time. Each must be pressed within
# LETTER_DURATION seconds to count as a hit (turns green; red if missed).
# Returns true only if every letter in the sequence was hit.
func play_sequence(length: int = 3) -> bool:
	label.visible = true
	var all_hit = true

	for i in range(length):
		var letter = LETTER_POOL[randi() % LETTER_POOL.length()]
		waiting_letter = letter
		hit_this_letter = false
		label.text = letter
		label.modulate = Color.WHITE

		var elapsed = 0.0
		while elapsed < LETTER_DURATION and not hit_this_letter:
			await get_tree().process_frame
			elapsed += get_process_delta_time()

		waiting_letter = ""
		label.modulate = Color.GREEN if hit_this_letter else Color.RED
		if not hit_this_letter:
			all_hit = false

		await get_tree().create_timer(FEEDBACK_DURATION).timeout

	label.visible = false
	return all_hit

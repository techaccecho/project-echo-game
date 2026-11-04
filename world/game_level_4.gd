extends Node2D
## Level 4 — The Haven. Baked by tools/gen_level4.py; this script owns what the
## bake cannot.
##
## The Haven is the only level with no route through it. There is no gate, no
## puzzle and nothing to break: the beats — Cedric's camp, the hooded stones,
## the altar at the centre, and the Guardian — sit far apart on an open plain
## and may be reached in any order. So what is here is the Guardian's wandering
## and two interactions, and it should stay that way; what belongs in this file
## is the finale's state, not progression gating.
##
## Still to come (the layout is built, the story is not): fragment 07 at the
## camp, the two-option closing choice, and the glitch hand-off to the blog.

const STORY := "res://dialogue/haven.dialogue"

## How long the Guardian stays in one stone before moving on.
const STAY := Vector2(12.0, 30.0)
## Now and then it does not settle at all. It leaves again almost at once,
## two or three times over, and then goes quiet for longer than usual. A fixed
## interval is a metronome you stop seeing after a few minutes; this way the
## plain occasionally looks like it is making up its mind.
const RESTLESS_CHANCE := 0.3
const BURST_HOPS := Vector2i(1, 3)
const BURST_WAIT := Vector2(2.5, 6.0)
## How much quicker the crossing is inside a burst. Taking the usual drifting
## 1.25s for each hop of a flurry reads as slow, not urgent.
const BURST_CROSS := 0.6
## The long stillness after a burst, so the burst reads as one.
const AFTER_BURST := Vector2(34.0, 58.0)
## It will not leave while the player is this close — you are standing there
## about to talk to it. Short on purpose: the crossing is worth seeing, so it
## is quite happy to move while you watch from across the plain.
const TOO_CLOSE := 76.0

var _player: CharacterBody2D
var _guardian: CharacterBody2D
## The stones it can inhabit, and which one it is in.
var _stones: Array[Node2D] = []
var _home := -1
var _until_move := 0.0
## Hops still owed to the burst it is in, whether the next crossing is one of
## them, and whether it has a burst to recover from. See _schedule().
var _burst := 0
var _quick := false
var _spent := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	Flags.set_flag("level4.arrived")
	$Altar/InteractionArea.interact = Callable(self, "_say").bind("altar")
	$Arch/ReturnArea.interact = Callable(self, "_on_arch")
	_guardian = $Entities/Guardian
	_stones.assign($Stones.get_children())
	# It starts in the stone nearest where the bake put it, so the level opens
	# with one of the ring lit rather than with a seventh figure beside them.
	_home = _nearest(_guardian.global_position)
	_guardian.global_position = _stones[_home].global_position
	_stones[_home].visible = false
	_schedule()


func _process(delta: float) -> void:
	if not _guardian.settled or _guardian.talking:
		return
	_until_move -= delta
	if _until_move > 0.0:
		return
	if _player != null and is_instance_valid(_player) \
			and _player.global_position.distance_to(_guardian.global_position) < TOO_CLOSE:
		return
	_schedule()
	_move_on()


# --- the Guardian's wandering ------------------------------------------------

## Leave the stone it is in and blow across to another one. The stone it
## leaves comes back as it lets go; the one it arrives in goes as it settles,
## so there is never a moment with two of it or none.
func _move_on() -> void:
	var next := _pick_stone()
	if next == _home:
		return
	await _guardian.vacate()
	_stones[_home].visible = true
	# -1 means "take your usual time"; a burst hop is quicker.
	var seconds := -1.0
	if _quick:
		seconds = BURST_CROSS * float(_guardian.cross_seconds)
	await _guardian.cross_to(_stones[next].global_position, seconds)
	_stones[next].visible = false
	_home = next
	await _guardian.settle()


## How long until it moves again, and whether that move is a quick one. Most
## waits are an ordinary long one; a few open a burst, in which every hop is
## short and quick; and the wait after a burst is longer than any ordinary one,
## so the flurry reads as a flurry rather than as the new tempo. Always called
## before the move it is scheduling, so no path through _process() can leave
## the timer expired with nothing booked.
func _schedule() -> void:
	if _burst > 0:                              # still inside one
		_burst -= 1
		_quick = true
		_until_move = randf_range(BURST_WAIT.x, BURST_WAIT.y)
	elif _spent:                                # the stillness after one
		_spent = false
		_quick = false
		_until_move = randf_range(AFTER_BURST.x, AFTER_BURST.y)
	elif randf() < RESTLESS_CHANCE:             # this move opens one
		_burst = randi_range(BURST_HOPS.x, BURST_HOPS.y)
		_spent = true
		_quick = true
		_until_move = randf_range(BURST_WAIT.x, BURST_WAIT.y)
	else:
		_quick = false
		_until_move = randf_range(STAY.x, STAY.y)


## Anywhere but where it is, and biased towards the far side of the plain so
## it does not shuffle between the same two neighbours all afternoon.
func _pick_stone() -> int:
	var best := _home
	var best_score := -1.0
	for i in _stones.size():
		if i == _home:
			continue
		var d := _stones[i].global_position.distance_to(_guardian.global_position)
		var score := d * randf_range(0.5, 1.5)
		if score > best_score:
			best_score = score
			best = i
	return best


func _nearest(to: Vector2) -> int:
	var best := 0
	for i in _stones.size():
		if _stones[i].global_position.distance_to(to) \
				< _stones[best].global_position.distance_to(to):
			best = i
	return best


# --- interactions ------------------------------------------------------------

## Back through the arch to the Corrupted Grove, at its gate.
func _on_arch() -> void:
	SceneManager.change_level("res://world/game_level_3.tscn", "GroveGate")


func _say(title: String) -> void:
	var res = load(STORY)
	if res == null:
		push_warning("GameLevel4: %s has not been imported yet." % STORY)
		return
	DialogueManager.show_dialogue_balloon(res, title, [self, _player])
	await DialogueManager.dialogue_ended

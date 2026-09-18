extends Node
## Autoload "Clock" — the time of day.
##
## A day is four phases — morning, afternoon, evening, night — and runs on a
## real-time clock while the game is unpaused. Nothing here draws anything: the
## world's light comes from a DayLight node in each outdoor level, which
## multiplies `tint()` into its CanvasModulate, and the little plank in the
## corner of the screen is ClockHud. Sleeping in a bed calls
## `sleep_until_morning()`.

signal phase_changed(phase: int)
signal day_changed(day: int)

enum Phase { MORNING, AFTERNOON, EVENING, NIGHT }
const PHASE_NAMES := ["Morning", "Afternoon", "Evening", "Night"]

## Real seconds for one full game day. Sixteen minutes: long enough that a
## phase is a stretch of play, short enough to see a night before the game is
## over.
const DAY_SECONDS := 16.0 * 60.0
## Where a new game and every morning begin.
const WAKE_HOUR := 7.0

## The colour the world is lit with at each hour, blended between the entries.
## Kept mild on purpose: night has to stay playable with no lamps in the pack.
const LIGHT := [
	[5.0,  Color(0.42, 0.46, 0.66)],   # last of the night
	[6.5,  Color(0.92, 0.74, 0.62)],   # dawn
	[8.5,  Color(1.00, 0.97, 0.90)],   # morning
	[12.0, Color(1.00, 1.00, 1.00)],   # noon
	[16.0, Color(1.00, 0.96, 0.88)],   # late afternoon
	[18.5, Color(1.00, 0.72, 0.50)],   # evening
	[20.5, Color(0.62, 0.52, 0.66)],   # dusk
	[22.0, Color(0.42, 0.46, 0.66)],   # night
]

var day: int = 1
## 0..24, fractional.
var hour: float = WAKE_HOUR
## Off on the title screen; on once a game starts.
var running: bool = false

var _last_phase: int = -1


func _process(delta: float) -> void:
	if not running:
		return
	hour += delta * 24.0 / DAY_SECONDS
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		day_changed.emit(day)
	_check_phase()


func phase() -> int:
	if hour >= 6.0 and hour < 12.0:
		return Phase.MORNING
	if hour >= 12.0 and hour < 17.0:
		return Phase.AFTERNOON
	if hour >= 17.0 and hour < 21.0:
		return Phase.EVENING
	return Phase.NIGHT


func phase_name() -> String:
	return PHASE_NAMES[phase()]


## The hour as "7:30", to the nearest ten minutes. A game hour is forty real
## seconds, so single minutes would tick past too fast to be worth reading.
func time_text() -> String:
	var minutes := int(round(hour * 60.0 / 10.0)) * 10
	minutes = minutes % (24 * 60)
	return "%d:%02d" % [minutes / 60, minutes % 60]


func is_night() -> bool:
	return phase() == Phase.NIGHT


## The world's light right now. White at noon, warm at the ends of the day,
## a cool blue-grey through the night.
func tint() -> Color:
	var n := LIGHT.size()
	for i in n:
		var h0: float = LIGHT[i][0]
		var h1: float = LIGHT[(i + 1) % n][0]
		var c0: Color = LIGHT[i][1]
		var c1: Color = LIGHT[(i + 1) % n][1]
		var span := h1 - h0
		if span <= 0.0:
			span += 24.0
		var since := hour - h0
		if since < 0.0:
			since += 24.0
		if since < span:
			return c0.lerp(c1, since / span)
	return Color.WHITE


## Begin a run at the first morning.
func start() -> void:
	day = 1
	hour = WAKE_HOUR
	running = true
	_last_phase = phase()


func set_time(new_day: int, new_hour: float) -> void:
	day = maxi(1, new_day)
	hour = fposmod(new_hour, 24.0)
	# A jump in time is still a change of phase to whoever is listening.
	_check_phase()


## Go to bed: the next morning arrives. Past midnight it is already the next
## day, so only the hour moves.
func sleep_until_morning() -> void:
	if hour >= WAKE_HOUR:
		day += 1
		day_changed.emit(day)
	hour = WAKE_HOUR
	_check_phase()


func _check_phase() -> void:
	var p := phase()
	if p != _last_phase:
		_last_phase = p
		phase_changed.emit(p)

extends Node
## Autoload "Lamp" — the oil in the player's lamp, and whether it is burning.
##
## The light itself is PlayerLamp, hung off whichever player node the current
## scene has; there is one of those per scene, so what has to outlast a scene
## change — how much oil is left, whether the wick is lit — lives here, and the
## save writes it from here.
##
## The player decides everything: [L] (or using the lamp from the hotbar)
## lights and douses it, and oil only goes in when he pours a flask himself —
## from the hotbar, or right-click in the bag. A lamp left burning in daylight
## burns just the same; nothing here is clever enough to save him the oil.

signal changed
## A short line for the HUD: "The lamp is already full."
signal message(text: String)

const LAMP_ITEM := preload("res://inventory/items/lamp.tres")
const OIL_ITEM := preload("res://inventory/items/oil_flask.tres")
const PLAYER_INV := preload("res://inventory/player_inv.tres")

const CAPACITY := 100.0
## Real seconds a full lamp burns for.
const BURN_SECONDS := 150.0
## What one flask puts back. Less than a full lamp, so a stack of flasks is
## worth carrying and topping up early wastes little.
const FLASK := 40.0
## The lamp is found with a little oil left in it — enough to learn what it
## does, not enough to get anywhere.
const START_FUEL := 40.0
## At or under this the flame starts guttering.
const LOW := 20.0
## Set the first time he picks up a flask; the quest list reads it.
const FLAG_OIL := "lamp.oil_found"

const POUR_SFX := "res://audio/sfx/splash.wav"
const CLICK_SFX := "res://audio/sfx/page_pickup.wav"

var fuel: float = START_FUEL
## Whether the wick is lit. Only ever true with oil in the lamp.
var on: bool = false


func _ready() -> void:
	PLAYER_INV.update.connect(_on_inventory_changed)


func _process(delta: float) -> void:
	if not on:
		return
	# Paused, on the title screen, or the lamp has left his bag: nothing burns.
	if not Clock.running or not has_lamp():
		return
	fuel = maxf(0.0, fuel - CAPACITY / BURN_SECONDS * delta)
	if fuel <= 0.0:
		on = false
		message.emit("The lamp sputters out.")
	changed.emit()


func has_lamp() -> bool:
	return PLAYER_INV.has(LAMP_ITEM)


func oil_count() -> int:
	return PLAYER_INV.count(OIL_ITEM)


## Whether the flame is actually giving light right now.
func is_lit() -> bool:
	return on and fuel > 0.0 and has_lamp()


func is_low() -> bool:
	return fuel <= LOW


## 0..1, for the HUD bar and the size of the pool of light.
func fraction() -> float:
	return fuel / CAPACITY


func toggle() -> void:
	if not has_lamp():
		return
	if not on and fuel <= 0.0:
		message.emit("The lamp is dry. Pour in some oil.")
		return
	on = not on
	Audio.sfx(CLICK_SFX, -10.0, 0.1)
	changed.emit()


## Pour one flask from the bag into the lamp. Returns whether any went in.
func refill() -> bool:
	if not has_lamp():
		message.emit("Nothing to pour it into yet.")
		return false
	if oil_count() <= 0:
		message.emit("No oil left.")
		return false
	if fuel >= CAPACITY - 0.5:
		message.emit("The lamp is already full.")
		return false
	PLAYER_INV.remove(OIL_ITEM, 1)
	fuel = minf(CAPACITY, fuel + FLASK)
	Audio.sfx(POUR_SFX, -16.0, 0.1)
	message.emit("You top up the lamp.")
	changed.emit()
	return true


## The one door for "use this item": the hotbar click and the bag's
## right-click both come through here. Returns false for anything that is not
## the lamp's business, so the caller can fall through to its own handling.
func use(item: InvItem) -> bool:
	if item == OIL_ITEM:
		refill()
		return true
	if item == LAMP_ITEM:
		toggle()
		return true
	return false


func can_use(item: InvItem) -> bool:
	return item == OIL_ITEM or item == LAMP_ITEM


# --- save -------------------------------------------------------------------

func reset() -> void:
	fuel = START_FUEL
	on = false
	changed.emit()


func restore(saved_fuel: float, saved_on: bool) -> void:
	fuel = clampf(saved_fuel, 0.0, CAPACITY)
	on = saved_on and fuel > 0.0
	changed.emit()


func _on_inventory_changed() -> void:
	if oil_count() > 0 and not Flags.has(FLAG_OIL):
		Flags.set_flag(FLAG_OIL)

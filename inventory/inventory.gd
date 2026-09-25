extends Resource

class_name Inv

signal update
## The highlighted hotbar slot changed, or what sits in it did. Anything gated
## on what he is holding — the axe swing, a fishing spot's prompt — listens to
## this as well as `update`.
signal selection_changed

## The first row of slots is the hotbar: what he is holding, wheeled through and
## drawn on screen whether or not the bag is open. The rest is the bag. insert()
## fills the first empty slot, so a tool he picks up lands in the hotbar and is
## usable without opening anything.
const HOTBAR_SIZE := 4

@export var slots: Array[InvSlot]

## Index into `slots` of the highlighted hotbar slot. Deliberately not exported:
## which tool is in his hand is a pose, not part of what he is carrying, so it
## starts at the first slot on every run and never reaches the save.
var selected: int = 0


## What he is holding, or null for an empty hand. This is the question the tools
## ask — as against has(), which only asks whether it is somewhere in the bag,
## and still answers for the quests.
func selected_item() -> InvItem:
	if selected < 0 or selected >= slots.size():
		return null
	var slot: InvSlot = slots[selected]
	if slot == null or slot.amount <= 0:
		return null
	return slot.item


## True if he is holding this. A null `item` means the caller never opted into
## the gate, so it passes — the same escape hatch has() callers rely on.
func holding(item: InvItem) -> bool:
	if item == null:
		return true
	return selected_item() == item


func select(index: int) -> void:
	var count: int = min(HOTBAR_SIZE, slots.size())
	if count <= 0:
		return
	var next: int = posmod(index, count)
	if next == selected:
		return
	selected = next
	selection_changed.emit()


## One step along the hotbar, wrapping at either end.
func scroll_selection(step: int) -> void:
	select(selected + step)


## Drag and drop: drop one slot onto another. Same item, and the two stack;
## different, and they trade places. Either way the held item may have changed,
## so the gates are told.
func move(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return
	if from_index < 0 or from_index >= slots.size():
		return
	if to_index < 0 or to_index >= slots.size():
		return
	var from: InvSlot = slots[from_index]
	var to: InvSlot = slots[to_index]
	if from == null or to == null or from.item == null:
		return
	if to.item == from.item:
		to.amount += from.amount
		from.item = null
		from.amount = 0
	else:
		var item: InvItem = to.item
		var amount: int = to.amount
		to.item = from.item
		to.amount = from.amount
		from.item = item
		from.amount = amount
	update.emit()
	selection_changed.emit()


# True if the player is carrying at least one of this item. Used to gate things
# like the rubble wall on the axe.
func has(item: InvItem) -> bool:
	if item == null:
		return false
	for slot in slots:
		if slot != null and slot.item == item and slot.amount > 0:
			return true
	return false

# How many of this item the player is carrying, across every slot. `has()` only
# answers yes/no; the blacksmith's three fish need the number.
func count(item: InvItem) -> int:
	if item == null:
		return 0
	var total := 0
	for slot in slots:
		if slot != null and slot.item == item:
			total += slot.amount
	return total


# The total across a set of interchangeable items — three kinds of fish are
# three fish, whichever ones they are.
func count_any(items: Array) -> int:
	var total := 0
	for item in items:
		total += count(item)
	return total


# Take items back out. Returns how many were actually removed, which is fewer
# than asked for if the player was not carrying enough.
func remove(item: InvItem, amount: int = 1) -> int:
	if item == null or amount <= 0:
		return 0
	var left := amount
	for slot in slots:
		if left <= 0:
			break
		if slot == null or slot.item != item:
			continue
		var taken: int = min(left, slot.amount)
		slot.amount -= taken
		left -= taken
		if slot.amount <= 0:
			slot.item = null
			slot.amount = 0
	if left < amount:
		update.emit()
		# The last of what he was holding may have just gone.
		selection_changed.emit()
	return amount - left


# Take `amount` from a set of interchangeable items, in the order given — the
# blacksmith does not care which three fish he gets.
func remove_any(items: Array, amount: int = 1) -> int:
	var left := amount
	for item in items:
		if left <= 0:
			break
		left -= remove(item, left)
	return amount - left


func insert(item: InvItem):
	# If the first slot is open, then its going to add a new item to that slot.
	# If the item passed equals item in a slot, add to amount
	var item_slots = slots.filter(func(slot): return slot.item == item)
	if !item_slots.is_empty():
		item_slots[0].amount += 1
	# If slot is empty
	else:
		var empty_slots = slots.filter(func(slot): return slot.item == null)
		if !empty_slots.is_empty():
			empty_slots[0].item = item
			empty_slots[0].amount = 1
	update.emit()
	# A tool landing in the highlighted slot arms it there and then.
	selection_changed.emit()

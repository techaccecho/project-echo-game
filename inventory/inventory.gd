extends Resource

class_name Inv

signal update
@export var slots: Array[InvSlot]

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

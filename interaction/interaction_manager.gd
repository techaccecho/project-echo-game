extends Node2D

#class_name InteractionManager

@onready var player = get_tree().get_first_node_in_group("player")
@onready var label = $Label

const base_text = "[E] to "

var active_areas = []
var can_interact = true

func register_area(area: InteractionArea):
	active_areas.push_back(area)

func deregister_area(area: InteractionArea):
	var index = active_areas.find(area)
	if index != -1:
		active_areas.remove_at(index)

func _process(_delta):
	# Remove nulls before doing anything
	active_areas = active_areas.filter(func(a): return a != null)
	
	if (active_areas.size() > 0 && can_interact):
		active_areas.sort_custom(_sort_by_distance_to_player)
		
		var closest = active_areas[0]
		if closest == null:
			return
		
		label.text = base_text + closest.action_name
		label.global_position = closest.global_position
		label.global_position.y -= 36
		#label.global_position.x = label.size.x / 2
		label.show()
	else:
		label.hide()

func _sort_by_distance_to_player(area1, area2):
	if area1 == null or area2 == null or player == null:
		return false
	
	var area1_to_player = player.global_position.distance_to(area1.global_position)
	var area2_to_player = player.global_position.distance_to(area2.global_position)
	return area1_to_player < area2_to_player

func _input(event):
	print("Active areas before: ", active_areas.size())
	if event.is_action_pressed("interact") && can_interact:
		if active_areas.size() > 0:
			### Change this to be able to interact with different things.
			## Might need to make object interactability instead of player interactability
			can_interact = false
			label.hide()
			
			await active_areas[0].interact.call()
			
			can_interact = true
	print("Active areas after: ", active_areas.size())

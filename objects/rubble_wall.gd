extends Node2D
## Rubble wall (Level 2) — stone and vine piled across the way to the cave.
##
## Cleared the same way the Level 1 trees are felled: swing the axe at it.
## Each hit knocks a stone off the pile (HurtComponent → DamageComponent, like
## MapleTreeHittableLight); the last one bursts it apart. Pressing interact
## only inspects — it tells you what you need, it doesn't do the work.

signal cleared

## Set once the wall is down, so it stays down.
const FLAG := "level2.rubble_cleared"
const CRUMBLE_SFX := "res://audio/sfx/stone_crumble.wav"

## Item the player must be carrying to clear this. Leave null to allow anyone.
@export var required_item: InvItem
@export var blocked_title: String = "blocked"
@export var hint_title: String = "hint"
@export var cleared_title: String = "cleared"

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var body: StaticBody2D = $Body
@onready var body_shape: CollisionShape2D = $Body/CollisionShape2D
@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent
@onready var rubble: Node2D = $Rubble
@onready var boulder: Sprite2D = $Rubble/Boulder
@onready var cluster: Sprite2D = $Rubble/Cluster
@onready var debris: Array[Sprite2D] = [$Rubble/MossyLeft, $Rubble/MossyRight]
@onready var chips: CPUParticles2D = $Chips
@onready var dust: CPUParticles2D = $Dust

var dialogue_resource = load("res://dialogue/rubble_wall.dialogue")
var player: CharacterBody2D
var is_cleared: bool = false
var being_hit: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")
	hurt_component.hurt.connect(_on_hurt)
	damage_component.max_damage_reached.connect(_on_max_damage_reached)
	if Flags.has(FLAG):
		_already_cleared()
		return


## Cleared on an earlier visit: only the scattered leftovers, nothing to hit.
func _already_cleared() -> void:
	is_cleared = true
	boulder.visible = false
	cluster.visible = false
	for d in debris:
		d.visible = true
	body_shape.disabled = true
	hurt_component.queue_free()
	interaction_area.monitoring = false
	interaction_area.queue_free()


func _player_has_tool() -> bool:
	if required_item == null:
		return true
	if player == null or player.inv == null:
		return false
	return player.inv.has(required_item)


func _on_interact() -> void:
	if is_cleared:
		return
	var title := hint_title if _player_has_tool() else blocked_title
	DialogueManager.show_dialogue_balloon(dialogue_resource, title, [self, player])


# --- taking hits ------------------------------------------------------------

func _on_hurt(hit_damage: int) -> void:
	if being_hit or is_cleared:
		return
	being_hit = true
	var stage: int = damage_component.current_damage + hit_damage
	if stage >= damage_component.max_damage:
		await _burst()
	else:
		await _knock(stage)
	damage_component.apply_damage(hit_damage)
	being_hit = false


func _on_max_damage_reached() -> void:
	is_cleared = true
	Flags.set_flag(FLAG)
	cleared.emit()
	DialogueManager.show_dialogue_balloon(dialogue_resource, cleared_title, [self, player])


## A hit that doesn't finish it: the pile shudders and loses a stone off the
## top. Stage 1 takes the boulder's peak, stage 2 the cluster's upper rock.
func _knock(stage: int) -> void:
	Audio.sfx(CRUMBLE_SFX, -10.0, 0.15)
	var from: Sprite2D
	match stage:
		1:
			from = boulder
			_throw_piece(boulder, Rect2(10, 1, 12, 14), Vector2(-8, -26), -1.0)
			_crop_bottom(boulder, 14)
		_:
			from = cluster
			_throw_piece(cluster, Rect2(6, 3, 20, 13), Vector2(-3, -15), 1.0)
			_crop_bottom(cluster, 16)
	_puff(from.global_position + Vector2(0, -8), 5, 8)
	await _shudder()


## The last hit: what's left splits and tumbles off to either side, and the
## small stones that were buried in the pile are all that stays.
func _burst() -> void:
	Audio.sfx(CRUMBLE_SFX, -3.0, 0.05)
	InteractionManager.deregister_area(interaction_area)
	interaction_area.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	hurt_component.set_deferred("monitoring", false)
	for s in [boulder, cluster]:
		var r: Rect2 = s.region_rect
		var half: float = r.size.x / 2.0
		_throw_piece(s, Rect2(r.position.x, r.position.y, half, r.size.y), Vector2(-half / 2.0, 0), -1.0, true)
		_throw_piece(s, Rect2(r.position.x + half, r.position.y, half, r.size.y), Vector2(half / 2.0, 0), 1.0, true)
		s.visible = false
	_puff(rubble.global_position + Vector2(0, -2), 12, 24)
	for d in debris:
		d.modulate.a = 0.0
		d.visible = true
		create_tween().tween_property(d, "modulate:a", 1.0, 0.5).set_delay(0.3)
	await _shudder()


func _shudder() -> void:
	var t := create_tween()
	rubble.modulate = Color(1.6, 1.6, 1.6)
	t.tween_property(rubble, "modulate", Color.WHITE, 0.18)
	var base := rubble.position
	for i in range(5):
		var off := Vector2((1.6 if i % 2 == 0 else -1.6) * (1.0 - i / 5.0), 0.0)
		t.parallel().tween_property(rubble, "position", base + off, 0.05).set_delay(i * 0.05)
	t.tween_property(rubble, "position", base, 0.05)
	await t.finished


## Keep only the bottom rows of a stone's region — the part still standing —
## without letting its base move.
func _crop_bottom(s: Sprite2D, top_row: int) -> void:
	var r := s.region_rect
	var cut := top_row - r.position.y
	s.region_rect = Rect2(r.position.x, top_row, r.size.x, r.size.y - cut)
	s.position.y += cut / 2.0


## A chunk of `s` (region in that sprite's texture space) that flies off in an
## arc, spinning, and fades where it lands. `dir` is which way it goes.
func _throw_piece(s: Sprite2D, region: Rect2, local_offset: Vector2, dir: float, low: bool = false) -> void:
	var p := Sprite2D.new()
	p.texture = s.texture
	p.region_enabled = true
	p.region_rect = Rect2(s.region_rect.position + region.position, region.size)
	p.z_index = z_index + 1
	add_child(p)
	var start := s.position + local_offset
	p.position = start
	var land := start + Vector2(dir * randf_range(14, 26), randf_range(8, 16))
	var peak := -randf_range(10, 18)
	if low:
		# The base splitting: pieces slump outward rather than fly.
		land = start + Vector2(dir * randf_range(20, 30), randf_range(6, 12))
		peak = -randf_range(4, 8)
	var dur := randf_range(0.42, 0.55)
	var spin := dir * randf_range(0.4, 0.7) * PI
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		p.position = start.lerp(land, k) + Vector2(0, peak * 4.0 * k * (1.0 - k))
		p.rotation = spin * k, 0.0, 1.0, dur)
	t.tween_property(p, "modulate:a", 0.0, 0.8).set_delay(0.6)
	t.tween_callback(p.queue_free)


func _puff(at: Vector2, chip_count: int, dust_count: int) -> void:
	chips.global_position = at
	chips.amount = chip_count
	chips.restart()
	dust.global_position = at
	dust.amount = dust_count
	dust.restart()

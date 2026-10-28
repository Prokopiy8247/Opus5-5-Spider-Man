extends Node
## Autoload "GameState": persistent player stats for the session.

const MAX_FOCUS: float = 3.0

var hp: float = 100.0
var max_hp: float = 100.0
var focus: float = 0.0
var xp: int = 0
var level: int = 1
var skill_points: int = 0
var suit_id: StringName = &"classic"
var gadget_index: int = 0
var ammo: Dictionary = {}
var skills: Array[StringName] = []
var invincible: bool = false
## Multipliers recomputed from skills and suit by Progression.
var mods: Dictionary = {}


func _ready() -> void:
	reset_mods()


func reset_mods() -> void:
	mods = {
		&"damage": 1.0, &"focus_gain": 1.0, &"swing_speed": 1.0, &"zip_speed": 1.0,
		&"damage_taken": 1.0, &"perfect_window": 0.15, &"heal_amount": 35.0,
		&"combo_window": 1.6, &"gadget_ammo": 1.0, &"web_strike_range": 14.0,
		&"takedown_range": 2.6, &"air_combo": 0.0, &"finisher_cost": 3.0,
	}


const SKILL_STATS: Dictionary = {
	&"damage": &"attack_damage", &"swing_speed": &"swing_speed", &"zip_speed": &"zip_speed",
	&"focus_gain": &"focus_gain", &"perfect_window": &"dodge_window",
}


## Base modifier times the Skills/Suits multiplier for the matching contract stat.
func mod(id: StringName, fallback: float = 1.0) -> float:
	var v: float = float(mods.get(id, fallback))
	var sk: Node = get_node_or_null(^"/root/Skills")
	if sk != null and SKILL_STATS.has(id):
		v *= float(sk.call(&"get_modifier", SKILL_STATS[id]))
	return v


func refresh_max_hp() -> void:
	var sk: Node = get_node_or_null(^"/root/Skills")
	var m: float = float(sk.call(&"get_modifier", &"max_health")) if sk != null else 1.0
	var ratio: float = hp / maxf(max_hp, 1.0)
	max_hp = 100.0 * m
	hp = max_hp * ratio
	Events.health_changed.emit(hp)


func has_skill(id: StringName) -> bool:
	return skills.has(id)


func set_hp(v: float) -> void:
	hp = clampf(v, 0.0, max_hp)
	Events.health_changed.emit(hp)


func damage(amount: float, from_dir: Vector3) -> float:
	if invincible or amount <= 0.0:
		return 0.0
	var dealt: float = amount * mod(&"damage_taken")
	set_hp(hp - dealt)
	Events.player_damaged.emit(dealt, from_dir)
	return dealt


func add_focus(v: float) -> void:
	var gain: float = v * (mod(&"focus_gain") if v > 0.0 else 1.0)
	focus = clampf(focus + gain, 0.0, MAX_FOCUS)
	Events.focus_changed.emit(focus)


func add_xp(n: int, reason: StringName = &"debug") -> void:
	if n <= 0:
		return
	xp += n
	Events.xp_gained.emit(n, reason)
	while xp >= xp_for_level(level + 1):
		level += 1
		skill_points += 1
		Events.level_up.emit(level)
	var sk: Node = get_node_or_null(^"/root/Skills")
	if sk != null:
		sk.call(&"save_progress")


## Cumulative XP needed to reach `lvl`.
func xp_for_level(lvl: int) -> int:
	var n: int = maxi(lvl - 1, 0)
	return 300 * n + 50 * n * n

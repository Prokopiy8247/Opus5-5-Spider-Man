class_name SuitManager
extends Node
## Autoload "Suits" (register after "Skills"). Loads suits.json, applies colors via
## HeroVisual.apply_suit on the player and exposes stat bonuses to Skills.get_modifier.

const DATA_PATH: String = "res://data/progression/suits.json"

var current: StringName = &"classic"
var _suits: Array[Dictionary] = []


func _ready() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if raw is Array:
		for v: Variant in raw:
			if v is Dictionary:
				_suits.append(v as Dictionary)
	current = GameState.suit_id if _find(GameState.suit_id).size() > 0 else &"classic"
	_apply_visual.call_deferred()


func get_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in _suits:
		var c: Dictionary = d.duplicate(true)
		c["equipped"] = StringName(str(d["id"])) == current
		out.append(c)
	return out


func equip(id: StringName) -> void:
	if _find(id).is_empty():
		return
	current = id
	GameState.suit_id = id
	_apply_visual()
	Events.suit_changed.emit(id)
	var sk: Node = get_node_or_null(^"/root/Skills")
	if sk != null:
		sk.call(&"save_progress")


func get_bonus(stat: StringName) -> float:
	return float((_find(current).get("bonus", {}) as Dictionary).get(String(stat), 1.0))


func _find(id: StringName) -> Dictionary:
	for d: Dictionary in _suits:
		if StringName(str(d.get("id", ""))) == id:
			return d
	return {}


func _apply_visual() -> void:
	var d: Dictionary = _find(current)
	var p: Node = get_tree().get_first_node_in_group(&"player")
	if d.is_empty() or p == null:
		return
	var hv: Node = p.find_child("HeroVisual", true, false)
	if hv == null:
		hv = p.get_node_or_null(^"Visual")
	if hv != null and hv.has_method(&"apply_suit"):
		hv.call(&"apply_suit", Color.html(str(d["primary"])), Color.html(str(d["secondary"])), Color.html(str(d["emblem"])))

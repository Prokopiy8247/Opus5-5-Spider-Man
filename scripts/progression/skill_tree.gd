class_name SkillTree
extends Node
## Autoload "Skills". Loads data/progression/skills.json, spends GameState.skill_points,
## multiplies effects of unlocked skills and the equipped suit bonus. Saves user://progress.json.

const DATA_PATH: String = "res://data/progression/skills.json"
const SAVE_PATH: String = "user://progress.json"
## QA runs (--qa=...) use their own file, wiped at startup, so bots never touch or depend on the player's save.
const QA_SAVE_PATH: String = "user://progress_qa.json"

var save_path: String = SAVE_PATH

var _skills: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _unlocked: Array[StringName] = []


func _ready() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if raw is Array:
		for v: Variant in raw:
			if v is Dictionary:
				var d: Dictionary = v
				_skills.append(d)
				_by_id[StringName(str(d.get("id", "")))] = d
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa="):
			save_path = QA_SAVE_PATH
			DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))
	load_progress()


func get_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in _skills:
		var c: Dictionary = d.duplicate(true)
		c["unlocked"] = is_unlocked(StringName(str(d["id"])))
		c["can_unlock"] = can_unlock(StringName(str(d["id"])))
		out.append(c)
	return out


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func can_unlock(id: StringName) -> bool:
	if not _by_id.has(id) or is_unlocked(id):
		return false
	var d: Dictionary = _by_id[id]
	if GameState.skill_points < int(d.get("cost", 1)):
		return false
	for r: Variant in d.get("requires", []):
		if not is_unlocked(StringName(str(r))):
			return false
	return true


func unlock(id: StringName) -> bool:
	if not can_unlock(id):
		return false
	GameState.skill_points -= int((_by_id[id] as Dictionary).get("cost", 1))
	_unlocked.append(id)
	GameState.skills = _unlocked.duplicate()
	Events.skill_unlocked.emit(id)
	GameState.refresh_max_hp()
	save_progress()
	return true


## Product of unlocked skill effects and the current suit bonus for `stat`; 1.0 by default.
func get_modifier(stat: StringName) -> float:
	var m: float = 1.0
	var key: String = String(stat)
	for id: StringName in _unlocked:
		var eff: Dictionary = (_by_id[id] as Dictionary).get("effect", {})
		m *= float(eff.get(key, 1.0))
	var suits: Node = get_node_or_null(^"/root/Suits")
	if suits != null and suits.has_method(&"get_bonus"):
		m *= float(suits.call(&"get_bonus", stat))
	return m


func save_progress() -> void:
	var suit: String = str(GameState.suit_id)
	var suits: Node = get_node_or_null(^"/root/Suits")
	if suits != null:
		suit = str(suits.get(&"current"))
	var data: Dictionary = {
		"xp": GameState.xp, "level": GameState.level, "skill_points": GameState.skill_points,
		"skills": _unlocked.map(func(s: StringName) -> String: return String(s)), "suit": suit,
	}
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))


func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not raw is Dictionary:
		return
	var d: Dictionary = raw
	GameState.xp = int(d.get("xp", GameState.xp))
	GameState.level = int(d.get("level", GameState.level))
	GameState.skill_points = int(d.get("skill_points", GameState.skill_points))
	_unlocked.clear()
	for s: Variant in d.get("skills", []):
		if _by_id.has(StringName(str(s))):
			_unlocked.append(StringName(str(s)))
	GameState.skills = _unlocked.duplicate()
	GameState.suit_id = StringName(str(d.get("suit", "classic")))

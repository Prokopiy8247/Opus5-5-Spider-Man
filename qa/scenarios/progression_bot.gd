extends "res://qa/scenarios/qa_scenario.gd"
## Adds XP, unlocks 3 skills through Skills.unlock, checks get_modifier changed,
## equips a different suit through Suits.equip.

const STATS: Array[StringName] = [&"swing_speed", &"zip_speed", &"attack_damage", &"max_health",
	&"focus_gain", &"gadget_cooldown", &"dodge_window", &"stealth_radius"]


func run() -> void:
	await wait_player()
	var gs: Node = get_autoload("GameState")
	var skills: Node = get_autoload("Skills")
	var suits: Node = get_autoload("Suits")
	if gs == null or skills == null or suits == null:
		fail("autoload missing: GameState=%s Skills=%s Suits=%s" % [gs != null, skills != null, suits != null])
		return
	var xp0: int = int(gs.get("xp"))
	if gs.has_method("add_xp"):
		gs.call("add_xp", 5000, &"qa")
	else:
		gs.set("xp", xp0 + 5000)
	await frames(2)
	metrics["xp_gained"] = int(gs.get("xp")) - xp0
	metrics["level"] = int(gs.get("level"))
	# Make sure there are enough points even if level-ups grant few.
	if int(gs.get("skill_points")) < 10:
		gs.set("skill_points", 10)
	var mods0: Dictionary = _mods(skills)
	var unlocked: Array[String] = []
	# Several passes so prerequisites unlocked earlier enable dependants.
	for pass_i: int in 4:
		for e: Dictionary in skills.call("get_all") as Array:
			if unlocked.size() >= 3:
				break
			var id: StringName = StringName(str(e.get("id", "")))
			if bool(skills.call("is_unlocked", id)) or not bool(skills.call("can_unlock", id)):
				continue
			if bool(skills.call("unlock", id)) and bool(skills.call("is_unlocked", id)):
				unlocked.append(String(id))
	metrics["unlocked"] = unlocked
	if unlocked.size() < 3:
		fail("only %d skills unlocked" % unlocked.size())
	var mods1: Dictionary = _mods(skills)
	var changed: Array[String] = []
	for s: StringName in STATS:
		if not is_equal_approx(float(mods0[s]), float(mods1[s])):
			changed.append(String(s))
	metrics["modifiers_changed"] = changed
	if changed.is_empty():
		fail("get_modifier unchanged after unlocking %s" % str(unlocked))
	# Persistence: wipe in-memory state, reload from the save file, unlocks must come back.
	skills.call("save_progress")
	var sp: int = int(gs.get("skill_points"))
	gs.set("skill_points", 0)
	skills.call("load_progress")
	var restored: int = 0
	for id: String in unlocked:
		if bool(skills.call("is_unlocked", StringName(id))):
			restored += 1
	metrics["reloaded_skills"] = restored
	metrics["reloaded_skill_points"] = int(gs.get("skill_points"))
	if restored != unlocked.size() or int(gs.get("skill_points")) != sp:
		fail("save/load lost progress: %d/%d skills, points %d vs %d" % [restored, unlocked.size(), int(gs.get("skill_points")), sp])
	# attack_damage multiplier reaches the combat damage formula through GameState.mod(&"damage").
	metrics["damage_mod"] = float(gs.call("mod", &"damage"))
	# Suit swap
	var cur: StringName = StringName(str(suits.get("current")))
	var target: StringName = &""
	for e: Dictionary in suits.call("get_all") as Array:
		var id: StringName = StringName(str(e.get("id", "")))
		if id != cur:
			target = id
			break
	if target == &"":
		fail("no alternative suit to equip")
		return
	var seen: Array[StringName] = []
	var ev: Node = get_autoload("Events")
	if ev != null and ev.has_signal("suit_changed"):
		ev.connect("suit_changed", func(id: StringName) -> void: seen.append(id))
	suits.call("equip", target)
	await frames(3)
	await screenshot("suit_%s" % target)
	metrics["suit_from"] = String(cur)
	metrics["suit_to"] = String(target)
	metrics["suit_changed_events"] = seen.size()
	if StringName(str(suits.get("current"))) != target:
		fail("Suits.current is '%s' after equip('%s')" % [suits.get("current"), target])


func _mods(skills: Node) -> Dictionary:
	var d: Dictionary = {}
	for s: StringName in STATS:
		d[s] = float(skills.call("get_modifier", s))
	return d

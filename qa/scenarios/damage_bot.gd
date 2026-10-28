extends "res://qa/scenarios/qa_scenario.gd"
## Spawns a thug, measures hit damage with attack_damage at level 0 (no skill),
## unlocks the attack_damage skill chain (level 1) and measures again.
## Skills persist to user://progress_qa.json (SkillTree switches there under --qa=).

var checks: Dictionary = {}
var _last_dmg: float = -1.0


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var skills: Node = get_autoload("Skills")
	var gs: Node = get_autoload("GameState")
	var ev: Node = get_autoload("Events")
	if skills == null or gs == null or ev == null:
		fail("autoload missing")
		return
	ev.connect("hit_landed", func(_t: Node3D, d: float, _c: int) -> void: _last_dmg = d)
	var w: Node = get_world()
	if w != null and w.has_method("teleport_point") and p.has_method("teleport"):
		p.call("teleport", w.call("teleport_point", &"base") as Vector3)
	await seconds(1.0)
	metrics["save_path"] = str(skills.get("save_path"))
	checks["qa_save_file"] = str(skills.get("save_path")) == "user://progress_qa.json"
	var mod0: float = float(skills.call("get_modifier", &"attack_damage"))
	var dmg0: float = await _measure(p, w)
	_unlock_attack(skills, gs)
	var mod1: float = float(skills.call("get_modifier", &"attack_damage"))
	var dmg1: float = await _measure(p, w)
	metrics["attack_mod_level0"] = mod0
	metrics["attack_mod_level1"] = mod1
	metrics["damage_level0"] = snappedf(dmg0, 0.01)
	metrics["damage_level1"] = snappedf(dmg1, 0.01)
	checks["hit_level0"] = dmg0 > 0.0
	checks["hit_level1"] = dmg1 > 0.0
	checks["modifier_increased"] = mod1 > mod0
	checks["damage_increased"] = dmg1 > dmg0
	await screenshot("damage_level1")
	metrics["checks"] = checks
	for k: String in checks:
		if not bool(checks[k]):
			fail("check failed: " + k)


## Unlocks skills (prerequisites first) until one with an attack_damage effect is unlocked.
func _unlock_attack(skills: Node, gs: Node) -> void:
	gs.set("skill_points", 50)
	var target: StringName = &""
	for e: Dictionary in skills.call("get_all") as Array:
		var eff: Variant = e.get("effect", {})
		if eff is Dictionary and (eff as Dictionary).has("attack_damage") and float((eff as Dictionary)["attack_damage"]) > 1.0:
			target = StringName(str(e["id"]))
			break
	if target == &"":
		fail("no skill with attack_damage effect")
		return
	metrics["attack_skill"] = String(target)
	for i: int in 6:
		if bool(skills.call("is_unlocked", target)):
			break
		for e: Dictionary in skills.call("get_all") as Array:
			var id: StringName = StringName(str(e["id"]))
			# Unlock only target's ancestors and target itself.
			if _is_needed(skills, id, target) and bool(skills.call("can_unlock", id)):
				skills.call("unlock", id)
	checks["attack_skill_unlocked"] = bool(skills.call("is_unlocked", target))


func _is_needed(skills: Node, id: StringName, target: StringName) -> bool:
	if id == target:
		return true
	for e: Dictionary in skills.call("get_all") as Array:
		if StringName(str(e["id"])) == target:
			for r: Variant in e.get("requires", []):
				if _is_needed(skills, id, StringName(str(r))):
					return true
	return false


## Spawns one thug 2 m in front of the player, attacks until the first hit lands; returns its damage.
## Only the bot's own thug is freed, so base guards (owned by EnemyBase) stay intact.
## Uses the first combo hit only (combo resets between measurements).
var _own: Array = []


func _measure(p: Node3D, w: Node) -> float:
	for e: Variant in _own:
		if is_instance_valid(e):
			(e as Node).queue_free()
	_own.clear()
	await seconds(1.5) # let combo window expire
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# spawn_enemies offsets a single enemy by +3.5 m on X; compensate so it lands 2 m ahead.
	var at: Vector3 = p.global_position + fwd * 2.0 - Vector3(3.5, 0.0, 0.0)
	if w != null and w.has_method("spawn_enemies"):
		_own = w.call("spawn_enemies", &"thug", 1, at) as Array
	await frames(5)
	_last_dmg = -1.0
	var t: float = 0.0
	while t < 12.0 and _last_dmg < 0.0 and is_instance_valid(p):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var move: Vector2 = Vector2.ZERO
		if not _own.is_empty() and is_instance_valid(_own[0]):
			var tgt: Node3D = _own[0] as Node3D
			if p.global_position.distance_to(tgt.global_position) > 2.5:
				move = Vector2(0, 1)
		bot(p, move, {"attack": int(t * 10.0) % 2 == 0})
	bot(p, Vector2.ZERO, {})
	return _last_dmg

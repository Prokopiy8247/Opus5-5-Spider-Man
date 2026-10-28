extends "res://qa/scenarios/qa_scenario.gd"
## Uses all 5 gadgets through Player.set_bot_input("gadget_use"/"gadget_next").
## Pass: Events.gadget_used fired with 5 distinct ids.

const EXPECTED: Array[StringName] = [&"web_bomb", &"impact_web", &"trip_mine", &"electric_web", &"suspension_matrix"]

var used: Array[StringName] = []


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var ev: Node = get_autoload("Events")
	if ev == null or not ev.has_signal("gadget_used"):
		fail("Events.gadget_used signal missing")
		return
	ev.connect("gadget_used", func(id: StringName) -> void:
		if not used.has(id):
			used.append(id))
	var w: Node = get_world()
	if w != null and w.has_method("teleport_point") and p.has_method("teleport"):
		p.call("teleport", w.call("teleport_point", &"base"))
	await seconds(1.0)
	if w != null and w.has_method("spawn_enemies"):
		# Ring of 3.5 m around the player: inside web_bomb's 5 m radius.
		w.call("spawn_enemies", &"thug", 4, p.global_position)
	await seconds(1.5)
	await screenshot("before")
	for slot: int in EXPECTED.size():
		var before: int = used.size()
		# Retry a few times: a gadget may need a target in range (enemies walk in).
		for attempt: int in 8:
			await _tap(p, "gadget_use")
			await seconds(0.5)
			if used.size() > before:
				break
		if used.size() == before:
			fail("slot %d: gadget_use produced no gadget_used" % slot)
		await _tap(p, "gadget_next")
		await seconds(0.3)
	await screenshot("after")
	var ids: Array[String] = []
	for id: StringName in used:
		ids.append(String(id))
	metrics["gadget_ids"] = ids
	metrics["distinct_gadgets"] = used.size()
	for id: StringName in EXPECTED:
		if not used.has(id):
			fail("gadget '%s' never emitted gadget_used" % id)


func _tap(p: Node3D, action: String) -> void:
	bot(p, Vector2.ZERO, {action: true})
	await get_tree().physics_frame
	await get_tree().physics_frame
	bot(p, Vector2.ZERO, {})
	await get_tree().physics_frame

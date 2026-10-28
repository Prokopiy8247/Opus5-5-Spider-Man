extends "res://qa/scenarios/qa_scenario.gd"
## Opens/closes K (open_skills), L (open_suits), M (open_map) via Input actions,
## cycles the gadget wheel with Tab (gadget_next), then equips another suit through
## Suits and checks that the hero's Suit_Primary colour changed.

var checks: Dictionary = {}


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	await seconds(1.0)
	for spec: Array in [["open_skills", "SkillMenu", "skills"], ["open_suits", "SuitMenu", "suits"], ["open_map", "MapScreen", "map"]]:
		await _menu_cycle(String(spec[0]), String(spec[1]), String(spec[2]))
	await _wheel_check(p)
	await _suit_check(p)
	metrics["checks"] = checks
	for k: String in checks:
		if not bool(checks[k]):
			fail("check failed: " + k)


func _find_ui(n: String) -> Control:
	return get_tree().root.find_child(n, true, false) as Control


## Input.action_press alone emits no InputEvent, so menus listening in _unhandled_input
## also get an InputEventAction through parse_input_event.
func _tap(action: String) -> void:
	Input.action_press(action)
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(3)
	Input.action_release(action)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(3)


func _menu_cycle(action: String, node_name: String, label: String) -> void:
	var m: Control = _find_ui(node_name)
	if m == null:
		checks["%s_found" % label] = false
		return
	checks["%s_found" % label] = true
	await _tap(action)
	checks["%s_opened" % label] = m.visible
	checks["%s_paused" % label] = get_tree().paused
	await screenshot("menu_%s_open" % label)
	await _tap(action)
	checks["%s_closed" % label] = not m.visible and not get_tree().paused
	if m.visible:
		m.visible = false
		get_tree().paused = false


func _wheel_check(p: Node3D) -> void:
	var wheel: Control = _find_ui("GadgetWheel")
	if wheel == null or not wheel.has_method("selected_index"):
		checks["wheel_found"] = false
		return
	checks["wheel_found"] = true
	await frames(3)
	var before: int = int(wheel.call("selected_index"))
	await _tap("gadget_next")
	await frames(3)
	var after: int = int(wheel.call("selected_index"))
	if after == before:
		# Player reads gadget_next through its bot-input layer when not driven by real keys.
		bot(p, Vector2.ZERO, {"gadget_next": true})
		await get_tree().physics_frame
		await get_tree().physics_frame
		bot(p, Vector2.ZERO, {})
		await frames(3)
		after = int(wheel.call("selected_index"))
		metrics["wheel_used_bot_fallback"] = true
	metrics["wheel_before"] = before
	metrics["wheel_after"] = after
	checks["wheel_tab_changes_slot"] = before >= 0 and after >= 0 and after != before
	await screenshot("gadget_wheel")


func _suit_check(p: Node3D) -> void:
	var suits: Node = get_autoload("Suits")
	if suits == null:
		checks["suit_color_changed"] = false
		return
	var c0: Variant = _primary_color(p)
	var cur: StringName = StringName(str(suits.get("current")))
	var target: StringName = &""
	for e: Dictionary in suits.call("get_all") as Array:
		var id: StringName = StringName(str(e.get("id", "")))
		if id != cur:
			target = id
			break
	suits.call("equip", target)
	await frames(4)
	var c1: Variant = _primary_color(p)
	metrics["suit_from"] = String(cur)
	metrics["suit_to"] = String(target)
	metrics["primary_before"] = str(c0)
	metrics["primary_after"] = str(c1)
	checks["suit_primary_found"] = c0 != null and c1 != null
	checks["suit_color_changed"] = c0 != null and c1 != null and not (c0 as Color).is_equal_approx(c1 as Color)
	await screenshot("suit_%s" % target)


## Albedo of the first Suit_Primary material (surface override first) or role=primary override.
func _primary_color(n: Node) -> Variant:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		var ov: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if ov != null and ov.has_meta(&"role") and StringName(ov.get_meta(&"role")) == &"primary":
			return ov.albedo_color
		if mi.mesh != null:
			for i: int in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(i)
				if m != null and m.resource_name.begins_with("Suit_Primary"):
					var o: BaseMaterial3D = mi.get_surface_override_material(i) as BaseMaterial3D
					if o != null:
						return o.albedo_color
					if m is BaseMaterial3D:
						return (m as BaseMaterial3D).albedo_color
	for c: Node in n.get_children():
		var r: Variant = _primary_color(c)
		if r != null:
			return r
	return null

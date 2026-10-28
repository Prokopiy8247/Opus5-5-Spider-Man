class_name SkillMenu
extends Control
## Skill screen. Toggled by "open_skills" (K); pauses the tree while open.

var _list: VBoxContainer
var _points: Label


func _ready() -> void:
	name = "SkillMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(640, 560)
	root.position = Vector2(-320, -280)
	add_child(root)
	var title := Label.new()
	title.text = "SKILLS"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	_points = Label.new()
	root.add_child(_points)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 480)
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "SkillList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var hint := Label.new()
	hint.text = "K - close"
	root.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_skills"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		rebuild()


func rebuild() -> void:
	_points.text = "Skill points: %d" % GameState.skill_points
	for c: Node in _list.get_children():
		c.queue_free()
	var skills: Array[Dictionary] = Skills.get_all()
	for s: Dictionary in skills:
		var id := StringName(str(s.get("id", "")))
		var row := HBoxContainer.new()
		row.name = String(id)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var effect: Dictionary = s.get("effect", {})
		var parts: PackedStringArray = []
		for k: Variant in effect.keys():
			parts.append("%s x%.2f" % [str(k), float(effect[k])])
		lbl.text = "%s  (cost %d)  %s" % [str(s.get("name", id)), int(s.get("cost", 1)), ", ".join(parts)]
		row.add_child(lbl)
		var btn := Button.new()
		btn.name = "Unlock"
		if Skills.is_unlocked(id):
			btn.text = "Unlocked"
			btn.disabled = true
		else:
			btn.text = "Unlock"
			btn.disabled = not Skills.can_unlock(id)
			btn.pressed.connect(_on_unlock.bind(id))
		row.add_child(btn)
		_list.add_child(row)


func _on_unlock(id: StringName) -> void:
	Skills.unlock(id)
	rebuild()

class_name SuitMenu
extends Control
## Suit picker. Toggled by "open_suits" (L); pauses the tree while open.

var _list: VBoxContainer


func _ready() -> void:
	name = "SuitMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.position = Vector2(-260, -200)
	root.custom_minimum_size = Vector2(520, 400)
	add_child(root)
	var title := Label.new()
	title.text = "SUITS"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	_list = VBoxContainer.new()
	_list.name = "SuitList"
	root.add_child(_list)
	var hint := Label.new()
	hint.text = "L - close"
	root.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_suits"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		rebuild()


func rebuild() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var suits: Array[Dictionary] = Suits.get_all()
	for s: Dictionary in suits:
		var id := StringName(str(s.get("id", "")))
		var row := HBoxContainer.new()
		row.name = String(id)
		for key: String in ["primary", "secondary", "emblem"]:
			var sw := ColorRect.new()
			sw.custom_minimum_size = Vector2(24, 24)
			sw.color = Color.from_string(str(s.get(key, "#808080")), Color.GRAY)
			row.add_child(sw)
		var btn := Button.new()
		btn.name = "Equip"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var equipped: bool = Suits.current == id
		btn.text = "%s%s" % [str(s.get("name", id)), "  (equipped)" if equipped else ""]
		btn.disabled = equipped
		btn.pressed.connect(_on_equip.bind(id))
		row.add_child(btn)
		_list.add_child(row)


func _on_equip(id: StringName) -> void:
	Suits.equip(id)
	rebuild()

class_name GadgetWheel
extends Control
## Five gadget slots (Slot0..Slot4). refresh(slots) takes GadgetManager.get_slots().
## If not fed externally, it polls the player's GadgetManager every frame.

const SLOT_COUNT := 5

var _slots: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _styles: Array[StyleBoxFlat] = []


func _ready() -> void:
	name = "GadgetWheel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	position = Vector2(-300, -140)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i: int in SLOT_COUNT:
		var p := PanelContainer.new()
		p.name = "Slot%d" % i
		p.custom_minimum_size = Vector2(112, 56)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.55)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.2)
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text = "-"
		p.add_child(l)
		row.add_child(p)
		# Also reparent-free access via GadgetWheel/SlotN: duplicate name lookup uses find_child.
		_slots.append(p)
		_labels.append(l)
		_styles.append(sb)


func _process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var gm: Node = player.get_node_or_null("GadgetManager")
	if gm != null and gm.has_method("get_slots"):
		var slots: Array[Dictionary] = []
		slots.assign(gm.call("get_slots"))
		refresh(slots)


func get_slot(i: int) -> PanelContainer:
	return _slots[i] if i >= 0 and i < _slots.size() else null


func selected_index() -> int:
	for i: int in _styles.size():
		if _styles[i].border_color == Color(1.0, 0.85, 0.2):
			return i
	return -1


func refresh(slots: Array[Dictionary]) -> void:
	for i: int in SLOT_COUNT:
		if i >= slots.size():
			_labels[i].text = "-"
			_styles[i].border_color = Color(1, 1, 1, 0.2)
			continue
		var s: Dictionary = slots[i]
		var left: float = float(s.get("cooldown_left", 0.0))
		var total: float = maxf(float(s.get("cooldown_total", 0.0)), 0.001)
		var txt: String = str(s.get("name", s.get("id", "")))
		if left > 0.0:
			txt += "\n%.1fs" % left
			_styles[i].bg_color = Color(0.25, 0.05, 0.05, 0.55 + 0.3 * left / total)
		else:
			txt += "\nREADY"
			_styles[i].bg_color = Color(0, 0, 0, 0.55)
		_labels[i].text = txt
		var sel: bool = bool(s.get("selected", false))
		_styles[i].border_color = Color(1.0, 0.85, 0.2) if sel else Color(1, 1, 1, 0.2)
		_styles[i].set_border_width_all(4 if sel else 2)
		_slots[i].scale = Vector2(1.1, 1.1) if sel else Vector2.ONE

class_name Hud
extends CanvasLayer
## HUD: HealthBar, 3 FocusSegments, GadgetPanel, ComboLabel, crosshair, speed readout.
## F1 toggles HUD, F3 opens the debug menu (time of day, teleports, unstuck, invincible, +XP),
## Esc pauses.

var root: Control
var health_bar: ProgressBar
var focus_segments: Array[ProgressBar] = []
var gadget_panel: Label
var combo_label: Label
var speed_label: Label
var debug_menu: PanelContainer
var pause_label: Label
var _combo_fade: float = 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(40, 40)
	root.add_child(box)
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(360, 22)
	health_bar.max_value = GameState.max_hp
	health_bar.value = GameState.hp
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override(&"fill", _sb(Color(0.85, 0.12, 0.15)))
	health_bar.add_theme_stylebox_override(&"background", _sb(Color(0, 0, 0, 0.55)))
	box.add_child(health_bar)
	var fbox: HBoxContainer = HBoxContainer.new()
	fbox.name = "Focus"
	box.add_child(fbox)
	for i: int in 3:
		var seg: ProgressBar = ProgressBar.new()
		seg.name = "FocusSegment%d" % (i + 1)
		seg.custom_minimum_size = Vector2(116, 10)
		seg.max_value = 1.0
		seg.show_percentage = false
		seg.add_theme_stylebox_override(&"fill", _sb(Color(0.95, 0.95, 1.0)))
		seg.add_theme_stylebox_override(&"background", _sb(Color(0, 0, 0, 0.55)))
		fbox.add_child(seg)
		focus_segments.append(seg)
	gadget_panel = _label("GadgetPanel", 22)
	gadget_panel.position = Vector2(40, 980)
	root.add_child(gadget_panel)
	combo_label = _label("ComboLabel", 56)
	combo_label.position = Vector2(1650, 420)
	root.add_child(combo_label)
	speed_label = _label("SpeedLabel", 20)
	speed_label.position = Vector2(1720, 1010)
	root.add_child(speed_label)
	var cross: Label = _label("Crosshair", 26)
	cross.text = "·"
	cross.position = Vector2(955, 520)
	root.add_child(cross)
	pause_label = _label("Paused", 64)
	pause_label.text = "PAUSED\nEsc to resume"
	pause_label.position = Vector2(780, 440)
	pause_label.visible = false
	add_child(pause_label)
	_build_debug()
	Events.health_changed.connect(func(v: float) -> void: health_bar.value = v)
	Events.focus_changed.connect(_on_focus)
	Events.combo_changed.connect(_on_combo)
	Events.gadget_used.connect(func(id: StringName) -> void: gadget_panel.text = "Used: %s" % String(id).capitalize())
	Events.base_alarm.connect(func(_id: StringName) -> void: gadget_panel.text = "ALARM! Base alerted")
	Events.wave_started.connect(func(_id: StringName, w: int) -> void: gadget_panel.text = "Wave %d / 3" % w)
	Events.base_cleared.connect(func(_id: StringName) -> void: gadget_panel.text = "Base cleared! +XP")
	gadget_panel.text = "G: gadget  Tab: next  K: skills  L: suits  M: map"
	_on_focus(GameState.focus)


func _sb(c: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(3)
	return s


func _label(n: String, size: int) -> Label:
	var l: Label = Label.new()
	l.name = n
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_focus(v: float) -> void:
	for i: int in 3:
		focus_segments[i].value = clampf(v - float(i), 0.0, 1.0)


func _on_combo(c: int) -> void:
	if c >= 2:
		combo_label.text = "%d HITS" % c
		combo_label.modulate = Color(1, 1, 1) if c < 5 else Color(1, 0.8, 0.2)
		_combo_fade = 2.0
	elif c == 0:
		_combo_fade = minf(_combo_fade, 0.4)


func _build_debug() -> void:
	debug_menu = PanelContainer.new()
	debug_menu.name = "DebugMenu"
	debug_menu.position = Vector2(1500, 40)
	debug_menu.visible = false
	add_child(debug_menu)
	var v: VBoxContainer = VBoxContainer.new()
	debug_menu.add_child(v)
	var title: Label = Label.new()
	title.text = "DEBUG (F3)"
	v.add_child(title)
	var tod: HSlider = HSlider.new()
	tod.name = "TimeOfDay"
	tod.min_value = 0.0
	tod.max_value = 24.0
	tod.step = 0.25
	tod.value = 18.5
	tod.custom_minimum_size = Vector2(300, 24)
	tod.value_changed.connect(func(h: float) -> void:
		var w: Node = get_tree().get_first_node_in_group(&"world")
		if w != null:
			w.call(&"set_time_of_day", h))
	v.add_child(tod)
	for id: String in ["downtown", "park", "base", "bridge", "landmark"]:
		_btn(v, "Teleport: " + id, func() -> void: Events.debug_teleport.emit(StringName(id)))
	_btn(v, "Unstuck", func() -> void:
		var p: Node = get_tree().get_first_node_in_group(&"player")
		if p != null:
			p.call(&"unstuck"))
	_btn(v, "Toggle invincible", func() -> void: GameState.invincible = not GameState.invincible)
	_btn(v, "+500 XP", func() -> void: GameState.add_xp(500, &"debug"))
	_btn(v, "Spawn 3 thugs", func() -> void:
		var w: Node = get_tree().get_first_node_in_group(&"world")
		if w != null:
			w.call(&"spawn_enemies", &"thug", 3))


func _btn(parent: Control, text: String, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"toggle_hud"):
		root.visible = not root.visible
	elif e.is_action_pressed(&"debug_menu"):
		debug_menu.visible = not debug_menu.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if debug_menu.visible else Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
		pause_label.visible = get_tree().paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_combo_fade = maxf(_combo_fade - delta, 0.0)
	combo_label.visible = _combo_fade > 0.0
	var p: Node = get_tree().get_first_node_in_group(&"player")
	if p != null:
		var v: Vector3 = p.get(&"velocity")
		speed_label.text = "%d km/h" % int(v.length() * 3.6)

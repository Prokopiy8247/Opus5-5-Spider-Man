class_name MapScreen
extends Control
## Top-down map of the 3000 x 1500 m island (X -> right, Z -> down, origin at centre).
## Toggled by "open_map" (M); pauses the tree while open.

const WORLD_SIZE := Vector2(3000.0, 1500.0)

var _rect: ColorRect
var _markers: Control


func _ready() -> void:
	name = "MapScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_rect = ColorRect.new()
	_rect.name = "MapRect"
	_rect.color = Color(0.12, 0.22, 0.32)
	_rect.custom_minimum_size = Vector2(1000, 500)
	_rect.size = Vector2(1000, 500)
	_rect.set_anchors_preset(Control.PRESET_CENTER)
	_rect.position = Vector2(-500, -250)
	add_child(_rect)
	_markers = Control.new()
	_markers.name = "Markers"
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.add_child(_markers)
	var legend := Label.new()
	legend.text = "MAP  -  blue: you, red: enemy base, green: cleared base.  M - close"
	legend.position = Vector2(0, -28)
	_rect.add_child(legend)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		rebuild()


func world_to_map(p: Vector3) -> Vector2:
	var u: float = clampf(p.x / WORLD_SIZE.x + 0.5, 0.0, 1.0)
	var v: float = clampf(p.z / WORLD_SIZE.y + 0.5, 0.0, 1.0)
	return Vector2(u * _rect.size.x, v * _rect.size.y)


func rebuild() -> void:
	for c: Node in _markers.get_children():
		c.queue_free()
	var i: int = 0
	for n: Node in get_tree().get_nodes_in_group("enemy_base"):
		if n is Node3D:
			var cleared: bool = n.has_method("is_cleared") and bool(n.call("is_cleared"))
			_add_marker("Base%d" % i, (n as Node3D).global_position,
				Color(0.2, 0.9, 0.3) if cleared else Color(0.95, 0.2, 0.2), 14.0)
			i += 1
	var player: Node = get_tree().get_first_node_in_group("player")
	if player is Node3D:
		_add_marker("Player", (player as Node3D).global_position, Color(0.3, 0.6, 1.0), 18.0)


func _add_marker(marker_name: String, pos: Vector3, col: Color, sz: float) -> void:
	var m := ColorRect.new()
	m.name = marker_name
	m.color = col
	m.size = Vector2(sz, sz)
	m.position = world_to_map(pos) - Vector2(sz, sz) * 0.5
	_markers.add_child(m)

extends Node
## Main: builds the world, spawns the player at the sunset rooftop, adds the HUD.


func _ready() -> void:
	var world_scr: GDScript = load("res://scripts/world/world.gd")
	var world: Node3D = world_scr.new()
	world.name = "World"
	add_child(world)
	var ps: PackedScene = load("res://scenes/core/player.tscn")
	var player: Node3D = ps.instantiate() as Node3D
	player.transform = world.call(&"get_spawn_transform")
	add_child(player)
	var hud_scr: GDScript = load("res://scripts/ui/hud.gd")
	var hud: CanvasLayer = hud_scr.new()
	add_child(hud)
	var menus: CanvasLayer = CanvasLayer.new()
	menus.name = "Menus"
	menus.layer = 20
	menus.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menus)
	for path: String in ["res://scripts/ui/menus/gadget_wheel.gd", "res://scripts/ui/menus/skill_menu.gd",
			"res://scripts/ui/menus/suit_menu.gd", "res://scripts/ui/menus/map_screen.gd"]:
		var scr: GDScript = load(path)
		menus.add_child(scr.new())
	var suits: Node = get_node_or_null(^"/root/Suits")
	if suits != null:
		suits.call_deferred(&"equip", suits.get(&"current"))
	GameState.refresh_max_hp()
	_connect_audio(player)


func _connect_audio(player: Node3D) -> void:
	var sfx: Node = get_node_or_null(^"/root/Sfx")
	if sfx == null:
		return
	var tick: Callable = func() -> void:
		if is_instance_valid(player):
			var v: Vector3 = player.get(&"velocity")
			if sfx.has_method(&"set_wind"):
				sfx.call(&"set_wind", v.length())
			if sfx.has_method(&"set_tension"):
				sfx.call(&"set_tension", 1.0 if player.call(&"get_state") == &"swinging" else 0.0)
	get_tree().process_frame.connect(tick)

class_name GadgetManager
extends Node
## Child of Player named "GadgetManager". Holds the 5 gadgets and handles gadget_use/gadget_next.

const SCRIPTS: Array[String] = [
	"res://scripts/gadgets/web_bomb.gd",
	"res://scripts/gadgets/impact_web.gd",
	"res://scripts/gadgets/trip_mine.gd",
	"res://scripts/gadgets/electric_web.gd",
	"res://scripts/gadgets/suspension_matrix.gd",
]

var gadgets: Array[Gadget] = []
var index: int = 0


func _ready() -> void:
	for path: String in SCRIPTS:
		var g: Gadget = (load(path) as GDScript).new() as Gadget
		g.name = String(g.id)
		add_child(g)
		gadgets.append(g)
	index = clampi(GameState.gadget_index, 0, gadgets.size() - 1)


## Input comes through the Player's sampled input (keyboard and QA bot alike).
func _physics_process(_delta: float) -> void:
	var p: Node = get_parent()
	if p == null or not p.has_method(&"pressed"):
		return
	if bool(p.call(&"pressed", &"gadget_use")):
		use_current()
	if bool(p.call(&"pressed", &"gadget_next")):
		next()


func use_current() -> bool:
	if gadgets.is_empty():
		return false
	return gadgets[index].activate(get_parent() as Node3D)


func next() -> void:
	if gadgets.is_empty():
		return
	index = (index + 1) % gadgets.size()
	GameState.gadget_index = index


func get_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in gadgets.size():
		var g: Gadget = gadgets[i]
		out.append({
			&"id": g.id, &"name": g.display_name, &"cooldown_left": g.cooldown_left,
			&"cooldown_total": g.effective_cooldown(), &"selected": i == index,
		})
	return out

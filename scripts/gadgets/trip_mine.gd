extends Gadget
## Places a mine at the player's feet; it webs enemies that come closer than 2 m.

const TRIGGER: float = 2.0
const BLAST: float = 3.0
const DURATION: float = 4.0
const LIFETIME: float = 60.0

var _mines: Array[Dictionary] = []  # {pos: Vector3, life: float}


func _init() -> void:
	id = &"trip_mine"
	display_name = "Trip Mine"
	cooldown_s = 5.0


func _fire(player: Node3D) -> bool:
	_mines.append({&"pos": player.global_position, &"life": LIFETIME})
	return true


func _physics_process(delta: float) -> void:
	for i: int in range(_mines.size() - 1, -1, -1):
		var m: Dictionary = _mines[i]
		m[&"life"] = float(m[&"life"]) - delta
		var pos: Vector3 = m[&"pos"]
		if not enemies_near(pos, TRIGGER).is_empty():
			for e: Node3D in enemies_near(pos, BLAST):
				Gadget.apply_status(e, &"WEBBED", DURATION)
			_mines.remove_at(i)
		elif float(m[&"life"]) <= 0.0:
			_mines.remove_at(i)


func active_mines() -> int:
	return _mines.size()

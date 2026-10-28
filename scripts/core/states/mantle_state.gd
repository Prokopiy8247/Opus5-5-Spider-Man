extends PlayerState
## Mantle: short scripted climb onto a ledge top.

var start: Vector3
var top: Vector3


func enter(_from: StringName, msg: Dictionary) -> void:
	start = player.global_position
	top = msg.get("top", start)
	player.play_anim(&"mantle", 0.05)


func physics(delta: float) -> void:
	var p: float = clampf(time_in_state / 0.25, 0.0, 1.0)
	var mid: Vector3 = Vector3(start.x, top.y + 0.6, start.z)
	var want: Vector3 = mid.lerp(top + Vector3.UP * 0.1, p) if p > 0.5 else start.lerp(mid, p * 2.0)
	player.velocity = (want - player.global_position) / maxf(delta, 0.001)
	if p >= 1.0:
		player.velocity = Vector3.ZERO
		player.change_state(&"grounded")

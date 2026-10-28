extends PlayerState
## Web Zip / Point Launch approach: pull fast toward the highlighted zip point.
## Pressing jump on arrival (or near it) triggers point_launch.

var target: Vector3 = Vector3.ZERO
var start: Vector3 = Vector3.ZERO
var dur: float = 0.4


func enter(_from: StringName, msg: Dictionary) -> void:
	var n: Node3D = msg.get("target") as Node3D
	target = n.global_position if n != null else player.global_position + player.cam_forward() * 10.0
	start = player.global_position
	dur = player.tuning.zip_duration / GameState.mod(&"zip_speed")
	player.attach_web(target)
	Events.zip_started.emit(target)
	player.play_anim(&"zip", 0.05)


func exit(_to: StringName) -> void:
	player.release_web()


func physics(delta: float) -> void:
	var p: float = clampf(time_in_state / dur, 0.0, 1.0)
	var want: Vector3 = start.lerp(target, p * p * (3.0 - 2.0 * p)) + Vector3.UP * 0.2
	player.velocity = (want - player.global_position) / maxf(delta, 0.001)
	player.face_dir(target - start, delta)
	var near: bool = p > 0.7
	if near and player.pressed(&"jump"):
		player.consume(&"jump")
		player.change_state(&"point_launch", {"dir": (target - start)})
		return
	if p >= 1.0:
		player.velocity = Vector3.UP * 4.0
		player.change_state(&"perched")

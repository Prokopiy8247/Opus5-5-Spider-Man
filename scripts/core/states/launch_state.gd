extends PlayerState
## Point Launch: catapult forward/up with a brief slow-motion.


func enter(_from: StringName, msg: Dictionary) -> void:
	var t: TraversalTuning = player.tuning
	var d: Vector3 = msg.get("dir", player.cam_forward())
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else -player.global_basis.z
	player.velocity = d * t.launch_forward + Vector3.UP * t.launch_up
	TimeScale.request_slowmo(t.launch_slowmo, t.launch_slowmo_time)
	Events.point_launch.emit()
	player.play_anim(&"point_launch", 0.05)


func physics(delta: float) -> void:
	player.apply_gravity(delta)
	if time_in_state > 0.35:
		player.change_state(&"airborne")

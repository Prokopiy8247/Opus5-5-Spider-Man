extends PlayerState
## Web swing: pendulum around the anchor with a rope constraint, pumping toward the swing
## direction and lateral compensation so a side anchor doesn't drag the hero into the wall.

var rope: float = 30.0
var swing_dir: Vector3 = Vector3.FORWARD


func enter(_from: StringName, msg: Dictionary) -> void:
	var a: Vector3 = msg.get("anchor", Vector3.INF)
	player.attach_web(a)
	var t: TraversalTuning = player.tuning
	var origin: Vector3 = player.global_position + Vector3.UP * 1.2
	rope = clampf(origin.distance_to(a), t.swing_min_rope, t.swing_max_rope)
	var hv: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	swing_dir = hv.normalized() if hv.length() > 2.0 else player.cam_forward() * Vector3(1, 0, 1)
	swing_dir = swing_dir.normalized()
	# Late attach while falling: convert part of the fall into forward speed (original "momentum" feel).
	if player.velocity.y < -5.0:
		player.velocity += swing_dir * t.swing_late_attach_boost
	# Never start slower than the minimum swing speed.
	var sp: float = player.velocity.length()
	if sp < t.swing_min_speed:
		player.velocity = (player.velocity.normalized() if sp > 0.5 else swing_dir) * t.swing_min_speed
		player.velocity += swing_dir * 2.0
	player.play_anim(&"swing_start", 0.08)


func exit(_to: StringName) -> void:
	player.release_web()


func physics(delta: float) -> void:
	var t: TraversalTuning = player.tuning
	var a: Vector3 = player.anchor
	if a == Vector3.INF:
		player.change_state(&"airborne")
		return
	if not player.held(&"swing"):
		_release()
		return
	if player.pressed(&"jump"):
		player.consume(&"jump")
		_release(true)
		return
	if player.pressed(&"zip") and player.highlighted_zip != null:
		player.consume(&"zip")
		player.change_state(&"zipping", {"target": player.highlighted_zip})
		return
	var origin: Vector3 = player.global_position + Vector3.UP * 1.2
	var to_anchor: Vector3 = a - origin
	var radial: Vector3 = to_anchor.normalized()
	# Past the bottom and climbing near anchor height: let go (no loop over the anchor).
	if to_anchor.y < 4.0 and player.velocity.y > 0.0 and time_in_state > 0.3:
		_release()
		return
	# Steering: player input bends the swing plane.
	var wish: Vector3 = player.wish_dir()
	if wish.length() > 0.1:
		swing_dir = swing_dir.slerp(wish.normalized(), clampf(t.swing_steer_rate * delta, 0.0, 1.0))
	swing_dir = Vector3(swing_dir.x, 0.0, swing_dir.z).normalized()
	player.apply_gravity(delta)
	# Pump along the tangent in the swing direction (keeps chains alive).
	var tangent: Vector3 = (swing_dir - radial * swing_dir.dot(radial)).normalized()
	var mult: float = GameState.mod(&"swing_speed")
	player.velocity += tangent * t.swing_pump_accel * mult * delta
	# Lateral compensation: remove sideways velocity relative to swing_dir.
	var side: Vector3 = swing_dir.cross(Vector3.UP)
	var lat: float = player.velocity.dot(side)
	player.velocity -= side * lat * clampf(t.swing_lateral_comp * delta * 3.0, 0.0, 1.0)
	# Straighten toward the travel direction.
	var hv: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if hv.length() > 1.0:
		var want: Vector3 = swing_dir * hv.length()
		hv = hv.lerp(want, clampf(t.swing_straighten_rate * delta, 0.0, 1.0))
		player.velocity.x = hv.x
		player.velocity.z = hv.z
	# Rope constraint: remove outward radial velocity when the rope is taut.
	var dist: float = to_anchor.length()
	if dist >= rope - 0.05:
		var out_v: float = player.velocity.dot(-radial)
		if out_v > 0.0:
			player.velocity += radial * out_v
		if dist > rope:
			player.velocity += radial * (dist - rope) * 8.0 * delta * 60.0 * 0.1
	# Ground clearance: shorten the rope if the arc would scrape the street.
	var down: Dictionary = player.ray(player.global_position, player.global_position + Vector3.DOWN * t.swing_ground_clearance)
	if not down.is_empty():
		rope = maxf(rope - 20.0 * delta, t.swing_min_rope)
		player.velocity.y = maxf(player.velocity.y, 2.0)
	# Wall clearance: push away from walls in front/side.
	for dir: Vector3 in [hv.normalized(), side, -side]:
		if dir.length_squared() < 0.1:
			continue
		var w: Dictionary = player.probe_wall(dir, t.swing_wall_clearance, 1.0)
		if not w.is_empty():
			var n: Vector3 = w.normal
			var into: float = player.velocity.dot(-n)
			if into > 0.0:
				player.velocity += n * into
	var sp: float = player.velocity.length()
	var vmax: float = t.swing_max_speed * mult
	if sp > vmax:
		player.velocity = player.velocity * (vmax / sp)
	player.face_dir(player.velocity, delta, 6.0)
	# Body tilt toward the rope.
	var local_r: Vector3 = player.global_basis.inverse() * radial
	player.set_lean(Vector3(-local_r.z * 0.3, 0.0, -local_r.x * 0.5))
	if time_in_state > 0.3:
		player.play_anim(&"swing_loop", 0.2)
	# Passed far beyond the anchor and rising steeply: auto release so the bot/user keeps flow.
	if time_in_state > 3.5:
		_release()


func _release(jump: bool = false) -> void:
	var t: TraversalTuning = player.tuning
	var hv: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var fwd: Vector3 = hv.normalized() if hv.length() > 1.0 else swing_dir
	player.velocity += fwd * t.swing_release_boost * (1.4 if jump else 1.0)
	player.velocity.y = maxf(player.velocity.y, 0.0) + t.swing_release_lift * (1.6 if jump else 1.0)
	player.set_lean(Vector3.ZERO)
	player.play_anim(&"swing_release", 0.05)
	player.change_state(&"airborne")


func post_move(_delta: float) -> void:
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.change_state(&"grounded")

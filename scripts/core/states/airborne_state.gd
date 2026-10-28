extends PlayerState
## In the air: falling/diving with air control; swing, zip, tricks; landing (roll / hero landing).


func enter(_from: StringName, _msg: Dictionary) -> void:
	player.air_time = 0.0
	player.peak_fall_speed = 0.0
	player.play_anim(&"fall", 0.2)


func physics(delta: float) -> void:
	var t: TraversalTuning = player.tuning
	player.air_time += delta
	if player.try_air_actions():
		return
	var diving: bool = player.held(&"dodge") and player.velocity.y < 0.0
	player.apply_gravity(delta, t.dive_gravity_mult if diving else 1.0)
	var term: float = t.dive_terminal_speed if diving else t.terminal_speed
	player.velocity.y = maxf(player.velocity.y, -term)
	var wish: Vector3 = player.wish_dir()
	var hv: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if wish.length() > 0.1:
		var keep: float = maxf(hv.length(), t.run_speed)
		hv = hv.move_toward(wish * keep, t.air_control * delta)
		player.face_dir(hv, delta, 4.0)
	player.velocity.x = hv.x
	player.velocity.z = hv.z
	player.peak_fall_speed = maxf(player.peak_fall_speed, -player.velocity.y)
	if player.air_time > 0.4:
		player.play_anim(&"dive" if diving else &"fall", 0.25)
	# Hitting a wall at speed starts a wall run.
	# Only near head-on impacts; glancing contacts slide along instead.
	if hv.length() > t.wall_run_min_speed:
		var hit: Dictionary = player.probe_wall(hv, 1.0)
		if not hit.is_empty() and hv.normalized().dot(-(hit.normal as Vector3)) > 0.75:
			player.change_state(&"wall_run", {"normal": hit.normal})


func post_move(_delta: float) -> void:
	if player.is_on_floor():
		var impact: float = player.peak_fall_speed
		var hero: bool = impact > player.tuning.hero_land_speed
		Events.landed.emit(impact, hero)
		if hero:
			player.play_anim(&"hero_land", 0.05)
		elif impact > player.tuning.roll_speed:
			player.play_anim(&"roll", 0.05)
		else:
			player.play_anim(&"land", 0.05)
		player.change_state(&"grounded")

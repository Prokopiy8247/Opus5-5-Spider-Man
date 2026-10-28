extends Node
## Autoload "TimeScale": slow motion and hit-stop. Uses real (unscaled) time for its own timers.

var _slowmo_scale: float = 1.0
var _slowmo_left: float = 0.0
var _hitstop_left: float = 0.0
var _last_ticks: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks = Time.get_ticks_usec()


## Slows the game to `scale` for `duration` real seconds. The strongest active request wins.
func request_slowmo(scale: float, duration: float) -> void:
	scale = clampf(scale, 0.05, 1.0)
	if _slowmo_left <= 0.0 or scale <= _slowmo_scale:
		_slowmo_scale = scale
	_slowmo_left = maxf(_slowmo_left, duration)
	_apply()


## Freezes the game almost completely for `ms` real milliseconds.
func hitstop(ms: int) -> void:
	_hitstop_left = maxf(_hitstop_left, float(ms) / 1000.0)
	_apply()


func is_slowed() -> bool:
	return Engine.time_scale < 0.99


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real_dt: float = float(now - _last_ticks) / 1000000.0
	_last_ticks = now
	if get_tree().paused:
		return
	if _hitstop_left > 0.0:
		_hitstop_left -= real_dt
	if _slowmo_left > 0.0:
		_slowmo_left -= real_dt
	_apply()


func _apply() -> void:
	var s: float = 1.0
	if _slowmo_left > 0.0:
		s = _slowmo_scale
	if _hitstop_left > 0.0:
		s = minf(s, 0.05)
	Engine.time_scale = s

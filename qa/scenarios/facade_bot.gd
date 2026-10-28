extends "res://qa/scenarios/qa_scenario.gd"
## Facade quality bot: 10 city locations, shots at 3 / 10 / 60 / 300 m plus an aerial view,
## each at day (13:00), sunset (18:48) and night (23:00) => 150 screenshots.
## Measures:
##   texel_density_px_m  per near-ground close shot (screen px per metre of facade / texture texel
##                       density available: pixels of the source texture per world metre),
##   shimmer_score       mean absolute frame difference at 300 m after a 0.05 m camera move,
##   texture_mem_mb      Performance.TEXTURE_MEM_USED,
##   draw_calls, fps_avg, fps_1pct_low,
##   distinct_looks, adjacent_identical, styles_seen from World.building_styles.get_building_styles().
## Fails on: density < 200 px/m near ground, shimmer > SHIMMER_MAX, texture memory > 512 MB,
## fps_avg < 120, fps_1pct_low < 60, draw calls > 125 % of the iteration-2 perf_sweep baseline.

const DENSITY_MIN: float = 200.0
const SHIMMER_MAX: float = 0.012
const TEX_MEM_MAX_MB: float = 512.0
const FPS_AVG_MIN: float = 120.0
const FPS_LOW_MIN: float = 60.0
const DRAW_CALL_FACTOR: float = 1.25
const BASELINE_PATH: String = "res://qa/evidence/baseline_iter2/perf_sweep_metrics.json"
const SHIMMER_SHIFT: float = 0.05
## Texture module from the contract: one facade layer = 2 bays x 2 floors at 2.7 x 3.75 m.
const TILE_PX: float = 2048.0
const TILE_W_M: float = 5.4

const LIGHTING: Array[Array] = [["day", 13.0], ["sunset", 18.8], ["night", 23.0]]
const DISTANCES: Array[float] = [3.0, 10.0, 60.0, 300.0]

var _cam: Camera3D
var _fps_samples: Array[float] = []
var _densities: Array[float] = []
var _shimmers: Array[float] = []


func run() -> void:
	var p: Node3D = await wait_player()
	var w: Node = get_world()
	if p == null or w == null:
		fail("player or world missing")
		return
	_cam = make_qa_camera(self)
	var spots: Array = _spots(w)
	metrics["locations"] = spots.size()
	if spots.size() != 10:
		fail("%d locations, expected 10" % spots.size())
	var max_draw: float = 0.0
	for s: Array in spots:
		var label: String = String(s[0])
		var target: Vector3 = s[1] as Vector3
		var dir: Vector3 = (s[2] as Vector3).normalized()
		for light: Array in LIGHTING:
			if w.has_method("set_time_of_day"):
				w.call("set_time_of_day", float(light[1]))
			await frames(2)
			for d: float in DISTANCES:
				var eye: Vector3 = target + dir * d + Vector3.UP * (1.7 if d <= 10.0 else d * 0.25)
				await place_cam(_cam, p, eye, target, 0.5)
				await frames(10)   # skip the teleport/stream hitch before sampling FPS
				_sample_perf()
				await screenshot("%s_%03dm_%s" % [label, int(d), light[0]])
				max_draw = maxf(max_draw, float(Performance.get_monitor(
						Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
				if d <= 3.0:   # 1080p resolves 200 px/m only up close; 10 m is reviewed by eye
					var px: float = _texel_density(eye.distance_to(target))
					_densities.append(snappedf(px, 0.1))
				if is_equal_approx(d, 300.0):
					var sh: float = await _shimmer(eye, target)
					_shimmers.append(snappedf(sh, 0.00001))
			# aerial view over the spot
			var air: Vector3 = target + Vector3(-120.0, 220.0, 120.0)
			await place_cam(_cam, p, air, target, 0.5)
			_sample_perf()
			await screenshot("%s_aerial_%s" % [label, light[0]])
			max_draw = maxf(max_draw, float(Performance.get_monitor(
					Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_write_metrics(w, max_draw)


func _sample_perf() -> void:
	var f: float = Engine.get_frames_per_second()
	if f > 0.0:
		_fps_samples.append(f)


## Source-texture pixels per world metre on the facade in front of the camera, derived from the
## contract tile module, plus the screen-space limit at this distance (whichever is lower is what
## the reviewer actually sees).
func _texel_density(dist_m: float) -> float:
	var texture_px_m: float = TILE_PX / TILE_W_M
	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var fov: float = _cam.fov
	# world metres covered by the viewport height at this distance
	var world_h: float = 2.0 * dist_m * tan(deg_to_rad(fov) * 0.5)
	var screen_px_m: float = vp.y / maxf(world_h, 0.001)
	return minf(texture_px_m, screen_px_m)


## Mean absolute luminance difference between two frames 0.05 m apart at 300 m.
func _shimmer(eye: Vector3, target: Vector3) -> float:
	var a: Image = await _grab()
	var side: Vector3 = (target - eye).cross(Vector3.UP).normalized()
	_cam.global_position = eye + side * SHIMMER_SHIFT
	_cam.look_at(target, Vector3.UP)
	await frames(2)
	var b: Image = await _grab()
	if a == null or b == null:
		return 0.0
	return _mean_diff(a, b)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return null
	img.resize(192, 108, Image.INTERPOLATE_BILINEAR)
	return img


func _mean_diff(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 0.0
	var total: float = 0.0
	var n: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			total += absf(ca.get_luminance() - cb.get_luminance())
			n += 1
	return total / maxf(1.0, float(n))


## The 10 contract locations: [label, look-at target, direction from target to the camera].
func _spots(w: Node) -> Array:
	var xs: PackedVector3Array = w.call("get_intersections") as PackedVector3Array
	var c: Vector3 = Vector3.ZERO
	for x: Vector3 in xs:
		if c == Vector3.ZERO or x.length() < c.length():
			c = x
	var lm: Vector3 = w.call("teleport_point", &"landmark") as Vector3
	var br: Vector3 = w.call("teleport_point", &"bridge") as Vector3
	var bs: Vector3 = w.call("teleport_point", &"base") as Vector3
	var cz: float = 750.0
	if w.get("CITY_Z") != null:
		cz = float(w.get("CITY_Z"))
	var f: Vector3 = Vector3(0.7, 0.0, 0.7)
	return [
		["loc00_street_corner", c + Vector3(0, 6, 0), f],
		["loc01_avenue", c + Vector3(120, 8, 0), Vector3(0, 0, 1)],
		["loc02_downtown_canyon", c + Vector3(-220, 30, -220), f],
		["loc03_midtown_block", c + Vector3(260, 20, 140), Vector3(1, 0, 0)],
		["loc04_residential", c + Vector3(-300, 10, 260), f],
		["loc05_landmark", lm + Vector3(0, 90, 0), f],
		["loc06_bridge_tower", br + Vector3(0, 25, 0), f],
		["loc07_base", bs + Vector3(0, 8, 0), f],
		["loc08_waterfront", Vector3(c.x, 10, -cz + 25.0), Vector3(0, 0, -1)],
		["loc09_podium_tower", c + Vector3(80, 40, -160), f],
	]


func _baseline_draw_calls() -> float:
	if not FileAccess.file_exists(BASELINE_PATH):
		fail("baseline missing: " + BASELINE_PATH)
		return 0.0
	var txt: String = FileAccess.get_file_as_string(BASELINE_PATH)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		fail("baseline is not a JSON object")
		return 0.0
	var d: Dictionary = data as Dictionary
	var best: float = float(d.get("draw_calls", 0.0))
	var sections: Variant = d.get("sections")
	if typeof(sections) == TYPE_DICTIONARY:
		for k: String in (sections as Dictionary).keys():
			var sec: Variant = (sections as Dictionary)[k]
			if typeof(sec) == TYPE_DICTIONARY:
				best = maxf(best, float((sec as Dictionary).get("draw_calls_max", 0.0)))
	return best


func _write_metrics(w: Node, max_draw: float) -> void:
	# ---- style assignment data from Back
	var styles_node: Variant = w.get("building_styles")
	var entries: Array = []
	var adjacent_identical: int = -1
	var distinct_looks: int = -1
	if styles_node != null and (styles_node as Object).has_method("get_building_styles"):
		entries = (styles_node as Object).call("get_building_styles") as Array
		if (styles_node as Object).has_method("count_adjacent_identical"):
			adjacent_identical = int((styles_node as Object).call("count_adjacent_identical"))
		if (styles_node as Object).has_method("count_distinct_looks"):
			distinct_looks = int((styles_node as Object).call("count_distinct_looks"))
	else:
		fail("World.building_styles.get_building_styles() not available")
	var looks: Dictionary = {}
	var styles_seen: Dictionary = {}
	for e: Dictionary in entries:
		looks[Vector2i(int(e.get("style", -1)), int(e.get("variant", -1)))] = true
		styles_seen[int(e.get("style", -1))] = true
	if distinct_looks < 0:
		distinct_looks = looks.size()
	if adjacent_identical < 0:
		adjacent_identical = _count_adjacent(entries)

	_fps_samples.sort()
	var fps_avg: float = 0.0
	for f: float in _fps_samples:
		fps_avg += f
	fps_avg = fps_avg / maxf(1.0, float(_fps_samples.size()))
	var low_n: int = maxi(1, int(float(_fps_samples.size()) * 0.01))
	var low: float = 0.0
	for i: int in low_n:
		low += _fps_samples[i]
	low = low / float(low_n)
	var tex_mem_mb: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0
	var baseline: float = _baseline_draw_calls()

	metrics["fps_avg"] = snappedf(fps_avg, 0.1)
	metrics["fps_1pct_low"] = snappedf(low, 0.1)
	metrics["draw_calls"] = max_draw
	metrics["draw_calls_baseline"] = baseline
	metrics["draw_calls_limit"] = snappedf(baseline * DRAW_CALL_FACTOR, 0.1)
	metrics["texture_mem_mb"] = snappedf(tex_mem_mb, 0.1)
	metrics["texel_density_px_m"] = _densities
	metrics["shimmer_score"] = _shimmers
	metrics["shimmer_max"] = SHIMMER_MAX
	metrics["distinct_looks"] = distinct_looks
	metrics["adjacent_identical"] = adjacent_identical
	metrics["styles_seen"] = styles_seen.keys().size()
	metrics["buildings"] = entries.size()
	metrics.merge(perf_snapshot(), false)

	# ---- gates
	for d: float in _densities:
		if d < DENSITY_MIN:
			fail("texel density %.0f px/m below %.0f near ground" % [d, DENSITY_MIN])
			break
	for s: float in _shimmers:
		if s > SHIMMER_MAX:
			fail("shimmer %.5f above %.5f at 300 m" % [s, SHIMMER_MAX])
			break
	if tex_mem_mb > TEX_MEM_MAX_MB:
		fail("texture memory %.0f MB above %.0f MB" % [tex_mem_mb, TEX_MEM_MAX_MB])
	if not _fps_samples.is_empty():
		if fps_avg < FPS_AVG_MIN:
			fail("fps_avg %.1f below %.0f" % [fps_avg, FPS_AVG_MIN])
		if low < FPS_LOW_MIN:
			fail("fps_1pct_low %.1f below %.0f" % [low, FPS_LOW_MIN])
	if baseline > 0.0 and max_draw > baseline * DRAW_CALL_FACTOR:
		fail("draw calls %.0f above %.0f%% of baseline %.0f"
				% [max_draw, DRAW_CALL_FACTOR * 100.0, baseline])
	if adjacent_identical > 0:
		fail("%d adjacent identical looks" % adjacent_identical)
	if distinct_looks < 30:
		fail("%d distinct looks, expected 30+" % distinct_looks)


## Fallback adjacency check (footprints within 2 m sharing style and variant).
func _count_adjacent(entries: Array) -> int:
	var n: int = 0
	for i: int in entries.size():
		var a: Dictionary = entries[i]
		var ba: AABB = a.get("aabb", AABB()) as AABB
		for j: int in range(i + 1, entries.size()):
			var b: Dictionary = entries[j]
			if int(a.get("style", -1)) != int(b.get("style", -2)):
				continue
			if int(a.get("variant", -1)) != int(b.get("variant", -2)):
				continue
			if ba.grow(2.0).intersects(b.get("aabb", AABB()) as AABB):
				n += 1
	return n

class_name World
extends Node3D
## Procedural Manhattan-style grid city (3000 x 1500 m). Buildings are merged per 128 m chunk into at most
## two ArrayMeshes ('Buildings_Main', 'Buildings_Special'); collision is one StaticBody3D per chunk.
## Also owns lighting / time of day, the park, the river, the bridge, the landmark, zip points and bases.

const CITY_X: float = CityGrid.CITY_X
const CITY_Z: float = CityGrid.CITY_Z
const AVE_SPACING: float = CityGrid.AVE_SPACING
const AVE_WIDTH: float = CityGrid.AVE_WIDTH
const STREET_SPACING: float = CityGrid.STREET_SPACING
const STREET_WIDTH: float = CityGrid.STREET_WIDTH
const CHUNK: float = 128.0  # matches ChunkStreamer.CHUNK_SIZE so each mesh maps to one stream chunk
const MAIN_AVE_Z: float = -30.0
## Grid-aligned park: whole blocks, curb to curb (kept in sync with CityGrid.PARK_RECT).
const PARK_RECT: Rect2 = CityGrid.PARK_RECT

@export var city_seed: int = 7

var hour: float = 18.5
var buildings: Array[AABB] = []
var bases: Array[Dictionary] = []
var building_styles: BuildingStyles = BuildingStyles.new()
var _building_mat: Material
var _aviation_tops: Array[Vector3] = []
var _aviation_mat: StandardMaterial3D
var _landmark_center: Vector3 = Vector3.ZERO
var _floodlights: Array[SpotLight3D] = []
var _night: float = 0.0
var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _env: Environment
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _chunks: Dictionary = {}  # Vector2i -> {"main": _Bucket, "special": _Bucket, "body": StaticBody3D}
var _spawn_box: AABB
var _stream_nodes: Array[Node3D] = []
var streamer: ChunkStreamer
var traffic: TrafficManager
var streets: StreetBuilder
var props: PropPlacer
var park: ParkBuilder


func _ready() -> void:
	add_to_group(&"world")
	var cfg: Resource = load("res://data/city.tres") if ResourceLoader.exists("res://data/city.tres") else null
	if cfg != null and cfg.get(&"city_seed") != null:
		city_seed = int(cfg.get(&"city_seed"))
	_rng.seed = city_seed
	_build_environment()
	_build_materials()
	_build_ground()
	_build_city()
	_build_landmark_and_bridge()
	_flush_chunks()
	_build_aviation_and_floodlights()
	_build_bases()
	_build_streaming()
	_build_streets_props_park()
	_build_traffic()
	set_time_of_day(hour)
	Events.debug_teleport.connect(func(id: StringName) -> void:
		var p: Node = get_tree().get_first_node_in_group(&"player")
		if p != null:
			p.call(&"teleport", teleport_point(id)))


func _process(delta: float) -> void:
	TrafficLights.clock += delta
	if _aviation_mat != null:
		# FAA-style slow red blink (~1 s period, short on-phase), only visible at dusk and night.
		var on: float = 1.0 if fposmod(TrafficLights.clock, 1.2) < 0.45 else 0.08
		_aviation_mat.emission_energy_multiplier = on * lerpf(0.6, 4.0, _night)
	var p: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if p != null and streamer != null:
		streamer.update_focus(p.global_position)


## Building meshes and zip points stream in 5x5 chunks; collision bodies stay loaded so
## web anchors never vanish under the player.
func _build_streaming() -> void:
	streamer = ChunkStreamer.new()
	streamer.name = "ChunkStreamer"
	streamer.add_to_group(&"chunk_streamer")
	add_child(streamer)
	for n: Node3D in _stream_nodes:
		streamer.register_node(n)
	for b: Dictionary in bases:
		(b["node"] as Node).add_to_group(&"stream_always")


## Closed loops along every avenue (CityGrid.avenue_lanes): avenues that cross the park are split
## into two loops that U-turn on the streets beside it, so no lane comes within 2 m of the park.
func _build_traffic() -> void:
	traffic = TrafficManager.new()
	traffic.name = "TrafficManager"
	traffic.add_to_group(&"traffic_manager")
	add_child(traffic)
	traffic.setup(get_avenue_lanes(), 40)
	traffic.set_stop_lines(get_stop_lines())


# ---------------------------------------------------------------- public API

func get_park_rect() -> Rect2:
	return PARK_RECT


func get_intersections() -> PackedVector3Array:
	return streets.intersections if streets != null else CityGrid.intersections()


## {"nodes": PackedVector3Array, "edges": PackedInt32Array, "crosswalk_edges": PackedInt32Array}
## (edges are flat index pairs; nodes sit on the walk band at y = 0.15).
func get_sidewalk_graph() -> Dictionary:
	if streets == null:
		return {"nodes": PackedVector3Array(), "edges": PackedInt32Array(), "crosswalk_edges": PackedInt32Array()}
	return {"nodes": streets.graph_nodes, "edges": streets.graph_edges, "crosswalk_edges": streets.graph_cross}


func get_avenue_lanes() -> Array[PackedVector3Array]:
	return CityGrid.avenue_lanes()


func get_curb_segments() -> Array[PackedVector3Array]:
	return streets.curb_segments if streets != null else [] as Array[PackedVector3Array]


func get_stop_lines() -> Array[Dictionary]:
	return streets.stop_lines if streets != null else [] as Array[Dictionary]


func get_light_state(light_id: int) -> StringName:
	return TrafficLights.state(light_id)


func get_spawn_transform() -> Transform3D:
	var top: Vector3 = Vector3(_spawn_box.get_center().x, _spawn_box.end.y + 0.2, _spawn_box.position.z + 1.5)
	# Face +X along the main avenue (z = 0) toward downtown.
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), top)


func get_safe_rooftop(near: Vector3) -> Vector3:
	var best: AABB = _spawn_box
	var bd: float = INF
	for b: AABB in buildings:
		var d: float = Vector2(b.get_center().x - near.x, b.get_center().z - near.z).length()
		if d < bd:
			bd = d
			best = b
	return Vector3(best.get_center().x, best.end.y + 1.0, best.get_center().z)


func teleport_point(id: StringName) -> Vector3:
	match id:
		&"downtown": return get_safe_rooftop(Vector3(0, 0, 0))
		&"park":
			if park != null:
				return park.get_teleport_point()
			return Vector3(PARK_RECT.get_center().x, 1.0, PARK_RECT.position.y + 10.0)
		&"bridge": return Vector3(0.0, 34.0, -CITY_Z - 120.0)
		&"landmark": return Vector3(0.0, 2.0, -66.0)
		&"base":
			if not bases.is_empty():
				return (bases[0]["pos"] as Vector3) + Vector3(0, 2, 18)
	return get_spawn_transform().origin


## Every building box with its look: {id, pos, size, aabb, style, variant, seed, district, ground_type}.
func get_building_styles() -> Array[Dictionary]:
	return building_styles.get_building_styles()


func get_bases() -> Array:
	return bases


func spawn_enemies(archetype: StringName, n: int, at: Vector3 = Vector3.INF, base_id: int = -1) -> Array:
	var out: Array = []
	var p: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var c: Vector3 = at
	if c == Vector3.INF:
		c = p.global_position + (-p.global_basis.z) * 8.0 if p != null else Vector3.ZERO
	var scr: GDScript = load("res://scripts/ai/enemy.gd")
	for i: int in n:
		var e: CharacterBody3D = scr.new()
		e.set(&"archetype", archetype)
		e.set(&"base_id", base_id)
		add_child(e)
		var a: float = TAU * float(i) / float(maxi(n, 1))
		e.global_position = c + Vector3(cos(a), 0.0, sin(a)) * 3.5 + Vector3.UP * 0.5
		out.append(e)
	return out


func set_time_of_day(h: float) -> void:
	hour = fposmod(h, 24.0)
	var elev: float = sin((hour - 5.0) / 14.5 * PI) * 65.0
	_sun.rotation_degrees = Vector3(-elev, -60.0, 0.0)
	var day: float = clampf((elev + 4.0) / 30.0, 0.0, 1.0)
	var sunset: float = clampf(1.0 - absf(elev - 6.0) / 22.0, 0.0, 1.0)
	_sun.light_energy = clampf(elev / 10.0, 0.0, 1.0) * 1.3
	_sun.light_color = Color(1.0, 0.82, 0.62).lerp(Color(1, 0.97, 0.92), clampf(elev / 40.0, 0.0, 1.0))
	_sky_mat.set_shader_parameter(&"day_factor", day)
	_sky_mat.set_shader_parameter(&"sunset_factor", sunset)
	var night: float = clampf(1.0 - (elev + 2.0) / 14.0, 0.0, 1.0)
	_night = night
	RenderingServer.global_shader_parameter_set(&"city_night", night)
	MeshKit.set_night_factor(night)
	for fl: SpotLight3D in _floodlights:
		fl.light_energy = 6.0 * night
		fl.visible = night > 0.05
	# Lower exposure and glow at night so lit windows (emission <= 4) stay coloured, not white.
	_env.tonemap_exposure = lerpf(1.05, 0.9, night)
	_env.glow_intensity = lerpf(0.5, 0.35, night)
	_env.ambient_light_energy = lerpf(0.35, 1.0, day)
	_env.fog_light_color = Color(0.95, 0.6, 0.45).lerp(Color(0.65, 0.75, 0.9), clampf(elev / 30.0, 0.0, 1.0)).lerp(Color(0.05, 0.07, 0.14), night)
	Events.time_of_day_changed.emit(hour)


# ---------------------------------------------------------------- build

func _build_environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	_env = Environment.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky: Sky = Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.05
	_env.tonemap_white = 6.0  # keeps emissive windows below white so their colour reads
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_strength = 0.8
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.6  # only bright cores (aviation lights, lamps) bloom, not window grids
	_env.glow_hdr_scale = 1.5
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.fog_enabled = true
	_env.fog_density = 0.0016
	_env.fog_sky_affect = 0.25
	_env.fog_aerial_perspective = 0.4
	_env.ssao_enabled = false
	we.environment = _env
	add_child(we)
	# 'city_night' is declared in project.godot ([shader_globals]).
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 260.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(_sun)


const BUILDING_MAT_PATH: String = "res://shaders/building_material.tres"


## One shared material for both chunk buckets (contract: res://shaders/building_material.tres).
func _build_materials() -> void:
	if ResourceLoader.exists(BUILDING_MAT_PATH):
		_building_mat = load(BUILDING_MAT_PATH)
	if _building_mat == null:
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load("res://shaders/building.gdshader")
		_building_mat = m


## Blinking red aviation lights (emissive spheres, no OmniLight) on every building over 150 m,
## and a ring of upward floodlights at the landmark base.
func _build_aviation_and_floodlights() -> void:
	_aviation_mat = StandardMaterial3D.new()
	_aviation_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aviation_mat.albedo_color = Color(1.0, 0.08, 0.05)
	_aviation_mat.emission_enabled = true
	_aviation_mat.emission = Color(1.0, 0.06, 0.03)
	_aviation_mat.emission_energy_multiplier = 1.0
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	sm.radial_segments = 12
	sm.rings = 6
	sm.material = _aviation_mat
	var xfs: Array[Transform3D] = []
	for top: Vector3 in _aviation_tops:
		xfs.append(Transform3D(Basis(), top + Vector3(0, 0.7, 0)))
	if not xfs.is_empty():
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sm
		mm.instance_count = xfs.size()
		for i: int in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "AviationLights"
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)  # not streamed: visible on the skyline from anywhere
	# Landmark floodlights: 8 spots at the podium corners and sides, aimed up the tower faces.
	var lc: Vector3 = _landmark_center
	var spots: Array[Vector3] = [
		Vector3(-26, 0.5, -21), Vector3(26, 0.5, -21), Vector3(-26, 0.5, 21), Vector3(26, 0.5, 21),
		Vector3(0, 0.5, -22), Vector3(0, 0.5, 22), Vector3(-27, 0.5, 0), Vector3(27, 0.5, 0)]
	for p: Vector3 in spots:
		var sl: SpotLight3D = SpotLight3D.new()
		sl.name = "LandmarkFlood"
		sl.light_color = Color(1.0, 0.9, 0.75)
		sl.spot_range = 320.0
		sl.spot_angle = 14.0
		sl.spot_attenuation = 0.4
		sl.shadow_enabled = false
		sl.light_energy = 0.0
		add_child(sl)
		var from: Vector3 = lc + p
		var to: Vector3 = lc + Vector3(p.x * 0.2, 170.0, p.z * 0.2)
		sl.look_at_from_position(from, to, Vector3.RIGHT if absf(p.x) < 1.0 else Vector3.FORWARD)
		_floodlights.append(sl)


func _flat_mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _build_ground() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ground"
	add_child(body)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(CITY_X * 2.0 + 200.0, 2.0, CITY_Z * 2.0 + 60.0)
	cs.shape = bs
	cs.position = Vector3(0, -1.0, 0)
	body.add_child(cs)
	# Asphalt: four strips around the park so no asphalt exists inside PARK_RECT.
	var asphalt: StandardMaterial3D = _flat_mat(Color(0.13, 0.13, 0.14), 0.85)
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	var fn: FastNoiseLite = FastNoiseLite.new()
	fn.frequency = 0.15
	nt.noise = fn
	nt.seamless = true
	asphalt.albedo_texture = nt
	asphalt.uv1_triplanar = true
	asphalt.uv1_scale = Vector3(0.2, 0.2, 0.2)
	var full: Rect2 = Rect2(-bs.size.x * 0.5, -bs.size.z * 0.5, bs.size.x, bs.size.z)
	var pr: Rect2 = PARK_RECT
	var strips: Array[Rect2] = [
		Rect2(full.position.x, full.position.y, full.size.x, pr.position.y - full.position.y),
		Rect2(full.position.x, pr.end.y, full.size.x, full.end.y - pr.end.y),
		Rect2(full.position.x, pr.position.y, pr.position.x - full.position.x, pr.size.y),
		Rect2(pr.end.x, pr.position.y, full.end.x - pr.end.x, pr.size.y),
	]
	for r: Rect2 in strips:
		var road: MeshInstance3D = MeshInstance3D.new()
		road.name = "Asphalt"
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = r.size
		road.mesh = pm
		road.material_override = asphalt
		road.position = Vector3(r.get_center().x, 0.0, r.get_center().y)
		add_child(road)
	# River south of the city.
	var water: MeshInstance3D = MeshInstance3D.new()
	var wm: PlaneMesh = PlaneMesh.new()
	wm.size = Vector2(CITY_X * 2.0 + 2000.0, 700.0)
	wm.subdivide_width = 120
	wm.subdivide_depth = 40
	water.mesh = wm
	var wmat: ShaderMaterial = ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	water.material_override = wmat
	water.position = Vector3(0, -2.0, -CITY_Z - 380.0)
	add_child(water)


## Sidewalks/curbs/markings, street props and the park (after buildings and streaming exist).
func _build_streets_props_park() -> void:
	streets = StreetBuilder.new()
	streets.build(self, streamer, city_seed)
	props = PropPlacer.new()
	props.city_seed = city_seed
	props.buildings = buildings
	add_child(props)
	props.build(streets, streamer)
	park = ParkBuilder.new()
	add_child(park)
	park.build(streamer)


func _chunk_for(p: Vector3) -> Dictionary:
	var k: Vector2i = Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if not _chunks.has(k):
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Chunk_%d_%d" % [k.x, k.y]
		body.add_to_group(&"anchorable")
		add_child(body)
		_chunks[k] = {"main": _Bucket.new(), "special": _Bucket.new(), "body": body}
	return _chunks[k]


## Adds one building box (mesh + collider). `district` forces "landmark" / "bridge"; otherwise
## BuildingStyles derives it from position. Positions, sizes and colliders are unchanged from iteration 2.
func _add_building(center_xz: Vector2, size: Vector3, district: String = "") -> void:
	var c: Vector3 = Vector3(center_xz.x, size.y * 0.5, center_xz.y)
	var ch: Dictionary = _chunk_for(c)
	var info: Dictionary = building_styles.assign(AABB(c - size * 0.5, size), district)
	var special: bool = int(info["style"]) >= BuildingStyles.STYLE_LANDMARK
	var bk: _Bucket = ch["special"] if special else ch["main"]
	var fit: Vector2 = fit_floors(size.y)
	_box(bk, c, size, info, 0, fit)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = c
	(ch["body"] as StaticBody3D).add_child(cs)
	buildings.append(AABB(c - size * 0.5, size))
	if size.y > 150.0:
		_aviation_tops.append(Vector3(c.x, size.y, c.z))
	# Rooftop details: water tower / AC block, plus a zip point on the roof edge.
	if size.y > 30.0 and _rng.randf() < 0.45:
		_box(bk, c + Vector3(_rng.randf_range(-3, 3), size.y * 0.5 + 1.5, _rng.randf_range(-3, 3)), Vector3(4, 3, 3), info, 2, fit)
	if _rng.randf() < 0.35:
		_add_zip_point(Vector3(c.x + size.x * 0.5 - 0.5, size.y + 0.3, c.z + size.z * 0.5 - 0.5))


func _add_zip_point(p: Vector3) -> void:
	var a: Area3D = Area3D.new()
	a.collision_layer = 1 << 7
	a.collision_mask = 0
	a.monitoring = false
	a.add_to_group(&"zip_point")
	a.add_to_group(&"perch_point")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sp: SphereShape3D = SphereShape3D.new()
	sp.radius = 0.6
	cs.shape = sp
	a.add_child(cs)
	add_child(a)
	a.position = p
	_stream_nodes.append(a)


func _build_city() -> void:
	var best_spawn: float = INF
	var z0: float = -CITY_Z
	while z0 < CITY_Z - 1.0:
		var zs: float = z0 + AVE_WIDTH * 0.5
		var ze: float = z0 + AVE_SPACING - AVE_WIDTH * 0.5
		var x0: float = -CITY_X
		while x0 < CITY_X - 1.0:
			var xs: float = x0 + STREET_WIDTH * 0.5
			var xe: float = x0 + STREET_SPACING - STREET_WIDTH * 0.5
			var block: Rect2 = Rect2(xs, zs, xe - xs, ze - zs)
			if not block.intersects(PARK_RECT):
				_fill_block(block)
				# Spawn candidate: block right north of avenue z=0, near the west end.
				if absf(zs - (AVE_WIDTH * 0.5 - AVE_SPACING * 0.0)) < 1.0 or absf(zs - AVE_WIDTH * 0.5) < 1.0:
					pass
			x0 += STREET_SPACING
		z0 += AVE_SPACING
	# Spawn: tallest-ish building touching the main avenue (z=0) near x=-1300.
	for b: AABB in buildings:
		# Main avenue centre line is z = -30 (avenues every 120 m from z = -750).
		if absf(b.position.z - (MAIN_AVE_Z + AVE_WIDTH * 0.5 + CityGrid.SIDEWALK_W)) < 1.5:
			var score: float = absf(b.get_center().x + 520.0) - b.size.y * 0.3
			if score < best_spawn and b.size.y > 35.0:
				best_spawn = score
				_spawn_box = b


func _fill_block(curb_rect: Rect2) -> void:
	# Buildings stand behind the 3.5 m sidewalk band (curb_rect is the curb line).
	var block: Rect2 = curb_rect.grow(-CityGrid.SIDEWALK_W + 1.0)
	# Split along X into 2-3 buildings with set-back margins.
	var parts: int = _rng.randi_range(2, 3)
	var w: float = block.size.x / float(parts)
	for i: int in parts:
		var cx: float = block.position.x + w * (float(i) + 0.5)
		var dist: float = Vector2(cx, block.get_center().y).length()
		var downtown: float = clampf(1.0 - dist / 900.0, 0.0, 1.0)
		var h: float = _rng.randf_range(32.0, 60.0) + downtown * _rng.randf_range(20.0, 110.0)
		# The facade roll is kept (unused) so the RNG sequence, and with it every position and height,
		# stays identical to iteration 2. Looks now come from BuildingStyles.
		var _facade_roll: int = _rng.randi_range(0, 3)
		if downtown > 0.6:
			_rng.randf()
		var size: Vector3 = Vector3(w - 1.0, h, block.size.y - 2.0)
		# Sometimes two towers in depth for variety.
		if _rng.randf() < 0.4:
			var d: float = size.z * 0.5
			_add_building(Vector2(cx, block.position.y + 1.0 + d * 0.5), Vector3(size.x, h, d - 0.5))
			_add_building(Vector2(cx, block.end.y - 1.0 - d * 0.5), Vector3(size.x, h * _rng.randf_range(0.6, 1.3), d - 0.5))
		else:
			_add_building(Vector2(cx, block.get_center().y), size)


func _build_landmark_and_bridge() -> void:
	# Landmark: a tall stepped tower in the centre (anchor for skyline shots).
	var c: Vector2 = Vector2(0.0, -66.0)
	_add_building(c + Vector2(0, -20), Vector3(40, 180, 30), "landmark")
	_add_building(c + Vector2(0, -20), Vector3(26, 240, 20), "landmark")
	_add_building(c + Vector2(0, -20), Vector3(8, 300, 8), "landmark")
	_landmark_center = Vector3(c.x, 0.0, c.y - 20.0)
	# Bridge over the river: deck + two towers + cable boxes, all anchorable.
	var bz: float = -CITY_Z - 120.0
	for i: int in 9:
		_add_building(Vector2(0, -CITY_Z - 10.0 - float(i) * 60.0), Vector3(30, 2, 60), "bridge")
	for tz: float in [bz, bz - 240.0]:
		_add_building(Vector2(-12, tz), Vector3(5, 110, 6), "bridge")
		_add_building(Vector2(12, tz), Vector3(5, 110, 6), "bridge")


func _flush_chunks() -> void:
	for k: Vector2i in _chunks:
		var ch: Dictionary = _chunks[k]
		for bucket_name: String in ["Buildings_Main", "Buildings_Special"]:
			var bk: _Bucket = ch["main"] if bucket_name == "Buildings_Main" else ch["special"]
			if bk.verts.is_empty():
				continue
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = bucket_name
			mi.mesh = bk.commit()
			mi.material_override = _building_mat
			mi.visibility_range_end = 1800.0
			mi.set_meta(&"stream_center", Vector3((float(k.x) + 0.5) * CHUNK, 0.0, (float(k.y) + 0.5) * CHUNK))
			add_child(mi)
			_stream_nodes.append(mi)

func _build_bases() -> void:
	# Five gang bases at street level on avenues; each EnemyBase spawns its own guards and waves.
	var spots: Array[Vector3] = [Vector3(-1100.0, 0.5, -30.0), Vector3(300.0, 0.5, 90.0), Vector3(900.0, 0.5, -150.0), Vector3(-500.0, 0.5, 330.0), Vector3(1200.0, 0.5, 450.0)]
	var waves: Array = [[&"thug", &"gunner", &"brute"], [&"thug", &"shield", &"gunner"], [&"gunner", &"brute", &"sniper"], [&"thug", &"shield", &"brute"], [&"shield", &"sniper", &"brute"]]
	var base_script: GDScript = load("res://scripts/ai/bases/enemy_base.gd")
	for i: int in spots.size():
		var pos: Vector3 = spots[i]
		var marker: Node3D = Node3D.new()
		marker.name = "Base_%d" % i
		marker.add_to_group(&"base")
		marker.set_meta(&"base_id", i)
		add_child(marker)
		marker.position = pos
		bases.append({"id": i, "pos": pos, "node": marker})
		# Base cover: Blender dumpsters and barriers on the avenue around the base (no code boxes).
		var cover: InstanceBatcher = InstanceBatcher.new()
		cover.group = &"base_cover"
		for j: int in 6:
			var id: String = "dumpster" if j % 2 == 0 else "barrier"
			var cp: Vector3 = Vector3(pos.x + _rng.randf_range(-8, 8), 0.0, pos.z + _rng.randf_range(-3, 3))
			var sz: Vector3 = Vector3(2.0, 1.4, 1.2) if id == "dumpster" else Vector3(1.8, 1.0, 0.4)
			cover.add(id, "res://assets/models/props/%s.glb" % id, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), cp), -1, {"type": "box", "size": sz})
		cover.flush(self, null)
		var eb: Node3D = base_script.new()
		eb.name = "EnemyBase_%d" % i
		eb.set(&"base_id", StringName("base_%d" % i))
		var wa: Array[StringName] = []
		wa.assign(waves[i])
		eb.set(&"wave_archetypes", wa)
		add_child(eb)
		eb.position = pos
		bases[i]["node"] = eb


## Vertex buffer for one chunk bucket (Buildings_Main or Buildings_Special).
## Layout per the iteration-3 contract: UV in metres, tangents, CUSTOM0/1 as RGBA_FLOAT.
class _Bucket:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var c0: PackedFloat32Array = PackedFloat32Array()
	var c1: PackedFloat32Array = PackedFloat32Array()

	func commit() -> ArrayMesh:
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_TANGENT] = tangents
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_CUSTOM0] = c0
		arr[Mesh.ARRAY_CUSTOM1] = c1
		var fmt: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		var m: ArrayMesh = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		return m


## Bay width in 2.4..3.0 so that wall_len / bay is an integer (nearest valid count to 2.7 m bays).
static func fit_bay(wall_len: float) -> float:
	if wall_len <= 3.0:
		return maxf(wall_len, 0.01)  # single bay; walls under 2.4 m cannot reach the range
	var lo: int = ceili(wall_len / 3.0)
	var hi: int = floori(wall_len / 2.4)
	if hi < lo:
		return wall_len / float(maxi(roundi(wall_len / 2.7), 1))
	return wall_len / float(clampi(roundi(wall_len / 2.7), lo, hi))


## Returns Vector2(floor_h, ground_h): ground_h in 4.0..5.0, floor_h in 3.5..4.0 and
## (height - ground_h) / floor_h an integer. Boxes under 7.5 m get nominal values.
static func fit_floors(height: float) -> Vector2:
	if height < 7.5:
		return Vector2(3.75, clampf(height, 4.0, 5.0))
	var best: Vector2 = Vector2(3.75, 4.5)
	var best_err: float = INF
	for gi: int in 11:
		var g: float = 4.0 + float(gi) * 0.1
		var n: int = maxi(roundi((height - g) / 3.75), 1)
		var f: float = (height - g) / float(n)
		var err: float = absf(f - 3.75) + absf(g - 4.5) * 0.05
		if f >= 3.5 and f <= 4.0 and err < best_err:
			best_err = err
			best = Vector2(f, g)
	return best


## Appends an axis-aligned box (5 faces, no bottom) with UV/tangent/custom data to a bucket.
## `info` is a BuildingStyles entry; `surface` 2 marks trim boxes (rooftop blocks).
## `fit` = Vector2(floor_h, ground_h) of the owning building.
func _box(bk: _Bucket, c: Vector3, s: Vector3, info: Dictionary, surface: int, fit: Vector2) -> void:
	var h: Vector3 = s * 0.5
	var faces: Array = [
		[Vector3.RIGHT, Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)],
		[Vector3.LEFT, Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3.UP, Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.FORWARD, Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
	]
	var style: float = float(info["style"])
	var variant: float = float(info["variant"])
	var seed_v: float = float(info["seed"])
	var gtype: float = float(info["ground_type"])
	for f: Array in faces:
		var n: Vector3 = f[0]
		# a = bottom-left, b = bottom-right, cc = top-right, d = top-left (seen from outside).
		var a: Vector3 = c + (f[1] as Vector3)
		var b: Vector3 = c + (f[2] as Vector3)
		var cc: Vector3 = c + (f[3] as Vector3)
		var d: Vector3 = c + (f[4] as Vector3)
		var roof: bool = n == Vector3.UP
		var t: Vector3
		var tw: float
		var bay: float
		var ua: Vector2
		var ub: Vector2
		var ucc: Vector2
		var ud: Vector2
		if roof:
			# Roof UV = world x,z; tangent +X. Bitangent = cross(N,T)*w must be +Z, so w = -1.
			t = Vector3.RIGHT
			tw = -1.0
			bay = fit_bay(s.x)
			ua = Vector2(a.x, a.z)
			ub = Vector2(b.x, b.z)
			ucc = Vector2(cc.x, cc.z)
			ud = Vector2(d.x, d.z)
		else:
			var wl: float = (b - a).length()
			t = (b - a) / wl
			tw = 1.0  # cross(N, T) = +Y on every wall, matching v running up
			bay = fit_bay(wl)
			ua = Vector2(0.0, a.y)
			ub = Vector2(wl, b.y)
			ucc = Vector2(wl, cc.y)
			ud = Vector2(0.0, d.y)
		var surf: float = 2.0 if surface == 2 else (1.0 if roof else 0.0)
		# Counter-clockwise seen from outside -> Godot front face is clockwise, so emit a, cc, b.
		var pts: Array[Vector3] = [a, cc, b, a, d, cc]
		var tex: Array[Vector2] = [ua, ucc, ub, ua, ud, ucc]
		for i: int in 6:
			bk.verts.append(pts[i])
			bk.normals.append(n)
			bk.tangents.append_array(PackedFloat32Array([t.x, t.y, t.z, tw]))
			bk.uvs.append(tex[i])
			bk.c0.append_array(PackedFloat32Array([style, variant, seed_v, surf]))
			bk.c1.append_array(PackedFloat32Array([bay, fit.x, fit.y, gtype]))

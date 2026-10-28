class_name PropPlacer
extends Node3D
## Deterministic street-prop placement from data/props/manifest.json (seeded by the city seed and
## each block / corner, so every run gives the same city). One MultiMeshInstance3D per prop
## variant per 128 m chunk (InstanceBatcher), registered with ChunkStreamer. Solid props get
## colliders on layer 7; anchor props get an 'anchorable' marker with meta 'anchor_point'.
## Overlaps: every placed footprint is reserved in a spatial hash and later props that would touch
## a reserved footprint, the road (outside the sidewalk band) or a building are skipped.
## Night: MeshKit drives the Emit_* materials; a pool of POOL_LIGHTS OmniLights follows the hero
## to the nearest lamp heads after dark.

const MANIFEST: String = "res://data/props/manifest.json"
const POOL_LIGHTS: int = 8
const LIGHT_RANGE: float = 60.0
const PARK_FRACTION_MIN: float = 0.3
const PARK_FRACTION_MAX: float = 0.5
const HASH_CELL: float = 4.0

var city_seed: int = 7
var buildings: Array[AABB] = []
var props: Dictionary = {}               # id -> manifest entry
var lamp_heads: PackedVector3Array = PackedVector3Array()
var placed_count: Dictionary = {}        # id -> int
var _hash: Dictionary = {}               # Vector2i -> Array[Rect2]
var _batch: InstanceBatcher = InstanceBatcher.new()
var _lights: Array[OmniLight3D] = []
var _light_timer: float = 0.0
var _anchor_root: Node3D
var signals: Array[Dictionary] = []      # {"pos": Vector3, "light_id": int} per signal head


static func load_manifest() -> Array:
	if not FileAccess.file_exists(MANIFEST):
		print("[PropPlacer] manifest missing: ", MANIFEST)
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (data is Dictionary):
		print("[PropPlacer] manifest unreadable")
		return []
	return (data as Dictionary).get("props", []) as Array


func build(streets: StreetBuilder, streamer: ChunkStreamer) -> void:
	name = "PropPlacer"
	for e: Variant in load_manifest():
		var d: Dictionary = e as Dictionary
		props[str(d.get("id", ""))] = d
	_anchor_root = Node3D.new()
	_anchor_root.name = "Anchors"
	add_child(_anchor_root)
	for b: AABB in buildings:
		_reserve(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var blocks: Array[Rect2] = CityGrid.block_rects()
	# Order matters: big fixed items first so small ones fill around them.
	for i: int in streets.intersections.size():
		rng.seed = MeshKit.seed_of(city_seed, 101, i)
		_intersection(streets.intersections[i], i, rng)
	for bi: int in blocks.size():
		rng.seed = MeshKit.seed_of(city_seed, 202, bi)
		_corners(blocks[bi], rng)
		_construction(blocks[bi], rng)
		_edges(blocks[bi], rng)
	rng.seed = MeshKit.seed_of(city_seed, 303)
	_parked_cars(streets.avenue_curb_spots, rng)
	_batch.flush(self, streamer)
	_tint_parked_cars()
	_build_light_pool()
	_build_signal_glow()


# ------------------------------------------------------------------ helpers

func _entry(id: String) -> Dictionary:
	return props.get(id, {}) as Dictionary


func _size(id: String) -> Vector3:
	var s: Array = _entry(id).get("size", [1, 1, 1]) as Array
	return Vector3(float(s[0]), float(s[1]), float(s[2]))


func _footprint(id: String, xf: Transform3D, pad: float) -> Rect2:
	var s: Vector3 = _size(id)
	var ax: Vector3 = xf.basis.x.normalized() * s.x * 0.5
	var az: Vector3 = xf.basis.z.normalized() * s.z * 0.5
	var hx: float = absf(ax.x) + absf(az.x) + pad
	var hz: float = absf(ax.z) + absf(az.z) + pad
	return Rect2(xf.origin.x - hx, xf.origin.z - hz, hx * 2.0, hz * 2.0)


func _free(r: Rect2) -> bool:
	for k: Vector2i in _cells(r):
		for o: Rect2 in _hash.get(k, []) as Array:
			if o.intersects(r):
				return false
	return true


func _reserve(r: Rect2) -> void:
	for k: Vector2i in _cells(r):
		if not _hash.has(k):
			_hash[k] = []
		(_hash[k] as Array).append(r)


func _cells(r: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(floori(r.position.x / HASH_CELL), floori(r.end.x / HASH_CELL) + 1):
		for z: int in range(floori(r.position.y / HASH_CELL), floori(r.end.y / HASH_CELL) + 1):
			out.append(Vector2i(x, z))
	return out


## True if the footprint lies inside some block's sidewalk band (not in the road).
func _on_sidewalk(r: Rect2, block: Rect2) -> bool:
	return block.encloses(r)


## Places one prop if its footprint is free. Returns true when placed.
func _place(id: String, xf: Transform3D, block: Rect2 = Rect2(), pad: float = 0.15, variant: int = -1) -> bool:
	var e: Dictionary = _entry(id)
	if e.is_empty():
		return false
	var fp: Rect2 = _footprint(id, xf, pad)
	if block.has_area() and not _on_sidewalk(fp, block):
		return false
	if not _free(fp):
		return false
	var col: Dictionary = {}
	var ct: String = str(e.get("collider", "none"))
	if ct != "none":
		var cz: Array = e.get("collider_size", [0, 0, 0]) as Array
		col = {"type": ct, "size": Vector3(float(cz[0]), float(cz[1]), float(cz[2]))}
	if not _batch.add(id, str(e.get("model", "")), xf, variant, col):
		return false
	_reserve(fp)
	placed_count[id] = int(placed_count.get(id, 0)) + 1
	if bool(e.get("anchor", false)):
		_anchor(id, xf)
	# Props that ride on another one (tree grates under street trees).
	for o: String in props:
		if str(_entry(o).get("attach_to", "")) == id:
			_batch.add(o, str(_entry(o).get("model", "")), xf, -1)
			placed_count[o] = int(placed_count.get(o, 0)) + 1
	return true


## Anchor marker at the top of lamps, mast arms and tree canopies (meta 'anchor_point').
func _anchor(id: String, xf: Transform3D) -> void:
	var s: Vector3 = _size(id)
	var top: Vector3 = xf.origin + Vector3.UP * s.y
	if id == "lamp_cobra":
		top = xf * Vector3(0.0, s.y, -2.4)  # arm head over the curb
		lamp_heads.append(top)
	elif id == "traffic_light_mast":
		top = xf * Vector3(5.0, 6.35, 0.0)
	var m: Marker3D = Marker3D.new()
	m.position = top
	m.set_meta(&"anchor_point", top)
	m.set_meta(&"prop_id", id)
	m.add_to_group(&"anchorable")
	_anchor_root.add_child(m)
	add_anchor_body(_anchor_root, top, 0.6 if id == "street_tree" else 0.35)


## Small layer-1 sphere at an anchor point: Player.find_anchor() rays use WORLD_MASK = 1,
## so this is what makes lamp heads, mast arms and canopies swingable. Placed >= 3 m above the
## ground, so it never touches a running hero.
static func add_anchor_body(parent: Node3D, p: Vector3, r: float) -> void:
	var b: StaticBody3D = StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = p
	b.add_to_group(&"stream_always")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sp: SphereShape3D = SphereShape3D.new()
	sp.radius = r
	cs.shape = sp
	b.add_child(cs)
	parent.add_child(b)


# ------------------------------------------------------------------ placement rules

## Intersection corners: mast-arm signals on the avenue corners, poles on the street corners.
func _intersection(c: Vector3, light_id: int, rng: RandomNumberGenerator) -> void:
	var hx: float = CityGrid.STREET_WIDTH * 0.5 + 0.6
	var hz: float = CityGrid.AVE_WIDTH * 0.5 + 0.6
	var y: float = CityGrid.CURB_H
	# Far-side mast arms (glb: arm along local +X, lenses face local +Z).
	# Eastbound (lane z+5) is served from the SE corner: arm -> +Z, lenses -> -X.
	# Westbound (lane z-5) from the NW corner: arm -> -Z, lenses -> +X.
	var se: Transform3D = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c.x + hx, y, c.z - hz))
	var nw: Transform3D = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(c.x - hx, y, c.z + hz))
	for xf: Transform3D in [nw, se]:
		if _place("traffic_light_mast", xf, Rect2(), 0.15, 0):
			_register_signal(xf, light_id, true)
	# Street-facing poles on the other two corners (lenses toward the cross street).
	var ne: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3(c.x + hx, y, c.z + hz))
	var sw: Transform3D = Transform3D(Basis.IDENTITY, Vector3(c.x - hx, y, c.z - hz))
	for xf2: Transform3D in [ne, sw]:
		if _place("traffic_light_pole", xf2):
			_register_signal(xf2, light_id, false)
	if rng.randf() < float(_entry("sign_stop").get("density", 0.0)):
		_place("sign_stop", Transform3D(Basis.IDENTITY, Vector3(c.x + hx, y, c.z - hz + 1.6)))


## Corner furniture in the 3.5 m band 2-6 m from each block corner.
func _corners(r: Rect2, rng: RandomNumberGenerator) -> void:
	var pts: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var ids: Array[String] = []
	for id: String in props:
		if str(_entry(id).get("placement", "")) == "corner":
			ids.append(id)
	ids.sort()
	for p: Vector2 in pts:
		var inward: Vector2 = Vector2(signf(r.get_center().x - p.x), signf(r.get_center().y - p.y))
		var slot: int = 0
		for id: String in ids:
			if rng.randf() >= float(_entry(id).get("density", 0.0)):
				continue
			# Alternate between the two curb arms of the corner.
			var along_x: bool = slot % 2 == 0
			var d: float = 2.5 + float(slot / 2) * 1.6
			var q: Vector2 = p + (Vector2(inward.x * d, inward.y * 0.7) if along_x else Vector2(inward.x * 0.7, inward.y * d))
			var face: Vector3 = Vector3(0, 0, -inward.y) if along_x else Vector3(-inward.x, 0, 0)
			_place(id, Transform3D(Basis.looking_at(face, Vector3.UP), Vector3(q.x, CityGrid.CURB_H, q.y)), r)
			slot += 1


## Rare construction sites: a scaffold shed along a building face with barriers, cones, a stack.
func _construction(r: Rect2, rng: RandomNumberGenerator) -> void:
	if rng.randf() > 0.08:
		return
	var z: float = r.position.y + CityGrid.SIDEWALK_W * 0.5
	var x0: float = r.position.x + 14.0
	var face: Basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	var y: float = CityGrid.CURB_H
	for i: int in 3:
		_place("scaffold_shed", Transform3D(face, Vector3(x0 + 3.0 + float(i) * 6.2, y, z + 0.1)), r, 0.0)
	for i: int in 6:
		_place("cone", Transform3D(face, Vector3(x0 + float(i) * 3.4, 0.0, r.position.y - 0.8)))
	_place("barrier", Transform3D(face, Vector3(x0 - 1.5, y, z)), r)
	_place("barrier", Transform3D(face, Vector3(x0 + 21.0, y, z)), r)
	_place("steam_stack", Transform3D(face, Vector3(x0 + 9.0, 0.0, r.position.y - 2.2)))


## Sidewalk-edge props along every block side: furniture line 0.6 m from the curb, larger
## items (shelters, newsstands, dumpsters) on the building side of the band.
func _edges(r: Rect2, rng: RandomNumberGenerator) -> void:
	var ids: Array[String] = []
	for id: String in props:
		var e: Dictionary = _entry(id)
		if str(e.get("placement", "")) == "sidewalk_edge" and float(e.get("spacing_m", 0.0)) > 0.0:
			ids.append(id)
	ids.sort()
	var sides: Array = [
		[Vector2(r.position.x, r.position.y), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(r.end.x, r.position.y), Vector2(0, 1), Vector2(-1, 0)],
		[Vector2(r.end.x, r.end.y), Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(r.position.x, r.end.y), Vector2(0, -1), Vector2(1, 0)],
	]
	for sd: Array in sides:
		var a: Vector2 = sd[0]
		var along: Vector2 = sd[1]
		var inward: Vector2 = sd[2]
		var side_len: float = r.size.x if absf(along.x) > 0.5 else r.size.y
		var face: Vector3 = Vector3(-inward.x, 0, -inward.y)  # props face the road
		for id: String in ids:
			var e: Dictionary = _entry(id)
			var spacing: float = float(e.get("spacing_m", 30.0))
			var dens: float = float(e.get("density", 1.0))
			var s: Vector3 = _size(id)
			var depth: float = 0.6 + s.z * 0.5 if s.y < 3.0 or id == "lamp_cobra" or id == "street_tree" else CityGrid.SIDEWALK_W - 0.3 - s.z * 0.5
			if id == "street_tree":
				depth = 0.9
			var d: float = 9.0 + rng.randf() * spacing * 0.5
			while d < side_len - 9.0:
				if rng.randf() < dens:
					var p: Vector2 = a + along * d + inward * depth
					var basis: Basis = Basis.looking_at(face, Vector3.UP)
					if id == "street_tree":
						basis = basis.rotated(Vector3.UP, rng.randf() * TAU)
					_place(id, Transform3D(basis, Vector3(p.x, CityGrid.CURB_H, p.y)), r)
				d += spacing * rng.randf_range(0.85, 1.15)


## Parked cars on 30-50% of avenue curb spots (per block side fraction from the seed).
func _parked_cars(spots: Array[Transform3D], rng: RandomNumberGenerator) -> void:
	var kinds: Array[String] = ["parked_car_sedan", "parked_car_hatch", "parked_car_van"]
	var weights: Array[float] = []
	var tot: float = 0.0
	for k: String in kinds:
		var w: float = float(_entry(k).get("density", 0.0))
		weights.append(w)
		tot += w
	if tot <= 0.0:
		return
	var fraction: float = rng.randf_range(PARK_FRACTION_MIN, PARK_FRACTION_MAX)
	for xf: Transform3D in spots:
		if rng.randf() >= fraction:
			continue
		var pick: float = rng.randf() * tot
		var k: String = kinds[0]
		for i: int in kinds.size():
			pick -= weights[i]
			if pick <= 0.0:
				k = kinds[i]
				break
		var yaw: Basis = xf.basis if rng.randf() < 0.5 else xf.basis.rotated(Vector3.UP, PI)
		_place(k, Transform3D(yaw, xf.origin), Rect2(), 0.3)


const CAR_TINTS: Array[Color] = [Color(1, 1, 1), Color(0.75, 0.82, 1.0), Color(1.0, 0.78, 0.72), Color(0.8, 0.95, 0.8), Color(0.65, 0.65, 0.7), Color(1.0, 0.95, 0.7)]


## Per-batch colour variety for parked cars: multiplies the exported textured body material.
func _tint_parked_cars() -> void:
	for c: Node in get_children():
		var mmi: MultiMeshInstance3D = c as MultiMeshInstance3D
		if mmi == null or not str(mmi.get_meta(&"prop_id", "")).begins_with("parked_car"):
			continue
		var h: int = absi(String(mmi.name).hash())
		StreetBuilder.apply_variant_tint(mmi, CAR_TINTS[h % CAR_TINTS.size()])


## Lens glow positions (local, Godot axes) matching the Blender generators: mast heads at
## x = 6.9 / 4.5 / 2.1, lens rows y = 5.7 / 5.4 / 5.1; pole head lens rows y = 3.59 / 3.3 / 3.01.
const MAST_HEADS: Array[float] = [6.9, 4.5, 2.1]
const MAST_ROWS: Array[float] = [5.7, 5.4, 5.1]
const POLE_ROWS: Array[float] = [3.59, 3.3, 3.01]
const LENS_COLORS: Array[Color] = [Color(1.0, 0.12, 0.06), Color(1.0, 0.65, 0.0), Color(0.15, 1.0, 0.4)]
const STATE_INDEX: Dictionary = {&"red": 0, &"yellow": 1, &"green": 2}

## glow xfs: [group][avenue 0 / cross 1][colour] -> Array[Transform3D]
var _glow_xfs: Array = []
var _glow_mmis: Array = []   # same layout, MultiMeshInstance3D


func _register_signal(xf: Transform3D, light_id: int, avenue: bool) -> void:
	signals.append({"pos": xf.origin, "light_id": light_id, "avenue": avenue})
	if _glow_xfs.is_empty():
		for g: int in TrafficLights.PHASE_GROUPS:
			_glow_xfs.append([[[], [], []], [[], [], []]])
	var g2: int = TrafficLights.group_of(light_id)
	var k: int = 0 if avenue else 1
	for ci: int in 3:
		var arr: Array = _glow_xfs[g2][k][ci]
		if avenue:
			for hxp: float in MAST_HEADS:
				arr.append(Transform3D(Basis.IDENTITY, xf * Vector3(hxp, MAST_ROWS[ci], 0.2)))
		else:
			arr.append(Transform3D(Basis.IDENTITY, xf * Vector3(0.0, POLE_ROWS[ci], 0.27)))


func _build_signal_glow() -> void:
	if _glow_xfs.is_empty():
		return
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	sm.radial_segments = 8
	sm.rings = 4
	for g: int in _glow_xfs.size():
		var row: Array = []
		for k: int in 2:
			var cols: Array = []
			for ci: int in 3:
				var mat: StandardMaterial3D = StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.albedo_color = LENS_COLORS[ci]
				mat.emission_enabled = true
				mat.emission = LENS_COLORS[ci]
				mat.emission_energy_multiplier = 4.0
				var m: SphereMesh = sm.duplicate() as SphereMesh
				m.material = mat
				var xfs: Array[Transform3D] = []
				xfs.assign(_glow_xfs[g][k][ci])
				var mmi: MultiMeshInstance3D = MeshKit.make_mmi(m, xfs, Vector3.ZERO, 450.0)
				mmi.name = "SignalGlow_g%d_%s_%d" % [g, "ave" if k == 0 else "cross", ci]
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.add_to_group(&"traffic_signal_glow")
				add_child(mmi)
				cols.append(mmi)
			row.append(cols)
		_glow_mmis.append(row)
	_update_signal_glow()


## Shows exactly one lens colour per (group, direction), from TrafficLights.clock.
func _update_signal_glow() -> void:
	for g: int in _glow_mmis.size():
		var ph: float = TrafficLights.group_phase(TrafficLights.clock, g)
		var states: Array[StringName] = [TrafficLights.state_for_phase(ph), TrafficLights.cross_state_for_phase(ph)]
		for k: int in 2:
			var on: int = int(STATE_INDEX[states[k]])
			for ci: int in 3:
				(_glow_mmis[g][k][ci] as MultiMeshInstance3D).visible = ci == on


# ------------------------------------------------------------------ night lights

func _build_light_pool() -> void:
	for i: int in POOL_LIGHTS:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "LampLight_%d" % i
		l.light_color = Color(1.0, 0.82, 0.55)
		l.omni_range = 14.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)


func _process(delta: float) -> void:
	_update_signal_glow()
	_light_timer -= delta
	if _light_timer > 0.0 or _lights.is_empty():
		return
	_light_timer = 0.5
	var nf: float = MeshKit.night_factor
	var p: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if p == null or nf < 0.05 or lamp_heads.is_empty():
		for l: OmniLight3D in _lights:
			l.visible = false
		return
	var hp: Vector3 = p.global_position
	# Partial selection of the nearest lamp heads (lamp count is a few thousand, cheap at 2 Hz).
	var best: Array = []
	for h: Vector3 in lamp_heads:
		var d: float = h.distance_squared_to(hp)
		if d > LIGHT_RANGE * LIGHT_RANGE:
			continue
		best.append([d, h])
	best.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i: int in _lights.size():
		var l: OmniLight3D = _lights[i]
		if i < best.size():
			l.position = (best[i][1] as Vector3) + Vector3.DOWN * 0.4
			l.light_energy = 2.2 * nf
			l.visible = true
		else:
			l.visible = false

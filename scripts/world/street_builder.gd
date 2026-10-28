class_name StreetBuilder
extends RefCounted
## Builds the street layer from road/*.glb: sidewalks (3.5 m, top y=0.15) with curbs,
## corner pieces, curb ramps, crosswalks, stop lines, avenue centre lines, manholes, vents.
## Colliders: one StaticBody3D per chunk on layer 1 with a box for each sidewalk slab and
## a 45 degree beveled ramp prism along each curb so the hero never snags.
## Also produces the data behind the World API (intersections, sidewalk graph, curbs, stop lines).

const ROAD: String = "res://assets/models/road/"
const TOP: float = CityGrid.CURB_H
const W: float = CityGrid.SIDEWALK_W

var intersections: PackedVector3Array = PackedVector3Array()
var curb_segments: Array[PackedVector3Array] = []
var stop_lines: Array[Dictionary] = []
var graph_nodes: PackedVector3Array = PackedVector3Array()
var graph_edges: PackedInt32Array = PackedInt32Array()
var graph_cross: PackedInt32Array = PackedInt32Array()
var avenue_curb_spots: Array[Transform3D] = []  # parking slots along avenue curbs (yaw along avenue)

var _batch: InstanceBatcher = InstanceBatcher.new()
var _bodies: Dictionary = {}  # Vector2i -> StaticBody3D
var _parent: Node3D
var _node_index: Dictionary = {}  # Vector2i(rounded x, z) -> node id


func build(parent: Node3D, streamer: ChunkStreamer, city_seed: int) -> void:
	_parent = parent
	_batch.group = &"street"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = MeshKit.seed_of(city_seed, 9001)
	intersections = CityGrid.intersections()
	for r: Rect2 in CityGrid.block_rects():
		_build_block(r, rng)
	_build_intersections(rng)
	_build_lane_marks(rng)
	_batch.flush(parent, streamer)
	for k: Vector2i in _bodies:
		var b: StaticBody3D = _bodies[k]
		b.set_meta(&"stream_center", MeshKit.chunk_center(k))
		b.add_to_group(&"stream_always")


## The only place where world builders touch materials of glb meshes: every BaseMaterial3D
## on node (MeshInstance3D surfaces or a MultiMeshInstance3D mesh) is duplicated and its
## albedo_color multiplied by tint. Textures, roughness and names stay as exported.
## Surfaces named *_paint, *_glass, *_emissive, Emit_* or *Brakelight/*Headlight are left alone.
static func apply_variant_tint(node: Node3D, tint: Color) -> void:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi != null and mi.mesh != null:
			for s: int in mi.mesh.get_surface_count():
				var tinted: Material = _tinted(mi.get_active_material(s), tint)
				if tinted != null:
					mi.set_surface_override_material(s, tinted)
			continue
		var mmi: MultiMeshInstance3D = n as MultiMeshInstance3D
		if mmi != null and mmi.multimesh != null and mmi.multimesh.mesh != null:
			var src: Mesh = mmi.multimesh.mesh
			var copy: Mesh = src.duplicate() as Mesh
			var changed: bool = false
			for s: int in copy.get_surface_count():
				var t: Material = _tinted(copy.surface_get_material(s), tint)
				if t != null:
					copy.surface_set_material(s, t)
					changed = true
			if changed:
				mmi.multimesh.mesh = copy


static func _tinted(m: Material, tint: Color) -> Material:
	var bm: BaseMaterial3D = m as BaseMaterial3D
	if bm == null:
		return null
	var nm: String = bm.resource_name.to_lower()
	for skip: String in ["_paint", "_glass", "_emissive", "emit_", "brakelight", "headlight", "glass", "tire", "rim", "trim", "wheel"]:
		if nm.contains(skip):
			return null
	var d: BaseMaterial3D = bm.duplicate() as BaseMaterial3D
	d.resource_name = bm.resource_name
	d.albedo_color = bm.albedo_color * tint
	return d


func _body(p: Vector3) -> StaticBody3D:
	var k: Vector2i = MeshKit.chunk_key(p)
	if not _bodies.has(k):
		var b: StaticBody3D = StaticBody3D.new()
		b.name = "Sidewalk_%d_%d" % [k.x, k.y]
		b.collision_layer = 1
		b.collision_mask = 0
		_parent.add_child(b)
		_bodies[k] = b
	return _bodies[k]


func _box_col(center: Vector3, size: Vector3) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	_body(center).add_child(cs)


## 45 degree bevel along a curb edge from a to b; out = unit vector pointing to the road.
func _bevel_col(a: Vector3, b: Vector3, out: Vector3) -> void:
	var seg_len: float = a.distance_to(b)
	var along: Vector3 = (b - a).normalized()
	var pts: PackedVector3Array = PackedVector3Array()
	for s: float in [-0.5, 0.5]:
		var o: Vector3 = along * seg_len * s
		pts.append(o)                              # curb top edge
		pts.append(o + Vector3(0, -TOP, 0))        # curb foot
		pts.append(o + out * TOP + Vector3(0, -TOP, 0))  # bevel foot on the road
	var sh: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	sh.points = pts
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = sh
	var mid: Vector3 = (a + b) * 0.5
	cs.position = Vector3(mid.x, TOP, mid.z)
	_body(mid).add_child(cs)


func _node(p: Vector3) -> int:
	var key: Vector2i = Vector2i(roundi(p.x * 2.0), roundi(p.z * 2.0))
	if _node_index.has(key):
		return _node_index[key]
	graph_nodes.append(p)
	_node_index[key] = graph_nodes.size() - 1
	return graph_nodes.size() - 1


func _edge(a: int, b: int, cross: bool = false) -> void:
	if cross:
		graph_cross.append(a)
		graph_cross.append(b)
	else:
		graph_edges.append(a)
		graph_edges.append(b)


## Yaw so the corner piece (curb on its local -X and +Z edges) faces the outward signs (ox, oz).
func _corner_yaw(ox: float, oz: float) -> float:
	for i: int in 4:
		var y: float = PI * 0.5 * float(i)
		var v: Vector3 = Vector3(-1, 0, 1).rotated(Vector3.UP, y)
		if signf(v.x) == signf(ox) and signf(v.z) == signf(oz):
			return y
	return 0.0


func _build_block(r: Rect2, rng: RandomNumberGenerator) -> void:
	var x0: float = r.position.x
	var x1: float = r.end.x
	var z0: float = r.position.y
	var z1: float = r.end.y
	# One slab collider for the whole raised block plus a beveled curb on every side.
	_box_col(Vector3(r.get_center().x, TOP * 0.5, r.get_center().y), Vector3(r.size.x, TOP, r.size.y))
	var corners: Array[Vector3] = [Vector3(x0, TOP, z0), Vector3(x1, TOP, z0), Vector3(x1, TOP, z1), Vector3(x0, TOP, z1)]
	var outs: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	var ids: Array[int] = []
	for i: int in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n: Vector3 = outs[i]
		_bevel_col(a, b, n)
		curb_segments.append(PackedVector3Array([a, b]))
		_side_tiles(a, b, n, rng)
		# Sidewalk graph node at the middle of the walk band near each corner.
		var c: Vector3 = corners[i]
		var inward: Vector3 = Vector3(signf(r.get_center().x - c.x), 0, signf(r.get_center().y - c.z))
		ids.append(_node(Vector3(c.x, TOP, c.z) + inward * (W * 0.5)))
		# Corner tile and curb ramp.
		var yaw: float = _corner_yaw(-inward.x, -inward.z)
		var cxf: Transform3D = Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, 0.0, c.z))
		_batch.add("sidewalk_corner", ROAD + "sidewalk_corner.glb", cxf, rng.randi_range(0, 1))
		var rxf: Transform3D = Transform3D(Basis(Vector3.UP, yaw + PI * 0.25), Vector3(c.x, 0.0, c.z) + inward * 0.9)
		_batch.add("curb_ramp", ROAD + "curb_ramp.glb", rxf, -1)
		if absf(n.z) > 0.5:
			_parking_spots(a, b, n)
	for i: int in 4:
		_edge(ids[i], ids[(i + 1) % 4])


## Straight sidewalk_8m tiles between the 7.5 m corner pieces; local -X (curb) faces the road.
func _side_tiles(a: Vector3, b: Vector3, out: Vector3, rng: RandomNumberGenerator) -> void:
	var along: Vector3 = (b - a).normalized()
	var start: float = W + 4.0
	var span: float = a.distance_to(b) - start * 2.0
	if span <= 0.5:
		return
	var n: int = maxi(1, ceili(span / 8.0))
	var sc: float = span / (float(n) * 8.0)
	var bx: Vector3 = -out
	var bz: Vector3 = bx.cross(Vector3.UP)
	var basis: Basis = Basis(bx, Vector3.UP, bz * sc)
	for i: int in n:
		var d: float = start + (float(i) + 0.5) * span / float(n)
		var p: Vector3 = Vector3(a.x, 0.0, a.z) + along * d - out * (W * 0.5)
		_batch.add("sidewalk_8m", ROAD + "sidewalk_8m.glb", Transform3D(basis, p), 0 if rng.randf() < 0.75 else 1)


## Parking slots on the road side of avenue-facing curbs (6.5 m apart, 10 m clear of corners).
func _parking_spots(a: Vector3, b: Vector3, out: Vector3) -> void:
	var along: Vector3 = (b - a).normalized()
	var seg_len: float = a.distance_to(b)
	var d: float = 10.0 + 3.25
	while d < seg_len - 10.0 - 3.0:
		var p: Vector3 = Vector3(a.x, 0.0, a.z) + along * d + out * 1.25
		avenue_curb_spots.append(Transform3D(Basis(Vector3.UP, PI * 0.5 if absf(along.x) > 0.5 else 0.0), p))
		d += 6.5


func _build_intersections(rng: RandomNumberGenerator) -> void:
	var hx: float = CityGrid.STREET_WIDTH * 0.5
	var hz: float = CityGrid.AVE_WIDTH * 0.5
	var cw: String = ROAD + "crosswalk_stripe.glb"
	for li: int in intersections.size():
		var c: Vector3 = intersections[li]
		# Crosswalks over the street (walk along X, bars along Z) north and south of the avenue.
		for sz: float in [-1.0, 1.0]:
			var z: float = c.z + sz * (hz + 2.0)
			var x: float = c.x - hx + 1.0
			while x <= c.x + hx - 0.9:
				_batch.add("crosswalk_stripe", cw, Transform3D(Basis.IDENTITY, Vector3(x, 0.005, z)), 0 if rng.randf() < 0.7 else 1)
				x += 1.2
		# Crosswalks over the avenue (walk along Z, bars along X) west and east of the street.
		for sx: float in [-1.0, 1.0]:
			var x2: float = c.x + sx * (hx + 2.0)
			var z2: float = c.z - hz + 1.0
			while z2 <= c.z + hz - 0.9:
				_batch.add("crosswalk_stripe", cw, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x2, 0.005, z2)), 0 if rng.randf() < 0.7 else 1)
				z2 += 1.2
		# Stop lines: eastbound (+X, lane z+5) stops west of the crosswalk; westbound east of it.
		var stop_d: float = hx + 4.0
		for dir: float in [1.0, -1.0]:
			var lane_side: float = 1.0 if dir > 0.0 else -1.0
			var pos: Vector3 = Vector3(c.x - dir * stop_d, 0.0, c.z + lane_side * CityGrid.LANE_OFFSET)
			stop_lines.append({"pos": pos, "dir": Vector3(dir, 0, 0), "light_id": li})
			var bar: Basis = Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK * 4.0)
			_batch.add("stop_line", cw, Transform3D(bar, Vector3(pos.x, 0.006, c.z + lane_side * 6.5)), 2)
		# Crosswalk graph edges between facing block corners.
		var a: float = hx + W * 0.5
		var b: float = hz + W * 0.5
		for s: float in [-1.0, 1.0]:
			_cross_if(Vector3(c.x - a, TOP, c.z + s * b), Vector3(c.x + a, TOP, c.z + s * b))
			_cross_if(Vector3(c.x + s * a, TOP, c.z - b), Vector3(c.x + s * a, TOP, c.z + b))


func _cross_if(p: Vector3, q: Vector3) -> void:
	var kp: Vector2i = Vector2i(roundi(p.x * 2.0), roundi(p.z * 2.0))
	var kq: Vector2i = Vector2i(roundi(q.x * 2.0), roundi(q.z * 2.0))
	if _node_index.has(kp) and _node_index.has(kq):
		_edge(_node_index[kp], _node_index[kq], true)


## Manholes and steam vents on the avenues (outside the park and intersections).
func _build_lane_marks(rng: RandomNumberGenerator) -> void:
	var hx: float = CityGrid.STREET_WIDTH * 0.5
	for z: float in CityGrid.avenue_zs():
		for s: Vector2 in CityGrid.avenue_spans(z):
			var x: float = s.x
			while x < s.y:
				var lx: float = fposmod(x + CityGrid.CITY_X, CityGrid.STREET_SPACING)
				if lx > hx + 8.0 and lx < CityGrid.STREET_SPACING - hx - 8.0 and not CityGrid.in_park(x, z, 2.0):
					if rng.randf() < 0.7:
						var mz: float = z + (CityGrid.LANE_OFFSET if rng.randf() < 0.5 else -CityGrid.LANE_OFFSET)
						_batch.add("manhole", ROAD + "manhole.glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, 0.004, mz)), -1)
					if rng.randf() < 0.2:
						_batch.add("steam_vent", ROAD + "steam_vent.glb", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x + 20.0, 0.004, z + rng.randf_range(-2.0, 2.0))), -1)
				x += 60.0
			# Centre line: dashed paint (narrow stripe variant) between intersections.
			var cx: float = s.x
			while cx < s.y:
				var lc: float = fposmod(cx + CityGrid.CITY_X, CityGrid.STREET_SPACING)
				if lc > hx + 7.0 and lc < CityGrid.STREET_SPACING - hx - 7.0:
					var cb: Basis = Basis(Vector3.UP, PI * 0.5)
					_batch.add("centre_line", ROAD + "crosswalk_stripe.glb", Transform3D(cb, Vector3(cx, 0.005, z)), 2)
				cx += 6.0

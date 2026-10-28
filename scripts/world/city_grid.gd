class_name CityGrid
extends RefCounted
## Single source of truth for the street grid, shared by World, StreetBuilder, PropPlacer,
## ParkBuilder and the traffic setup (mirrored in traffic/sim_traffic.py and park/sim_poisson.py).
## Blocks are the curb rectangles (sidewalk included). The park is a union of whole grid blocks
## between street x=-210 and x=240 and avenue z=90 and z=330; no asphalt exists inside it.

const CITY_X: float = 1500.0
const CITY_Z: float = 750.0
const AVE_SPACING: float = 120.0
const AVE_WIDTH: float = 26.0
const STREET_SPACING: float = 90.0
const STREET_WIDTH: float = 16.0
const SIDEWALK_W: float = 3.5
const CURB_H: float = 0.15
## Curb rectangle of the park: 5 x 2 whole blocks (x -232..202, z 103..317) plus the streets and
## the avenue (z=210) between them, aligned to the block curbs.
const PARK_RECT: Rect2 = Rect2(-232.0, 103.0, 434.0, 214.0)
const LANE_OFFSET: float = 5.0
const LANE_X0: float = -1460.0
const LANE_X1: float = 1460.0


## Curb rectangles of every block in the order World builds them (park blocks excluded).
static func block_rects(include_park_blocks: bool = false) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var z0: float = -CITY_Z
	while z0 < CITY_Z - 1.0:
		var x0: float = -CITY_X
		while x0 < CITY_X - 1.0:
			var r: Rect2 = Rect2(x0 + STREET_WIDTH * 0.5, z0 + AVE_WIDTH * 0.5, STREET_SPACING - STREET_WIDTH, AVE_SPACING - AVE_WIDTH)
			if include_park_blocks or not r.intersects(PARK_RECT):
				out.append(r)
			x0 += STREET_SPACING
		z0 += AVE_SPACING
	return out


## Street centre lines (x) that have blocks on both sides.
static func street_xs() -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var x: float = -CITY_X + STREET_SPACING
	while x < CITY_X - 1.0:
		out.append(x)
		x += STREET_SPACING
	return out


## Avenue centre lines (z) that have blocks on both sides.
static func avenue_zs() -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var z: float = -CITY_Z + AVE_SPACING
	while z < CITY_Z - AVE_SPACING + 1.0:
		out.append(z)
		z += AVE_SPACING
	return out


static func in_park(x: float, z: float, margin: float = 0.0) -> bool:
	return PARK_RECT.grow(margin).has_point(Vector2(x, z))


## Intersection centres (y=0) outside the park. Ids are the indices into this array.
static func intersections() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for z: float in avenue_zs():
		for x: float in street_xs():
			if not in_park(x, z, 1.0):
				out.append(Vector3(x, 0.0, z))
	return out


## Avenue x-spans [x0, x1] for the closed traffic loops: avenues crossing the park are split
## so the U-turn sits on the street just outside it (8 m from the curb).
static func avenue_spans(z: float) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	if z + LANE_OFFSET + 2.0 > PARK_RECT.position.y and z - LANE_OFFSET - 2.0 < PARK_RECT.end.y:
		spans.append(Vector2(LANE_X0, PARK_RECT.position.x - STREET_WIDTH * 0.5))
		spans.append(Vector2(PARK_RECT.end.x + STREET_WIDTH * 0.5, LANE_X1))
	else:
		spans.append(Vector2(LANE_X0, LANE_X1))
	return spans


## Closed loops: +X on z+5, -X on z-5.
static func avenue_lanes() -> Array[PackedVector3Array]:
	var lanes: Array[PackedVector3Array] = []
	for z: float in avenue_zs():
		for s: Vector2 in avenue_spans(z):
			lanes.append(PackedVector3Array([Vector3(s.x, 0.0, z + LANE_OFFSET), Vector3(s.y, 0.0, z + LANE_OFFSET),
				Vector3(s.y, 0.0, z - LANE_OFFSET), Vector3(s.x, 0.0, z - LANE_OFFSET)]))
	return lanes

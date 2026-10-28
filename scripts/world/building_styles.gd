class_name BuildingStyles
extends RefCounted
## Per-building style assignment (iteration 3 contract). Loads data/buildings/styles.json, picks
## style / variant / seed from a position hash by district and enforces the neighbour rule:
## buildings whose XZ footprints touch or are within NEIGHBOUR_GAP m differ in (style, variant).

const STYLES_PATH: String = "res://data/buildings/styles.json"
const NEIGHBOUR_GAP: float = 2.0
const VARIANTS: int = 3
const STYLE_LANDMARK: int = 12
const STYLE_BRIDGE: int = 13
const STYLE_WAREHOUSE: int = 10
const CELL: float = 64.0
## Enemy base spots (kept in sync with World._build_bases).
const BASE_SPOTS: Array[Vector3] = [Vector3(-1100.0, 0.5, -30.0), Vector3(300.0, 0.5, 90.0), Vector3(900.0, 0.5, -150.0), Vector3(-500.0, 0.5, 330.0), Vector3(1200.0, 0.5, 450.0)]
const BASE_RADIUS: float = 70.0

var styles: Array[Dictionary] = []
var _entries: Array[Dictionary] = []
var _grid: Dictionary = {}  # Vector2i -> Array[int] (indices into _entries)


func _init() -> void:
	var f: FileAccess = FileAccess.open(STYLES_PATH, FileAccess.READ)
	if f == null:
		push_error("BuildingStyles: cannot open %s" % STYLES_PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary and (data as Dictionary).get("styles") is Array:
		for s: Variant in (data as Dictionary)["styles"]:
			styles.append(s as Dictionary)


## District from the footprint centre; `forced` ("landmark", "bridge") wins.
static func district_for(center: Vector3, forced: String = "") -> String:
	if forced != "":
		return forced
	for b: Vector3 in BASE_SPOTS:
		if Vector2(center.x - b.x, center.z - b.z).length() < BASE_RADIUS:
			return "base"
	if center.z < -CityGrid.CITY_Z + 130.0:
		return "waterfront"
	var d: float = Vector2(center.x, center.z).length()
	if d < 450.0:
		return "downtown"
	if d < 900.0:
		return "midtown"
	return "residential"


static func _hash01(p: Vector3, salt: int) -> float:
	var h: int = hash(Vector3i(roundi(p.x * 10.0), roundi(p.z * 10.0), roundi(p.y * 10.0) + salt * 7919))
	return float(h & 0xFFFFFF) / float(0x1000000)


func _ids_for(district: String, h: float) -> Array[int]:
	var fit: Array[int] = []
	var any: Array[int] = []
	for s: Dictionary in styles:
		if not (s.get("districts", []) as Array).has(district):
			continue
		any.append(int(s["id"]))
		if h >= float(s.get("min_h", 0)) and h <= float(s.get("max_h", 1000)):
			fit.append(int(s["id"]))
	return fit if not fit.is_empty() else any


func _near(box: AABB) -> Array[int]:
	var out: Array[int] = []
	var g: AABB = box.grow(NEIGHBOUR_GAP)
	for cx: int in range(floori(g.position.x / CELL), floori(g.end.x / CELL) + 1):
		for cz: int in range(floori(g.position.z / CELL), floori(g.end.z / CELL) + 1):
			for i: int in _grid.get(Vector2i(cx, cz), []):
				var o: AABB = _entries[i]["aabb"]
				if g.position.x <= o.end.x and g.end.x >= o.position.x and g.position.z <= o.end.z and g.end.z >= o.position.z and not out.has(i):
					out.append(i)
	return out


## Registers one building box (world space) and returns its entry:
## {id, pos, size, aabb, style, variant, seed, district, ground_type}.
func assign(box: AABB, forced_district: String = "") -> Dictionary:
	var c: Vector3 = box.get_center()
	var district: String = district_for(c, forced_district)
	var r: float = _hash01(c, 1)
	var seed_v: float = _hash01(c, 2)
	var ids: Array[int] = []
	if district == "landmark":
		ids = [STYLE_LANDMARK]
	elif district == "bridge":
		ids = [STYLE_BRIDGE]
	else:
		ids = _ids_for(district, box.size.y)
		if ids.is_empty():
			ids = [0]
		# Waterfront and base blocks are mostly industrial warehouses.
		if (district == "waterfront" or district == "base") and ids.has(STYLE_WAREHOUSE):
			ids.erase(STYLE_WAREHOUSE)
			var rest: Array[int] = ids.duplicate()
			ids = [STYLE_WAREHOUSE]
			if r >= 0.7:
				ids.push_front(rest[int(r * 997.0) % rest.size()] if not rest.is_empty() else STYLE_WAREHOUSE)
			ids.append_array(rest)
	var taken: Dictionary = {}
	for i: int in _near(box):
		taken[Vector2i(int(_entries[i]["style"]), int(_entries[i]["variant"]))] = true
	# Candidate order: hashed rotation over (style, variant) pairs; first free pair wins.
	var n: int = ids.size() * VARIANTS
	var start: int = int(r * 4093.0) % n
	if (district == "waterfront" or district == "base") and ids[0] == STYLE_WAREHOUSE:
		start = int(r * 4093.0) % VARIANTS  # prefer a warehouse variant first
	var pick: Vector2i = Vector2i(ids[0], 0)
	var found: bool = false
	for k: int in n:
		var j: int = (start + k) % n
		var cand: Vector2i = Vector2i(ids[int(float(j) / float(VARIANTS))], j % VARIANTS)
		if not taken.has(cand):
			pick = cand
			found = true
			break
	# Saturated neighbourhood (e.g. a bridge deck piece touching both towers): any free generic look.
	if not found:
		for k: int in 12 * VARIANTS:
			var j2: int = (start + k) % (12 * VARIANTS)
			var c2: Vector2i = Vector2i(int(float(j2) / float(VARIANTS)), j2 % VARIANTS)
			if not taken.has(c2):
				pick = c2
				break
	var gts: Array = styles[pick.x].get("ground_types", [0]) if pick.x < styles.size() else [0]
	var e: Dictionary = {
		"id": _entries.size(), "pos": c, "size": box.size, "aabb": box,
		"style": pick.x, "variant": pick.y, "seed": seed_v, "district": district,
		"ground_type": int(gts[int(seed_v * 7919.0) % gts.size()]),
	}
	var idx: int = _entries.size()
	_entries.append(e)
	for cx: int in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
		for cz: int in range(floori(box.position.z / CELL), floori(box.end.z / CELL) + 1):
			var key: Vector2i = Vector2i(cx, cz)
			if not _grid.has(key):
				_grid[key] = []
			(_grid[key] as Array).append(idx)
	return e


func get_building_styles() -> Array[Dictionary]:
	return _entries


## Number of footprint pairs within NEIGHBOUR_GAP sharing (style, variant); 0 when the rule holds.
func count_adjacent_identical() -> int:
	var n: int = 0
	for i: int in _entries.size():
		for j: int in _near(_entries[i]["aabb"]):
			if j > i and _entries[j]["style"] == _entries[i]["style"] and _entries[j]["variant"] == _entries[i]["variant"]:
				n += 1
	return n


func count_distinct_looks() -> int:
	var seen: Dictionary = {}
	for e: Dictionary in _entries:
		seen[Vector2i(int(e["style"]), int(e["variant"]))] = true
	return seen.size()

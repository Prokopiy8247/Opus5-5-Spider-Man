extends "res://qa/scenarios/qa_scenario.gd"
## One test lot per style id 0..13 and variant 0..2 (42 looks). Each lot is a standalone
## building box built with the contract vertex layout (UV in metres, tangents,
## CUSTOM0 = style/variant/seed/surface, CUSTOM1 = bay/floor/ground_h/ground_type) and the
## shared material res://shaders/building_material.tres.
## For every look: close view (3 m) and mid view (60 m), at day (13:00) and night (23:00)
## => 14 * 3 * 2 * 2 = 168 screenshots in qa/evidence/building_gallery/.

const STYLES: int = 14
const VARIANTS: int = 3
const MATERIAL_PATH: String = "res://shaders/building_material.tres"
const LOT_SPACING: float = 60.0
const STYLE_NAMES: Array[String] = [
	"red_brick_tenement", "tan_brick_prewar", "brownstone", "artdeco_limestone",
	"glass_bluegreen", "glass_dark_steel", "brutalist_concrete", "white_terracotta",
	"midcentury_ribbon", "steel_glass_spandrel", "industrial_warehouse",
	"mixed_podium_tower", "landmark_limestone", "bridge_masonry_steel",
]
## style -> ground_floor_type (contract: 0 storefront, 1 roll_shutter, 2 lobby_canopy,
## 3 stoop, 4 warehouse_dock, 5 glass_lobby)
const GROUND_TYPE: Array[int] = [0, 0, 3, 2, 5, 5, 1, 2, 0, 5, 4, 0, 5, 4]

var _root: Node3D
var _cam: Camera3D
var _mat: Material


func run() -> void:
	var w: Node = get_world()
	if w == null:
		fail("world missing")
		return
	await wait_player()
	# A clean gallery area far above the city so no city geometry is in frame.
	_root = Node3D.new()
	_root.name = "GalleryLots"
	add_child(_root)
	_root.global_position = Vector3(0.0, 900.0, 0.0)
	if ResourceLoader.exists(MATERIAL_PATH):
		_mat = load(MATERIAL_PATH) as Material
	else:
		fail("missing material " + MATERIAL_PATH)
	_cam = make_qa_camera(self)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -60.0, 0.0)
	light.light_energy = 1.0
	_root.add_child(light)

	var shots: int = 0
	var lots: int = 0
	for style: int in STYLES:
		for variant: int in VARIANTS:
			var centre: Vector3 = _root.global_position + Vector3(float(lots) * LOT_SPACING, 0.0, 0.0)
			var mi: MeshInstance3D = _make_lot(style, variant, centre)
			lots += 1
			var label: String = "s%02d_%s_v%d" % [style, STYLE_NAMES[style], variant]
			for lighting: Array in [["day", 13.0, 1.0, 0.0], ["night", 23.0, 0.08, 1.0]]:
				_set_lighting(w, light, float(lighting[1]), float(lighting[2]), float(lighting[3]))
				# close: 3 m from the ground floor; mid: 60 m, whole facade
				await place_cam(_cam, null, centre + Vector3(0.0, 2.0, 11.0),
						centre + Vector3(0.0, 2.5, 8.0), 0.2)
				await screenshot("%s_close_%s" % [label, lighting[0]])
				await place_cam(_cam, null, centre + Vector3(0.0, 18.0, 68.0),
						centre + Vector3(0.0, 16.0, 0.0), 0.2)
				await screenshot("%s_mid_%s" % [label, lighting[0]])
			shots += 4
			mi.queue_free()
			await frames(1)

	metrics["lots"] = lots
	metrics["styles"] = STYLES
	metrics["variants"] = VARIANTS
	metrics["expected_shots"] = shots
	metrics["style_names"] = STYLE_NAMES
	metrics.merge(perf_snapshot(), false)
	if lots != STYLES * VARIANTS:
		fail("%d lots, expected %d" % [lots, STYLES * VARIANTS])
	if screenshots.size() != shots and DisplayServer.get_name() != "headless":
		fail("%d screenshots, expected %d" % [screenshots.size(), shots])


func _set_lighting(w: Node, light: DirectionalLight3D, hour: float, energy: float, night: float) -> void:
	if w.has_method("set_time_of_day"):
		w.call("set_time_of_day", hour)
	light.light_energy = energy
	RenderingServer.global_shader_parameter_set(&"city_night", night)


## Builds one test box (8 x 8 m footprint, 24 m tall) with the contract vertex layout.
func _make_lot(style: int, variant: int, centre: Vector3) -> MeshInstance3D:
	var size := Vector3(8.0, 24.0, 8.0)
	var seed_v: float = fmod(float(style) * 0.137 + float(variant) * 0.41, 1.0)
	var bay: float = 2.7
	var floor_h: float = 3.75
	var ground_h: float = 4.5
	var gtype: float = float(GROUND_TYPE[style])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	# four walls + roof, UV in metres, v from ground level 0
	var half: Vector2 = Vector2(size.x, size.z) * 0.5
	var corners: Array[Vector2] = [
		Vector2(-half.x, half.y), Vector2(half.x, half.y),
		Vector2(half.x, -half.y), Vector2(-half.x, -half.y),
	]
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var dir: Vector2 = (b - a).normalized()
		var len_m: float = a.distance_to(b)
		var n := Vector3(dir.y, 0.0, -dir.x)
		var tan := Vector3(dir.x, 0.0, dir.y)
		var p0 := Vector3(a.x, 0.0, a.y)
		var p1 := Vector3(b.x, 0.0, b.y)
		var up := Vector3(0.0, size.y, 0.0)
		_quad(st, [p0, p1, p1 + up, p0 + up],
			[Vector2(0.0, 0.0), Vector2(len_m, 0.0), Vector2(len_m, size.y), Vector2(0.0, size.y)],
			n, tan, style, variant, seed_v, 0.0, bay, floor_h, ground_h, gtype)
	var ry: float = size.y
	_quad(st, [
			Vector3(-half.x, ry, -half.y), Vector3(half.x, ry, -half.y),
			Vector3(half.x, ry, half.y), Vector3(-half.x, ry, half.y)],
		[Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)],
		Vector3.UP, Vector3.RIGHT, style, variant, seed_v, 1.0, bay, floor_h, ground_h, gtype)
	var mesh: ArrayMesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Lot_s%02d_v%d" % [style, variant]
	mi.mesh = mesh
	if _mat != null:
		mi.material_override = _mat
	_root.add_child(mi)
	mi.global_position = centre
	return mi


func _quad(st: SurfaceTool, pts: Array, uvs: Array, n: Vector3, tan: Vector3,
		style: int, variant: int, seed_v: float, surface: float,
		bay: float, floor_h: float, ground_h: float, gtype: float) -> void:
	var c0 := Color(float(style), float(variant), seed_v, surface)
	var c1 := Color(bay, floor_h, ground_h, gtype)
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_tangent(Plane(tan, 1.0))
		st.set_uv(uvs[idx] as Vector2)
		st.set_custom(0, c0)
		st.set_custom(1, c1)
		st.add_vertex(pts[idx] as Vector3)

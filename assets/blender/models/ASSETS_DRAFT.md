# Iteration 2 asset draft (Front) — text for docs/ASSETS.md

Generators live in `assets/blender/models/<name>.py`; each has `build()` and `GLB_PATH`, and runs
with `W:\Blender\blender.exe -b --python assets/blender/models/<name>.py`. One mesh per variant,
named `<name>_v1/_v2/_v3` inside a single glb, pivot at the ground centre, 1 unit = 1 m,
`export_yup=True`, at most 2 materials, colour variation in the `Col` vertex-colour layer.
Triangle counts below are expected values from the builder geometry (bevels included); the real
numbers are printed by `_kit.run()` when the lead runs each script, and every row stays inside the
contract limit (props 150–2000, trees LOD0 ≤6000 / LOD1 ≤2000 / billboard ≤64).

Status: generators static-checked only (`python assets/blender/models/check_kit.py` → 49/49 OK,
`compile_all.py` → 58/58 files parse). Not yet run in Blender, so no glb and no screenshots.

## Props (res://assets/models/props/)

| Name | Variants | Expected tris | Size (m, x/y/z) | Purpose |
|---|---|---|---|---|
| lamp_cobra | 3 (single, tall, twin arm) | 600–900 | 1.0 × 5.2 × 9.6 | Avenue street lighting; `Emit_Lamp` lens drives night glow, lamp head is an anchor point |
| lamp_lantern | 2 | 500–800 | 0.6 × 0.6 × 4.3 | Side street / park path lighting, ornamental post with `Emit_` lantern glass |
| traffic_light_mast | 2 | 900–1400 | 0.5 × 6.5 × 7.2 | Avenue intersection signal on a mast arm; `Emit_` lenses per aspect, arm is an anchor |
| traffic_light_pole | 2 | 500–900 | 0.5 × 0.5 × 4.0 | Side-street pole signal, same `Emit_` lens naming |
| bench | 3 (backed, backless, long) | 700–1100 | 1.8–2.4 × 0.6 × 0.9 | Sidewalk and park seating, cast-iron frame plus wood slats |
| trash_can | 2 (wire basket, lidded) | 450–800 | 0.6 × 0.6 × 1.14 | Litter baskets at corners and along the kerb |
| dumpster | 3 (closed, lid open, small) | 700–1100 | 1.4–1.9 × 1.1–1.3 × 1.4 | Construction and alley dressing, solid box collider |
| phone_booth | 2 (open kiosk, full booth) | 500–900 | 1.1 × 0.8 × 2.3 | Sidewalk phone kiosk, blank sign panel (no logos) |
| hydrant | 3 (bronze, red, short) | 650–950 | 0.6 × 0.6 × 0.9 | Kerbside hydrant, cylinder collider |
| mailbox | 3 (blue, relay, wide) | 600–900 | 0.66–0.86 × 0.6 × 1.4 | Corner mailbox, rounded top and pull hopper |
| news_box | 3 (single, double, low) | 500–900 | 0.45–0.95 × 0.4 × 1.2 | Newspaper vending boxes clustered near corners |
| bus_shelter | 2 (long, short with ad panel) | 900–1500 | 3.0–4.4 × 1.9 × 2.7 | Avenue bus stop, glazed back, bench inside, box collider |
| bike_rack | 3 (hoop pair, wave, single) | 400–800 | 1.2–2.2 × 0.2 × 0.95 | Sidewalk bike parking, thin cylinder colliders |
| bollard | 3 (steel, ornamental, granite) | 350–700 | 0.4 × 0.4 × 1.0 | Plaza and park entrance protection |
| parking_meter | 3 (single, twin, pay station) | 450–800 | 0.3–0.4 × 0.3 × 1.4–1.7 | Avenue kerb meters at a 6 m spacing |
| sign_street | 3 (blade, crossed, with plate) | 400–700 | 1.1 × 1.1 × 2.8 | Street-name blades at intersection corners |
| sign_stop | 3 (plain, all-way, leaning) | 400–700 | 0.85 × 0.85 × 2.4 | Side-street stop control |
| cone | 3 (70 cm, 45 cm, weighted) | 350–650 | 0.36–0.4 × 0.4 × 0.75 | Construction zones, no collider |
| barrier | 3 (A-frame, water, steel fence) | 800–1400 | 2.1–2.2 × 0.6 × 1.1 | Work-zone barricades, box collider |
| scaffold_shed | 2 (8 m, 6 m) | 2500–4000 | 6–8 × 2.9 × 4.0 | NYC sidewalk construction bridge; `Emit_Shed_Deck` under-deck lamp strip |
| street_tree | 3 (summer, autumn, young) | LOD0 2500–4500, LOD1 300–600, bb 8 | 3.4 × 3.4 × 4.6–6.2 | Sidewalk pit tree; `Leaves` uses foliage.gdshader, canopy is an anchor |
| tree_grate | 3 (square, round, with guard) | 600–1100 | 1.5–1.6 × 1.5 × 0.05–0.66 | Flat grate around street trees, no collider |
| planter | 3 (square, round, long) | 900–1600 | 0.95–1.8 × 0.7–0.95 × 0.8 | Concrete planters with shrub masses, box collider |
| steam_stack | 3 (tall, short, with cones) | 700–1300 | 0.9–1.8 × 0.9–1.8 × 1.6–2.6 | Con-Ed style steam stack over a manhole, vapour VFX anchor |
| food_cart | 2 (hot-dog, coffee) | 1400–2200 | 2.0 × 1.4 × 2.2 | Street vendor cart, umbrella canopy, box collider |
| newsstand | 2 (large, small) | 1300–2000 | 2.0–2.6 × 1.7–2.6 × 2.9 | Corner kiosk, blank panels, box collider |
| parked_car_sedan | 3 paints | 1100–1700 | 1.82 × 4.6 × 1.5 | Avenue kerb parking, static body |
| parked_car_hatch | 3 paints | 1000–1600 | 1.74 × 3.9 × 1.5 | Side-street kerb parking |
| parked_car_van | 3 paints | 1200–1900 | 1.98 × 5.2 × 2.3 | Delivery van at loading zones |

## Road kit (res://assets/models/road/)

| Name | Variants | Expected tris | Size (m) | Purpose |
|---|---|---|---|---|
| sidewalk_8m | 2 (plain, with panel + tree pit) | 400–800 | 3.5 × 8.0 × 0.3 | Straight sidewalk tile, walk top at y=0.15, 0.15 m granite curb on the street edge |
| sidewalk_corner | 2 (plain, with ramp notch) | 900–1500 | 7.5 × 7.5 × 0.3 | L-shaped intersection corner with a radiused curb |
| curb_ramp | 2 (1.6 m, 2.4 m diagonal) | 300–600 | 1.6–2.4 × 1.8 × 0.16 | ADA ramp from sidewalk 0.15 down to road 0, tactile panel |
| crosswalk_stripe | 3 (clean, worn, narrow) | 20–120 | 0.4–0.6 × 3.0 × 0.012 | Crosswalk band / stop bar, sits on the asphalt, no collider |
| manhole | 3 (radial, waffle, square box) | 500–900 | 0.8–0.9 × 0.6–0.9 × 0.05 | Flush road cover, no collider |
| steam_vent | 3 (subway grate, round, strip) | 400–800 | 1.2–2.0 × 0.5–0.9 × 0.05 | Flush vent grating, steam VFX anchor |

## Park kit (res://assets/models/park/)

| Name | Variants | Expected tris | Size (m) | Purpose |
|---|---|---|---|---|
| tree_oak | 3 (summer, autumn, old wide) | LOD0 3500–5500, LOD1 400–700, bb 8 | 6.5 × 6.5 × 7.4–9.0 | Main park canopy tree; tapered trunk with root flare, 7–8 branches, clustered leaf masses; canopy is a swing anchor |
| tree_poplar | 3 (summer, autumn, tall) | LOD0 2500–4000, LOD1 300–600, bb 8 | 3.2 × 3.2 × 10–13 | Tall columnar tree lining park edges |
| tree_conifer | 3 (spruce, blue fir, young) | LOD0 2000–3500, LOD1 300–600, bb 8 | 3.8 × 3.8 × 5.5–9.5 | Evergreen groups; needle tiers keep winter colour |
| tree_blossom | 3 (pink, white, autumn) | LOD0 3000–5000, LOD1 300–600, bb 8 | 5.0 × 5.0 × 5.0–5.4 | Flowering cherry near the plaza and paths |
| tree_maple | 3 (green, scarlet, orange) | LOD0 3500–5500, LOD1 400–700, bb 8 | 5.6 × 5.6 × 6.8–7.2 | Autumn colour accent tree with forked branches |
| shrub | 3 (green, autumn, flowering) | 1200–2200 | 1.6–2.0 × 1.6–2.0 × 0.9–1.3 | Lawn and path-edge bushes, no collider |
| hedge | 3 (1.0 m, 0.6 m, 1.6 m) | 900–1800 | 2.0 × 0.7–0.9 × 0.7–1.7 | Clipped hedge segments framing paths and the plaza, box collider |
| rock | 3 (boulder, slab, cluster) | 1200–2400 | 1.8–2.4 × 1.8–2.0 × 0.5–1.4 | Schist outcrops on the lawn, box/cylinder collider |
| fountain | 2 (round, octagonal tiered) | 2200–3400 | 6.4 × 6.4 × 2.6 | Plaza centrepiece, water surface discs use the water material slot |
| bridge | 2 (stone arch 8 m, timber 7 m) | 2500–3800 | 8–9 × 2.0–2.8 × 2.4 | Pond crossing on the path loop, walkable collider |
| picnic_table | 3 (1.8 m, 2.4 m, round) | 1100–2000 | 1.8–2.6 × 1.5–2.6 × 0.8 | Lawn seating clusters |
| playground | 2 (swings + slide, climber) | 3000–4400 | 7.5 × 4.5 × 2.6 | Playground area; separate parts, box colliders only on frames |
| statue | 3 (figure, equestrian, obelisk) | 1600–2800 | 1.6–2.4 × 1.6–2.4 × 2.5–4.8 | Path intersection monument, no logos or real names |
| park_wall | 3 (solid, railing, entrance pier) | 1500–2800 | 4.0 × 0.6–0.8 × 1.2–2.5 | Park perimeter wall segments and entrance piers |

## Shared files

| File | Purpose |
|---|---|
| `_kit.py` | Bevel/material helpers, `Builder` (box/cyl/pipe/sphere/blob/quad/jitter), `variants()`, tree helpers (`trunk`, `branches`, `leaf_masses`, `billboard`, `tree_sets`), export with `export_yup=True` and tri/material validation in `run()` |
| `_car.py` | Shared parked-car body (hood/cabin/trunk, glass, lights, wheels) for the three car props |
| `_humanoid.py` | Humanoid rig, 17 base clips plus `ko_back/ko_front/ko_side/ko_heavy`; `death` stays as a copy of `ko_back` |
| `check_kit.py` | Static contract checker for all 49 generators (build(), GLB_PATH, variants, materials, LOD sets) |
| `compile_all.py` | Syntax check of every generator without Blender |
| `shaders/foliage.gdshader` | Foliage wind shader (`wind_strength`, `night_factor`), used by every `Leaves` material |

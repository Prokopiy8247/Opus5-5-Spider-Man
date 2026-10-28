"""Park layout + Poisson-disc (Bridson) tree placement. Mirrors ParkBuilder (park_builder.gd).
Writes data/props/park_trees.json, which ParkBuilder loads, so the game uses exactly this set.
Usage: python scripts/world/park/sim_poisson.py   (exit 0 = all checks pass)"""
import json, math, os, random, sys

# CityGrid.PARK_RECT (x0, z0, x1, z1)
X0, Z0, X1, Z1 = -232.0, 103.0, 202.0, 317.0
CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2          # (-15, 210)
SEED = 7
R_MIN = 7.0          # Poisson-disc minimum spacing (m)
EDGE = 4.0           # keep clear of the wall
PATH_CLEAR = 2.0     # extra clearance beyond the path half-width (trunk + canopy overhang)
RING_A, RING_B, RING_W = 180.0, 80.0, 5.0
DIAG_W = 4.0
SPOKE_W = 4.0
PLAZA_R = 18.0
POND = (-112.0, 210.0, 30.0, 17.0)   # cx, cz, semi-x, semi-z
PLAYGROUND = (110.0, 160.0, 7.0, 6.0)  # cx, cz, half-x, half-z (+ clearance)
SPECIES = [("tree_oak", 0.30), ("tree_poplar", 0.15), ("tree_conifer", 0.15), ("tree_blossom", 0.15), ("tree_maple", 0.25)]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "data", "props", "park_trees.json")


def paths():
    """Straight path segments ((x0,z0),(x1,z1),width). The ring is handled analytically."""
    m = 3.0
    segs = [((X0 + m, Z0 + m), (X1 - m, Z1 - m), DIAG_W), ((X0 + m, Z1 - m), (X1 - m, Z0 + m), DIAG_W)]
    segs.append(((CX, Z0), (CX, CZ - PLAZA_R), SPOKE_W))          # south spoke
    segs.append(((CX, CZ + PLAZA_R), (CX, Z1), SPOKE_W))          # north spoke
    segs.append(((X0, CZ), (CX - PLAZA_R, CZ), SPOKE_W))          # west spoke (crosses the pond: bridge)
    segs.append(((CX + PLAZA_R, CZ), (X1, CZ), SPOKE_W))          # east spoke
    return segs


def seg_dist(p, a, b):
    ax, az = b[0] - a[0], b[1] - a[1]
    l2 = ax * ax + az * az
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * az) / l2))
    return math.hypot(p[0] - a[0] - ax * t, p[1] - a[1] - az * t)


RING_PTS = [(CX + RING_A * math.cos(i * math.tau / 720), CZ + RING_B * math.sin(i * math.tau / 720)) for i in range(720)]


def ring_dist(p):
    """Distance from p to the ring centre line (ellipse sampled every 0.5 degrees, < 0.8 m chord)."""
    return min(math.hypot(p[0] - q[0], p[1] - q[1]) for q in RING_PTS)


def on_pond(p, extra=0.0):
    cx, cz, a, b = POND
    return ((p[0] - cx) / (a + extra)) ** 2 + ((p[1] - cz) / (b + extra)) ** 2 <= 1.0


def blocked(p):
    if not (X0 + EDGE <= p[0] <= X1 - EDGE and Z0 + EDGE <= p[1] <= Z1 - EDGE):
        return True
    if math.hypot(p[0] - CX, p[1] - CZ) <= PLAZA_R + PATH_CLEAR + 1.0:
        return True
    if on_pond(p, PATH_CLEAR + 1.0):
        return True
    if abs(p[0] - PLAYGROUND[0]) <= PLAYGROUND[2] + 3 and abs(p[1] - PLAYGROUND[1]) <= PLAYGROUND[3] + 3:
        return True
    if ring_dist(p) <= RING_W / 2 + PATH_CLEAR:
        return True
    for a, b, w in paths():
        if seg_dist(p, a, b) <= w / 2 + PATH_CLEAR:
            return True
    return False


def bridson(rng, r, k=30):
    cell = r / math.sqrt(2)
    gw, gh = int((X1 - X0) / cell) + 1, int((Z1 - Z0) / cell) + 1
    grid = [[-1] * gh for _ in range(gw)]
    pts, active = [], []

    def gi(p):
        return int((p[0] - X0) / cell), int((p[1] - Z0) / cell)

    def fits(p):
        if not (X0 <= p[0] < X1 and Z0 <= p[1] < Z1):
            return False
        i, j = gi(p)
        for a in range(max(0, i - 2), min(gw, i + 3)):
            for b in range(max(0, j - 2), min(gh, j + 3)):
                q = grid[a][b]
                if q >= 0 and math.dist(p, pts[q]) < r:
                    return False
        return True

    def add(p):
        pts.append(p)
        i, j = gi(p)
        grid[i][j] = len(pts) - 1
        active.append(len(pts) - 1)

    add((X0 + 10.0, Z0 + 20.0))
    while active:
        idx = active[rng.randrange(len(active))]
        base = pts[idx]
        for _ in range(k):
            a = rng.random() * math.tau
            d = r * (1.0 + rng.random())
            p = (base[0] + math.cos(a) * d, base[1] + math.sin(a) * d)
            if fits(p):
                add(p)
                break
        else:
            active.remove(idx)
    return pts


def main():
    rng = random.Random(SEED)
    raw = bridson(rng, R_MIN)
    trees = [p for p in raw if not blocked(p)]
    tot = sum(w for _, w in SPECIES)
    out = []
    for p in trees:
        u, s = rng.random() * tot, 0
        for si, (_, w) in enumerate(SPECIES):
            u -= w
            if u <= 0:
                s = si
                break
        out.append([round(p[0], 3), round(p[1], 3), s, round(rng.random() * math.tau, 3), round(rng.uniform(0.85, 1.2), 3)])
    # Checks
    min_sp = min(math.dist(a[:2], b[:2]) for i, a in enumerate(out) for b in out[i + 1:]) if len(out) > 1 else 0.0
    on_paths = sum(1 for t in out if blocked((t[0], t[1])))
    in_pond = sum(1 for t in out if on_pond((t[0], t[1])))
    in_plaza = sum(1 for t in out if math.hypot(t[0] - CX, t[1] - CZ) <= PLAZA_R)
    counts = {SPECIES[i][0]: sum(1 for t in out if t[2] == i) for i in range(len(SPECIES))}
    print(f"poisson candidates = {len(raw)}, trees kept = {len(out)}")
    print(f"min spacing = {min_sp:.2f} m (r = {R_MIN})")
    print(f"trees on paths/clearance = {on_paths}, in pond = {in_pond}, in plaza = {in_plaza}")
    print("species:", counts)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "seed": SEED, "min_spacing": R_MIN, "species": [s for s, _ in SPECIES], "trees": out}, f, separators=(",", ":"))
    print("wrote", os.path.normpath(OUT))
    ok = {"count_500_plus": len(out) >= 500, "min_spacing_ok": min_sp >= R_MIN - 1e-6,
          "none_on_paths": on_paths == 0, "none_in_pond": in_pond == 0, "none_in_plaza": in_plaza == 0}
    for k, v in ok.items():
        print(("PASS " if v else "FAIL ") + k)
    print("RESULT", "PASS" if all(ok.values()) else "FAIL")
    return 0 if all(ok.values()) else 1


if __name__ == "__main__":
    sys.exit(main())

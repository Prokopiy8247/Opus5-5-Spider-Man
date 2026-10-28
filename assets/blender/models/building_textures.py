"""Iteration 3 building texture bake (Front, T1).

Run:  W:\\Blender\\blender.exe -b --python assets/blender/models/building_textures.py -- [--only 0,4,10,16,20,24] [--size 2048] [--verify]
Also runs with plain Python + numpy + Pillow (same code path, no bpy) for quick checks.

Each layer is a height/material field computed with numpy (the same "procedural bake to PNG"
idea as _kit.py, but at 2048 px and with PBR outputs). Outputs per layer:
  assets/textures/buildings/<name>/{albedo,normal,orm,emission}.png
Then packs assets/textures/buildings/arrays/*_array.png (layers stacked vertically, 32 layers)
and writes the .import files (Texture2DArray, BC7 / VRAM compressed, mipmaps).
Facade tile = 2 bays x 2 floors (5.4 x 7.5 m). Ground tile = 2 bays x ground floor. Roof = 8 x 8 m.
Albedo is close to neutral per style; the shader applies the variant tint palettes.
"""
import os
import sys

import numpy as np

try:
    import bpy  # noqa: F401
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "buildings")
LAYERS = 32
FACADE_W, FACADE_H = 5.4, 7.5

STYLES = ["red_brick_tenement", "tan_brick_prewar", "brownstone", "artdeco_limestone",
          "glass_bluegreen", "glass_dark_steel", "brutalist_concrete", "white_terracotta",
          "midcentury_ribbon", "steel_glass_spandrel", "industrial_warehouse",
          "mixed_podium_tower", "landmark_limestone", "bridge_masonry_steel"]
GROUND = ["ground_storefront", "ground_roll_shutter", "ground_lobby_canopy", "ground_stoop",
          "ground_warehouse_dock", "ground_glass_lobby"]
ROOFS = ["roof_gravel", "roof_tar", "roof_concrete", "roof_green", "roof_metal"]


def layer_names():
    names = {i: s for i, s in enumerate(STYLES)}
    for i, g in enumerate(GROUND):
        names[16 + i] = g
    for i, r in enumerate(ROOFS):
        names[24 + i] = r
    return names


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


# ------------------------------------------------------------------ canvas
class Canvas:
    """Metre-space canvas. h = height (m, + is out of the wall), alb sRGB, rough, metal,
    win/curt/frame masks. y grows up (row 0 is the top of the image when saved)."""

    def __init__(self, wm, hm, res, rng):
        self.wm, self.hm, self.res = wm, hm, res
        self.ppm = res / max(wm, hm)
        self.W = res
        self.H = res
        xs = (np.arange(self.W) + 0.5) / self.W * wm
        ys = (np.arange(self.H) + 0.5) / self.H * hm
        self.x, self.y = np.meshgrid(xs, ys[::-1])
        self.rng = rng
        z = np.zeros((self.H, self.W), np.float32)
        self.h = z.copy()
        self.alb = np.zeros((self.H, self.W, 3), np.float32)
        self.rough = z + 0.85
        self.metal = z.copy()
        self.ao = z + 1.0
        self.win = z.copy()
        self.curt = z.copy()
        self.frame = z.copy()

    def rect(self, x0, y0, x1, y1):
        return (self.x >= x0) & (self.x < x1) & (self.y >= y0) & (self.y < y1)

    def paint(self, m, col, h=None, rough=None, metal=None):
        self.alb[m] = col
        if h is not None:
            self.h[m] = h
        if rough is not None:
            self.rough[m] = rough
        if metal is not None:
            self.metal[m] = metal


def vnoise(x, y, scale, seed):
    """Tileable-enough value noise (period = canvas) for tint / grime."""
    r = np.random.default_rng(seed)
    g = r.random((64, 64)).astype(np.float32)
    fx, fy = x * scale, y * scale
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[iy % 64, ix % 64]
    b = g[iy % 64, (ix + 1) % 64]
    c = g[(iy + 1) % 64, ix % 64]
    d = g[(iy + 1) % 64, (ix + 1) % 64]
    return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty


def fbm(x, y, scale, seed, octaves=4):
    s, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + vnoise(x, y, scale * (2 ** o), seed + o) * amp
        tot += amp
        amp *= 0.5
    return s / tot


# ------------------------------------------------------------------ wall materials
def brick(cv, base, mortar, bond_header=6, var=0.12, seed=1):
    course = 0.0677  # 57 mm + 10 mm joint
    blen = 0.204
    row = np.floor(cv.y / course)
    off = np.where(row % 2 == 1, blen * 0.5, 0.0)
    header = (row % bond_header) == 0
    L = np.where(header, blen * 0.5, blen)
    bx = (cv.x + off) / L
    bid = np.floor(bx) + row * 131.0
    fx = (bx - np.floor(bx)) * L
    fy = cv.y - row * course
    j = 0.010
    joint = (fx < j) | (fy < j)
    rnd = np.modf(np.sin(bid * 12.9898) * 43758.5453)[0]
    rnd = np.abs(rnd)
    tint = 1.0 + (rnd[..., None] - 0.5) * 2 * var
    burnt = (rnd > 0.93)[..., None]
    col = base * tint * np.where(burnt, 0.7, 1.0)
    col = col * (0.92 + 0.16 * fbm(cv.x, cv.y, 6.0, seed)[..., None])
    cv.alb[:] = np.where(joint[..., None], mortar, col)
    cv.h[:] = np.where(joint, -0.006, 0.0) + 0.002 * rnd
    cv.rough[:] = np.where(joint, 0.95, 0.82)


def ashlar(cv, base, bw=1.2, bh=0.6, joint=0.008, var=0.06, seed=2):
    row = np.floor(cv.y / bh)
    off = np.where(row % 2 == 1, bw * 0.5, 0.0)
    bx = (cv.x + off) / bw
    bid = np.floor(bx) + row * 57.0
    fx = (bx - np.floor(bx)) * bw
    fy = cv.y - row * bh
    jm = (fx < joint) | (fy < joint)
    rnd = np.abs(np.modf(np.sin(bid * 78.233) * 43758.5453)[0])
    col = base * (1.0 + (rnd[..., None] - 0.5) * 2 * var)
    col = col * (0.94 + 0.12 * fbm(cv.x, cv.y, 3.0, seed)[..., None])
    cv.alb[:] = np.where(jm[..., None], base * 0.72, col)
    cv.h[:] = np.where(jm, -0.008, 0.0)
    cv.rough[:] = 0.78


def concrete(cv, base, board=0.125, tie=0.6, seed=3, panel=None):
    n = fbm(cv.x, cv.y, 4.0, seed)
    col = base * (0.88 + 0.22 * n[..., None])
    by = np.floor(cv.y / board)
    rnd = np.abs(np.modf(np.sin(by * 4.1 + np.floor(cv.x / 2.4) * 9.3) * 43758.5)[0])
    col = col * (0.96 + 0.08 * rnd[..., None])
    line = (cv.y - by * board) < 0.004
    tx = (cv.x % tie) - tie * 0.5
    ty = (cv.y % tie) - tie * 0.5
    hole = tx * tx + ty * ty < 0.018 ** 2
    cv.alb[:] = col
    cv.alb[line] *= 0.85
    cv.alb[hole] = base * 0.35
    cv.h[:] = np.where(line, -0.002, 0.0) + np.where(hole, -0.015, 0.0)
    if panel is not None:
        seam = ((cv.x % panel[0]) < 0.015) | ((cv.y % panel[1]) < 0.015)
        cv.alb[seam] = base * 0.45
        cv.h[seam] = -0.012
    cv.rough[:] = 0.9


def terracotta(cv, base, seed=4):
    ashlar(cv, base, bw=0.45, bh=0.3, joint=0.005, var=0.04, seed=seed)
    cv.rough[:] = 0.45  # glazed


def metal_panel(cv, base, pw=1.35, ph=1.875, seed=5):
    cv.alb[:] = base * (0.95 + 0.1 * fbm(cv.x, cv.y, 2.0, seed)[..., None])
    seam = ((cv.x % pw) < 0.012) | ((cv.y % ph) < 0.012)
    cv.alb[seam] = base * 0.4
    cv.h[:] = np.where(seam, -0.01, 0.0)
    cv.rough[:] = 0.4
    cv.metal[:] = 0.85


# ------------------------------------------------------------------ windows and trim
def window(cv, cx, y0, w, hgt, frame_col, reveal=0.15, frame=0.06, mull=1, transom=True,
           sill=True, lintel=True, sill_col=None, panes=(1, 1), ac=False, streak=True):
    """Recessed window centred at cx. Reveal is dark (AO), frame raised, glass mask -> win."""
    x0, x1, y1 = cx - w / 2, cx + w / 2, y0 + hgt
    opening = cv.rect(x0, y0, x1, y1)
    cv.h[opening] = -reveal
    cv.alb[opening] = frame_col * 0.5
    g = cv.rect(x0 + frame, y0 + frame, x1 - frame, y1 - frame)
    fm = opening & ~g
    cv.paint(fm, frame_col, h=-reveal + 0.04, rough=0.5)
    cv.frame[fm] = 1.0
    cv.paint(g, np.array([0.05, 0.065, 0.08], np.float32), h=-reveal, rough=0.06, metal=0.2)
    cv.win[g] = 1.0
    # mullions / muntins
    gw, gh = w - 2 * frame, hgt - 2 * frame
    nx, ny = max(mull + 1, panes[0]), panes[1] + (1 if transom else 0)
    bar = 0.035 if panes[0] > 2 else 0.05
    for i in range(1, nx):
        m = g & cv.rect(x0 + frame + gw * i / nx - bar / 2, y0, x0 + frame + gw * i / nx + bar / 2, y1)
        cv.paint(m, frame_col, h=-reveal + 0.03, rough=0.5)
        cv.win[m] = 0.0
        cv.frame[m] = 1.0
    for j in range(1, ny + 1 if transom else ny):
        yy = y0 + frame + gh * (0.72 if (transom and j == ny) else j / max(ny, 1))
        m = g & cv.rect(x0, yy - bar / 2, x1, yy + bar / 2)
        cv.paint(m, frame_col, h=-reveal + 0.03, rough=0.5)
        cv.win[m] = 0.0
        cv.frame[m] = 1.0
    # curtain / blind mask: pseudo random per window, lower part of the glass
    r = abs(np.sin(cx * 91.7 + y0 * 13.1)) % 1.0
    if r > 0.45:
        top = y1 - frame - gh * (0.15 + 0.6 * ((r * 7.0) % 1.0))
        cv.curt[g & (cv.y > top)] = 1.0
    # baked AO: darken reveal sides and the frame near the top of the opening
    d = np.minimum(np.minimum(cv.x - x0, x1 - cv.x), y1 - cv.y)
    cv.ao[opening] *= np.clip(0.45 + d[opening] / 0.25, 0.45, 1.0)
    sc = frame_col if sill_col is None else sill_col
    if sill:
        s = cv.rect(x0 - 0.08, y0 - 0.09, x1 + 0.08, y0)
        cv.paint(s, sc, h=0.045, rough=0.7)
        cv.ao[cv.rect(x0 - 0.08, y0 - 0.14, x1 + 0.08, y0 - 0.09)] *= 0.6
    if lintel:
        s = cv.rect(x0 - 0.06, y1, x1 + 0.06, y1 + 0.16)
        cv.paint(s, sc, h=0.025, rough=0.75)
    if streak:
        n = fbm(cv.x, cv.y, 9.0, int(cx * 10))
        st = cv.rect(x0 - 0.05, y0 - 1.6, x1 + 0.05, y0 - 0.09)
        k = np.clip((cv.y - (y0 - 1.6)) / 1.5, 0, 1) * (0.3 + 0.7 * n)
        cv.alb[st] *= (1.0 - 0.35 * k[st])[..., None]
    if ac:
        a = cv.rect(cx - 0.33, y0 + 0.02, cx + 0.33, y0 + 0.42)
        cv.paint(a, np.array([0.62, 0.62, 0.6], np.float32), h=0.12, rough=0.6, metal=0.4)
        cv.win[a] = 0.0
        grill = a & ((np.floor(cv.y / 0.03) % 2) == 0) & (cv.x > cx - 0.28) & (cv.x < cx + 0.05)
        cv.alb[grill] *= 0.55
        cv.ao[cv.rect(cx - 0.33, y0 - 0.5, cx + 0.33, y0 + 0.02)] *= 0.75


def band(cv, y0, y1, col, h=0.05, rough=0.75):
    m = cv.rect(-1, y0, 99, y1)
    cv.paint(m, col, h=h, rough=rough)
    cv.frame[m] = 0.0
    cv.ao[cv.rect(-1, y0 - 0.12, 99, y0)] *= 0.7


def patches(cv, col, n, seed):
    r = np.random.default_rng(seed)
    for _ in range(n):
        x, y = r.random() * cv.wm, r.random() * cv.hm
        w, hh = 0.3 + r.random() * 0.8, 0.2 + r.random() * 0.5
        m = cv.rect(x, y, x + w, y + hh) & (cv.win == 0) & (cv.frame == 0)
        cv.alb[m] = cv.alb[m] * 0.5 + col * 0.5


def curtain_wall(cv, glass, mull, mw=1.35, spandrel=None, cap=0.06):
    """Full-height glass: win everywhere except mullions and spandrels."""
    cv.alb[:] = glass
    cv.rough[:] = 0.05
    cv.metal[:] = 0.3
    cv.h[:] = -0.05
    cv.win[:] = 1.0
    v = (cv.x % mw) < cap
    m = v
    if spandrel is not None:
        fl = cv.y % (FACADE_H / 2)
        sp = fl < spandrel
        cv.alb[sp] = glass * 0.6 + mull * 0.4
        cv.rough[sp] = 0.25
        cv.win[sp] = 0.0
        cv.h[sp] = -0.03
        m = m | ((fl > spandrel) & (fl < spandrel + cap))
    cv.paint(m, mull, h=0.03, rough=0.35, metal=0.9)
    cv.win[m] = 0.0
    cv.frame[m] = 1.0
    cv.ao[v] *= 0.9
    r = np.abs(np.sin(np.floor(cv.x / mw) * 7.7 + np.floor(cv.y / (FACADE_H / 2)) * 3.3))
    cv.curt[(cv.win > 0) & (r > 0.6)] = 1.0
    cv.alb[cv.win > 0] *= (0.85 + 0.3 * r[cv.win > 0])[..., None]


# ------------------------------------------------------------------ layer builders
C = hexc
BAYX = (1.35, 4.05)          # window centres of the 2 bays
FLY = (0.0, 3.75)            # floor bottoms of the 2 floors


def punched(cv, frame_col, w=1.2, h=1.8, sill_h=0.9, ac_seed=0, **kw):
    r = np.random.default_rng(ac_seed)
    for fy in FLY:
        for bx in BAYX:
            window(cv, bx, fy + sill_h, w, h, frame_col, ac=bool(ac_seed and r.random() < 0.3), **kw)


def f_red_brick(cv):
    brick(cv, C("#8a3b2a"), C("#b9ad9c"), seed=11)
    patches(cv, C("#a04a35"), 5, 1)
    punched(cv, C("#ece6da"), sill_col=C("#c8bfae"), panes=(2, 2), ac_seed=3)
    # fire escape shadow hint is geometry-free: darker band under each floor line
    band(cv, 3.6, 3.75, C("#6a2c20"), h=0.02)


def f_tan_brick(cv):
    brick(cv, C("#c8a26a"), C("#d8ccb4"), var=0.08, seed=12)
    punched(cv, C("#3a3a36"), sill_col=C("#d9cfbb"), panes=(1, 2), ac_seed=5)
    band(cv, 3.55, 3.75, C("#d9cfbb"))
    band(cv, 7.35, 7.5, C("#d9cfbb"))


def f_brownstone(cv):
    ashlar(cv, C("#6b4a3a"), bw=0.9, bh=0.45, joint=0.006, var=0.05, seed=13)
    cv.rough[:] = 0.88
    punched(cv, C("#2d2420"), w=1.1, h=2.1, sill_h=0.8, panes=(2, 2), sill_col=C("#5a3d30"))
    for fy in FLY:
        for bx in BAYX:   # pediment hood over each window
            cv.paint(cv.rect(bx - 0.75, fy + 2.9, bx + 0.75, fy + 3.12), C("#5c3e31"), h=0.08)
    band(cv, 7.2, 7.5, C("#4e352a"), h=0.1)


def f_artdeco(cv):
    ashlar(cv, C("#cfc4ae"), bw=1.35, bh=0.75, seed=14)
    for px in (0.0, 2.7, 5.4):        # vertical piers
        cv.paint(cv.rect(px - 0.35, 0, px + 0.35, 99), C("#d8ceb8"), h=0.12, rough=0.7)
        cv.ao[cv.rect(px - 0.42, 0, px - 0.35, 99) | cv.rect(px + 0.35, 0, px + 0.42, 99)] *= 0.6
    for fy in FLY:
        for bx in BAYX:
            window(cv, bx, fy + 0.95, 1.3, 1.95, C("#2a3a3a"), reveal=0.25, panes=(3, 1), lintel=False, sill=False)
            sp = cv.rect(bx - 0.65, fy + 2.9, bx + 0.65, fy + 3.75)  # ornamental spandrel
            cv.paint(sp, C("#5a6a5e"), h=-0.08, rough=0.45, metal=0.6)
            chev = sp & (np.abs(((cv.x - bx) * 4) % 1 - 0.5) * 0.4 > (cv.y - fy - 2.9) % 0.2 - 0.1)
            cv.alb[chev] *= 1.35
    cv.metal[cv.rect(-1, -1, 99, 99) & (cv.metal > 0.5)] = 0.7


def f_glass_bluegreen(cv):
    curtain_wall(cv, C("#2f5f68"), C("#9aa6a8"), mw=1.35, spandrel=None)


def f_glass_dark(cv):
    curtain_wall(cv, C("#14181c"), C("#2a2d30"), mw=1.35, spandrel=0.9, cap=0.08)


def f_brutalist(cv):
    concrete(cv, C("#8f8c84"), seed=16, panel=(2.7, 3.75))
    for fy in FLY:
        for bx in BAYX:
            window(cv, bx, fy + 1.0, 1.6, 1.6, C("#3c3c3a"), reveal=0.35, panes=(2, 1),
                   transom=False, sill=False, lintel=False)
    band(cv, 3.45, 3.75, C("#9a968c"), h=0.2)


def f_terracotta(cv):
    terracotta(cv, C("#ece4d4"), seed=17)
    punched(cv, C("#4a5248"), panes=(2, 2), sill_col=C("#f2ebdc"))
    band(cv, 3.5, 3.75, C("#e2d6c0"))


def f_midcentury(cv):
    metal_panel(cv, C("#b9bcbc"), pw=2.7, ph=3.75, seed=18)
    for fy in FLY:  # ribbon window across the whole tile
        g = cv.rect(-1, fy + 1.05, 99, fy + 2.75)
        cv.paint(g, C("#1d2a2e"), h=-0.06, rough=0.07, metal=0.3)
        cv.win[g] = 1.0
        for k in range(9):
            m = g & cv.rect(k * 0.675 - 0.025, -1, k * 0.675 + 0.025, 99)
            cv.paint(m, C("#c9cccb"), h=0.0, rough=0.35, metal=0.9)
            cv.win[m] = 0.0
            cv.frame[m] = 1.0
        cv.ao[cv.rect(-1, fy + 2.6, 99, fy + 2.75)] *= 0.6
        cv.curt[g & (np.abs(np.sin(np.floor(cv.x / 0.675) * 5.1 + fy)) > 0.5) & (cv.y > fy + 2.0)] = 1.0


def f_steel_spandrel(cv):
    curtain_wall(cv, C("#3a4a58"), C("#5d6670"), mw=1.35, spandrel=1.1, cap=0.07)


def f_warehouse(cv):
    brick(cv, C("#7a3a28"), C("#8f8476"), bond_header=6, var=0.16, seed=20)
    patches(cv, C("#5a2c20"), 8, 2)
    for fy in FLY:
        for bx in BAYX:
            window(cv, bx, fy + 0.8, 1.9, 2.4, C("#3c4a40"), reveal=0.22, frame=0.05,
                   panes=(4, 4), transom=False, sill_col=C("#9a9080"))
            cv.paint(cv.rect(bx - 1.0, fy + 3.2, bx + 1.0, fy + 3.45), C("#6a3022"), h=0.02)  # brick arch hint


def f_mixed(cv):
    curtain_wall(cv, C("#4b6a78"), C("#d0d2d0"), mw=1.35, spandrel=0.7, cap=0.05)
    for px in (0.0, 2.7, 5.4):
        cv.paint(cv.rect(px - 0.12, 0, px + 0.12, 99), C("#c9c3b5"), h=0.06, rough=0.7, metal=0.0)
        cv.win[cv.rect(px - 0.12, 0, px + 0.12, 99)] = 0.0


def f_landmark(cv):
    ashlar(cv, C("#ddd5c3"), bw=1.35, bh=0.9, seed=22)
    for px in (0.0, 2.7, 5.4):
        cv.paint(cv.rect(px - 0.25, 0, px + 0.25, 99), C("#b8a676"), h=0.1, rough=0.3, metal=0.9)
    for fy in FLY:
        for bx in BAYX:
            window(cv, bx, fy + 0.6, 1.4, 2.6, C("#8c7a4a"), reveal=0.3, panes=(3, 2), lintel=False,
                   sill_col=C("#c8b98a"))
    band(cv, 3.55, 3.75, C("#b8a676"), h=0.06, rough=0.3)
    cv.metal[cv.alb[..., 1] < 0] = 0  # no-op guard


def f_bridge(cv):
    ashlar(cv, C("#9a9184"), bw=1.8, bh=0.9, joint=0.012, var=0.1, seed=23)
    cv.rough[:] = 0.92
    for bx in BAYX:   # narrow arched slots with steel frames
        window(cv, bx, 1.5, 0.7, 4.0, C("#3e4a52"), reveal=0.45, panes=(1, 3), transom=False,
               sill_col=C("#857c70"), streak=True)
    band(cv, 6.9, 7.5, C("#4a545a"), h=0.08, rough=0.4)
    cv.metal[cv.rect(-1, 6.9, 99, 7.5)] = 0.8
    patches(cv, C("#6c665c"), 6, 3)


FACADES = [f_red_brick, f_tan_brick, f_brownstone, f_artdeco, f_glass_bluegreen, f_glass_dark,
           f_brutalist, f_terracotta, f_midcentury, f_steel_spandrel, f_warehouse, f_mixed,
           f_landmark, f_bridge]

GROUND_H = 4.5   # nominal ground floor; shader stretches v by ground_floor_h / 4.5


def sign_band(cv, y0, y1, col):
    cv.paint(cv.rect(-1, y0, 99, y1), col, h=0.08, rough=0.5)
    cv.ao[cv.rect(-1, y0 - 0.15, 99, y0)] *= 0.55
    r = np.random.default_rng(int(y0 * 100))
    for k in range(2):  # generic lettering blocks (no brands)
        cx = 1.35 + 2.7 * k
        for i in range(5):
            lx = cx - 0.8 + i * 0.34
            m = cv.rect(lx, y0 + 0.15, lx + 0.22, y1 - 0.15)
            cv.paint(m, C("#efe6c8"), h=0.1)
            cv.win[m] = 0.6 * r.random() + 0.4   # sign glows at night


def g_storefront(cv):
    brick(cv, C("#5a3a30"), C("#9a8f80"), seed=31)
    for bx in BAYX:
        window(cv, bx, 0.45, 2.3, 2.75, C("#2c2c2c"), reveal=0.12, frame=0.07, panes=(3, 1),
               sill_col=C("#4a4a48"), streak=False)
        cv.paint(cv.rect(bx - 1.15, 0.0, bx + 1.15, 0.45), C("#3a3a3a"), h=-0.02, rough=0.6)
    sign_band(cv, 3.45, 4.2, C("#2a3e5a"))


def g_shutter(cv):
    concrete(cv, C("#7c7a74"), seed=32)
    for bx in BAYX:
        m = cv.rect(bx - 1.2, 0.0, bx + 1.2, 3.2)
        cv.paint(m, C("#8a8c8c"), h=-0.05, rough=0.55, metal=0.7)
        rib = m & ((cv.y % 0.08) < 0.012)
        cv.alb[rib] *= 0.6
        cv.ao[cv.rect(bx - 1.2, 3.0, bx + 1.2, 3.2)] *= 0.5
        # graffiti-free tag stain + rust
        cv.alb[m & (fbm(cv.x, cv.y, 3, 7) > 0.62)] *= C("#c09070")
        cv.paint(cv.rect(bx - 1.3, 3.2, bx + 1.3, 3.45), C("#4a4a4a"), h=0.1, metal=0.6)
    sign_band(cv, 3.6, 4.3, C("#6a2a22"))


def g_lobby(cv):
    ashlar(cv, C("#b8b0a2"), bw=1.35, bh=0.75, seed=33)
    window(cv, 2.7, 0.0, 2.4, 3.0, C("#a08a5a"), reveal=0.3, panes=(2, 1), sill=False, streak=False)
    for bx in (0.7, 4.7):
        window(cv, bx, 0.9, 1.0, 2.0, C("#2c2c2c"), streak=False)
    cv.paint(cv.rect(0.8, 3.15, 4.6, 3.45), C("#2a2a2a"), h=0.3, rough=0.4, metal=0.8)  # canopy
    cv.ao[cv.rect(0.8, 2.6, 4.6, 3.15)] *= 0.45


def g_stoop(cv):
    ashlar(cv, C("#6b4a3a"), bw=0.9, bh=0.45, seed=34)
    for k in range(6):   # stoop steps rising to the door
        cv.paint(cv.rect(0.4, k * 0.2, 2.4, k * 0.2 + 0.2), C("#7a5a48") * (0.85 + 0.03 * k), h=0.3 - k * 0.04)
        cv.ao[cv.rect(0.4, k * 0.2, 2.4, k * 0.2 + 0.03)] *= 0.5
    window(cv, 1.4, 1.2, 1.1, 2.6, C("#3a2418"), reveal=0.25, panes=(2, 1), sill=False)  # door
    window(cv, 4.05, 1.4, 1.1, 2.0, C("#2d2420"), panes=(2, 2), sill_col=C("#5a3d30"))
    cv.paint(cv.rect(2.4, 0, 5.4, 0.9), C("#3a3632"), h=-0.05)  # garden-level areaway rail shade
    cv.paint(cv.rect(-1, 4.1, 99, 4.5), C("#4e352a"), h=0.1)


def g_dock(cv):
    brick(cv, C("#7a3a28"), C("#8f8476"), var=0.18, seed=35)
    for bx in BAYX:
        m = cv.rect(bx - 1.2, 1.1, bx + 1.2, 3.9)
        cv.paint(m, C("#5e6a62"), h=-0.1, rough=0.6, metal=0.6)
        cv.alb[m & ((cv.y % 0.3) < 0.02)] *= 0.55
        cv.paint(cv.rect(bx - 1.35, 0.0, bx + 1.35, 1.1), C("#6e6c66"), h=0.25, rough=0.95)  # dock
        cv.paint(cv.rect(bx - 1.3, 0.85, bx + 1.3, 1.1), C("#2a2a2a"), h=0.3, rough=0.9)    # bumper
        cv.paint(cv.rect(bx - 0.08, 0.2, bx + 0.08, 1.1), C("#c9a22a"), h=0.26)            # hazard
    patches(cv, C("#5a2c20"), 6, 4)


def g_glass_lobby(cv):
    curtain_wall(cv, C("#253a44"), C("#2e3236"), mw=1.35, spandrel=None, cap=0.07)
    cv.curt[:] = 0.0
    band(cv, 3.9, 4.5, C("#3a3e42"), h=0.08, rough=0.35)
    cv.paint(cv.rect(1.9, 0.0, 3.5, 2.6), C("#1a2228"), h=-0.08, rough=0.05, metal=0.5)  # revolving door
    cv.frame[cv.rect(2.66, 0, 2.74, 2.6)] = 1.0


GROUNDS = [g_storefront, g_shutter, g_lobby, g_stoop, g_dock, g_glass_lobby]


def r_base(cv, col, rough, seed, scale):
    n = fbm(cv.x, cv.y, scale, seed, 5)
    cv.alb[:] = col * (0.8 + 0.4 * n[..., None])
    cv.h[:] = n * 0.01
    cv.rough[:] = rough


def r_gravel(cv):
    r_base(cv, C("#6e6a62"), 0.95, 41, 1.0)
    g = fbm(cv.x, cv.y, 40.0, 42, 2)
    cv.alb *= (0.75 + 0.5 * g[..., None])
    cv.h += g * 0.01


def r_tar(cv):
    r_base(cv, C("#2a2a2c"), 0.8, 43, 0.6)
    seam = (cv.x % 1.0) < 0.03
    cv.alb[seam] *= 1.5
    cv.h[seam] += 0.004
    cv.alb[fbm(cv.x, cv.y, 0.4, 44) > 0.6] *= 1.25   # sun-faded patches


def r_concrete(cv):
    concrete(cv, C("#8a8780"), board=2.0, tie=99.0, seed=45, panel=(2.0, 2.0))
    for (x, y) in ((1.5, 1.5), (5.5, 4.5)):           # vents / hatch
        cv.paint(cv.rect(x, y, x + 0.8, y + 0.8), C("#7a7c7c"), h=0.2, metal=0.7, rough=0.5)
        cv.ao[cv.rect(x - 0.2, y - 0.2, x + 1.0, y)] *= 0.6


def r_green(cv):
    r_base(cv, C("#4c6a34"), 0.95, 46, 2.0)
    path = (np.abs(cv.x - 4.0) < 0.4) | (np.abs(cv.y - 4.0) < 0.4)
    cv.paint(path, C("#8f8a80"), h=0.0, rough=0.9)
    cv.alb[(~path) & (fbm(cv.x, cv.y, 8, 47) > 0.6)] *= C("#a0a060")


def r_metal(cv):
    metal_panel(cv, C("#7c8486"), pw=0.5, ph=99.0, seed=48)
    rib = (cv.x % 0.5) < 0.04
    cv.h[rib] = 0.02
    cv.alb[rib] *= 1.15


ROOF_FNS = [r_gravel, r_tar, r_concrete, r_green, r_metal]


def build_layer(idx, res):
    rng = np.random.default_rng(idx)
    if idx < 14:
        cv = Canvas(FACADE_W, FACADE_H, res, rng)
        FACADES[idx](cv)
    elif 16 <= idx < 22:
        cv = Canvas(FACADE_W, GROUND_H, res, rng)
        GROUNDS[idx - 16](cv)
    elif 24 <= idx < 29:
        cv = Canvas(8.0, 8.0, res, rng)
        ROOF_FNS[idx - 24](cv)
    else:
        return None
    return cv


# ------------------------------------------------------------------ PBR outputs
def box_blur(a, r):
    if r < 1:
        return a
    k = 2 * r + 1
    p = np.pad(a, r, mode="wrap")
    c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def maps(cv):
    """Return uint8 albedo RGB, normal RGB (OpenGL / Godot +Y), orm RGB, emission RGB."""
    sx = cv.wm / cv.W
    sy = cv.hm / cv.H
    h = cv.h.astype(np.float32)
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * sx)
    dy = -(np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * sy)   # rows go down, v goes up
    strength = 0.6
    n = np.dstack([-dx * strength, -dy * strength, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    cav = np.clip(1.0 + (h - box_blur(h, max(1, int(0.08 / sx)))) * 6.0, 0.5, 1.0)
    ao = np.clip(cv.ao * cav, 0.0, 1.0)
    alb = np.clip(cv.alb * (0.55 + 0.45 * ao[..., None]), 0, 1)   # bake some AO into albedo
    u8 = lambda a: (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    orm = np.dstack([ao, cv.rough, cv.metal])
    emi = np.dstack([cv.win, cv.curt * (cv.win > 0), cv.frame])
    half = lambda a: a.reshape(a.shape[0] // 2, 2, a.shape[1] // 2, 2, 3).mean((1, 3))
    return u8(alb), u8(n * 0.5 + 0.5), u8(half(orm)), u8(half(emi))


def neutral(res):
    z = np.zeros((res, res, 3), np.uint8)
    a = z + 128
    nrm = z.copy()
    nrm[..., :2] = 128
    nrm[..., 2] = 255
    h = res // 2
    orm = np.zeros((h, h, 3), np.uint8)
    orm[..., 0] = 255
    orm[..., 1] = 230
    return a, nrm, orm, np.zeros((h, h, 3), np.uint8)


# ------------------------------------------------------------------ IO
MAP_NAMES = ("albedo", "normal", "orm", "emission")
ARRAY_FILES = ("albedo_array.png", "normal_array.png", "orm_array.png", "emission_mask_array.png")


def save_png(path, arr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if IN_BLENDER:
        h, w = arr.shape[:2]
        img = bpy.data.images.new("bt_tmp", w, h, alpha=True, float_buffer=False)
        rgba = np.ones((h, w, 4), np.float32)
        rgba[..., :3] = arr[::-1].astype(np.float32) / 255.0   # Blender rows go bottom-up
        img.pixels.foreach_set(rgba.ravel())
        img.colorspace_settings.name = "Non-Color"           # write bytes as is
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
    else:
        from PIL import Image
        Image.fromarray(arr, "RGB").save(path, optimize=False)


def load_png(path):
    from PIL import Image
    return np.asarray(Image.open(path).convert("RGB"))


IMPORT_TMPL = """[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[deps]

source_file="res://assets/textures/buildings/arrays/{f}"

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=1
slices/vertical={n}
"""


def write_import(fname, n):
    p = os.path.join(OUT, "arrays", fname + ".import")
    txt = IMPORT_TMPL.format(f=fname, n=n)
    if fname.startswith("normal"):
        txt = txt.replace("compress/channel_pack=0", "compress/channel_pack=0\ncompress/normal_map=1")
    with open(p, "w", newline="\n") as fh:
        fh.write(txt)


def pack(res):
    """Stack 32 layers vertically (slices/vertical=32). Missing layers -> neutral filler."""
    names = layer_names()
    os.makedirs(os.path.join(OUT, "arrays"), exist_ok=True)
    for mi, (mname, afile) in enumerate(zip(MAP_NAMES, ARRAY_FILES)):
        size = res if mi < 1 else res // 2   # albedo 2048; normal/orm/emission 1024 (VRAM budget)
        tiles = []
        for li in range(LAYERS):
            p = os.path.join(OUT, names.get(li, "_"), mname + ".png")
            if li in names and os.path.exists(p):
                t = load_png(p)
                if t.shape[0] != size:
                    from PIL import Image
                    t = np.asarray(Image.fromarray(t).resize((size, size), Image.LANCZOS))
            else:
                t = neutral(res)[mi][:size, :size]   # uniform filler, crop to the map size
            tiles.append(t)
        save_png(os.path.join(OUT, "arrays", afile), np.concatenate(tiles, 0))
        write_import(afile, LAYERS)
        print("packed", afile, LAYERS, "layers", size, "px")


def vram_mb(res):
    """BC7 = 1 byte / px, mip chain x 4/3."""
    big = res * res * 1.0 * 4 / 3 * LAYERS
    small = (res // 2) ** 2 * 1.0 * 4 / 3 * LAYERS * 3
    return (big + small) / (1024 * 1024)


def verify(res):
    names = layer_names()
    ok = 0
    for li in sorted(names):
        have = [m for m in MAP_NAMES if os.path.exists(os.path.join(OUT, names[li], m + ".png"))]
        print("layer %2d %-24s maps %d/4 %s" % (li, names[li], len(have), "OK" if len(have) == 4 else "MISSING"))
        ok += len(have) == 4
    print("contract layers: %d/%d complete" % (ok, len(names)))
    for f in ARRAY_FILES:
        p = os.path.join(OUT, "arrays", f)
        print("array", f, "present" if os.path.exists(p) else "MISSING",
              "import" if os.path.exists(p + ".import") else "NO_IMPORT")
    mb = vram_mb(res)
    print("estimated building texture VRAM: %.1f MB (budget 512) %s" % (mb, "PASS" if mb <= 512 else "FAIL"))
    return ok == len(names) and mb <= 512


def main(argv):
    res = 2048
    only = None
    if "--size" in argv:
        res = int(argv[argv.index("--size") + 1])
    if "--only" in argv:
        only = [int(s) for s in argv[argv.index("--only") + 1].split(",")]
    if "--verify" in argv:
        return 0 if verify(res) else 1
    names = layer_names()
    for li in sorted(names):
        if only is not None and li not in only:
            continue
        cv = build_layer(li, res)
        for mname, arr in zip(MAP_NAMES, maps(cv)):
            save_png(os.path.join(OUT, names[li], mname + ".png"), arr)
        print("baked layer", li, names[li])
    pack(res)
    return 0 if verify(res) else 1


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    rc = main(a)
    if not IN_BLENDER:
        sys.exit(rc)

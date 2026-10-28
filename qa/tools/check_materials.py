"""Material contract check for exported .glb models (stdlib only).

Scans assets/models/{props,road,park}/*.glb, parses the glTF JSON chunk and the
embedded PNG images (BIN chunk bufferViews), and reports every mesh primitive that
  - has no material                         -> reason 'no_material'
  - material has no baseColorTexture        -> reason 'no_texture'
  - average sRGB colour (texture * baseColorFactor, or factor alone) has every
    channel > 0.85                          -> reason 'near_white'
Materials whose name ends with _paint/_glass/_emissive are exempt from
no_texture and near_white (road paint, glass and lights may be plain white).

Writes qa/evidence/material_check/metrics.json:
  {pass, models_checked, primitives_checked, failures: [{file, mesh, primitive, reason}], ...}
Usage: python qa/tools/check_materials.py [project_root]
"""
import json
import os
import struct
import sys
import zlib

DIRS = ("assets/models/props", "assets/models/road", "assets/models/park")
WHITE = 0.85
EXEMPT = ("_paint", "_glass", "_emissive")


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, _ver, _len = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("not a glb")
    off, js, binc = 12, None, b""
    while off + 8 <= len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            binc = chunk
        off += 8 + clen
    if js is None:
        raise ValueError("no JSON chunk")
    return js, binc


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def png_info(raw):
    """Returns (width, height, (r, g, b) average in 0..1 sRGB) of a PNG."""
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    off, idat, plte, trns = 8, [], None, None
    w = h = depth = ctype = interlace = 0
    while off < len(raw):
        ln, = struct.unpack_from(">I", raw, off)
        typ = raw[off + 4: off + 8]
        body = raw[off + 8: off + 8 + ln]
        if typ == b"IHDR":
            w, h, depth, ctype, _c, _f, interlace = struct.unpack(">IIBBBBB", body)
        elif typ == b"PLTE":
            plte = body
        elif typ == b"IDAT":
            idat.append(body)
        elif typ == b"IEND":
            break
        off += 12 + ln
    if interlace:
        raise ValueError("interlaced PNG not supported")
    chans = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    bpp_bits = chans * depth
    bpp = max(1, bpp_bits // 8)
    stride = (w * bpp_bits + 7) // 8
    data = zlib.decompress(b"".join(idat))
    prev = bytearray(stride)
    sums = [0.0, 0.0, 0.0]
    pos = 0
    maxv = float((1 << depth) - 1)
    for _y in range(h):
        ft = data[pos]
        line = bytearray(data[pos + 1: pos + 1 + stride])
        pos += 1 + stride
        if ft == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                c = prev[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + _paeth(a, prev[i], c)) & 255
        prev = line
        if depth == 8:
            if ctype == 3:
                for x in range(w):
                    k = line[x] * 3
                    sums[0] += plte[k]
                    sums[1] += plte[k + 1]
                    sums[2] += plte[k + 2]
            elif chans >= 3:
                sums[0] += sum(line[0::chans])
                sums[1] += sum(line[1::chans])
                sums[2] += sum(line[2::chans])
            else:
                g = sum(line[0::chans])
                sums[0] += g
                sums[1] += g
                sums[2] += g
        elif depth == 16 and ctype != 3:
            vals = struct.unpack(">%dH" % (stride // 2), bytes(line))
            if chans >= 3:
                for ci in range(3):
                    sums[ci] += sum(vals[ci::chans])
            else:
                g = sum(vals[0::chans])
                sums = [s + g for s in sums]
        else:
            # low bit depths: sample-level decode is not needed for the kit; treat as grey 0.5
            sums = [s + 0.5 * maxv * w for s in sums]
    n = float(max(1, w * h))
    if ctype == 3:
        maxv = 255.0
    return w, h, tuple(s / n / maxv for s in sums)


def image_bytes(js, binc, img_idx, base_dir):
    img = js["images"][img_idx]
    if "bufferView" in img:
        bv = js["bufferViews"][img["bufferView"]]
        o = bv.get("byteOffset", 0)
        return binc[o: o + bv["byteLength"]], True
    uri = img.get("uri", "")
    p = os.path.join(base_dir, uri)
    if uri and os.path.isfile(p):
        with open(p, "rb") as f:
            return f.read(), False
    return None, False


def check_file(path, rel, cache, failures, notes):
    js, binc = read_glb(path)
    mats = js.get("materials", [])
    prims = 0
    for mi, mesh in enumerate(js.get("meshes", [])):
        mname = mesh.get("name", "mesh%d" % mi)
        for pi, prim in enumerate(mesh.get("primitives", [])):
            prims += 1
            rec = {"file": rel, "mesh": mname, "primitive": pi}
            if "material" not in prim or prim["material"] >= len(mats):
                failures.append(dict(rec, reason="no_material"))
                continue
            mat = mats[prim["material"]]
            matn = mat.get("name", "")
            pbr = mat.get("pbrMetallicRoughness", {})
            fac = pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])
            exempt = matn.endswith(EXEMPT)
            if not matn.startswith("M_"):
                notes.append(dict(rec, material=matn, note="name not M_<model>_<part>"))
            tex = pbr.get("baseColorTexture")
            if tex is None:
                if exempt:
                    continue
                failures.append(dict(rec, reason="no_texture", material=matn))
                avg = (1.0, 1.0, 1.0)
            else:
                key = (rel, tex["index"])
                if key not in cache:
                    try:
                        src = js["textures"][tex["index"]].get("source")
                        raw, embedded = image_bytes(js, binc, src, os.path.dirname(path))
                        if raw is None:
                            cache[key] = None
                        else:
                            w, h, a = png_info(raw)
                            cache[key] = (w, h, a, embedded)
                    except Exception as e:  # noqa: BLE001 - report, do not crash
                        notes.append(dict(rec, material=matn, note="texture decode: %s" % e))
                        cache[key] = None
                info = cache[key]
                if info is None:
                    if not exempt:
                        failures.append(dict(rec, reason="no_texture", material=matn))
                    continue
                w, h, avg, embedded = info
                small_ok = ("_lod1" in rel or "_bb" in rel) and (w, h) == (128, 128)
                if (w, h) != (256, 256) and not small_ok:
                    notes.append(dict(rec, material=matn, note="texture %dx%d" % (w, h)))
                if not embedded:
                    notes.append(dict(rec, material=matn, note="texture not embedded"))
            if exempt:
                continue
            col = [avg[i] * fac[i] for i in range(3)]
            if min(col) > WHITE:
                failures.append(dict(rec, reason="near_white", material=matn,
                                     avg_srgb=[round(c, 3) for c in col]))
    return prims


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", ".."))
    failures, notes, cache = [], [], {}
    files = prims = 0
    for d in DIRS:
        full = os.path.join(root, d)
        if not os.path.isdir(full):
            continue
        for fn in sorted(os.listdir(full)):
            if not fn.endswith(".glb"):
                continue
            rel = d + "/" + fn
            files += 1
            try:
                prims += check_file(os.path.join(full, fn), rel, cache, failures, notes)
            except Exception as e:  # noqa: BLE001
                failures.append({"file": rel, "mesh": "", "primitive": -1, "reason": "no_material",
                                 "error": str(e)})
    by_reason = {}
    for f in failures:
        by_reason[f["reason"]] = by_reason.get(f["reason"], 0) + 1
    out = {"pass": files > 0 and not failures, "models_checked": files,
           "primitives_checked": prims, "failure_count": len(failures),
           "failures_by_reason": by_reason,
           "files_failing": len({f["file"] for f in failures}),
           "failures": failures, "notes": notes}
    ev = os.path.join(root, "qa", "evidence", "material_check")
    os.makedirs(ev, exist_ok=True)
    with open(os.path.join(ev, "metrics.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)
    print("models_checked: %d" % files)
    print("primitives_checked: %d" % prims)
    print("failures: %d %s (files failing: %d)" % (len(failures), json.dumps(by_reason),
                                                   out["files_failing"]))
    print("notes: %d" % len(notes))
    print("pass: %s" % ("true" if out["pass"] else "false"))
    return 0 if out["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())

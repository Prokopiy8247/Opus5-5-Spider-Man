"""Models ChunkStreamer: 128 m chunks, 5x5 load square, flight across the city grid."""
import math
import sys

CHUNK, R = 128.0, 2
CITY_X, CITY_Z = 1500.0, 750.0


def chunk_of(x, z):
    return (math.floor(x / CHUNK), math.floor(z / CHUNK))


def main():
    chunks = set()
    x = -CITY_X
    while x < CITY_X:
        z = -CITY_Z
        while z < CITY_Z:
            chunks.add(chunk_of(x + 1, z + 1))
            z += CHUNK
        x += CHUNK
    loaded, focus, recalcs, max_loaded, frames = set(chunks), None, 0, 0, 0
    path = [(-1400 + i * 2.0, -30 + 400 * math.sin(i / 300.0)) for i in range(1400)]
    for px, pz in path:
        frames += 1
        c = chunk_of(px, pz)
        if c == focus:
            continue
        focus, recalcs = c, recalcs + 1
        loaded = {k for k in chunks if abs(k[0] - c[0]) <= R and abs(k[1] - c[1]) <= R}
        max_loaded = max(max_loaded, len(loaded))
        assert c in loaded
    print(f"total={len(chunks)} max_loaded={max_loaded} final_loaded={len(loaded)} frames={frames} recalcs={recalcs}")
    ok = max_loaded <= 25 < len(chunks) and recalcs < frames
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

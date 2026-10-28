"""Mirror of TrafficCar/TrafficManager logic: closed-lane motion and the 6 m stop rule.
Usage: python scripts/world/traffic/sim_traffic.py  (exit 0 = all checks pass)"""
import math, random, sys

STOP, HALF_W, VMIN, VMAX, DT = 6.0, 2.0, 8.0, 14.0, 1.0 / 60.0


class Lane:
    def __init__(self, pts):
        self.pts, self.cum, t = pts, [], 0.0
        for i, p in enumerate(pts):
            self.cum.append(t)
            q = pts[(i + 1) % len(pts)]
            t += math.dist(p, q)
        self.length = t

    def sample(self, d):
        s = d % self.length
        n = len(self.pts)
        for i in range(n):
            end = self.cum[i + 1] if i + 1 < n else self.length
            if s <= end:
                a, b = self.pts[i], self.pts[(i + 1) % n]
                seg = end - self.cum[i]
                k = 0.0 if seg < 1e-4 else (s - self.cum[i]) / seg
                return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
        return self.pts[0]


class Car:
    def __init__(self, lane, d, v):
        self.lane, self.d, self.cruise, self.v = lane, d % lane.length, v, 0.0

    def pos(self):
        return self.lane.sample(self.d)

    def fwd(self):
        a, b = self.lane.sample(self.d), self.lane.sample(self.d + 1.0)
        l = math.dist(a, b) or 1.0
        return ((b[0] - a[0]) / l, (b[1] - a[1]) / l)

    def blocking(self, p):
        c, f = self.pos(), self.fwd()
        dx, dz = p[0] - c[0], p[1] - c[1]
        ahead = dx * f[0] + dz * f[1]
        if ahead <= 0.0 or ahead >= STOP:
            return False
        return math.hypot(dx - f[0] * ahead, dz - f[1] * ahead) < HALF_W

    def advance(self, blocked):
        tgt = 0.0 if blocked else self.cruise
        acc = (40.0 if blocked else 6.0) * DT
        self.v = max(self.v - acc, tgt) if self.v > tgt else min(self.v + acc, tgt)
        if self.v > 0.0:
            self.d = (self.d + self.v * DT) % self.lane.length


def step(cars, player):
    for c in cars:
        b = player is not None and c.blocking(player)
        if not b:
            b = any(o is not c and c.blocking(o.pos()) for o in cars)
        c.advance(b)


# ---- Mirror of CityGrid (scripts/world/city_grid.gd) and TrafficLights.
CITY_X, CITY_Z, AVE_SP, STREET_SP, STREET_W, AVE_W = 1500.0, 750.0, 120.0, 90.0, 16.0, 26.0
PARK = (-232.0, 103.0, 202.0, 317.0)  # x0, z0, x1, z1
LANE_OFF, LX0, LX1, CLEAR = 5.0, -1460.0, 1460.0, 2.0
GREEN, YELLOW, RED = 12.0, 3.0, 15.0
CYCLE = GREEN + YELLOW + RED


def avenue_zs():
    z, out = -CITY_Z + AVE_SP, []
    while z < CITY_Z - AVE_SP + 1.0:
        out.append(z)
        z += AVE_SP
    return out


def street_xs():
    x, out = -CITY_X + STREET_SP, []
    while x < CITY_X - 1.0:
        out.append(x)
        x += STREET_SP
    return out


def in_park(x, z, m=0.0):
    return PARK[0] - m <= x <= PARK[2] + m and PARK[1] - m <= z <= PARK[3] + m


def spans(z):
    if z + LANE_OFF + 2.0 > PARK[1] and z - LANE_OFF - 2.0 < PARK[3]:
        return [(LX0, PARK[0] - STREET_W / 2), (PARK[2] + STREET_W / 2, LX1)]
    return [(LX0, LX1)]


def city_lanes():
    out = []
    for z in avenue_zs():
        for a, b in spans(z):
            out.append([(a, z + LANE_OFF), (b, z + LANE_OFF), (b, z - LANE_OFF), (a, z - LANE_OFF)])
    return out


def seg_dist_to_rect(a, b, steps=200):
    best = 1e9
    for i in range(steps + 1):
        k = i / steps
        x, z = a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k
        dx = max(PARK[0] - x, 0.0, x - PARK[2])
        dz = max(PARK[1] - z, 0.0, z - PARK[3])
        best = min(best, math.hypot(dx, dz))
    return best


def light_state(t, light_id):
    g = (light_id * 7 + 1) % 3
    ph = (t + g * CYCLE / 3.0) % CYCLE
    return "green" if ph < GREEN else ("yellow" if ph < GREEN + YELLOW else "red")


def stop_lines(lane_z_plus):
    """Stop lines for one avenue, mirroring StreetBuilder: (x, dir, light_id)."""
    out = []
    li = 0
    for z in avenue_zs():
        for x in street_xs():
            if in_park(x, z, 1.0):
                continue
            if abs(z - lane_z_plus) < 1e-6:
                out.append((x - (STREET_W / 2 + 4.0), 1.0, li))
                out.append((x + (STREET_W / 2 + 4.0), -1.0, li))
            li += 1
    return out


def park_and_lights():
    ok = {}
    lanes = city_lanes()
    min_d = min(seg_dist_to_rect(l[i], l[(i + 1) % 4]) for l in lanes for i in range(4))
    print(f"lanes = {len(lanes)}, min lane distance to park rect = {min_d:.2f} m (need >= {CLEAR})")
    ok["lanes_clear_of_park"] = min_d >= CLEAR
    # 10-minute run, 40 cars spread across all lanes, sampled at 60 Hz.
    random.seed(7)
    L = [Lane(l) for l in lanes]
    cars = [Car(L[i % len(L)], random.uniform(0, L[i % len(L)].length), random.uniform(VMIN, VMAX)) for i in range(40)]
    inside = 0
    for _ in range(60 * 600):
        for c in cars:
            c.advance(False)
            p = c.pos()
            if in_park(p[0], p[1]):
                inside += 1
    print(f"car positions inside park over 10 min: {inside}")
    ok["cars_in_park_0"] = inside == 0
    # Red light: an eastbound car approaching a stop line stops 0..9 m before it and only goes on green.
    z = avenue_zs()[0]
    sl = [s for s in stop_lines(z) if s[1] > 0][3]
    lane = Lane([(LX0, z + LANE_OFF), (LX1, z + LANE_OFF), (LX1, z - LANE_OFF), (LX0, z - LANE_OFF)])
    t0 = None
    for t_try in range(0, 60):
        if light_state(float(t_try), sl[2]) == "red" and light_state(float(t_try) - 1.0, sl[2]) != "red":
            t0 = float(t_try)
            break
    car = Car(lane, (sl[0] - 40.0) - LX0, 12.0)
    car.v = 12.0
    t, ran_red, stopped_at = t0 - 2.0, False, None
    for _ in range(60 * 30):
        x = car.pos()[0]
        ahead = sl[0] - x - 2.3
        st = light_state(t, sl[2])
        blocked = 0.0 <= ahead <= 9.0 and (st == "red" or (st == "yellow" and ahead > 3.0))
        if blocked and car.v == 0.0 and stopped_at is None:
            stopped_at = ahead
        if ahead < 0.0 and st == "red" and x - 2.3 < sl[0] + 1.0 and stopped_at is not None:
            ran_red = True
        car.advance(blocked)
        t += DT
    print(f"red light: stopped {stopped_at if stopped_at is None else round(stopped_at, 2)} m before the stop line, passed after green = {car.pos()[0] > sl[0]}")
    ok["stops_at_red_line"] = stopped_at is not None and 0.0 <= stopped_at <= 9.0
    ok["goes_on_green"] = car.pos()[0] > sl[0] and not ran_red
    states = {light_state(t / 10.0, 5) for t in range(0, 300)}
    ok["light_cycles_all_states"] = states == {"green", "yellow", "red"}
    return ok


def main():
    ok = park_and_lights()
    # Closed rectangular lane around one block (avenue/street grid, 90 x 120 m).
    lane = Lane([(0, 0), (90, 0), (90, 120), (0, 120)])
    ok["lane_length_420"] = abs(lane.length - 420.0) < 1e-6
    car = Car(lane, 0.0, 12.0)
    t, laps, prev = 0.0, 0, 0.0
    while t < 80.0:
        step([car], None)
        if car.d < prev:
            laps += 1
        prev = car.d
        t += DT
    ok["loops_closed_lane"] = laps >= 2
    p = car.pos()
    ok["stays_on_lane"] = any(abs(p[0] - x) < 1e-3 for x in (0, 90)) or any(abs(p[1] - z) < 1e-3 for z in (0, 120))
    ok["speed_cruise"] = abs(car.v - 12.0) < 1e-6
    # Stop rule: player standing on the lane at (50, 0).
    c2 = Car(lane, 20.0, 14.0)
    player = (50.0, 0.0)
    for _ in range(60 * 10):
        step([c2], player)
    gap = player[0] - c2.pos()[0]
    ok["stops_before_player"] = c2.v == 0.0 and 0.0 < gap <= STOP
    print(f"stopped gap to player = {gap:.2f} m")
    for _ in range(60 * 3):
        step([c2], (50.0, 30.0))  # player walks off the lane
    ok["resumes_after_player_leaves"] = c2.v > 0.0 and c2.pos()[0] > 50.0
    ok["player_beside_lane_ignored"] = not Car(lane, 45.0, 10.0).blocking((48.0, 3.0))
    # Car following: fast car behind slow car never closes under 0 gap / passes it.
    random.seed(1)
    cars = [Car(lane, 30.0 * i, random.uniform(VMIN, VMAX)) for i in range(10)]
    min_gap = 1e9
    for _ in range(60 * 60):
        step(cars, None)
        ds = sorted(c.d for c in cars)
        gaps = [(ds[(i + 1) % len(ds)] - ds[i]) % lane.length for i in range(len(ds))]
        min_gap = min(min_gap, min(gaps))
    print(f"min gap between 10 cars over 60 s = {min_gap:.2f} m")
    ok["no_overtake_or_overlap"] = min_gap > 3.0
    ok["speeds_in_range"] = all(VMIN <= c.cruise <= VMAX for c in cars)
    for k, v in ok.items():
        print(("PASS " if v else "FAIL ") + k)
    print("RESULT", "PASS" if all(ok.values()) else "FAIL")
    return 0 if all(ok.values()) else 1


if __name__ == "__main__":
    sys.exit(main())

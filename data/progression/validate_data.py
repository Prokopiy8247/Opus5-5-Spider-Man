"""Validates skills.json, suits.json and archetypes.json against the shared contract."""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = {"swing_speed", "zip_speed", "attack_damage", "max_health", "focus_gain",
         "gadget_cooldown", "dodge_window", "stealth_radius"}
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
errors = []


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        errors.append(f"{rel}: root must be an array")
        return []
    return data


def need(rel, rec, keys):
    for k, t in keys.items():
        if k not in rec:
            errors.append(f"{rel}: {rec.get('id')} missing '{k}'")
        elif not isinstance(rec[k], t) or (t is int and isinstance(rec[k], bool)):
            errors.append(f"{rel}: {rec.get('id')} '{k}' wrong type")


def stats_ok(rel, rec, key):
    for s, v in rec.get(key, {}).items():
        if s not in STATS:
            errors.append(f"{rel}: {rec['id']} unknown stat '{s}'")
        if not isinstance(v, (int, float)) or v == 1.0:
            errors.append(f"{rel}: {rec['id']} stat '{s}' has no real effect")


skills = load("progression/skills.json")
ids = [s.get("id") for s in skills]
for s in skills:
    need("skills", s, {"id": str, "name": str, "cost": int, "requires": list, "effect": dict})
    stats_ok("skills", s, "effect")
    if not s.get("effect"):
        errors.append(f"skills: {s.get('id')} empty effect")
    for r in s.get("requires", []):
        if r not in ids:
            errors.append(f"skills: {s['id']} requires missing '{r}'")
if len(ids) != len(set(ids)):
    errors.append("skills: duplicate ids")
if len(skills) < 12:
    errors.append(f"skills: need >=12, got {len(skills)}")
if "attack_damage" not in ids:
    errors.append("skills: no 'attack_damage' skill")

suits = load("progression/suits.json")
for s in suits:
    need("suits", s, {"id": str, "name": str, "primary": str, "secondary": str, "emblem": str, "bonus": dict})
    for c in ("primary", "secondary", "emblem"):
        if not HEX.match(str(s.get(c, ""))):
            errors.append(f"suits: {s.get('id')} bad color {c}")
    stats_ok("suits", s, "bonus")
if sorted(s.get("id") for s in suits) != ["classic", "iron", "stealth"]:
    errors.append("suits: ids must be classic, stealth, iron")

arch = load("enemies/archetypes.json")
for a in arch:
    need("archetypes", a, {"id": str, "health": int, "damage": int, "speed": (int, float),
                           "attack_range": (int, float), "xp": int, "block_front": bool, "ranged": bool})
by = {a.get("id"): a for a in arch}
if sorted(by) != ["brute", "gunner", "shield", "sniper", "thug"]:
    errors.append("archetypes: ids must be thug, brute, gunner, shield, sniper")
if not by.get("shield", {}).get("block_front"):
    errors.append("archetypes: shield must block_front")
for r in ("gunner", "sniper"):
    if not by.get(r, {}).get("ranged"):
        errors.append(f"archetypes: {r} must be ranged")

print(f"skills: {len(skills)}")
print(f"suits: {len(suits)}")
print(f"archetypes: {len(arch)}")
for e in errors:
    print("ERROR:", e)
print(f"errors: {len(errors)}")
sys.exit(1 if errors else 0)

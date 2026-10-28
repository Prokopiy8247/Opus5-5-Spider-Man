class_name TrafficLights
extends RefCounted
## Signal timing for every intersection (contract: green 12 s, yellow 3 s, red 15 s for the
## avenue direction). The cross street gets the complementary phase (its green covers the
## avenue's red, minus a 3 s yellow). Each intersection has its own deterministic offset,
## quantised into PHASE_GROUPS groups so the visual lamps can share materials per group.

const GREEN: float = 12.0
const YELLOW: float = 3.0
const RED: float = 15.0
const CYCLE: float = GREEN + YELLOW + RED  # 30 s
const PHASE_GROUPS: int = 3

## Simulation clock (seconds). Advanced by World._process; QA may set it directly.
static var clock: float = 0.0


static func group_of(light_id: int) -> int:
	# Avenue "green wave": neighbouring intersections are offset by one group.
	return posmod(light_id * 7 + 1, PHASE_GROUPS)


static func offset_of(light_id: int) -> float:
	return float(group_of(light_id)) * CYCLE / float(PHASE_GROUPS)


static func state_at(t: float, light_id: int) -> StringName:
	return state_for_phase(fposmod(t + offset_of(light_id), CYCLE))


static func state_for_phase(ph: float) -> StringName:
	if ph < GREEN:
		return &"green"
	if ph < GREEN + YELLOW:
		return &"yellow"
	return &"red"


## Cross-street state: green while the avenue is red (minus its own 3 s yellow).
static func cross_state_for_phase(ph: float) -> StringName:
	var p: float = ph - (GREEN + YELLOW)
	if p < 0.0:
		return &"red"
	if p < RED - YELLOW:
		return &"green"
	return &"yellow"


static func group_phase(t: float, group: int) -> float:
	return fposmod(t + float(group) * CYCLE / float(PHASE_GROUPS), CYCLE)


static func state(light_id: int) -> StringName:
	return state_at(clock, light_id)

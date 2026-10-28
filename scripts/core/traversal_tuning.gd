class_name TraversalTuning
extends Resource
## Traversal balance (data/traversal.tres). Defaults are used if the .tres is missing.

@export var gravity: float = 22.0
@export var run_speed: float = 7.0
@export var sprint_speed: float = 16.0
@export var ground_accel: float = 60.0
@export var air_control: float = 8.0
@export var jump_velocity: float = 10.0
@export var terminal_speed: float = 55.0
@export var dive_terminal_speed: float = 80.0
@export var dive_gravity_mult: float = 1.8

@export_group("Swing")
@export var swing_ray_count_yaw: int = 9
@export var swing_ray_count_pitch: int = 5
@export var swing_cone_yaw_deg: float = 50.0
@export var swing_pitch_min_deg: float = 32.0
@export var swing_pitch_max_deg: float = 72.0
@export var swing_ray_length: float = 95.0
@export var swing_ideal_height: float = 24.0
@export var swing_ideal_distance: float = 36.0
@export var swing_min_rope: float = 10.0
@export var swing_max_rope: float = 75.0
@export var swing_min_speed: float = 24.0
@export var swing_max_speed: float = 45.0
@export var swing_pump_accel: float = 9.0
@export var swing_steer_rate: float = 1.6
@export var swing_straighten_rate: float = 1.2
@export var swing_wall_clearance: float = 3.0
@export var swing_lateral_comp: float = 0.75
@export var swing_ground_clearance: float = 3.5
@export var swing_release_boost: float = 7.0
@export var swing_release_lift: float = 6.0
@export var swing_late_attach_boost: float = 4.0

@export_group("Zip / Launch")
@export var zip_range: float = 65.0
@export var zip_duration: float = 0.4
@export var zip_cone_deg: float = 35.0
@export var launch_forward: float = 26.0
@export var launch_up: float = 20.0
@export var launch_slowmo: float = 0.35
@export var launch_slowmo_time: float = 0.3

@export_group("Wall run")
@export var wall_run_min_speed: float = 9.0
@export var wall_run_speed: float = 14.0
@export var wall_run_up_speed: float = 12.0
@export var wall_kick_speed: float = 14.0

@export_group("Landing")
@export var hero_land_speed: float = 24.0
@export var roll_speed: float = 14.0

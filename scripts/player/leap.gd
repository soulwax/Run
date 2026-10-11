class_name Leap
extends RefCounted

## Stable GDScript API for gameplay and probes. Per-frame skeleton evaluation
## is performed by LeapMotion in C#; these small helpers remain shared with
## player physics and the deterministic leap-math probe.

const BONES := ["DEF-spine", "DEF-spine.004", "DEF-spine.006",
	"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
	"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L",
	"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R"]

var _motion: LeapMotion

var amount: float:
	get: return _motion.Amount if _motion else 0.0
	set(value):
		if _motion:
			_motion.Amount = value
var progress: float:
	get: return _motion.Progress if _motion else 0.0
	set(value):
		if _motion:
			_motion.Progress = value
var lead_left: bool:
	get: return _motion.LeadLeft if _motion else true
	set(value):
		if _motion:
			_motion.LeadLeft = value
var active: bool:
	get: return bool(_motion.get("active")) if _motion else false
	set(value):
		if _motion:
			_motion.set("active", value)


static func fit(skeleton: Skeleton3D) -> Leap:
	var leap := Leap.new()
	for name in BONES:
		if skeleton.find_bone(name) < 0:
			push_warning("Leap: missing bone " + name)
			return leap
	var motion := LeapMotion.new()
	motion.name = "Leap"
	motion.Configure(Tune.PLAYER_MODEL_SCALE, Tune.LEAP_DIP_DEPTH, Tune.LEAP_DIP_DROP,
		Tune.LEAP_DIP_FREQ, Tune.LEAP_DIP_ZETA, Tune.LEAP_DIP_LEAN,
		Tune.LEAP_SPLIT, Tune.LEAP_POINT, Tune.LEAP_ARMS, Tune.LEAP_CHEST)
	skeleton.add_child(motion)
	leap._motion = motion
	return leap


## She has landed: spring the crouch on the lead leg, deeper for a harder drop.
func dip(power: float, left: bool) -> void:
	if _motion:
		_motion.Dip(power, left)


## Flat-ground flight duration from the jump impulse and the game's gravity.
static func airtime(rise: float) -> float:
	var g := Tune.GRAVITY
	var band := minf(Tune.APEX_SPEED, rise)
	var up := (rise - band) / g
	var hang := band / (g * Tune.APEX_HANG)
	var left := (rise * rise - band * band) / (2.0 * g)
	var fall_g := g * Tune.FALL_GRAVITY
	var down := (-band + sqrt(band * band + 2.0 * fall_g * left)) / fall_g
	return up + hang * 2.0 + down


## Time leads until LEAP_REACH_HOLD; then the arriving ground finishes the reach.
static func flight_progress(air_time: float, flight: float, drop: float) -> float:
	var by_time := maxf(air_time / maxf(flight, 0.1), 0.0)
	if by_time < Tune.LEAP_REACH_HOLD:
		return by_time
	var near := 1.0 - clampf(drop / Tune.LEAP_REACH_HEIGHT, 0.0, 1.0)
	return lerpf(Tune.LEAP_REACH_HOLD, 1.0, near)


## One step of the underdamped landing spring: displacement and velocity.
static func spring(x: float, v: float, dt: float) -> Vector2:
	var w := Tune.LEAP_DIP_FREQ
	var z := Tune.LEAP_DIP_ZETA
	var steps := maxi(1, ceili(dt * 240.0))
	var h := dt / float(steps)
	for i in steps:
		v += (-w * w * x - 2.0 * z * w * v) * h
		x += v * h
	return Vector2(x, v)


static func dip_kick(depth: float) -> float:
	return 2.0 * depth * Tune.LEAP_DIP_FREQ


static func knee_fold(a: float, b: float, span: float, drop: float) -> float:
	var lo := absf(a - b) + 0.001
	var hi := a + b - 0.001
	var now := acos(clampf((a * a + b * b - pow(clampf(span, lo, hi), 2.0)) / (2.0 * a * b), -1.0, 1.0))
	var then := acos(clampf((a * a + b * b - pow(clampf(span - drop, lo, hi), 2.0)) / (2.0 * a * b), -1.0, 1.0))
	return now - then


static func line(through: float, strength: float) -> Dictionary:
	var p := clampf(through, 0.0, 1.0)
	var swell := strength * sin(PI * clampf(p / 0.8, 0.0, 1.0))
	return {
		"split": Tune.LEAP_SPLIT * swell,
		"straighten": 0.7 * swell,
		"point_trail": Tune.LEAP_POINT * strength,
		"point_lead": Tune.LEAP_POINT * strength * lerpf(1.0, 0.25, smoothstep(0.75, 1.0, p)),
		"arms": Tune.LEAP_ARMS * swell,
		"chest": Tune.LEAP_CHEST * strength * (1.0 - smoothstep(0.8, 1.0, p)),
	}

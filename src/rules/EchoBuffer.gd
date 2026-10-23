class_name EchoBuffer
extends RefCounted
## Rolling history of a player's recent movement (2.5 s at 10 Hz) plus discrete action events.
## Lives on the server only. Payload is sent once per Echo cast.

const DURATION := 6.0
const INTERVAL := 0.1
const EVT_FIRE := 1
const EVT_DASH := 2

var times: Array[float] = []
var positions: Array[Vector3] = []
var yaws: Array[float] = []
var pitches: Array[float] = []
var events: Array = []  # [t, kind, yaw, pitch]
var _last_t := -1.0


func push(t: float, pos: Vector3, yaw: float, pitch: float) -> void:
	if _last_t >= 0.0 and t - _last_t < INTERVAL - 0.0001:
		return
	_last_t = t
	times.append(t)
	positions.append(pos)
	yaws.append(yaw)
	pitches.append(pitch)
	_trim(t)


func push_event(t: float, kind: int, yaw: float, pitch: float) -> void:
	events.append([t, kind, yaw, pitch])
	_trim(t)


func _trim(now: float) -> void:
	var cutoff := now - DURATION
	while times.size() > 0 and times[0] < cutoff - 0.0001:
		times.pop_front()
		positions.pop_front()
		yaws.pop_front()
		pitches.pop_front()
	while events.size() > 0 and events[0][0] < cutoff - 0.0001:
		events.pop_front()


func sample_count() -> int:
	return times.size()


## True when the recorded history spans at least `seconds`.
func has_span(seconds: float) -> bool:
	return times.size() >= 2 and (times[times.size() - 1] - times[0]) >= seconds


## Interpolated sample at absolute time t (clamped to the recorded range).
func sample_abs(t: float) -> Dictionary:
	var n := times.size()
	if n == 0:
		return {"pos": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0}
	if t <= times[0] or n == 1:
		return {"pos": positions[0], "yaw": yaws[0], "pitch": pitches[0]}
	if t >= times[n - 1]:
		return {"pos": positions[n - 1], "yaw": yaws[n - 1], "pitch": pitches[n - 1]}
	var i := 1
	while i < n - 1 and times[i] < t:
		i += 1
	var span := times[i] - times[i - 1]
	var a := 0.0 if span <= 0.0 else clampf((t - times[i - 1]) / span, 0.0, 1.0)
	return {"pos": positions[i - 1].lerp(positions[i], a), "yaw": lerp_angle(yaws[i - 1], yaws[i], a), "pitch": lerpf(pitches[i - 1], pitches[i], a)}


func clear() -> void:
	times.clear()
	positions.clear()
	yaws.clear()
	pitches.clear()
	events.clear()
	_last_t = -1.0


## Compact, self-contained payload: times are relative to the oldest sample.
func payload() -> Dictionary:
	if times.is_empty():
		return {}
	var t0 := times[0]
	var rel := PackedFloat32Array()
	for t in times:
		rel.append(t - t0)
	var evs := []
	for e in events:
		if e[0] >= t0:
			evs.append([e[0] - t0, e[1], e[2], e[3]])
	return {
		"t": rel,
		"pos": PackedVector3Array(positions),
		"yaw": PackedFloat32Array(yaws),
		"pitch": PackedFloat32Array(pitches),
		"events": evs,
		"duration": rel[rel.size() - 1],
	}


## Interpolated sample at relative time rt from a payload.
static func sample_at(p: Dictionary, rt: float) -> Dictionary:
	var ts: PackedFloat32Array = p["t"]
	var pos: PackedVector3Array = p["pos"]
	var yaw: PackedFloat32Array = p["yaw"]
	var pitch: PackedFloat32Array = p["pitch"]
	var n := ts.size()
	if n == 0:
		return {"pos": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0}
	if rt <= ts[0] or n == 1:
		return {"pos": pos[0], "yaw": yaw[0], "pitch": pitch[0]}
	if rt >= ts[n - 1]:
		return {"pos": pos[n - 1], "yaw": yaw[n - 1], "pitch": pitch[n - 1]}
	var i := 1
	while i < n - 1 and ts[i] < rt:
		i += 1
	var span := ts[i] - ts[i - 1]
	var a := 0.0 if span <= 0.0 else clampf((rt - ts[i - 1]) / span, 0.0, 1.0)
	return {
		"pos": pos[i - 1].lerp(pos[i], a),
		"yaw": lerp_angle(yaw[i - 1], yaw[i], a),
		"pitch": lerpf(pitch[i - 1], pitch[i], a),
	}

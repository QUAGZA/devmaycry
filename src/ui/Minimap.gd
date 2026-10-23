class_name Minimap
extends Control
## Top-down tactical drawing of the current arena: geometry footprints, objectives, traversal
## features, temporal props, teammates, the local player and ONLY enemies currently in line of sight of
## a living teammate (no permanent reveal). `full` draws the whole map north-up; otherwise a heading-up
## view of `view_radius` metres around the local player (clipped to a circle by the HUD mask shader).

var full := false
var view_radius := 42.0
var _seen: Dictionary = {}
var _seen_t := 0.0
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.mono_font()


func _process(delta: float) -> void:
	_seen_t -= delta
	if _seen_t <= 0.0:
		_seen_t = 0.25
		_update_seen()
	queue_redraw()


func _update_seen() -> void:
	var lp := Game.local_player
	if lp == null or not is_instance_valid(lp) or Game.world == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var space := Game.world.get_world_3d().direct_space_state
	for enemy: Player in Game.players.values():
		if not is_instance_valid(enemy) or enemy == lp or not enemy.alive:
			continue
		if lp.team != 0 and enemy.team == lp.team:
			continue
		for mate: Player in Game.players.values():
			if not is_instance_valid(mate) or not mate.alive:
				continue
			if mate != lp and (lp.team == 0 or mate.team != lp.team):
				continue
			if mate.global_position.distance_to(enemy.global_position) > 70.0:
				continue
			var q := PhysicsRayQueryParameters3D.create(mate.eye_position(), enemy.global_position + Vector3(0, 1.2, 0), 1, [mate.get_rid()])
			if space.intersect_ray(q).is_empty():
				_seen[enemy.id] = now
				break


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, 0.86 if full else 0.72))
	if Game.world == null or Game.map_def == null:
		return
	var def: MapDef = Game.map_def
	var lp := Game.local_player
	var center := size * 0.5
	var scale := 1.0
	var rot := 0.0
	var origin := Vector2.ZERO
	if full:
		var ext: Vector2 = def.extent
		scale = minf(size.x / (ext.x * 2.15), size.y / (ext.y * 2.15))
	else:
		scale = (size.x * 0.5) / view_radius
		if lp != null and is_instance_valid(lp):
			origin = Vector2(lp.global_position.x, lp.global_position.z)
			var fwd := Vector2(-sin(lp.yaw), -cos(lp.yaw))
			rot = -PI / 2.0 - fwd.angle()
	var xf := Transform2D(rot, Vector2(scale, scale), 0.0, center)
	# grid
	var step := 10.0
	var grid_col := Color(Palette.STONE, 0.1)
	var ext2: Vector2 = def.extent
	var gx := -ext2.x
	while gx <= ext2.x:
		draw_line(xf * (Vector2(gx, -ext2.y) - origin), xf * (Vector2(gx, ext2.y) - origin), grid_col, 1.0)
		gx += step
	var gz := -ext2.y
	while gz <= ext2.y:
		draw_line(xf * (Vector2(-ext2.x, gz) - origin), xf * (Vector2(ext2.x, gz) - origin), grid_col, 1.0)
		gz += step
	# arena boundary: authored floor polygons (real topology) or the legacy rectangle
	draw_set_transform_matrix(xf)
	if not def.floor_polys.is_empty():
		for fp in def.floor_polys:
			var pts: PackedVector2Array = fp["pts"]
			var shifted := PackedVector2Array()
			for q in pts:
				shifted.append(q - origin)
			var fy: float = fp["y"]
			var shade := Color(Palette.PORCELAIN, 0.10) if absf(fy) < 0.3 else (Color(Palette.MINT, 0.16) if fy > 0.0 else Color(Palette.COBALT, 0.22))
			draw_colored_polygon(shifted, shade)
	else:
		draw_rect(Rect2(-ext2 - origin, ext2 * 2.0), Color(Palette.STONE, 0.5), false, 2.0 / scale)
	draw_set_transform_matrix(Transform2D())
	# geometry footprints
	for f in def.footprints:
		var n: Node3D = f["node"]
		if not is_instance_valid(n):
			continue
		var p := Vector2(n.global_position.x, n.global_position.z) - origin
		if not full and p.length() > view_radius * 1.6:
			continue
		var local_xf := Transform2D(rot - n.rotation.y, Vector2(scale, scale), 0.0, xf * p)
		draw_set_transform_matrix(local_xf)
		var w: float = f["w"]
		var d: float = f["d"]
		var col := Color(Palette.PORCELAIN, 0.22) if f["kind"] == "ramp" else Color(Palette.STONE, 0.55)
		if f["kind"] == "cyl":
			draw_circle(Vector2.ZERO, w * 0.5, col)
		else:
			draw_rect(Rect2(-w * 0.5, -d * 0.5, w, d), col)
	draw_set_transform_matrix(Transform2D())
	var live := Game.live
	# stability fields
	for i in def.fields.size():
		var fd: Dictionary = def.fields[i]
		var fp: Vector3 = fd["position"]
		var rem := 7.0
		var lf: Array = live.get("fields", [])
		if i < lf.size():
			rem = float(lf[i].get("remaining", 7.0))
		var c := Palette.MINT if rem > 0.0 else Palette.STONE
		var sp := xf * (Vector2(fp.x, fp.z) - origin)
		draw_arc(sp, float(fd.get("radius", 15.0)) * scale, 0.0, TAU, 48, Color(c, 0.9), 2.0)
		draw_circle(sp, float(fd.get("radius", 15.0)) * scale, Color(c, 0.08))
		if full:
			draw_string(_font, sp + Vector2(-26, -4), "FIELD %s %0.1fs" % [["A", "B"][i % 2], rem], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
	# vault / stabilizer
	if live.has("vault"):
		var v: Vector3 = live["vault"]
		var sp := xf * (Vector2(v.x, v.z) - origin)
		draw_rect(Rect2(sp - Vector2(6, 6), Vector2(12, 12)), Palette.COBALT)
		if full:
			draw_string(_font, sp + Vector2(10, 4), "VAULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.COBALT)
	if live.has("stabilizer"):
		var s: Vector3 = live["stabilizer"]
		var sp := xf * (Vector2(s.x, s.z) - origin)
		draw_arc(sp, 7.0, 0.0, TAU, 24, Palette.MINT, 2.5)
		draw_arc(sp, 3.0, 0.0, TAU, 16, Palette.MINT, 2.0)
		if full:
			draw_string(_font, sp + Vector2(10, 4), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.MINT)
	# features
	for fe in def.features.get_children():
		if not (fe is Node3D):
			continue
		var fp := Vector2(fe.global_position.x, fe.global_position.z) - origin
		if fe is Features.PhaseGate:
			var sp := xf * fp
			draw_arc(sp, 5.0, 0.0, TAU, 16, Palette.MINT, 2.0)
			draw_string(_font, sp + Vector2(-4, 4), fe.gate_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.MINT)
		elif fe is Features.Zipline:
			draw_line(xf * (Vector2(fe.a.x, fe.a.z) - origin), xf * (Vector2(fe.b.x, fe.b.z) - origin), Palette.BRASS, 2.0)
		elif fe is Features.VectorSling:
			var sp := xf * fp
			var tp := xf * (Vector2(fe.target.x, fe.target.z) - origin)
			draw_line(sp, tp, Color(Palette.VERMILION, 0.6), 1.5)
			draw_circle(sp, 4.0, Palette.VERMILION)
			draw_arc(tp, 4.0, 0.0, TAU, 12, Palette.VERMILION, 1.5)
	for tp in def.temporal_props:
		if is_instance_valid(tp):
			var sp := xf * (Vector2(tp.global_position.x, tp.global_position.z) - origin)
			var c := Palette.PORCELAIN if tp.state == "intact" or tp.state == "damaged" else (Palette.COBALT if tp.state.begins_with("restored") else Color(Palette.STONE, 0.4))
			draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), c)
	# core
	var core: Dictionary = live.get("core", {})
	if not core.is_empty():
		var cm := str(core.get("mode", ""))
		var cp: Vector3 = core.get("pos", Vector3.ZERO)
		if cm == "carried":
			var c = Game.players.get(int(core.get("carrier", 0)))
			if c != null and is_instance_valid(c):
				cp = c.global_position
		var sp := xf * (Vector2(cp.x, cp.z) - origin)
		var k := clampf(float(core.get("v", 0.0)) / 100.0, 0.0, 1.0)
		var cc := Palette.COBALT if cm == "locked" else Palette.MINT.lerp(Palette.VERMILION, k)
		draw_circle(sp, 6.0, cc)
		draw_arc(sp, 9.0, 0.0, TAU, 20, Color(cc, 0.7), 2.0)
	# players
	var now := Time.get_ticks_msec() / 1000.0
	for pl: Player in Game.players.values():
		if not is_instance_valid(pl) or not pl.alive:
			continue
		var pp := Vector2(pl.global_position.x, pl.global_position.z) - origin
		var sp := xf * pp
		var is_mate := lp != null and is_instance_valid(lp) and (pl == lp or (lp.team != 0 and pl.team == lp.team))
		if is_mate:
			var heading := rot + atan2(-sin(pl.yaw), -cos(pl.yaw)) + PI / 2.0 - PI / 2.0
			var fwd := Vector2(-sin(pl.yaw), -cos(pl.yaw)).rotated(rot)
			var tri := PackedVector2Array([sp + fwd * 9.0, sp + fwd.rotated(2.5) * 7.0, sp + fwd.rotated(-2.5) * 7.0])
			draw_colored_polygon(tri, Palette.PORCELAIN if pl == lp else pl.color)
			if full and pl != lp:
				draw_string(_font, sp + Vector2(10, 4), pl.pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, pl.color)
		elif _seen.has(pl.id) and now - float(_seen[pl.id]) < 2.0:
			var dm := PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(6, 0), sp + Vector2(0, 7), sp + Vector2(-6, 0)])
			draw_colored_polygon(dm, Palette.VERMILION)
	# heading indicator
	if not full:
		var north := Vector2(0, -1).rotated(rot)
		draw_string(_font, center + north * (size.x * 0.5 - 16.0) - Vector2(5, -5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.BRASS)
	else:
		draw_string(_font, Vector2(12, 20), "%s / NORTH UP / CAPS LOCK OR ESC TO CLOSE" % def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.PORCELAIN)

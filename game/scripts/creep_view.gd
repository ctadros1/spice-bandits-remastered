extends RefCounted

# Reviewed against isolated ARM execution in native-creep-reference.json.
# These are separate drawn positions; targeting keeps the logical position.
const DIRECTIONS = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, 0), Vector2(-1, 0)]
const SEMI_DIRECTIONS = [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0)]
const SEMI_NAMES = ["TurnDownLeft", "TurnDownRight", "TurnUpLeft", "TurnUpRight", "TurnLeft", "TurnRight"]
const ROUND_FLAGS = [
	[0, 1, 1, 1, 1, 1, 0, 0], [1, 0, 1, 1, 1, 1, 0, 0],
	[1, 0, 0, 1, 0, 1, 0, 0], [0, 1, 1, 0, 1, 0, 0, 0],
	[1, 0, 0, 1, 0, 1, 0, 0], [0, 1, 1, 0, 1, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]]
const FROM_SEMI = [
	[-1, 0, 0, 0, 1, 0, 0, 0], [1, 0, -1, 0, 0, 0, 0, 0],
	[0, 1, 0, 0, -1, 0, 0, 0], [0, -1, 0, 1, 0, 0, 0, 0],
	[0, 0, -1, 1, -1, 1, 0, 0], [0, 0, 1, -1, 1, -1, 0, 0]]
const TO_SEMI = [
	[1, 0, 1, -1, -1, 1, 0, 0], [-1, 0, 1, -1, -1, 1, 0, 0],
	[0, -1, 1, -1, -1, 1, 0, 0], [0, 1, 1, -1, -1, 1, 0, 0],
	[0, 0, 1, -1, 1, -1, 0, 0], [0, 0, -1, 1, -1, 1, 0, 0]]

static func f32(value: float) -> float: return Vector2(value,0.0).x

static func movement_tick(start: Vector2, target: Vector2, future: Vector2, p: float, carry: float, speed: float, dt: float, hex_height: float) -> Dictionary:
	return SpiceNative.movement_tick(start,target,future,p,carry,speed,dt,hex_height)

static func reference_movement_tick(start: Vector2, target: Vector2, future: Vector2, p: float, carry: float, speed: float, dt: float, hex_height: float) -> Dictionary:
	# CCreep::UpdateMovementAndShooting0x7bfa8. A boundary consumes its
	# own frame. Overshoot carries the whole increment, capped at0.3.
	p = f32(p)
	carry = f32(carry)
	var transitioned = p >= 1.0 or start == target
	if transitioned:
		start = target
		target = future
		p = carry
		carry = 0.0
	else:
		var length = f32(start.distance_to(target))
		var factor = f32(hex_height/length) if length != 0 else 1.0
		var increment = f32(f32(f32(float(dt)/1000.0)*f32(speed/1000.0))*factor)
		p = f32(p+increment)
		if p > 1.0:
			p = 1.0
			carry = minf(increment, f32(0.3))
	var pos = Vector2(f32(start.x+f32(f32(target.x-start.x)*p)), f32(start.y+f32(f32(target.y-start.y)*p)))
	return {"progress": p, "carry": carry, "position": pos, "start": start, "target": target, "transitioned": transitioned}

static func signed(v: Vector2) -> Vector2:
	return Vector2(0 if absf(v.x) < 0.05000000074505806 else signf(v.x), 0 if absf(v.y) < 0.05000000074505806 else signf(v.y))

static func can_round(current: Vector2, future: Vector2) -> bool:
	var a = DIRECTIONS.find(current)
	var b = DIRECTIONS.find(future)
	return a >= 0 and b >= 0 and int(ROUND_FLAGS[a][b]) == 1

static func corner_end(target: Vector2, future: Vector2, progress: float) -> Vector2:
	var delta = future-target
	var length = f32(delta.length())
	if length == 0: return target
	var amount = f32(length*f32(1.0-progress))
	var direction = Vector2(f32(delta.x/length), f32(delta.y/length))
	return Vector2(f32(target.x+f32(direction.x*amount)), f32(target.y+f32(direction.y*amount)))

static func position(logical: Vector2, start: Vector2, end: Vector2, progress: float) -> Vector2:
	if progress > 0.25 and progress < 0.75: return logical
	var delta = end-start
	var length = f32(delta.length())
	# The original divides by zero for a degenerate reverse corner. Retain
	# the finite logical position so a reconstructed replay cannot become NaN.
	if length == 0: return logical
	var direction = Vector2(f32(delta.x/length), f32(delta.y/length))
	var projected = 0.0
	if progress >= 0.75:
		var offset = logical-start
		projected = f32(f32(f32(delta.x*offset.x)+f32(delta.y*offset.y))/length)
	else:
		var reverse = start-end
		var offset = logical-end
		var backwards = f32(f32(f32(reverse.x*offset.x)+f32(reverse.y*offset.y))/length)
		if backwards <= 0: return logical
		projected = f32(length-backwards)
	return Vector2(f32(start.x+f32(direction.x*projected)), f32(start.y+f32(direction.y*projected)))

static func turn_values(progress: float, semi: Vector2, current: Vector2) -> Dictionary:
	progress = f32(progress)
	var row = SEMI_DIRECTIONS.find(semi)
	var column = DIRECTIONS.find(current)
	var direction = 0
	var p = 0.0
	if progress < 0.25:
		p = progress
		if row >= 0 and column >= 0: direction = int(FROM_SEMI[row][column])
	elif progress >= 0.5:
		p = f32(progress-0.5)
		if row >= 0 and column >= 0: direction = int(TO_SEMI[row][column])
	if p >= 0.125:
		var blend = minf(1, f32(f32(p-0.125)*8))
		return {"rotation": f32(f32(float(-direction)*15)*f32(1-blend)), "alpha": 1.0, "blend_rotation": 0.0, "blend_alpha": 0.0}
	var blend = f32(p*8)
	var alpha = f32(blend*1.5)
	return {"rotation": f32(f32(float(direction)*15)*blend), "alpha": maxf(0, f32(1-alpha)),
		"blend_rotation": f32(float(-direction)*f32(30-f32(blend*15))), "blend_alpha": minf(1, alpha)}

static func progress(sim, e: Dictionary) -> float:
	if e.has("move_progress"): return float(e.move_progress)
	if int(e.path_at) >= e.path.size(): return 1.0
	var target = sim.center(e.path[e.path_at].x, e.path[e.path_at].y)
	var start: Vector2 = e.get("move_start", sim.center(e.cell.x, e.cell.y))
	var length = start.distance_to(target)
	return f32(clampf(start.distance_to(e.pos)/length, 0, 1)) if length > 0 else 1.0

static func prepare(sim, e: Dictionary) -> void:
	var p = progress(sim, e)
	if p > 0.25 and p < 0.75 and e.has("corner"): e.corner.enabled = false
	if e.attacking: return
	var future_at=int(e.path_at)+1
	if future_at>=e.path.size():
		if p>=0.5 and e.has("semi"):e.semi.enabled=false
		return
	var peek={"path":e.path,"path_at":future_at,"cell":e.path[e.path_at],"disco_until":e.disco_until,"bombing":e.get("bombing",false),"def":e.def}
	if not sim.movement_point_allowed(peek):
		if p >= 0.5 and e.has("semi"): e.semi.enabled = false
		return
	var key = int(e.path_at)
	var target = sim.center(e.path[key].x, e.path[key].y)
	var future = sim.center(e.path[key+1].x, e.path[key+1].y)
	var incoming = signed(target-e.get("move_start", sim.center(e.cell.x, e.cell.y)))
	var outgoing = signed(future-target)
	var enabled = can_round(incoming, outgoing)
	if p >= 0.5 and int(e.get("semi_key", -1)) != key:
		e.semi_key = key
		e.semi = {"enabled": enabled, "direction": signed(corner_end(target, future, p)-e.pos), "incoming": incoming, "outgoing": outgoing}
	if p >= 0.75 and int(e.get("corner_key", -1)) != key:
		e.corner_key = key
		e.corner = {"enabled": enabled, "start": e.pos, "end": corner_end(target, future, p)}

static func update(sim, e: Dictionary) -> void:
	var p = progress(sim, e)
	var corner = e.get("corner", {})
	e.visual_pos = position(e.pos, corner.start, corner.end, p) if not e.attacking and corner.get("enabled", false) else e.pos
	var normal = sim.creep_animation(e)
	var values = {"rotation": 0.0, "alpha": 1.0, "blend_rotation": 0.0, "blend_alpha": 0.0}
	var primary = normal
	var secondary = normal
	var semi = e.get("semi", {})
	var physical = int(e.def.traits.get("dir_interpolation", 1 if bool(e.native_air) else 0)) == 1
	if physical and not e.attacking and semi.get("enabled", false):
		var index = SEMI_DIRECTIONS.find(semi.direction)
		if index >= 0:
			if p >= 0.5 and p < 0.75:
				values = turn_values(p, semi.direction, semi.incoming)
				if p < 0.625: secondary = SEMI_NAMES[index]
				else: primary = SEMI_NAMES[index]
			elif p >= 0.75: primary = SEMI_NAMES[index]
			elif p > 0 and p < 0.25 and corner.get("enabled", false):
				values = turn_values(p, semi.direction, semi.outgoing)
				if p < 0.125: primary = SEMI_NAMES[index]
	var states = [primary, secondary]
	var ages = e.get("anim_age", [{"state": "", "born": sim.clock_ms}, {"state": "", "born": sim.clock_ms}])
	for i in range(2):
		if ages[i].state != states[i]: ages[i] = {"state": states[i], "born": sim.clock_ms}
	e.anim_age = ages
	e.visual_layers = [{"state": primary, "rotation": values.rotation, "alpha": values.alpha, "born": ages[0].born},
		{"state": secondary, "rotation": values.blend_rotation, "alpha": values.blend_alpha, "born": ages[1].born}]

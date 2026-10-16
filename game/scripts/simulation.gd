class_name BanditSimulation
extends RefCounted

const PortalView=preload("res://scripts/portal_view.gd")
const CreepPortal=preload("res://scripts/creep_portal_view.gd")
const CreepHit=preload("res://scripts/creep_hit_view.gd")
const CreepFreeze=preload("res://scripts/creep_freeze_view.gd")
var reference_spawn_presentation=false

const CreepView = preload("res://scripts/creep_view.gd")
const CreepLight = preload("res://scripts/creep_light_view.gd")
const Targeting = preload("res://scripts/targeting.gd")
const STEP_MS = 30
const ROOT_TYPES = [1, 4, 7, 10, 13, 16]
const WALK_ANIMATIONS = {
	Vector2i(0, -1): "RunUp", Vector2i(0, 1): "RunDown",
	Vector2i(1, 0): "TurnRight", Vector2i(-1, 0): "TurnLeft",
	Vector2i(1, -1): "RunUpRight", Vector2i(-1, -1): "RunUpLeft",
	Vector2i(1, 1): "RunDownRight", Vector2i(-1, 1): "RunDownLeft"
}
# UpdateShootingDirection 0x7dcac: std::map lexical order breaks ties.
const AIM_ANIMATIONS = {
	"RunDown": Vector2(0, 1), "RunDownLeft": Vector2(-0.9050999879837036, 0.4250999987125397),
	"RunDownRight": Vector2(0.9050999879837036, 0.4250999987125397), "RunUp": Vector2(0, -1),
	"RunUpLeft": Vector2(-0.9050999879837036, -0.4250999987125397), "RunUpRight": Vector2(0.9050999879837036, -0.4250999987125397),
	"TurnDownLeft": Vector2(-0.5027999877929688, 0.864300012588501), "TurnDownRight": Vector2(0.5027999877929688, 0.864300012588501),
	"TurnLeft": Vector2(-1, 0), "TurnRight": Vector2(1, 0),
	"TurnUpLeft": Vector2(-0.5027999877929688, -0.864300012588501), "TurnUpRight": Vector2(0.5027999877929688, -0.864300012588501)
}
var catalog: Dictionary
var map: Dictionary
var config: Dictionary
var upgrades: Dictionary = {}
var unlocks: Array = []
var abilities: Dictionary = {}
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var bases: Array[Dictionary] = []
var sources: Array[Dictionary] = []
var running_waves: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var animations: Dictionary = {}
var enemy_missiles: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var portals: Array[Dictionary] = []
var static_portals: Array[Dictionary] = []
var events: Array[Dictionary] = []
var replay: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var money: float = 200.0
var clock_ms: int = 0
var water_phase = 0.0
var accumulator: int = 0
var next_wave_ms: int = 0
var wave_index: int = 0
var kills: int = 0
var score: float = 0.0
var built_count: int = 0
var upgrade_top_count = 0
var kill_chain = 0
var closed_kill_chain = 0
var kill_chain_idle_ms = 0
var early_wave_count: int = 0
var outcome: String = "playing"
var paused: bool = false
var freeze_state=CreepFreeze.initial()
# Compatibility deadline for UI/renderer poses; the source decrements an
# integer countdown with float32 subtraction in ProcessPlayers.
var freeze_until:int:
	get:return clock_ms+int(freeze_state.remaining) if int(freeze_state.remaining)>0 else 0
	set(value):
		freeze_state.remaining=maxi(0,value-clock_ms)
		if int(freeze_state.remaining)>0:
			for enemy in enemies:CreepFreeze.apply(enemy,1)
var disco_until: int = 0
var defense_until: int = 0
var last_paths_ms: int = 0
var pending_towers: Array[int] = []
var next_id: int = 1
var path_cache: Dictionary = {}
var route_cost_cache: Dictionary = {}
var displacement_owners: Dictionary = {}
var build_overrides: Dictionary = {}
var penalty_ground: PackedFloat32Array = PackedFloat32Array()
var penalty_air: PackedFloat32Array = PackedFloat32Array()
var penalty_signature: String = ""
var rng = RandomNumberGenerator.new()
var discrepancies: Array[String] = []
var tutorial_finished: bool = true
var spawn_hold = false
var survival_remaining_ms: int = 0
var tick_ms: float = STEP_MS
var live_updates = false
var step_lookup_active = false
var step_support: Array[Dictionary] = []
var step_enemies: Dictionary = {}
var cell_positions: PackedVector2Array = PackedVector2Array()
var profile_hotpaths: bool = false
var hotpath_timings: Dictionary = {}

func timed_section(key: String, started: int) -> int:
	var now = Time.get_ticks_usec()
	if profile_hotpaths:
		var row = hotpath_timings.get(key, {"total_usec": 0, "calls": 0})
		row.total_usec += now-started
		row.calls += 1
		hotpath_timings[key] = row
	return now

func setup(data: Dictionary, map_data: Dictionary, mission: Dictionary, profile: Dictionary, seed: int = 114, animation_data: Dictionary = {}) -> void:
	catalog = data
	animations = animation_data
	map = map_data
	cell_positions.clear()
	for y in range(int(map.hex_height)):
		for x in range(int(map.hex_width)):cell_positions.append(raw_center(x,y))
	config = mission
	water_phase = 0.0
	upgrades = profile.get("upgrades", {}).duplicate(true)
	unlocks = profile.get("unlocks", []).duplicate()
	abilities = profile.get("abilities", {}).duplicate(true)
	rng.seed = seed
	for b in config.bases:
		var item = b.duplicate(true)
		item.pos = center(int(b.x), int(b.y))
		item.hp = float(b.hp)
		item.hpmax = float(b.get("hpmax", b.hp))
		bases.append(item)
	for s in config.sources:
		var item = s.duplicate(true)
		item.pos = center(int(s.x), int(s.y))
		sources.append(item)
	if int(config.settings.get("build_around_base", 0)) == 0:
		# CBase ctor 0x75720 clears build flags on ordinary linked cells.
		for b in bases:
			for cell in ordinary_links(Vector2i(int(b.x), int(b.y))): build_overrides[cell_index(cell)] = 0
	for b in bases: b.bomb_circles = construct_bomb_circles(Vector2i(int(b.x), int(b.y)))
	next_wave_ms = int(config.get("wavedelay", 30000))
	survival_remaining_ms = int(config.settings.get("survive_time", 0))*60000
	for point in config.settings.get("mines", []):
		mines.append({"pos": center(int(point.x), int(point.y)), "cell": Vector2i(int(point.x), int(point.y)), "ready": int(catalog.tower_magic.mine_sleep), "static": true})
	for pair in config.settings.get("teleports", []):
		var presentation=PortalView.create(float(catalog.tower_magic.portal_reload),float(catalog.tower_magic.portal_duration),true)
		PortalView.connect_gates(presentation)
		static_portals.append({"in": Vector2i(int(pair["in"].x), int(pair["in"].y)), "out": Vector2i(int(pair.out.x), int(pair.out.y)),"presentation":presentation})
	if int(config.settings.get("tutorial", 0)):
		next_wave_ms = 1000000
		tutorial_finished = false
		spawn_hold = true
		for index in range(map.cells.size()): build_overrides[index] = 0
		for cell in [Vector2i(6, 7), Vector2i(7, 4), Vector2i(8, 6), Vector2i(11, 3)]: build_overrides[cell_index(cell)] = 1
		# CMagicPanel ctor0x96c60 injects all five stocks only in training.
		abilities = {"m_freeze": 5, "m_lsd": 5, "m_actdef": 5, "m_mine": 5, "m_portal": 5}

func f32(value: float) -> float:
	# Vector2 uses32-bit components in the pinned single-precision build;
	# its inline value avoids allocating a byte/float array for each operation.
	return Vector2(value,0.0).x

func center(x: int, y: int) -> Vector2:
	if x>=0 and y>=0 and x<int(map.hex_width) and y<int(map.hex_height) and not cell_positions.is_empty():return cell_positions[y*int(map.hex_width)+x]
	return raw_center(x,y)

func raw_center(x: int, y: int) -> Vector2:
	return Vector2(float(map.hex_offset_x) + float(map.hex_side) + float(map.hex_base)/2.0 + x*float(map.hex_base + map.hex_side),
		float(map.hex_offset_y) + float(map.hex_h)/2.0 + y*float(map.hex_h) + (x%2)*float(map.hex_h)/2.0)

func cell_index(cell: Vector2i) -> int:
	return cell.y * int(map.hex_width) + cell.x

func within(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < int(map.hex_width) and cell.y < int(map.hex_height)

func nearest(pos: Vector2) -> Vector2i:
	var width = float(map.hex_base + map.hex_side)
	var x = int(round((pos.x - float(map.hex_offset_x) - float(map.hex_side) - float(map.hex_base)/2.0)/width))
	var y = int(round((pos.y - float(map.hex_offset_y) - float(map.hex_h)/2.0 - (x%2)*float(map.hex_h)/2.0)/float(map.hex_h)))
	var best = Vector2i(x, y)
	var best_distance = INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c = Vector2i(x+dx, y+dy)
			var d = center(c.x, c.y).distance_squared_to(pos)
			if within(c) and d < best_distance:
				best = c
				best_distance = d
	return best

func neighbours(cell: Vector2i) -> Array[Vector2i]:
	# CHexMap::UpdateCellPositions builds six links, then adds horizontal x±2 links.
	var odd = cell.x % 2
	var deltas = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, -1 if odd == 0 else 1), Vector2i(1, -1 if odd == 0 else 1)]
	if cell.x == 0:
		deltas = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, -1)]
		if cell.y == 0: deltas = [Vector2i(0, 1), Vector2i(1, 0)]
		elif cell.y == int(map.hex_height)-1: deltas = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0)]
	elif cell.x == int(map.hex_width)-1:
		deltas = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1 if odd == 0 else 1), Vector2i(0, 1)]
		if cell.y == 0: deltas = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1)] if odd else [Vector2i(-1, 0), Vector2i(0, 1)]
		elif cell.y == int(map.hex_height)-1: deltas = [Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0)] if not odd else [Vector2i(0, -1), Vector2i(-1, 0)]
	elif cell.y == 0:
		deltas = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
		if odd: deltas.append(Vector2i(1, 1)); deltas.append(Vector2i(-1, 1))
	elif cell.y == int(map.hex_height)-1:
		deltas = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
		if not odd: deltas.append(Vector2i(1, -1)); deltas.append(Vector2i(-1, -1))
	var result: Array[Vector2i] = []
	for delta in deltas + [Vector2i(-2, 0), Vector2i(2, 0)]:
		var n = cell + delta
		if within(n): result.append(n)
	return result

func link_allowed(a: Vector2i, b: Vector2i, air: bool, destination: Vector2i = Vector2i(-1, -1)) -> bool:
	if air or absi(a.x-b.x) != 2: return true
	var middle = Vector2i(int((a.x+b.x)/2), a.y)
	var alternate = middle+Vector2i(0, 1 if middle.x%2 == 0 else -1)
	for cell in [middle, alternate]:
		if within(cell) and not walkable(cell, Vector2i(-1, -1), destination, false): return false
	return true

func tower_at(cell: Vector2i) -> Dictionary:
	for t in towers:
		if t.cell == cell: return t
	return {}

func walkable(cell: Vector2i, start: Vector2i, end: Vector2i, air: bool) -> bool:
	if not within(cell): return false
	if air or cell == start or cell == end: return true
	for b in bases:
		if cell == Vector2i(int(b.x), int(b.y)):
			return b.hp <= 0 or int(config.settings.get("allbaseswalkable", 0)) == 1
	return int(map.cells[cell_index(cell)].get("w", 0)) == 1 and tower_at(cell).is_empty()

func buildable(cell: Vector2i) -> bool:
	return within(cell) and int(build_overrides.get(cell_index(cell), map.cells[cell_index(cell)].get("b", 0))) == 1

func update_penalties() -> void:
	var signature = ""
	for t in towers: signature += "%s:%s:%s:%s;" % [t.id, t.type, t.level, clock_ms >= t.ready_ms]
	if signature == penalty_signature and penalty_ground.size() == map.cells.size(): return
	penalty_signature = signature
	path_cache.clear()
	route_cost_cache.clear()
	penalty_ground.resize(map.cells.size())
	penalty_air.resize(map.cells.size())
	penalty_ground.fill(1.0)
	penalty_air.fill(1.0)
	if int(config.settings.get("dumbcreeps", 0)) == 1: return
	# CMap::MarkTowerCells, 0x103968. These exclusions are the native 0x78828 mask.
	for t in towers:
		if int(t.type) in [3, 5, 11, 15, 16, 17, 18] or clock_ms < t.ready_ms: continue
		var boost = bonuses(t)
		var damage_add = f32(float(t.def.get("damage", 0))*f32(boost.damage-1.0))
		# Preserve the native penalty arithmetic, including adding the support factor to ROF.
		var dps = f32(f32(f32(float(t.def.get("damage", 0))+damage_add)*1000.0)/f32(float(t.def.get("rof", 1000))+boost.rof))
		var ground_add = f32(f32(dps*0.5)*0.20000000298023224)
		var air_add = f32(f32(dps*0.5)*0.15000000596046448)
		for y in range(int(map.hex_height)):
			for x in range(int(map.hex_width)):
				if not in_range(t.pos, center(x, y), float(t.def.range)/1000.0*boost.range): continue
				var at = cell_index(Vector2i(x, y))
				if int(t.def.get("aim", 0)) != 2: penalty_ground[at] = f32(penalty_ground[at]+ground_add)
				if int(t.def.get("aim", 0)) != 1: penalty_air[at] = f32(penalty_air[at]+air_add)

func route(start: Vector2i, end: Vector2i, air: bool = false) -> Array[Vector2i]:
	update_penalties()
	var key = "%d:%d:%s" % [cell_index(start), cell_index(end), air]
	if path_cache.has(key): return path_cache[key].duplicate()
	var result: Array[Vector2i] = []
	if not within(start) or not within(end): return result
	# Original A*: Chebyshev distance in map pixels, f32 cost and strict tie comparison.
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var costs: Dictionary = {start: 0.0}
	var scores: Dictionary = {start: 0.0}
	var closed: Dictionary = {}
	while not queue.is_empty():
		var best_index = 0
		var best_score = INF
		for i in range(queue.size()):
			var candidate_score = float(scores[queue[i]])
			if candidate_score < best_score:
				best_score = candidate_score
				best_index = i
		var current = queue[best_index]
		queue.remove_at(best_index)
		closed[current] = true
		if current == end: break
		for n in neighbours(current):
			if closed.has(n) or not walkable(n, start, end, air) or not link_allowed(current, n, air, end): continue
			var difference = center(n.x, n.y)-center(current.x, current.y)
			var penalty = penalty_air[cell_index(n)] if air else penalty_ground[cell_index(n)]
			var cost = f32(float(costs[current])+f32(maxf(absf(difference.x), absf(difference.y))*penalty))
			# Native 0x105ec4-0x105ed4 compares the open neighbor's g to
			# the CURRENT cell's g. Preserve this unusual rule, not textbook A*.
			if not costs.has(n) or float(costs[n]) < float(costs[current]):
				costs[n] = cost
				var goal_difference = center(n.x, n.y)-center(end.x, end.y)
				scores[n] = f32(cost+maxf(absf(goal_difference.x), absf(goal_difference.y)))
				previous[n] = current
				if n not in queue: queue.append(n)
	if previous.has(end):
		var c = end
		var selection_cost = 0
		while c != start:
			result.push_front(c)
			# Backtracking 0x106180 and 0x106136 adds each f score twice,
			# truncating to uint after each addition. This selects among bases.
			selection_cost = int(f32(float(selection_cost)+float(scores[c])))
			selection_cost = int(f32(float(selection_cost)+float(scores[c])))
			c = previous[c]
		result.push_front(start)
		route_cost_cache[key] = selection_cost
		result = smooth_route(result)
	path_cache[key] = result.duplicate()
	return result

func ordinary_links(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for other in neighbours(cell):
		if absi(other.x-cell.x) != 2: result.append(other)
	return result

func open_cell(cell: Vector2i, destination: Vector2i = Vector2i(-1, -1)) -> bool:
	return walkable(cell, Vector2i(-1, -1), destination, false)

func shared_regular_link(path: Array[Vector2i], start_at: int, count: int) -> Vector2i:
	var counts: Dictionary = {}
	for i in range(start_at, mini(start_at+count, path.size())):
		for link in ordinary_links(path[i]):
			counts[link] = int(counts.get(link, 0))+1
			if int(counts[link]) >= count: return link
	return Vector2i(-1, -1)

func path_regular_links(path: Array[Vector2i], at: int) -> int:
	# CountCellLinksInPath: stop once two links appear in the first four
	# positions, or after the fifth position regardless of count.
	var links = ordinary_links(path[at])
	var count = 0
	for i in range(at, path.size()):
		if path[i] in links: count += 1
		if (i-at < 4 and count > 1) or i-at >= 4: break
	return count

func smooth_route(input: Array[Vector2i]) -> Array[Vector2i]:
	# FindShortestPath 0x106236..0x1065ac runs these passes from goal to
	# source, then reverses. Running them forward changes corner ties.
	var path = input.duplicate()
	path.reverse()
	if path.size() >= 2 and absi(path[0].x-path[1].x) == 2:
		var other_links = neighbours(path[1])
		for link in neighbours(path[0]):
			if link in other_links:
				path.insert(1, link)
				break
	for at in range(path.size()):
		var shared = shared_regular_link(path, at, 3)
		if shared.x < 0 or not open_cell(shared, input[-1]) or at+2 >= path.size(): continue
		if absi(path[at+1].x-path[at+2].x) == 2 or absi(path[at+1].x-path[at].x) == 2: path[at+1] = shared
	var at = 0
	while at < path.size():
		var shared = shared_regular_link(path, at, 4)
		if shared.x >= 0 and open_cell(shared, input[-1]) and at+3 < path.size():
			path.remove_at(at+1)
			path.remove_at(at+1)
			path.insert(at+1, shared)
		at += 1
	at = 0
	while at < path.size():
		while at+1 < path.size() and path_regular_links(path, at) > 1: path.remove_at(at+1)
		at += 1
	path.reverse()
	return path

func route_cost(path: Array[Vector2i], air: bool) -> float:
	if path.is_empty(): return INF
	var key = "%d:%d:%s" % [cell_index(path[0]), cell_index(path[-1]), air]
	if path_cache.has(key) and route_cost_cache.has(key): return float(route_cost_cache[key])
	var cost = 0.0
	for i in range(1, path.size()):
		var difference = center(path[i].x, path[i].y)-center(path[i-1].x, path[i-1].y)
		var penalty = penalty_air[cell_index(path[i])] if air else penalty_ground[cell_index(path[i])]
		cost = f32(cost+f32(maxf(absf(difference.x), absf(difference.y))*penalty))
	return cost

func in_range(a: Vector2, b: Vector2, radius: float) -> bool:
	return SpiceNative.in_range(a, b, radius, float(map.hex_h))

func reference_in_range(a: Vector2, b: Vector2, radius: float) -> bool:
	# Kept as the reviewed scalar reference for native-kernel regression checks.
	if radius <= 0: return false
	var axes = range_axes(radius)
	var dx = f32(b.x-a.x)
	var dy = f32(f32(b.y-a.y)*f32(axes.x/axes.y))
	return f32(f32(dx*dx)+f32(dy*dy)) <= f32(axes.x*axes.x)

func range_axes(radius: float) -> Vector2:
	# CHexMap ctor sets g_fDistBetweenCellsDiv=hex_h/1000.
	# GetNearestCreep multiplies the horizontal semiaxis by g_fTowerCircleProp (f32 1.44).
	var vertical = f32(radius*float(map.hex_h))
	return Vector2(f32(vertical*1.440000057220459), vertical)

func tower_data(type: int, level: int) -> Dictionary:
	var form = catalog.tower_towers[type].duplicate(true)
	var def = form.levels[level - 1]
	form.erase("levels")
	form.merge(def, true)
	for key in catalog.tower_upgrades:
		var u = catalog.tower_upgrades[key]
		var n = int(upgrades.get(key, 0))
		if n <= 0 or not u.has("tower_key"): continue
		var applies = (not u.has("tower_types") or type in u.tower_types) and (not u.has("tower_levels") or level in u.tower_levels)
		if u.has("tower_types2") and u.has("tower_levels2"):
			applies = applies or (type in u.tower_types2 and level in u.tower_levels2)
		if applies and form.has(u.tower_key):
			form[u.tower_key] = f32(float(form[u.tower_key]) * f32(1.0 + float(u.tower_percent)*n/100.0))
	form.type = type
	form.level = level
	return form

func can_unlock(def: Dictionary) -> bool:
	return not def.has("unlock") or str(def.unlock) in unlocks

func build(cell: Vector2i, type: int) -> String:
	if paused or outcome != "playing": return "The game is paused."
	if type not in ROOT_TYPES: return "This form is reached through an upgrade branch."
	if not buildable(cell): return "You cannot build here."
	if not tower_at(cell).is_empty(): return "A tower is already here."
	for b in bases:
		if Vector2i(int(b.x), int(b.y)) == cell: return "Keep the base clear."
	for s in sources:
		if Vector2i(int(s.x), int(s.y)) == cell: return "Keep the entrance clear."
	for pair in static_portals:
		if cell == pair["in"] or cell == pair.out: return "Keep the portal clear."
	for e in enemies:
		if e.hp > 0 and (e.cell == cell or e.next_cell == cell): return "An enemy is using this hex."
	var def = tower_data(type, 1)
	if not can_unlock(def): return "Unlock %s in the Tech Shop." % def.name
	var price = floor(float(def.price))
	if money < price: return "Not enough money."
	var t = {"id": next_id, "type": type, "level": 1, "cell": cell, "pos": center(cell.x, cell.y),
		"player": 1,
		# UpdateParams reinitializes its animator before the depth-copy guard,
		# so original towers retain their construction resource's depth height.
		"depth_filename": def.filename,
		"def": def, "hp": float(def.get("hp", 300)), "ready_ms": clock_ms, "shot_ms": 0,
		"angle": 0.0, "born_ms": clock_ms, "foundation_ms": clock_ms, "reload_ms": 100000.0, "targeting": "fastest", "receipts": [price]}
	next_id += 1
	towers.append(t)
	built_count += 1
	money = f32(money - price)
	pending_towers.append(t.id)
	path_cache.clear()
	record("build", {"x": cell.x, "y": cell.y, "type": type})
	emit("build", {"pos": t.pos, "type": type})
	return ""

func upgrade_options(t: Dictionary) -> Array:
	if int(t.level) < 3: return [[int(t.type), int(t.level)+1]]
	var options = []
	for key in ["u1", "u2"]:
		if t.def.has(key): options.append([int(t.def[key]), 1])
	return options

func upgrade_tower(id: int, type: int, level: int) -> String:
	if paused or outcome != "playing": return "The game is paused."
	var t = find_tower(id)
	if t.is_empty() or [type, level] not in upgrade_options(t): return "Invalid upgrade branch."
	if clock_ms < t.ready_ms: return "Wait for construction."
	var def = tower_data(type, level)
	if not can_unlock(def): return "Unlock %s in the Tech Shop." % def.name
	var cost = floor(float(def.price))
	if money < cost: return "Not enough money."
	money = f32(money - cost)
	# TowerPanel0xef49c/0xf07c8 counts level2->3 upgrades whose new form
	# has no further branch. Selling later does not undo this match counter.
	if int(t.level) == 2 and not def.has("u1") and not def.has("u2"): upgrade_top_count += 1
	t.receipts.append(cost)
	t.merge({"type": type, "level": level, "def": def, "ready_ms": clock_ms, "born_ms": clock_ms}, true)
	if type == 5: t.erase("nuke")
	if type == 3: t.extra_target_delay_ms = rng.randi()%500
	path_cache.clear()
	record("upgrade", {"id": id, "type": type, "level": level})
	emit("upgrade", {"pos": t.pos, "type": type, "level": level})
	return ""

func find_tower(id: int) -> Dictionary:
	for t in towers:
		if t.id == id: return t
	return {}

func sell_price(t: Dictionary) -> int:
	var ratio = float(catalog.tower_sell_return)/100.0 * (1.0 + int(upgrades.get("up_destruct", 0))*0.05)
	var total = 0
	for cost in t.receipts: total += int(floor(f32(float(cost)*ratio)))
	return total

func sell(id: int) -> String:
	if paused or outcome != "playing": return "The game is paused."
	var t = find_tower(id)
	if t.is_empty(): return ""
	var refund = sell_price(t)
	money = f32(money + refund)
	towers.erase(t)
	# CTower destructor0xe3134 destroys its owned missiles, clouds and bubbles.
	missiles = missiles.filter(func(p): return int(p.owner) != id)
	zones = zones.filter(func(z): return int(z.owner) != id)
	bubbles = bubbles.filter(func(b): return int(b.owner) != id)
	pending_towers.erase(id)
	path_cache.clear()
	reroute_all()
	record("sell", {"id": id})
	emit("sell", {"pos": t.pos, "refund": refund})
	return ""

func paths_valid() -> bool:
	for s in sources:
		var reaches = false
		for b in bases:
			if b.hp > 0 and not route(Vector2i(int(s.x), int(s.y)), Vector2i(int(b.x), int(b.y))).is_empty(): reaches = true
		if not reaches: return false
	for e in enemies:
		if e.hp > 0 and not e.air and e.base >= 0 and bases[e.base].hp > 0:
			if route(e.cell, Vector2i(int(bases[e.base].x), int(bases[e.base].y))).is_empty(): return false
	return true

func validate_paths() -> void:
	if pending_towers.is_empty() or clock_ms - last_paths_ms < 250: return
	last_paths_ms = clock_ms
	while not paths_valid() and not pending_towers.is_empty():
		var t = find_tower(pending_towers.pop_back())
		if not t.is_empty():
			for cost in t.receipts: money = f32(money+float(cost))
			towers.erase(t)
			emit("blocked", {"pos": t.pos})
			path_cache.clear()
	pending_towers.clear()
	reroute_all()

func reroute_all() -> void:
	for e in enemies:
		if e.hp <= 0: continue
		set_enemy_path(e)

func set_enemy_path(e: Dictionary) -> void:
	release_displacement(int(e.id))
	# UpdateShortestPath0x7ace0 plans from the current segment's endpoint,
	# while preserving its progress. Blocking the endpoint before the native
	# .7 boundary (.5 for a horizontal shortcut) reverses that segment.
	var original_cell: Vector2i = e.cell
	var endpoint: Vector2i = e.get("next_cell", original_cell)
	var moving = not e.attacking and endpoint != original_cell and int(e.get("path_at", 0)) < e.get("path", []).size()
	var search_cell = original_cell
	if moving:
		var p = CreepView.progress(self, e)
		var next_open = bool(e.air) or open_cell(endpoint)
		var current_open = bool(e.air) or open_cell(original_cell)
		var threshold = 0.5 if absi(endpoint.x-original_cell.x) >= 2 and endpoint.y == original_cell.y else f32(0.7)
		if current_open and not next_open and p < threshold:
			e.cell = endpoint
			e.move_start = center(endpoint.x, endpoint.y)
			e.move_progress = f32(1.0-p)
			endpoint = original_cell
			for key in ["corner", "corner_key", "semi", "semi_key"]: e.erase(key)
		else: e.move_progress = p
		search_cell = endpoint
	else:
		e.move_start = e.pos
		e.visual_pos = e.pos
		e.erase("move_progress")
		e.move_carry = 0.0
		for key in ["corner", "corner_key", "semi", "semi_key"]: e.erase(key)
	e.attacking = false
	e.attack_reload_ms = 0
	e.bombing = false
	e.bomb_dropped_at = -1
	var best_path: Array[Vector2i] = []
	var best_cost = INF
	var target = -1
	if clock_ms < e.get("disco_until", 0):
		var eligible: Array[Vector2i] = []
		for y in range(int(map.hex_height)):
			for x in range(int(map.hex_width)):
				var cell = Vector2i(x, y)
				if int(map.cells[cell_index(cell)].w) == 1 and tower_at(cell).is_empty(): eligible.append(cell)
		for attempt in range(10):
			if eligible.is_empty(): break
			# Decompiled LCG helpers: wrapping 32-bit state, high 15-bit output.
			e.random_state = (int(e.random_state)*214013+2531011) & 0xffffffff
			var ordinal = ((int(e.random_state) >> 16) & 0x7fff) % eligible.size()
			# The original enumeration counts from one; ordinal zero falls back to the last cell.
			var destination = eligible[posmod(ordinal-1, eligible.size())]
			var wandering = route(search_cell, destination, e.air)
			if wandering.size() > 1:
				if moving: wandering.push_front(e.cell)
				e.path = wandering
				e.path_at = 1
				e.next_cell = wandering[1]
				return
	for i in range(bases.size()):
		var b = bases[i]
		if b.hp <= 0: continue
		var destination = Vector2i(int(b.x), int(b.y))
		var candidate = route(search_cell, destination, e.air)
		var candidate_cost = route_cost(candidate, e.air)
		if not candidate.is_empty() and candidate_cost < best_cost:
			best_path = candidate
			best_cost = candidate_cost
			target = i
	# FindPathToBase 0x7b5fc removes the base-center point for every
	# non-kamikaze enemy before GetFirstMovementPoint applies stand-off.
	if best_path.size() > 1 and int(e.def.traits.get("kamikaze", 0)) != 1: best_path.pop_back()
	if moving and not best_path.is_empty(): best_path.push_front(e.cell)
	e.path = best_path
	e.path_at = 1
	e.base = target
	e.next_cell = best_path[1] if best_path.size() > 1 else e.cell

func movement_point_allowed(e: Dictionary) -> bool:
	var remaining = e.path.size()-int(e.path_at)
	if remaining <= 0: return false
	if clock_ms < int(e.disco_until) or bool(e.get("bombing", false)): return true
	var stand_off = int(e.def.base_distance)
	if remaining > stand_off: return true
	# GetFirstMovementPoint 0x7ba04: horizontal links count differently.
	return absi(e.cell.x-e.path[e.path_at].x) == 2 and remaining >= int(floor(float(stand_off)*0.5))

func construct_bomb_circles(base: Vector2i) -> Array:
	# 0x10b078: each ordinary base neighbor is the CENTER of a six-edge
	# ring. Walk its neighboring cells from the base, excluding the prior
	# point; the fixed center is not itself part of the flight path.
	var circles = []
	for pivot in ordinary_links(base):
		var path: Array[Vector2i] = [base]
		var previous = base
		for i in range(5):
			var found = false
			for candidate in ordinary_links(pivot):
				if candidate == previous or path[-1] not in ordinary_links(candidate): continue
				previous = path[-1]
				path.append(candidate)
				found = true
				break
			if not found: break
		if path.size() == 6: path.append(base); circles.append(path)
	return circles

func bomber_circle(current: Vector2i, base_index: int) -> Array[Vector2i]:
	var b = bases[base_index]
	var base_cell = Vector2i(int(b.x), int(b.y))
	var result: Array[Vector2i] = []
	if base_cell.x <= 0 or base_cell.y <= 0 or current not in neighbours(base_cell): return result
	var candidates = ordinary_links(base_cell)
	# GetCirclePath 0x10b258 chooses the farthest ordinary neighbor from
	# the approaching cell, then an eligible ring and its orientation.
	while not candidates.is_empty():
		var chosen = candidates[0]
		var distance = -1.0
		for cell in candidates:
			var value = f32(center(cell.x, cell.y).distance_squared_to(center(current.x, current.y)))
			if value > distance: distance = value; chosen = cell
		candidates.erase(chosen)
		for circle in b.get("bomb_circles", []):
			if circle[1] != chosen and circle[-2] != chosen: continue
			if result.is_empty() or (rng.randi() & 1) == 1: result.assign(circle)
		if not result.is_empty():
			if result[1] != chosen: result.reverse()
			return result
	return result

func launch_enemy_missiles(e: Dictionary, bomb: bool = false) -> void:
	var start=enemy_visual_aim_point(e)
	var count = 1 if bomb else 2
	for i in range(count):
		var destination: Vector2 = bases[e.base].pos
		var origin=SpiceNative.creep_missile_origin(start,destination)
		enemy_missiles.append({"pos": origin, "start":origin,"previous": start, "destination": destination,"body_flag":true,
			"velocity": Vector2.ZERO, "acceleration": Vector2.ZERO, "angle": f32(native_angpos(-e.dir)*57.295780181884766),
			"base": int(e.base), "owner": e.id, "damage": float(e.def.damage)*0.5, "type": e.type, "bomb": bomb})
	emit("enemy_shot", {"from": start, "to": bases[e.base].pos, "type": e.type, "filename": e.def.filename})

func base_damage(index: int, amount: float) -> void:
	var b = bases[index]
	if b.hp <= 0: return
	b.hp = maxf(0.0, f32(b.hp-amount))
	emit("base_hit", {"pos": b.pos, "damage": amount})
	if b.hp <= 0:
		if int(config.settings.get("build_around_base", 0)) == 0:
			for cell in ordinary_links(Vector2i(int(b.x), int(b.y))): build_overrides[cell_index(cell)] = 1
		path_cache.clear()
		reroute_all()

func release_displacement(owner: int) -> void:
	for cell in displacement_owners:
		var slots = displacement_owners[cell]
		for i in range(slots.size()):
			if int(slots[i]) == owner: slots[i] = -1

func displace_point(cell: Vector2i, toward: Vector2, owner: int, fallback: Vector2) -> Vector2:
	# Native rejects the outside edges and offers nine ordered points at h/3.
	if cell.x <= 0 or cell.y <= 0 or not within(cell): return fallback
	var slots = displacement_owners.get(cell, [-1, -1, -1, -1, -1, -1, -1, -1, -1])
	displacement_owners[cell] = slots
	var directions = [Vector2.ZERO, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP]
	var origin = center(cell.x, cell.y)
	var radius = f32(float(map.hex_h)/3.0)
	var best = -1
	var best_distance = INF
	for i in range(directions.size()):
		if int(slots[i]) >= 0: continue
		var pos = origin+directions[i]*radius
		var distance = f32(pos.distance_to(toward))
		if distance < best_distance: best_distance = distance; best = i
	if best < 0: return fallback
	slots[best] = owner
	return origin+directions[best]*radius

func spawn_delay(delay: float) -> int:
	return maxi(0,int(delay)) if live_updates else maxi(STEP_MS,int(ceil(delay/STEP_MS))*STEP_MS)

func next_wave(early: bool = true, already_counted:bool=false) -> void:
	if paused or outcome != "playing" or wave_index >= config.waves.size(): return
	var wave = config.waves[wave_index]
	if early and not already_counted: early_wave_count += 1
	running_waves.append({"index": wave_index, "at": 0, "spawn_ms": clock_ms})
	running_waves[-1].spawn_ms = clock_ms + spawn_delay(float(wave.delay))
	wave_index += 1
	next_wave_ms = clock_ms + int(config.wavedelay)
	record("wave", {"early": early})
	emit("wave", {"index": wave_index, "early": early})

func spawn_enemy(type: int, source_index: int, wave_type: String, enemy_id: int = -1, grow: bool = true) -> Dictionary:
	if type == 0: return {}
	if source_index >= sources.size():
		# ProcessWaves checks the source before AddCreep; absent sources skip the slot.
		var discrepancy = "Config %s source %d is absent; slot skipped by the traced ProcessWaves guard." % [config.configid, source_index]
		if discrepancy not in discrepancies: discrepancies.append(discrepancy)
		return {}
	var def = catalog.tower_creeps[type]
	if not def.has("filename"):
		var warning = "Config %s references undefined enemy %d; AddCreep null-resource guard skips this slot." % [config.configid, type]
		if warning not in discrepancies: discrepancies.append(warning)
		return {}
	# The resource loader uses NSNumber.intValue for all six numeric combat fields.
	def = def.duplicate(true)
	for field in ["hp", "speed", "damage", "price", "rof", "base_distance"]: def[field] = int(def.get(field, 0))
	def.traits = catalog.get("resource_params", {}).get("creeps/"+str(def.filename), {})
	var hp_scale = 1.0 + float(config.settings.get("creep_hp", 0))/100.0
	# Wave type is indicator metadata. The inspected spawn chain does not scale HP/speed by it.
	var speed_scale = 1.0
	var s = sources[source_index]
	var c = Vector2i(int(s.x), int(s.y))
	# LoadCreepsResource reads hp with NSNumber.intValue before construction.
	var hp = f32(float(int(def.hp))*hp_scale)
	var chosen_id = next_id if enemy_id < 0 else enemy_id
	var e = {"id": chosen_id, "random_state": chosen_id, "type": type, "def": def, "hp": hp, "max_hp": hp,
		"owner": int(s.get("neutrality", 0)), "target_owner": int(s.get("target", 0)), "state": 0,
		"speed": f32(float(def.speed)*speed_scale), "cell": c, "next_cell": c, "pos": center(c.x, c.y),
		"dir": Vector2.RIGHT, "source": source_index, "air": def.get("class", "ground") == "air", "native_air": def.get("class", "ground") == "air",
		"base": -1, "path": [], "path_at": 1, "attacking": false, "attack_reload_ms": 0, "attack_point": Vector2.ZERO, "slow": 1.0, "slow_until": 0,
		"float_until": 0, "disco_until": disco_until, "portal_ms": 0, "born_ms": clock_ms, "slow_pending": -1.0,
		"grow_ms": 0 if grow and def.get("class", "ground") == "ground" else 400,"draw_light":1.0,"freeze_attached":false,"freeze_remaining":0,"animation_divisor":1.0,"animation_multiplier":1.0}
	e.merge(CreepHit.initial())
	next_id += 1
	enemies.append(e)
	set_enemy_path(e)
	emit("spawn", {"id": e.id, "type": type})
	return e

func spawn_presentation(e: Dictionary) -> Dictionary:
	# CCreep::ProcessGrowUp 0x7f058 + InterpolateEase 0x110674.
	# Only ground creeps with the constructor flag enabled grow. ProcessWaves
	# supplies true. Freeze does not skip this presentation timer in Update.
	if float(e.grow_ms)>=400.0 and e.has("portal_pose"):
		return {"scale":1.0,"alpha":e.portal_pose.anim_alpha,"native_scale":e.portal_pose.scale}
	if not reference_spawn_presentation and float(e.grow_ms)>=400.0:return {"scale":1.0,"alpha":1.0}
	var t = clampf(f32(float(e.grow_ms)/400.0), 0.0, 1.0)
	var eased = f32(f32(t*6.0)-15.0)
	eased = f32(f32(eased*t)+10.0)
	eased = f32(f32(f32(eased*t)*t)*t)
	return {"scale": eased, "alpha": t}

func creep_animation(e: Dictionary) -> String:
	if e.attacking:
		var angle = f32(atan2(e.dir.y, e.dir.x))
		var closest = INF
		var state = "RunDown"
		for name in AIM_ANIMATIONS:
			var facing: Vector2 = AIM_ANIMATIONS[name]
			var difference = absf(wrapf(angle-f32(atan2(facing.y, facing.x)), -PI, PI))
			if difference < closest: closest = difference; state = name
		return state
	# GetDirFixFloatinPoint 0x7f150 zeros axes below0.05 pixel, then
	# GetAnimationFromDir 0x7f1f0 maps the eight signed directions.
	var movement = center(e.next_cell.x, e.next_cell.y)-center(e.cell.x, e.cell.y)
	if movement.is_zero_approx(): movement = e.dir*float(map.hex_h)
	var direction = Vector2i(0 if absf(movement.x) < 0.05000000074505806 else int(signf(movement.x)), 0 if absf(movement.y) < 0.05000000074505806 else int(signf(movement.y)))
	return WALK_ANIMATIONS.get(direction, "RunDown")

func choose_target(t: Dictionary, radius: float) -> Dictionary:
	var result = SpiceNative.select_target(enemies, {"cell":Vector2(t.cell),"mode":str(t.targeting),"gravity":int(t.type)==11,"aim":int(t.def.get("aim",0)),"owner":int(t.get("player",1)),"ellipse":true,"origin":t.pos,"radius":radius,"hex_height":float(map.hex_h)}, target_grid)
	return enemies[result.selected] if result.selected >= 0 else {}

func target_grid(e: Dictionary) -> Vector2:
	# UpdatePosition0x7d108 interpolates integer segment endpoints separately
	# from the logical pixel position and the rounded body position.
	return vector_interpolate(Vector2(e.cell), Vector2(e.next_cell), CreepView.progress(self, e))

func can_hit(aim: int, e: Dictionary) -> bool:
	var air = bool(e.get("native_air", e.air))
	return aim == 0 or (aim == 1 and not air) or (aim == 2 and air)

func find_enemy(id: int) -> Dictionary:
	if step_lookup_active:return step_enemies.get(id,{})
	for enemy in enemies:
		if int(enemy.id) == id: return enemy
	return {}

func normalize_degrees(value: float) -> float:
	# AngleNormalize 0x1106f8 converts through an unsigned16-bit turn.
	return f32(float(int(f32(value)*182.04444444444445)&65535)*0.0054931640625)

func native_angpos(direction: Vector2) -> float:
	if direction == Vector2.ZERO: return -99999.0
	if direction.x == 0: return 1.570796012878418 if direction.y > 0 else -1.570796012878418
	var angle = f32(atan(f32(direction.y/direction.x)))
	if direction.x < 0: angle = f32(angle+(3.141592025756836 if direction.y > 0 else -3.141592025756836))
	return angle

func tower_aim_angle(t: Dictionary, e: Dictionary) -> float:
	var direction = t.pos+Vector2(0, -7)-e.pos
	return normalize_degrees(f32(f32(native_angpos(direction)*57.295780181884766)+90.0))

func interpolate_degrees(start: float, goal: float, progress: float) -> float:
	# InterpolateDegrees 0x110740 truncates the difference before the180 test,
	# then truncates again if the interpolated result crosses360 degrees.
	if absi(int(f32(goal-start))) > 180:
		if goal <= start: goal = f32(goal+360.0)
		else: start = f32(start+360.0)
	var value = f32(start+f32(f32(goal-start)*progress))
	if value < 0 or value > 360: value = float(int(value)%360)
	return value

func rotating_target(t: Dictionary, radius: float, interval: float, turns: bool = true) -> Dictionary:
	# CTower::Update 0xe53b4 retains the target ID. Only death/out-of-range
	# reacquires it; each acquisition resets its delay and initial turn.
	if not t.has("tracking"):
		t.tracking = {"id": -1, "acquisition": 0.0, "turn": 0.0,
			"locked": false, "start": t.angle, "first_ms": 0, "first_done": false}
		if not t.has("reload_ms"): t.reload_ms = 100000.0
	var state: Dictionary = t.tracking
	var target = find_enemy(int(state.id))
	if not target.is_empty() and (target.hp <= 0 or int(target.get("state", 0)) in [2, 3] or (int(t.type) == 11 and int(target.get("state", 0)) == 5) or not in_range(t.pos, target.pos, radius)):
		target = {}
	if target.is_empty():
		target = choose_target(t, radius)
		if target.is_empty(): state.id = -1; return {}
		state.merge({"id": target.id, "acquisition": 0.0, "turn": 0.0, "locked": false,
			"start": t.angle, "first_ms": 0, "first_done": false}, true)
	if not state.first_done:
		state.first_ms += tick_ms
		if state.first_ms >= 2000:
			t.reload_ms = interval
			state.first_done = true
	var ideal = tower_aim_angle(t, target)
	if state.locked: t.angle = ideal
	var delay = int(catalog.tower_targeting_delay)+int(t.get("extra_target_delay_ms", 0))
	state.acquisition = f32(float(state.acquisition)+f32(float(tick_ms)/maxi(1, delay)))
	if state.acquisition < 1.0: return {}
	t.reload_ms = f32(float(t.reload_ms)+tick_ms)
	if t.reload_ms < interval: return {}
	if not state.locked:
		if not turns:
			t.angle = ideal
			state.locked = true
			return target
		state.turn = f32(float(state.turn)+f32(float(tick_ms)/maxi(1, int(catalog.tower_targeting_duration))))
		t.angle = interpolate_degrees(float(state.start), ideal, float(state.turn))
		if state.turn < 1.0: return {}
		t.angle = ideal
		state.start = ideal
		state.turn = 0.0
		state.locked = true
	return target

func bonuses(t: Dictionary) -> Dictionary:
	var result = {"damage": 1.0, "range": 1.0, "rof": 1.0}
	if int(t.type) >= 16: return result
	for support in (step_support if step_lookup_active else towers):
		if support.id == t.id or support.type < 16 or clock_ms < support.ready_ms: continue
		if t.pos.distance_to(support.pos) < float(support.def.range)/1000.0*float(map.hex_h):
			# ProcessSupply keeps the maximum benefit in each component; it does not compound towers.
			result.damage = maxf(result.damage, f32(1.0 + float(support.def.get("dmg_bonus", 0))/100.0))
			result.range = maxf(result.range, f32(1.0 + float(support.def.get("range_bonus", 0))/100.0))
			result.rof = maxf(result.rof, f32(1.0 + float(support.def.get("rof_bonus", 0))/100.0))
	return result

func damage(e: Dictionary, amount: float, owner: int = 0, kind:int=0) -> void:
	if e.hp<=0 or int(e.get("state",0)) in [2,3]:return
	e.hp = f32(e.hp - amount)
	if not e.has("hit_running"):e.merge(CreepHit.initial())
	CreepHit.after_damage(e,kind)
	if e.hp <= 0:
		kills += 1
		kill_chain += 1
		var source_path = route(Vector2i(int(sources[e.source].x), int(sources[e.source].y)), Vector2i(int(bases[e.base].x), int(bases[e.base].y)), e.air) if e.base >= 0 else []
		var remaining = maxi(0, e.path.size()-e.path_at)
		var factor = f32(2.0-f32(float(remaining)/maxi(1, source_path.size())))
		var nominal = floorf(f32(float(e.def.price)*factor))
		var reward = maxi(1, int(f32(nominal*(1.0 + int(upgrades.get("up_interest", 0))*0.05))))
		money = f32(money+reward)
		score = f32(score+reward)
		emit("kill", {"id": e.id, "pos": e.pos, "type": e.type, "owner": owner, "reward": reward})

func shoot(t: Dictionary, e: Dictionary, boost: Dictionary) -> void:
	var d = t.def
	# Native uses the animator position (centerY-7) minus the creep point,
	# AngPos in radians, f32 radians-to-degrees, then adds90 degrees.
	t.angle = tower_aim_angle(t, e)
	t.reload_ms = 0.0
	# CTower::Update divides the nominal interval by the maximum support factor.
	t.shot_ms = clock_ms + maxi(30, int(f32(float(d.get("rof", 1000))/boost.rof)))
	emit("shot", {"from": t.pos, "to": e.pos,"visual_to":enemy_visual_aim_point(e), "type": t.type, "filename": d.filename,"enemy_id":e.id,"tower_id":t.id})
	if t.type in [4, 5, 6, 14]:
		var count = [2, 3, 4][int(t.level)-1] if int(t.type) == 6 else [2, 4, 6][int(t.level)-1] if int(t.type) == 14 else 1
		var divisor = (4.0 if int(t.level) == 3 else 3.0) if int(t.type) == 6 else 6.0 if int(t.type) == 14 else 1.0
		var direction = (e.pos-(t.pos+Vector2(0, -7))).normalized()
		var lateral = Vector2(-direction.y, direction.x)
		for i in range(count):
			var origin = t.pos+Vector2(0, -7)
			if count > 1:
				# UpdateMissiles0xe6e00 alternates launch offsets. Three has a center shot.
				var separation = 15.0 if int(t.type) == 14 else 10.0
				if count == 3: origin += lateral*([0.0, 15.0, -15.0][i])
				elif count == 4 and int(t.type) == 6: origin += lateral*(-4.0 if i%2 == 0 else 4.0)
				else: origin += lateral*(-separation if i%2 == 0 else separation)
				origin.y -= 15.0
			var p = new_missile(origin, e.pos, d, int(e.id), int(t.type), int(t.id), float(boost.damage), divisor)
			p.active = count == 1
			missiles.append(p)
	elif t.type in [7, 8, 9]:
		var origin = t.pos+Vector2(0, -7)
		var height = float(animations.get("towers/"+str(d.filename), {}).get("params", {}).get("tower_height", 50))
		var destination = enemy_visual_aim_point(e)
		var bubble = {"pos": origin, "destination": destination, "start_y": origin.y-height,
			"end_y": origin.y-height-60.0, "shadow": origin, "shadow_start": origin,
			"age": 0.0, "progress": 0.0, "flying": false, "active": true,
			"alpha": 0.4, "size": 16, "type": t.type, "def": d, "owner": t.id}
		bubbles.append(bubble)
		zones.append({"pos": destination, "def": d, "until": -1, "owner": t.id, "type": t.type, "bubble": bubble,
			"damage_bonus": f32(float(d.get("damage", 0))*f32(float(boost.damage)-1.0))})
	elif t.type == 11:
		e.float_until = clock_ms + int(d.get("float_time", 3000))
		e.state = 5
		emit("float", {"pos": e.pos})
	else:
		damage(e, f32(float(d.get("damage", 0))*boost.damage), t.id,1 if int(t.type)==15 else 0)

func enemy_aim_point(e: Dictionary) -> Vector2:
	var offset = e.def.get("traits", {}).get("offset", [0, 0])
	return e.pos+Vector2(float(offset[0]), float(offset[1]))

func enemy_visual_aim_point(e: Dictionary) -> Vector2:
	var offset = e.def.get("traits", {}).get("offset", [0, 0])
	return e.get("visual_pos", e.pos)+Vector2(float(offset[0]), float(offset[1]))

func vector_interpolate(start: Vector2, goal: Vector2, progress: float) -> Vector2:
	# InterpolateVectors2D0x1107e8 clamps, then multiplies each endpoint separately.
	progress = clampf(progress, 0, 1)
	return Vector2(f32(f32(start.x*f32(1.0-progress))+f32(goal.x*progress)),
		f32(f32(start.y*f32(1.0-progress))+f32(goal.y*progress)))

func new_missile(origin: Vector2, destination: Vector2, definition: Dictionary, target: int, type: int, owner: int, boost: float = 1.0, divisor: float = 1.0) -> Dictionary:
	var start = origin
	if type != 5: start += (destination-origin).normalized()*10.0
	else:
		var texture = animations.get("towers/"+str(definition.filename), {}).get("textures", {}).get("missile", {})
		start.y += int(texture.get("frame_height", 154))/2+10
	return {"pos": start, "origin": start, "previous": start, "destination": destination,
		"target": target, "def": definition, "owner": owner, "boost": boost, "type": type,
		"divisor": divisor, "launch_ms": clock_ms, "active": true, "age_ms": 0,
		"velocity": Vector2.ZERO, "acceleration": Vector2.ZERO, "angle": 90.0,
		"up": 0.0, "down": 0.0, "nuke_velocity": f32(float(definition.get("velocity", 3000))*5.0),
		"nuke_acceleration": 0.0, "alpha": 1.0, "scale": 0.5 if type == 5 else 1.0}

func process_nuke(t: Dictionary, radius: float, boost: Dictionary) -> void:
	var interval = f32(float(t.def.rof)/float(boost.rof))
	if not t.has("reload_ms"): t.reload_ms = 100000.0
	if not t.has("nuke"): t.nuke = {"opening": false, "id": -1, "destination": Vector2.ZERO}
	var state: Dictionary = t.nuke
	t.reload_ms = f32(float(t.reload_ms)+tick_ms)
	if t.reload_ms > interval and not state.opening:
		var target = choose_target(t, radius)
		if target.is_empty(): t.reload_ms = interval
		else:
			state.opening = true
			state.id = target.id
			t.animation = "Open"
			t.animation_ms = clock_ms
			emit("nuke_warning", {"pos": t.pos, "filename": t.def.filename})
	var target = find_enemy(int(state.id))
	if not target.is_empty(): state.destination = target.pos
	if state.opening and t.reload_ms >= f32(interval+2000.0):
		missiles.append(new_missile(t.pos+Vector2(0, -7), state.destination, t.def, -1, 5, int(t.id), float(boost.damage)))
		t.reload_ms = 0.0
		state.opening = false
		state.id = -1
		emit("nuke_launch", {"pos": t.pos, "to": state.destination})

func update_bubble(b: Dictionary) -> void:
	if not b.active: return
	if not b.flying:
		b.age = f32(float(b.age)+f32(float(tick_ms)/500.0))
		b.progress = f32(float(b.progress)+f32(float(tick_ms)/f32(float(b.age)+500.0)))
		b.pos.y = maxf(float(b.end_y), f32(float(b.start_y)+f32(f32(float(b.end_y)-float(b.start_y))*float(b.progress))))
		b.size = int(f32(16.0+f32(48.0*float(b.progress))))
		b.alpha = minf(1.0, f32(float(b.alpha)+float(b.progress)))
		if b.pos.y <= b.end_y:
			b.flying = true
			b.age = 0.0
			b.progress = 0.0
			b.size = 64
			b.shadow.y = f32(float(b.shadow_start.y)+f32(f32(float(b.start_y)-float(b.end_y))*0.5))
	else:
		b.progress = f32(float(b.progress)+f32(float(tick_ms)/600.0))
		b.pos = vector_interpolate(b.pos, b.destination, float(b.progress))
		b.shadow = vector_interpolate(b.shadow, b.destination, float(b.progress))
		if b.pos.distance_to(b.destination) < 5.0 or b.progress >= 1.0:
			b.active = false
			emit("bubble_impact", {"pos": b.pos, "type": b.type})

func missile_hits(p: Dictionary, half_size: float = 20.0) -> bool:
	var delta: Vector2 = p.pos-p.destination
	if absf(delta.x) < half_size and absf(delta.y) < half_size: return true
	if projectile_crosses_rectangle(p, half_size): return true
	return int(p.age_ms) > 8000

func projectile_crosses_rectangle(p: Dictionary, half_size: float) -> bool:
	# LineIntersectRect0x1108b8 tests the four edges, without an interior test.
	var lo: Vector2 = p.destination-Vector2.ONE*half_size
	var hi: Vector2 = p.destination+Vector2.ONE*half_size
	var corners = [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]
	for i in range(4):
		if native_segments_intersect(p.get("previous", p.pos), p.pos, corners[i], corners[(i+1)%4]): return true
	return false

func native_segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	# LineIntersectLine0x11095c rejects parallel/zero-length segments and
	# includes endpoints. Keep its32-bit determinant and both divisions.
	var v = b-a
	var w = d-c
	var r = c-a
	var determinant = f32(f32(v.y*w.x)-f32(v.x*w.y))
	if determinant == 0.0: return false
	var u = f32(f32(f32(v.x*r.y)-f32(v.y*r.x))/determinant)
	var t = f32(f32(f32(w.x*r.y)-f32(w.y*r.x))/determinant)
	return u >= 0.0 and u <= 1.0 and t >= 0.0 and t <= 1.0

func update_missile(p: Dictionary) -> bool:
	if not p.get("active", true): return false
	p.age_ms += tick_ms
	if int(p.type) == 5:
		p.nuke_velocity = maxf(float(p.def.get("velocity", 3000)), f32(float(p.nuke_velocity)-float(p.nuke_acceleration)))
		p.nuke_acceleration = f32(float(p.nuke_acceleration)+f32(float(tick_ms)/5.0))
		if p.up < 1.0:
			p.up = f32(float(p.up)+f32(f32(f32(1000.0/float(p.nuke_velocity))*tick_ms)/500.0))
			p.pos = vector_interpolate(p.origin, p.origin+Vector2(0, -500), float(p.up))
			p.up = minf(1.0, float(p.up))
			p.alpha = maxf(0.0, f32(1.0-f32(f32(float(p.up)-0.800000011920929)*5.0))) if p.up > 0.800000011920929 else 1.0
			p.scale = f32(f32(float(p.up)*0.8999999761581421)+0.15000000596046448)
			if p.up >= 1.0:
				var owner = find_tower(int(p.owner))
				if not owner.is_empty(): owner.animation = "Close"; owner.animation_ms = clock_ms+tick_ms
		else:
			p.alpha = minf(1.0, f32(float(p.down)*5.0))
			p.down = f32(float(p.down)+f32(f32(f32(1000.0/float(p.def.get("velocity", 3000)))*tick_ms)/500.0))
			p.pos = vector_interpolate(p.destination+Vector2(0, -500), p.destination, float(p.down))
			p.scale = f32(1.0-f32(float(p.down)*0.5))
			var texture = animations.get("towers/"+str(p.def.filename), {}).get("textures", {}).get("missile2", {})
			p.pos.y = f32(p.pos.y+f32(f32(float(texture.get("frame_height", 154))*-0.30000001192092896)*float(p.scale)))
			return p.down >= 1.0
		return false
	if missile_hits(p): return true
	steer_projectile(p, float(p.def.get("velocity", 3000)))
	return false

func steer_projectile(p: Dictionary, raw_velocity: float) -> void:
	# Tower and creep missile classes use the same damped recurrence.
	p.previous = p.pos
	var seconds = f32(minf(tick_ms, 100.0)/1000.0)
	var gamma = f32(f32(seconds*3.75)/0.30000001192092896)
	var speed = f32(raw_velocity*maxf(seconds, 0.03999999910593033))
	var goal: Vector2 = (p.destination-p.pos).normalized()*speed
	if gamma >= 1.0: p.velocity = goal; p.acceleration = Vector2.ZERO
	var velocity: Vector2 = p.velocity
	var acceleration: Vector2 = p.acceleration
	var next_velocity = velocity+acceleration*gamma
	p.acceleration = acceleration+(goal-velocity-2.0*acceleration)*gamma
	p.velocity = next_velocity
	p.pos += next_velocity*seconds
	p.angle = f32(native_angpos(p.previous-p.destination)*57.295780181884766)

func impact(p: Dictionary) -> void:
	var destination: Vector2 = p.get("destination", p.pos)
	var radius = float(p.def.get("damagerange", 0))/1000.0
	var per_missile = f32(f32(float(p.def.get("damage", 0))*float(p.boost))/float(p.get("divisor", 1.0)))
	for e in enemies:
		if e.hp <= 0: continue
		# CMissile::DoDamageToTarget 0xdecc4: a normal missile directly hits
		# its target even when collateral damage is ground-only. Nukes use area.
		if int(p.type) != 5 and int(e.id) == int(p.target):
			damage(e, per_missile, p.owner,2)
			continue
		if radius <= 0 or not can_hit(int(p.def.get("damagerangeaim", p.def.get("aim", 0))), e): continue
		var distance = f32(e.pos.distance_to(destination)/float(map.hex_h))
		if distance >= radius: continue
		var falloff = f32(1.0-f32(distance/per_missile)) if distance > 0 and per_missile > 0 else 1.0
		damage(e, f32(per_missile*falloff), p.owner)
	if p.type == 5:
		zones.append({"pos": destination, "def": p.def, "until": clock_ms + int(p.def.get("poison_duration", 6000)), "owner": p.owner, "type": 5,
			"damage_bonus": f32(float(p.def.get("damage", 0))*f32(float(p.boost)-1.0))})
	emit("explosion", {"pos": destination, "type": p.type, "filename": p.def.filename, "radius": maxf(0.4, radius)})

func duration(key: String, upgrade_key: String = "") -> int:
	var result = f32(float(catalog.tower_magic[key])*(1.0 + float(upgrades.get("up_wizard", 0))*0.05))
	if not upgrade_key.is_empty(): result = f32(result*(1.0+float(upgrades.get(upgrade_key, 0))*0.05))
	return int(result)

func ability_error(key: String, pos: Vector2 = Vector2.ZERO) -> String:
	if paused or outcome != "playing": return "The game is paused."
	if key not in ["m_freeze", "m_lsd", "m_actdef", "m_mine", "m_portal"]: return "Unknown magic."
	if int(abilities.get(key, 0)) <= 0: return "Buy more in the Tech Shop."
	if key == "m_freeze" and clock_ms < freeze_until: return "Freeze is still active."
	if key == "m_lsd" and clock_ms < disco_until: return "Disco Magic is still active."
	if key == "m_actdef" and clock_ms < defense_until: return "Active Defense is still active."
	if key == "m_mine" and mines.size() >= int(catalog.tower_magic.mine_max): return "Maximum mines reached."
	if key in ["m_mine", "m_portal"]:
		var cell = nearest(pos)
		if not within(cell) or int(map.cells[cell_index(cell)].w) != 1: return "Choose an open hex."
		if key=="m_mine" and (not buildable(cell) or not tower_at(cell).is_empty()):return "Choose an open hex."
	if key == "m_portal" and portals.size() >= 2: return "A portal pair is already active."
	return ""

func use_ability(key: String, pos: Vector2 = Vector2.ZERO) -> String:
	var error = ability_error(key, pos)
	if not error.is_empty(): return error
	if key in ["m_mine", "m_portal"]:
		var cell = nearest(pos)
		pos = center(cell.x, cell.y)
	match key:
		"m_freeze": freeze_until = clock_ms + duration("freeze_duration", "up_freeze")
		"m_lsd":
			disco_until = clock_ms + duration("lsd_duration", "up_pharm")
			for e in enemies:
				e.disco_until = disco_until
				set_enemy_path(e)
		"m_actdef": defense_until = clock_ms + duration("actdef_duration", "up_actdef")
		"m_mine": mines.append({"pos": pos, "cell": nearest(pos), "ready": clock_ms + int(catalog.tower_magic.mine_sleep), "born_ms":clock_ms,"static": false})
		"m_portal":
			portals.append({"pos": pos, "until": clock_ms+duration("portal_duration"),"born_ms":clock_ms})
			if portals.size() == 1:
				portals[0].presentation=PortalView.create(float(catalog.tower_magic.portal_reload),duration("portal_duration"))
				emit("portal_pending", {"pos": pos})
				return "Choose the portal exit."
			portals[0].until = clock_ms+duration("portal_duration")
			portals[0].connected_ms=clock_ms
			PortalView.connect_gates(portals[0].presentation)
		_: return "Unknown magic."
	abilities[key] = int(abilities[key])-1
	record("magic", {"key": key, "x": pos.x, "y": pos.y})
	emit("magic", {"key": key, "pos": pos})
	return ""

func advance(ms: int) -> void:
	if paused or outcome != "playing": return
	accumulator += ms
	while accumulator >= STEP_MS and outcome == "playing":
		accumulator -= STEP_MS
		step()

func advance_frame(ms: float) -> void:
	if paused or outcome != "playing": return
	live_updates = true
	tick_ms = f32(maxf(0,ms))
	step()
	tick_ms = STEP_MS

func cancel_portal_placement() -> void:
	if portals.size() == 1: portals.clear()

func creep_portal_base(e:Dictionary) -> Vector2:
	var values=e.def.traits.get("scale",[1,1])
	return Vector2(values[0],values[1])

func teleport_enemy(e:Dictionary,exit_cell:Vector2i) -> void:
	# Original TeleportCreep sets state2/clock0 and collapses logical/drawn
	# anchors at the exit, then pops/peeks its newly supplied path. The next
	# movement update consumes a boundary without moving the logical point.
	e.state=0;e.cell=exit_cell;e.next_cell=exit_cell;e.pos=center(exit_cell.x,exit_cell.y)
	e.attacking=false;e.path=[];e.path_at=1
	set_enemy_path(e)
	e.portal_pose.state=2;e.portal_pose.clock=0.0;e.portal_marker=Vector2i(-1,-1)
	e.portal_boundary=true;e.move_progress=1.0;e.move_carry=0.0;e.move_start=e.pos
	if e.path.size()>1:e.dir=(center(e.path[1].x,e.path[1].y)-e.pos).normalized()
	CreepView.update(self,e)

func check_portal_transfers(presentation:Dictionary,entry:Vector2i,exit_cell:Vector2i) -> void:
	var queue:Array=presentation.queue
	if presentation.gates[0].state==3:
		# A closing entrance flushes any still-shrinking queued creeps.
		for id in queue:
			var e=find_enemy(int(id))
			if not e.is_empty() and e.hp>0 and e.has("portal_pose"):teleport_enemy(e,exit_cell)
		queue.clear();return
	if presentation.gates[0].state!=2:return
	for e in enemies:
		if e.hp<=0 or bool(e.native_air) or int(e.state) in [2,3,5]:continue
		if e.next_cell==entry:e.portal_marker=entry
		var phase=int(e.portal_pose.state) if e.has("portal_pose") else 0
		if CreepPortal.can_enter(1,int(e.state),phase,e.next_cell==entry,CreepView.progress(self,e)):
			if not e.has("portal_pose"):e.portal_pose=CreepPortal.create(creep_portal_base(e),float(e.draw_light),float(e.def.traits.get("shadow_scale_factor",1)))
			e.portal_pose.clock=0.0;e.portal_pose.state=1
			queue.append(int(e.id))
			emit("teleport",{"id":e.id,"pos":e.pos})
		if e.get("portal_marker",Vector2i(-1,-1))==entry and e.cell==entry and e.has("portal_pose"):
			# Native list traversal removes its first queued entry here.
			if not queue.is_empty():queue.pop_front()
			teleport_enemy(e,exit_cell)

func step() -> void:
	step_lookup_active = false
	var timed = Time.get_ticks_usec() if profile_hotpaths else 0
	var previous_ms = clock_ms
	clock_ms = int(f32(float(clock_ms)+tick_ms))
	if map.has("water"):
		water_phase = f32(water_phase+f32(tick_ms/float(map.water.speed)))
	for expiry in [["m_actdef", defense_until]]:
		if previous_ms < int(expiry[1]) and clock_ms >= int(expiry[1]): emit("magic_end", {"key": expiry[0]})
	var seconds = float(tick_ms)/1000.0
	validate_paths()
	if bool(freeze_state.room_active) or spawn_hold:
		next_wave_ms += tick_ms
		for running in running_waves: running.spawn_ms += tick_ms
	if not spawn_hold and clock_ms >= next_wave_ms and wave_index < config.waves.size(): next_wave(false)
	for running in ([] if spawn_hold else running_waves.duplicate()):
		var wave = config.waves[running.index]
		while clock_ms >= running.spawn_ms and running.at < wave.creep_ids.size():
			var src = int(wave.source_ids[running.at]) if running.at < wave.source_ids.size() else 0
			spawn_enemy(int(wave.creep_ids[running.at]), src, str(wave.type), (int(running.index)+1)*int(catalog.get("tower_max_wave_length", 100))+int(running.at))
			running.at += 1
			running.spawn_ms = clock_ms + spawn_delay(float(wave.delay))
			if live_updates:break
		if running.at >= wave.creep_ids.size(): running_waves.erase(running)
	# Waves read the previous room flag; ProcessPlayers then updates the
	# shared countdown before ProcessSpeed/ProcessFreeze on each creep.
	if CreepFreeze.advance_timer(freeze_state,tick_ms):emit("magic_end",{"key":"m_freeze"})
	if not spawn_hold and not freeze_state.room_active and survival_remaining_ms>0:
		survival_remaining_ms=maxi(0,int(f32(float(survival_remaining_ms)-tick_ms)))
		if survival_remaining_ms==0:finish("victory");return
	# Recovered normal-update order: enemies, towers, mines, portals, bases.
	if profile_hotpaths: timed = timed_section("spawn_paths", timed)
	for e in enemies:
		if e.hp <= 0: continue
		e.grow_ms = minf(400, f32(float(e.grow_ms)+tick_ms))
		e.slow = e.slow_pending if e.slow_pending > 0 else 1.0
		e.consumed_slow=e.slow_pending>0
		e.slow_pending = -1.0
		var current_speed=f32(float(e.speed)*float(e.slow))
		e.animation_divisor=f32(1000.0/current_speed) if current_speed!=0 else INF
		e.animation_multiplier=0.0 if e.get("freeze_attached",false) else 1.0
		CreepFreeze.process_creep(e,int(freeze_state.remaining))
		e.poison_count = 0
		e.slow_count = 0
		if e.float_until > 0 and clock_ms >= e.float_until:
			e.air = e.native_air
			e.float_until = 0
			e.state = 0
			set_enemy_path(e)
		if e.disco_until > 0 and clock_ms >= e.disco_until:
			e.disco_until = 0
			set_enemy_path(e)
		if e.get("hit_running",false):CreepHit.advance(e,tick_ms)
		if int(e.freeze_remaining)>0 or clock_ms < e.float_until: continue
		if e.path.is_empty() or e.base < 0: continue
		CreepView.prepare(self, e)
		if e.get("portal_boundary",false):
			e.portal_boundary=false;e.cell=e.next_cell;e.move_start=e.pos;e.move_progress=0.0
		elif e.speed > 0 and movement_point_allowed(e):
			var cell = e.path[e.path_at]
			var point = center(cell.x, cell.y)
			e.next_cell = cell
			var future = point
			var peek = {"cell":cell,"path_at":int(e.path_at)+1,"path":e.path,"disco_until":e.disco_until,"bombing":e.get("bombing",false),"def":e.def}
			if movement_point_allowed(peek): future = center(e.path[peek.path_at].x, e.path[peek.path_at].y)
			var movement = CreepView.movement_tick(e.move_start, point, future, CreepView.progress(self, e), float(e.get("move_carry", 0)), f32(float(e.speed)*float(e.slow)), tick_ms, float(map.hex_h))
			e.move_progress = movement.progress
			e.move_carry = movement.carry
			e.pos = movement.position
			e.move_start = movement.start
			if movement.transitioned:
				e.cell = cell
				e.path_at += 1
				e.next_cell = e.path[e.path_at] if e.path_at < e.path.size() else cell
			if (movement.target-movement.start).length() > 0.001: e.dir = (movement.target-movement.start).normalized()
			if e.bombing and cell == Vector2i(int(bases[e.base].x), int(bases[e.base].y)) and int(e.bomb_dropped_at) != int(e.path_at):
				if movement.progress > 0.5:
					launch_enemy_missiles(e, true)
					e.bomb_dropped_at = e.path_at
			# Native kamikaze switches to attack in the latter half of the
			# final base link, before reaching its center.
			if int(e.def.traits.get("kamikaze", 0)) == 1 and e.next_cell == Vector2i(int(bases[e.base].x), int(bases[e.base].y)) and float(e.move_progress) > 0.5 and e.disco_until == 0:
				base_damage(int(e.base), float(e.def.damage))
				e.hp = 0.0
				emit("base_impact", {"id": e.id, "pos": e.pos, "type": e.type})
				continue
		e.draw_light=CreepLight.from_map(map,e.cell,e.next_cell,CreepView.progress(self,e),float(e.get("draw_light",1)))
		if not movement_point_allowed(e) and e.disco_until == 0:
			var b = bases[e.base]
			if int(e.def.traits.get("shoot_bomb", 0)) == 1:
				var circle = bomber_circle(e.cell, int(e.base))
				if not circle.is_empty():
					circle.pop_back() # native skips the trailing base before selecting another ring
					e.path = circle
					e.path_at = 0
					e.bombing = true
					e.bomb_dropped_at = -1
				continue
			if int(e.def.traits.get("kamikaze", 0)) != 1:
				if not e.attacking:
					e.attacking = true
					e.attack_point = displace_point(e.cell, b.pos, int(e.id), e.pos)
					e.attack_reload_ms = 0
				var aim_distance = float(e.speed)/1000.0*float(map.hex_h)*seconds*float(e.slow)
				e.pos = e.pos.move_toward(e.attack_point, aim_distance)
				e.dir = (b.pos-e.pos).normalized()
				if e.pos.distance_to(e.attack_point) > 0.001: continue
				e.attack_reload_ms += tick_ms
				if int(e.attack_reload_ms) < int(e.def.rof): continue
				e.attack_reload_ms = 0
			if int(e.def.traits.get("shoot_missile", 0)) == 1: launch_enemy_missiles(e)
			else: base_damage(int(e.base), float(e.def.damage))
			if int(e.def.traits.get("kamikaze", 0)) == 1:
				e.hp = 0.0
				emit("base_impact", {"id": e.id, "pos": e.pos, "type": e.type})
		elif e.path_at >= e.path.size() and clock_ms < e.disco_until: set_enemy_path(e)
	for e in enemies:
		if e.hp > 0:
			CreepView.update(self,e)
			if e.has("portal_pose"):CreepPortal.advance(e.portal_pose,tick_ms,creep_portal_base(e),float(e.draw_light),float(e.def.traits.get("shadow_scale_factor",1)))
	if profile_hotpaths: timed = timed_section("creep_movement", timed)
	for projectile in enemy_missiles.duplicate():
		var b = bases[projectile.base]
		if b.hp <= 0: enemy_missiles.erase(projectile); continue
		# CCreepMissile::Update0x8120c tests the previous segment against
		# a10px rectangle, then steers using its raw3000 pixel resource velocity.
		if projectile_crosses_rectangle(projectile, 10.0):
			base_damage(int(projectile.base), float(projectile.damage))
			emit("enemy_impact", {"pos": b.pos, "type": projectile.type})
			enemy_missiles.erase(projectile)
		else:
			var angle = projectile.angle
			SpiceNative.creep_missile_tick(projectile,tick_ms,3000)
			if not projectile.bomb:projectile.angle=f32(native_angpos(projectile.previous-projectile.destination)*57.295780181884766)
			else:projectile.angle = angle
	step_support.clear();step_enemies.clear()
	for support in towers:
		if int(support.type)>=16 and clock_ms>=support.ready_ms: step_support.append(support)
	for enemy in enemies:step_enemies[int(enemy.id)]=enemy
	step_lookup_active = true
	for t in towers:
		if clock_ms < t.ready_ms: continue
		var boost = bonuses(t)
		var radius = float(t.def.get("range", 0))/1000.0*float(boost.range)
		if int(t.type) in [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 13, 14, 15]:
			if int(t.type) == 3 and not t.has("extra_target_delay_ms"): t.extra_target_delay_ms = rng.randi()%500
			var target = rotating_target(t, radius, f32(float(t.def.get("rof", 1000))/boost.rof), int(t.type) not in [7, 8, 9, 10, 11])
			if not target.is_empty(): shoot(t, target, boost)
		elif int(t.type) == 5:
			process_nuke(t, radius, boost)
		elif t.type < 16 and clock_ms >= t.shot_ms:
			if t.type == 12:
				for index in SpiceNative.range_candidates(enemies, t.pos, radius, float(map.hex_h), int(t.def.get("aim", 0))):
					var e = enemies[index]
					damage(e, float(t.def.damage)*seconds*boost.damage, t.id)
					emit("beam", {"from": t.pos, "to": e.pos,"visual_to":enemy_visual_aim_point(e), "type": 12, "filename": t.def.filename,"enemy_id":e.id,"tower_id":t.id})
			else:
				var target = choose_target(t, radius)
				if not target.is_empty(): shoot(t, target, boost)
		# CTower::Update skips UpdateActiveDefense when both electric/area
		# resource flags0x86/0x87 are set (the BBQ branch already has area bolts).
		if clock_ms < defense_until and int(t.type) != 12:
			for index in SpiceNative.range_candidates(enemies, t.pos, float(catalog.tower_magic.actdef_range)/1000.0, float(map.hex_h), int(t.def.get("aim", 0))):
				var e = enemies[index]
				damage(e, float(catalog.tower_magic.actdef_damage)*seconds, t.id)
				emit("beam", {"from": t.pos, "to": e.pos,"visual_to":enemy_visual_aim_point(e), "type": 10,"enemy_id":e.id,"tower_id":t.id})
	if profile_hotpaths: timed = timed_section("towers", timed)
	for t in towers:
		if int(t.type) not in [6, 14]: continue
		var owned = missiles.filter(func(p): return int(p.owner) == int(t.id))
		if owned.is_empty(): continue
		t.volley_reload_ms = f32(float(t.get("volley_reload_ms", 0))+tick_ms)
		var interval = f32(f32(3000.0/float(t.def.velocity))*100.0)
		if t.volley_reload_ms >= interval:
			for p in owned:
				if not p.active: p.active = true; p.launch_ms = clock_ms; break
			t.volley_reload_ms = 0.0
	for p in missiles.duplicate():
		for e in enemies:
			if int(p.type) != 5 and e.id == p.target and e.hp > 0: p.destination = enemy_aim_point(e)
		if update_missile(p):
			impact(p)
			missiles.erase(p)
	for z in zones.duplicate():
		if z.has("bubble"):
			if z.bubble.active: continue
			z.erase("bubble")
			z.until = clock_ms+int(z.def.get("poison_duration", 2000))-tick_ms
			emit("cloud_active", {"pos": z.pos, "type": z.type})
		if clock_ms >= z.until:
			zones.erase(z)
			continue
		for e in enemies:
			var distance = f32(e.pos.distance_to(z.pos)/float(map.hex_h))
			if e.hp <= 0 or e.air or distance >= float(z.def.get("poison_range", 0))/1000.0: continue
			if z.def.has("slowdown"):
				# Counters reset before enemy movement. Clouds supply the next frame's factor.
				var factor = f32(1.0-float(z.def.slowdown)/pow(2.0, e.slow_count)/100.0)
				e.slow_pending = factor if e.slow_pending <= 0 else f32(e.slow_pending*factor)
				e.slow_count += 1
			# CPoison::DoDamage0xe17c0 adds the tower's direct-damage support
			# bonus to poison damage; chemical resources have zero direct damage.
			var nominal = f32(float(z.def.get("poison_damage", 0))+float(z.get("damage_bonus", 0)))
			var falloff = f32(1.0-distance/nominal) if nominal > 0 and distance > 0 else 1.0
			damage(e, f32(f32(nominal*falloff)*seconds/pow(2.0, e.poison_count)), z.owner,3)
			e.poison_count += 1
	# UpdatePoisons0xe75dc updates clouds before bubbles: arrivals become damaging
	# on the following tick and their lifetime does not run while in flight.
	for b in bubbles.duplicate():
		if not b.active: bubbles.erase(b)
		else: update_bubble(b)
	if profile_hotpaths: timed = timed_section("projectiles_clouds", timed)
	update_kill_chain()
	for mine in mines.duplicate():
		if clock_ms < mine.ready: continue
		for e in enemies:
			if e.hp > 0 and not e.air and clock_ms >= e.float_until and e.cell == mine.cell:
				for other in enemies:
					var distance = f32(mine.pos.distance_to(other.pos)/float(map.hex_h))
					var radius = float(catalog.tower_magic.mine_range)/1000.0
					if not other.air and distance < radius:
						var power = float(catalog.tower_magic.mine_damage)*(1.0+int(upgrades.get("up_miner", 0))*0.05)
						damage(other, f32(power*f32(1.0-distance/radius)))
				emit("explosion", {"pos": mine.pos, "type": 0, "radius": 2.0})
				mines.erase(mine)
				break
	if portals.size() == 2:
		var presentation:Dictionary=portals[0].presentation
		# Original manager removes an already-deleted pair on the next update.
		if presentation.deleted:portals.clear()
		else:
			PortalView.advance(presentation,tick_ms)
			check_portal_transfers(presentation,nearest(portals[0].pos),nearest(portals[1].pos))
	for pair in static_portals:
		PortalView.advance(pair.presentation,tick_ms)
		check_portal_transfers(pair.presentation,pair["in"],pair.out)
	for e in enemies.duplicate():
		if e.hp <= 0:
			release_displacement(int(e.id))
			enemies.erase(e)
	var living = 0
	for b in bases:
		if b.hp > 0: living += 1
		if b.hp <= 0 and str(b.get("mustsurvive", "")) not in ["", "0"]: living = -100
	if living <= 0: finish("defeat")
	elif tutorial_finished and wave_index >= config.waves.size() and running_waves.is_empty() and enemies.is_empty(): finish("victory")
	step_lookup_active = false
	step_support.clear();step_enemies.clear()
	if profile_hotpaths: timed_section("cleanup", timed)

func update_kill_chain() -> void:
	# UpdateKillsInRaw0xe9ae8 resets its integer timer while any owned
	# tower holds a target. A gap strictly over300ms closes a chain.
	var held = false
	for tower in towers:
		var target = find_enemy(int(tower.get("tracking", {}).get("id", -1)))
		if not target.is_empty() and target.hp > 0: held = true; break
	if held: kill_chain_idle_ms = 0; return
	kill_chain_idle_ms += tick_ms
	if kill_chain_idle_ms > 300:
		if kill_chain > 5:
			closed_kill_chain = maxi(closed_kill_chain, kill_chain)
			emit("kill_chain", {"count": kill_chain})
		kill_chain = 0
		kill_chain_idle_ms = 0

func finish(result: String) -> void:
	if outcome != "playing": return
	outcome = result
	emit(result, {"score": score, "kills": kills})

func base_fraction() -> float:
	var total = 0.0
	var max_hp = 0.0
	for b in bases:
		total += b.hp
		max_hp += b.hpmax
	return total/max_hp if max_hp > 0 else 0.0

func perfect_game() -> bool:
	# CWinLoseScreen::Open uses the early-wave counter for Sudden Death.
	if int(config.gametype) == 3: return early_wave_count >= config.waves.size()
	for b in bases:
		if int(b.get("player", 0)) in [0, 1] and b.hp < b.hpmax: return false
	return true

func emit(kind: String, payload: Dictionary) -> void:
	payload = payload.duplicate()
	payload.kind = kind
	payload.ms = clock_ms
	events.append(payload)
	if kind not in ["beam", "shot"]: trace.append(payload)

func record(kind: String, args: Dictionary) -> void:
	replay.append({"ms": clock_ms, "kind": kind, "args": args.duplicate(true)})

func digest() -> String:
	# Include future-affecting state, not just visible positions and HP.
	return JSON.stringify([clock_ms, accumulator, money, wave_index, next_wave_ms, kills, score,
		built_count, upgrade_top_count, kill_chain, closed_kill_chain, kill_chain_idle_ms, replay,
		outcome, paused, early_wave_count, enemies, towers, bases, running_waves, missiles, enemy_missiles, zones, bubbles, mines, portals,
		static_portals, abilities, freeze_until, freeze_state, disco_until, defense_until, pending_towers,
		last_paths_ms, next_id, rng.state, tutorial_finished, spawn_hold, survival_remaining_ms, displacement_owners, build_overrides]).sha256_text()

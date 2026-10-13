class_name BanditSimulation
extends RefCounted

const STEP_MS = 30
const ROOT_TYPES = [1, 4, 7, 10, 13, 16]
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
var zones: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var portals: Array[Dictionary] = []
var static_portals: Array[Dictionary] = []
var events: Array[Dictionary] = []
var replay: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var money: float = 200.0
var clock_ms: int = 0
var accumulator: int = 0
var next_wave_ms: int = 0
var wave_index: int = 0
var kills: int = 0
var score: float = 0.0
var built_count: int = 0
var early_wave_count: int = 0
var outcome: String = "playing"
var paused: bool = false
var freeze_until: int = 0
var disco_until: int = 0
var defense_until: int = 0
var last_paths_ms: int = 0
var pending_towers: Array[int] = []
var next_id: int = 1
var path_cache: Dictionary = {}
var route_cost_cache: Dictionary = {}
var displacement_owners: Dictionary = {}
var penalty_ground: PackedFloat32Array = PackedFloat32Array()
var penalty_air: PackedFloat32Array = PackedFloat32Array()
var penalty_signature: String = ""
var rng = RandomNumberGenerator.new()
var discrepancies: Array[String] = []
var tutorial_finished: bool = true
var survival_remaining_ms: int = 0

func setup(data: Dictionary, map_data: Dictionary, mission: Dictionary, profile: Dictionary, seed: int = 114) -> void:
	catalog = data
	map = map_data
	config = mission
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
	next_wave_ms = int(config.get("wavedelay", 30000))
	survival_remaining_ms = int(config.settings.get("survive_time", 0))*60000
	for point in config.settings.get("mines", []):
		mines.append({"pos": center(int(point.x), int(point.y)), "cell": Vector2i(int(point.x), int(point.y)), "ready": int(catalog.tower_magic.mine_sleep), "static": true})
	for pair in config.settings.get("teleports", []):
		static_portals.append({"in": Vector2i(int(pair["in"].x), int(pair["in"].y)), "out": Vector2i(int(pair.out.x), int(pair.out.y))})
	if int(config.settings.get("tutorial", 0)):
		next_wave_ms = 1000000
		tutorial_finished = false
		abilities.m_mine = 5

func f32(value: float) -> float:
	var bytes = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	return bytes.decode_float(0)

func center(x: int, y: int) -> Vector2:
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

func link_allowed(a: Vector2i, b: Vector2i, air: bool) -> bool:
	if air or absi(a.x-b.x) != 2: return true
	var middle = Vector2i(int((a.x+b.x)/2), a.y)
	var alternate = middle+Vector2i(0, 1 if middle.x%2 == 0 else -1)
	for cell in [middle, alternate]:
		if within(cell) and (int(map.cells[cell_index(cell)].w) != 1 or not tower_at(cell).is_empty()): return false
	return true

func tower_at(cell: Vector2i) -> Dictionary:
	for t in towers:
		if t.cell == cell: return t
	return {}

func walkable(cell: Vector2i, start: Vector2i, end: Vector2i, air: bool) -> bool:
	if not within(cell): return false
	if air or cell == start or cell == end: return true
	return int(map.cells[cell_index(cell)].get("w", 0)) == 1 and tower_at(cell).is_empty()

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
			if closed.has(n) or not walkable(n, start, end, air) or not link_allowed(current, n, air): continue
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

func open_cell(cell: Vector2i) -> bool:
	return within(cell) and int(map.cells[cell_index(cell)].w) == 1 and tower_at(cell).is_empty()

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
		if shared.x < 0 or not open_cell(shared) or at+2 >= path.size(): continue
		if absi(path[at+1].x-path[at+2].x) == 2 or absi(path[at+1].x-path[at].x) == 2: path[at+1] = shared
	var at = 0
	while at < path.size():
		var shared = shared_regular_link(path, at, 4)
		if shared.x >= 0 and open_cell(shared) and at+3 < path.size():
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
	if not within(cell) or int(map.cells[cell_index(cell)].get("b", 0)) != 1: return "You cannot build here."
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
		"def": def, "hp": float(def.get("hp", 300)), "ready_ms": clock_ms + 1000, "shot_ms": 0,
		"angle": 0.0, "targeting": "fastest", "receipts": [price]}
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
	t.receipts.append(cost)
	t.merge({"type": type, "level": level, "def": def, "ready_ms": clock_ms + 1000}, true)
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
	e.attacking = false
	e.attack_reload_ms = 0
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
			var wandering = route(e.cell, destination, e.air)
			if wandering.size() > 1:
				e.path = wandering
				e.path_at = 1
				e.next_cell = wandering[1]
				return
	for i in range(bases.size()):
		var b = bases[i]
		if b.hp <= 0: continue
		var destination = Vector2i(int(b.x), int(b.y))
		var candidate = route(e.cell, destination, e.air)
		var candidate_cost = route_cost(candidate, e.air)
		if not candidate.is_empty() and candidate_cost < best_cost:
			best_path = candidate
			best_cost = candidate_cost
			target = i
	e.path = best_path
	e.path_at = 1
	e.base = target
	e.next_cell = best_path[1] if best_path.size() > 1 else e.cell

func movement_point_allowed(e: Dictionary) -> bool:
	var remaining = e.path.size()-int(e.path_at)
	if remaining <= 0: return false
	if clock_ms < int(e.disco_until): return true
	var stand_off = int(e.def.base_distance)
	if remaining > stand_off: return true
	# GetFirstMovementPoint 0x7ba04: horizontal links count differently.
	return absi(e.cell.x-e.path[e.path_at].x) == 2 and remaining >= int(floor(float(stand_off)*0.5))

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

func next_wave(early: bool = true) -> void:
	if paused or outcome != "playing" or wave_index >= config.waves.size(): return
	var wave = config.waves[wave_index]
	if early: early_wave_count += 1
	running_waves.append({"index": wave_index, "at": 0, "spawn_ms": clock_ms})
	running_waves[-1].spawn_ms = clock_ms + maxi(STEP_MS, int(ceil(float(wave.delay)/STEP_MS))*STEP_MS)
	wave_index += 1
	next_wave_ms = clock_ms + int(config.wavedelay)
	record("wave", {"early": early})
	emit("wave", {"index": wave_index, "early": early})

func spawn_enemy(type: int, source_index: int, wave_type: String, enemy_id: int = -1) -> Dictionary:
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
		"speed": f32(float(def.speed)*speed_scale), "cell": c, "next_cell": c, "pos": center(c.x, c.y),
		"dir": Vector2.RIGHT, "source": source_index, "air": def.get("class", "ground") == "air", "native_air": def.get("class", "ground") == "air",
		"base": -1, "path": [], "path_at": 1, "attacking": false, "attack_reload_ms": 0, "attack_point": Vector2.ZERO, "slow": 1.0, "slow_until": 0,
		"float_until": 0, "disco_until": disco_until, "portal_ms": 0, "born_ms": clock_ms, "slow_pending": -1.0}
	next_id += 1
	enemies.append(e)
	set_enemy_path(e)
	emit("spawn", {"id": e.id, "type": type})
	return e

func choose_target(t: Dictionary, radius: float) -> Dictionary:
	var best: Dictionary = {}
	for e in enemies:
		if e.hp <= 0 or not can_hit(int(t.def.get("aim", 0)), e): continue
		if int(t.type) == 11 and clock_ms < int(e.float_until): continue
		if clock_ms < e.float_until and int(t.type) not in [7, 8, 9, 12]: continue
		if not in_range(t.pos, e.pos, radius): continue
		if best.is_empty(): best = e
		elif t.targeting == "fastest" and e.speed*e.slow > best.speed*best.slow: best = e
		elif t.targeting == "strongest" and e.hp > best.hp: best = e
		elif t.targeting == "weakest" and e.hp < best.hp: best = e
	return best

func can_hit(aim: int, e: Dictionary) -> bool:
	return aim == 0 or (aim == 1 and not e.air) or (aim == 2 and e.air)

func bonuses(t: Dictionary) -> Dictionary:
	var result = {"damage": 1.0, "range": 1.0, "rof": 1.0}
	if int(t.type) >= 16: return result
	for support in towers:
		if support.id == t.id or support.type < 16 or clock_ms < support.ready_ms: continue
		if t.pos.distance_to(support.pos) < float(support.def.range)/1000.0*float(map.hex_h):
			# ProcessSupply keeps the maximum benefit in each component; it does not compound towers.
			result.damage = maxf(result.damage, f32(1.0 + float(support.def.get("dmg_bonus", 0))/100.0))
			result.range = maxf(result.range, f32(1.0 + float(support.def.get("range_bonus", 0))/100.0))
			result.rof = maxf(result.rof, f32(1.0 + float(support.def.get("rof_bonus", 0))/100.0))
	return result

func damage(e: Dictionary, amount: float, owner: int = 0) -> void:
	if e.hp <= 0: return
	e.hp = f32(e.hp - amount)
	if e.hp <= 0:
		kills += 1
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
	t.angle = atan2(e.pos.y-t.pos.y, e.pos.x-t.pos.x)
	# CTower::Update divides the nominal interval by the maximum support factor.
	t.shot_ms = clock_ms + maxi(30, int(f32(float(d.get("rof", 1000))/boost.rof)))
	emit("shot", {"from": t.pos, "to": e.pos, "type": t.type, "filename": d.filename})
	if t.type in [4, 5, 6, 14]:
		# ProcessNukeLaunch has a 2000 ms opening/warning stage before launch.
		var count = [2, 3, 4][int(t.level)-1] if int(t.type) == 6 else [2, 4, 6][int(t.level)-1] if int(t.type) == 14 else 1
		var divisor = (4.0 if int(t.level) == 3 else 3.0) if int(t.type) == 6 else 6.0 if int(t.type) == 14 else 1.0
		for i in range(count):
			missiles.append({"pos": t.pos, "destination": e.pos, "target": e.id, "def": d, "owner": t.id, "boost": boost.damage, "type": t.type, "divisor": divisor, "launch_ms": clock_ms+2000 if t.type == 5 else clock_ms})
	elif t.type in [7, 8, 9]:
		zones.append({"pos": e.pos, "def": d, "until": clock_ms + int(d.get("poison_duration", 2000)), "owner": t.id, "type": t.type})
	elif t.type == 11:
		e.float_until = clock_ms + int(d.get("float_time", 3000))
		emit("float", {"pos": e.pos})
	else:
		damage(e, f32(float(d.get("damage", 0))*boost.damage), t.id)

func impact(p: Dictionary) -> void:
	var radius = float(p.def.get("damagerange", 0))/1000.0
	var per_missile = f32(f32(float(p.def.get("damage", 0))*float(p.boost))/float(p.get("divisor", 1.0)))
	for e in enemies:
		if e.hp <= 0: continue
		# CMissile::DoDamageToTarget 0xdecc4: a normal missile directly hits
		# its target even when collateral damage is ground-only. Nukes use area.
		if int(p.type) != 5 and int(e.id) == int(p.target):
			damage(e, per_missile, p.owner)
			continue
		if radius <= 0 or not can_hit(int(p.def.get("damagerangeaim", p.def.get("aim", 0))), e): continue
		var distance = f32(e.pos.distance_to(p.pos)/float(map.hex_h))
		if distance >= radius: continue
		var falloff = f32(1.0-f32(distance/per_missile)) if distance > 0 and per_missile > 0 else 1.0
		damage(e, f32(per_missile*falloff), p.owner)
	if p.type == 5:
		zones.append({"pos": p.pos, "def": p.def, "until": clock_ms + int(p.def.get("poison_duration", 6000)), "owner": p.owner, "type": 5})
	emit("explosion", {"pos": p.pos, "type": p.type, "radius": maxf(0.4, radius)})

func duration(key: String, upgrade_key: String = "") -> int:
	var result = f32(float(catalog.tower_magic[key])*(1.0 + float(upgrades.get("up_wizard", 0))*0.05))
	if not upgrade_key.is_empty(): result = f32(result*(1.0+float(upgrades.get(upgrade_key, 0))*0.05))
	return int(result)

func use_ability(key: String, pos: Vector2 = Vector2.ZERO) -> String:
	if paused or outcome != "playing": return "The game is paused."
	if int(abilities.get(key, 0)) <= 0: return "Buy more in the Tech Shop."
	if key == "m_freeze" and clock_ms < freeze_until: return "Freeze is still active."
	if key == "m_lsd" and clock_ms < disco_until: return "Disco Magic is still active."
	if key == "m_actdef" and clock_ms < defense_until: return "Active Defense is still active."
	if key == "m_mine" and mines.size() >= int(catalog.tower_magic.mine_max): return "Maximum mines reached."
	if key in ["m_mine", "m_portal"]:
		var cell = nearest(pos)
		if not within(cell) or int(map.cells[cell_index(cell)].w) != 1: return "Choose an open hex."
		pos = center(cell.x, cell.y)
	match key:
		"m_freeze": freeze_until = clock_ms + duration("freeze_duration", "up_freeze")
		"m_lsd":
			disco_until = clock_ms + duration("lsd_duration", "up_pharm")
			for e in enemies:
				e.disco_until = disco_until
				set_enemy_path(e)
		"m_actdef": defense_until = clock_ms + duration("actdef_duration", "up_actdef")
		"m_mine": mines.append({"pos": pos, "cell": nearest(pos), "ready": clock_ms + int(catalog.tower_magic.mine_sleep), "static": false})
		"m_portal":
			if portals.size() >= 2: return "A portal pair is already active."
			portals.append({"pos": pos, "until": clock_ms+duration("portal_duration")})
			if portals.size() == 1:
				emit("portal_pending", {"pos": pos})
				return "Choose the portal exit."
			portals[0].until = clock_ms+duration("portal_duration")
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

func cancel_portal_placement() -> void:
	if portals.size() == 1: portals.clear()

func step() -> void:
	clock_ms += STEP_MS
	var seconds = float(STEP_MS)/1000.0
	validate_paths()
	if clock_ms < freeze_until:
		next_wave_ms += STEP_MS
		for running in running_waves: running.spawn_ms += STEP_MS
	elif survival_remaining_ms > 0:
		survival_remaining_ms = maxi(0, survival_remaining_ms-STEP_MS)
		if survival_remaining_ms == 0: finish("victory"); return
	if clock_ms >= next_wave_ms and wave_index < config.waves.size(): next_wave(false)
	for running in running_waves.duplicate():
		var wave = config.waves[running.index]
		while clock_ms >= running.spawn_ms and running.at < wave.creep_ids.size():
			var src = int(wave.source_ids[running.at]) if running.at < wave.source_ids.size() else 0
			spawn_enemy(int(wave.creep_ids[running.at]), src, str(wave.type), (int(running.index)+1)*int(catalog.get("tower_max_wave_length", 100))+int(running.at))
			running.at += 1
			running.spawn_ms = clock_ms + maxi(STEP_MS, int(ceil(float(wave.delay)/STEP_MS))*STEP_MS)
		if running.at >= wave.creep_ids.size(): running_waves.erase(running)
	# Recovered normal-update order: enemies, towers, mines, portals, bases.
	for e in enemies:
		if e.hp <= 0: continue
		e.slow = e.slow_pending if e.slow_pending > 0 else 1.0
		e.slow_pending = -1.0
		e.poison_count = 0
		e.slow_count = 0
		if e.float_until > 0 and clock_ms >= e.float_until:
			e.air = e.native_air
			e.float_until = 0
			set_enemy_path(e)
		if e.disco_until > 0 and clock_ms >= e.disco_until:
			e.disco_until = 0
			set_enemy_path(e)
		if clock_ms < freeze_until or clock_ms < e.float_until: continue
		if e.path.is_empty() or e.base < 0: continue
		var distance = float(e.speed)/1000.0*float(map.hex_h)*seconds*float(e.slow)
		while distance > 0 and movement_point_allowed(e):
			var cell = e.path[e.path_at]
			var point = center(cell.x, cell.y)
			var travel = e.pos.distance_to(point)
			e.next_cell = cell
			if travel > 0.001: e.dir = (point-e.pos).normalized()
			if travel <= distance:
				e.pos = point
				e.cell = cell
				e.path_at += 1
				distance -= travel
			else:
				e.pos = e.pos.move_toward(point, distance)
				distance = 0
		if not movement_point_allowed(e) and e.disco_until == 0:
			var b = bases[e.base]
			if int(e.def.traits.get("kamikaze", 0)) != 1:
				if not e.attacking:
					e.attacking = true
					e.attack_point = displace_point(e.cell, b.pos, int(e.id), e.pos)
					e.attack_reload_ms = 0
				var aim_distance = float(e.speed)/1000.0*float(map.hex_h)*seconds*float(e.slow)
				e.pos = e.pos.move_toward(e.attack_point, aim_distance)
				e.dir = (b.pos-e.pos).normalized()
				if e.pos.distance_to(e.attack_point) > 0.001: continue
				e.attack_reload_ms += STEP_MS
				if int(e.attack_reload_ms) < int(e.def.rof): continue
				e.attack_reload_ms = 0
			b.hp = maxf(0.0, b.hp-float(e.def.damage))
			emit("base_hit", {"pos": b.pos, "damage": e.def.damage})
			if int(e.def.traits.get("kamikaze", 0)) == 1:
				e.hp = 0.0
				emit("base_impact", {"id": e.id, "pos": e.pos, "type": e.type})
			if b.hp <= 0:
				path_cache.clear()
				reroute_all()
		elif e.path_at >= e.path.size() and clock_ms < e.disco_until: set_enemy_path(e)
	for t in towers:
		if clock_ms < t.ready_ms: continue
		var boost = bonuses(t)
		var radius = float(t.def.get("range", 0))/1000.0*float(boost.range)
		if t.type < 16 and clock_ms >= t.shot_ms:
			if t.type == 12:
				for e in enemies:
					if e.hp > 0 and can_hit(int(t.def.get("aim", 0)), e) and in_range(t.pos, e.pos, radius):
						damage(e, float(t.def.damage)*seconds*boost.damage, t.id)
						emit("beam", {"from": t.pos, "to": e.pos, "type": 12})
			else:
				var target = choose_target(t, radius)
				if not target.is_empty(): shoot(t, target, boost)
		if clock_ms < defense_until:
			for e in enemies:
				if e.hp > 0 and can_hit(int(t.def.get("aim", 0)), e) and in_range(t.pos, e.pos, float(catalog.tower_magic.actdef_range)/1000.0):
					damage(e, float(catalog.tower_magic.actdef_damage)*seconds, t.id)
					emit("beam", {"from": t.pos, "to": e.pos, "type": 10})
	for p in missiles.duplicate():
		for e in enemies:
			if int(p.type) != 5 and e.id == p.target and e.hp > 0: p.destination = e.pos
		if clock_ms < p.launch_ms: continue
		var travel = float(p.def.get("velocity", 3000))/1000.0*float(map.hex_h)*seconds
		p.pos = p.pos.move_toward(p.destination, travel)
		if p.pos.distance_to(p.destination) < 0.1:
			impact(p)
			missiles.erase(p)
	for z in zones.duplicate():
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
			var nominal = float(z.def.get("poison_damage", 0))
			var falloff = f32(1.0-distance/nominal) if nominal > 0 and distance > 0 else 1.0
			damage(e, f32(f32(nominal*falloff)*seconds/pow(2.0, e.poison_count)), z.owner)
			e.poison_count += 1
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
		if clock_ms >= portals[0].until: portals.clear()
		else:
			for e in enemies:
				if e.hp <= 0 or e.air or clock_ms < e.float_until or clock_ms < e.portal_ms: continue
				if e.cell == nearest(portals[0].pos):
					e.pos = portals[1].pos
					e.cell = nearest(e.pos)
					e.portal_ms = clock_ms+int(catalog.tower_magic.portal_reload)
					set_enemy_path(e)
	for pair in static_portals:
		for e in enemies:
			if e.hp > 0 and not e.air and clock_ms >= e.portal_ms and e.cell == pair["in"]:
				e.cell = pair.out
				e.pos = center(e.cell.x, e.cell.y)
				e.portal_ms = clock_ms+int(catalog.tower_magic.portal_reload)
				set_enemy_path(e)
				emit("teleport", {"id": e.id, "pos": e.pos})
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
		outcome, paused, early_wave_count, enemies, towers, bases, running_waves, missiles, zones, mines, portals,
		static_portals, abilities, freeze_until, disco_until, defense_until, pending_towers,
		last_paths_ms, next_id, rng.state, tutorial_finished, survival_remaining_ms, displacement_owners]).sha256_text()

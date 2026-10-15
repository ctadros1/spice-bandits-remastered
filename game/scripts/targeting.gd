extends RefCounted

# CCreepManager::GetNearestCreep0xfb9b0. Compared with the preserved ARM
# function, not a replacement oracle derived from this implementation.
static func f32(v: float) -> float: return Vector2(v,0.0).x

static func eligible(e: Dictionary, aim: int, owner: int, gravity: bool) -> bool:
	var state = int(e.get("state", 0))
	var enemy_aim = int(e.get("aim", 2 if e.get("native_air", e.get("air", false)) else 1))
	return state not in [2, 3] and (not gravity or state != 5) and float(e.get("hp", 10)) > 0 and (aim == 0 or aim == enemy_aim) and int(e.get("owner", 0)) != owner and int(e.get("target_owner", 0)) in [0, owner]

static func select(entries: Array, cell: Vector2, mode: String, gravity: bool, aim: int, owner: int, collect: bool = false, grid: Callable = Callable(), in_range: Callable = Callable()) -> Dictionary:
	var candidates: Array[int] = []
	var nearest = 100000000.0
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		if not eligible(e, aim, owner, gravity): continue
		var point: Vector2
		if grid.is_valid(): point = grid.call(e)
		else: point = Vector2(e.grid[0], e.grid[1])
		var x = f32(point.x-cell.x)
		var y = f32(point.y-cell.y)
		var distance = f32(f32(x*x)+f32(y*y))
		if not collect or gravity:
			if distance >= nearest: continue
		if in_range.is_valid() and not in_range.call(e): continue
		candidates.append(i)
		nearest = distance
	if collect and not gravity: return {"selected": -1, "collected": candidates}
	var best = -1
	var threshold = 100000000.0 if mode == "weakest" else 0.0
	for i in candidates:
		var e: Dictionary = entries[i]
		var value = f32(float(e.get("speed", 1000))*float(e.get("slow", 1))) if mode in ["", "fastest"] else f32(float(e.get("hp", 10)))
		if (mode in ["", "fastest", "strongest"] and value > threshold) or (mode == "weakest" and value < threshold):
			best = i
			threshold = float(int(value)) if mode == "strongest" else value
	return {"selected": best, "collected": []}

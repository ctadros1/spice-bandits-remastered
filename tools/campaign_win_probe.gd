extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var rows: Array = []
var content
var profile
var hashes: Dictionary
var selected_configs: Array = []
var magic_enabled = false
var strategy = "range"
var deployment_failures: Dictionary = {}
var rejected_cells: Dictionary = {}
var output = "../builds/campaign-win-probe.json"
var tower_limit = 96
var earned_profile = ""
var diagnostic_shopping: Array=[]

func _initialize() -> void: run.call_deferred()

func source_hashes() -> Dictionary:
	var values = {}
	for path in ["res://scripts/simulation.gd", "res://scripts/creep_view.gd", "res://data/catalog.json", "res://data/maps.json", "res://data/animations.json", "res://native/bin/libspice_hotpaths.dylib", "res://../native/hotpaths.cpp"]: values[path] = FileAccess.get_sha256(path)
	values["strategy_harness"] = FileAccess.get_sha256(get_script().resource_path)
	values["targeting"] = FileAccess.get_sha256("res://scripts/targeting.gd")
	values["profile"] = FileAccess.get_sha256("res://scripts/profile.gd")
	if not earned_profile.is_empty(): values["earned_profile"] = FileAccess.get_sha256(earned_profile)
	return values

func write_report(complete: bool) -> void:
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": complete, "engine": Engine.get_version_info().string,
		"method": ("Read-only battle strategy using a copy of the saved earned profile, legal battle budget and owned technology/upgrades/stock. Requested shop purchases spend earned currency in an isolated diagnostic copy. No campaign progress or rewards are saved. " if not earned_profile.is_empty() else "Automated legal battle-budget strategies with all recovered tower technology and ten levels of local upgrades pre-owned, excluding Friend Power. Five of each combat magic item pre-owned when --magic is enabled. ")+"Long-range branches, spread placements and pre-wave deployment. Not a fresh-profile campaign traversal or original-device parity. Tutorial is covered by the separate scripted tutorial replay.",
		"seed": 114, "strategy": strategy, "tower_limit": tower_limit, "source_hashes_before": hashes, "source_hashes_after": source_hashes(), "resources_unchanged": hashes == source_hashes(), "configurations": rows}, "\t"))
	file.close()

func candidates(s) -> Array:
	var points = []
	for source in s.sources:
		for base in s.bases:
			if s.bases.any(func(b): return int(b.get("mustsurvive", 0)) == 1) and int(base.get("mustsurvive", 0)) != 1: continue
			for air in [false, true]:
				var path = s.route(Vector2i(int(source.x), int(source.y)), Vector2i(int(base.x), int(base.y)), air)
				for i in range(path.size()):
					points.append({"pos": s.center(path[i].x, path[i].y), "weight": 0.25+float(i)/maxi(1, path.size()), "air": air})
	var result = []
	for y in range(int(s.map.hex_height)):
		for x in range(int(s.map.hex_width)):
			var cell = Vector2i(x, y)
			if not s.buildable(cell) or rejected_cells.has(cell): continue
			var position = s.center(x, y)
			var utility = 0.0
			for point in points:
				var distance = position.distance_to(point.pos)/float(s.map.hex_h)
				var reach = 12.0 if strategy in ["wide", "defense", "air_sniper", "air_mixed"] else 3.5
				if distance <= reach: utility += float(point.weight)*(reach-distance)
			if utility > 0: result.append({"cell": cell, "utility": utility})
	result.sort_custom(func(a, b): return a.utility > b.utility)
	return result

func promote(s, tower) -> void:
	var wanted = int(tower.get("desired_type", tower.type))
	var root_type = 1+int((wanted-1)/3)*3
	for choice in [[root_type, 2], [root_type, 3], [wanted, 1], [wanted, 2], [wanted, 3]]:
		if choice in s.upgrade_options(tower):
			if not s.upgrade_tower(int(tower.id), choice[0], choice[1]).is_empty(): return

func deploy(s, positions: Array, family: int) -> bool:
	for tower in s.towers:
		if int(tower.type) != int(tower.get("desired_type", tower.type)) or int(tower.level) < 3:
			var wanted=int(tower.get("desired_type",tower.type))
			var next=s.upgrade_options(tower).filter(func(choice):return (int(choice[0])==int(tower.type) or int(choice[0])==wanted) and s.can_unlock(s.tower_data(choice[0],choice[1])))
			if next.is_empty():continue
			var before = s.money
			promote(s, tower)
			return s.money<before
	var ordered = []
	for candidate in positions:
		if not s.tower_at(candidate.cell).is_empty(): continue
		var nearby = 0.0
		var point = s.center(candidate.cell.x, candidate.cell.y)
		for tower in s.towers:
			var radius = float(tower.def.range)/1000.0*float(s.bonuses(tower).range)
			if s.in_range(tower.pos, point, radius): nearby += 1.0
		ordered.append({"cell": candidate.cell, "utility": candidate.utility/pow(1.0+nearby, 2)})
	ordered.sort_custom(func(a, b): return a.utility > b.utility)
	var root_type = 1+int((family-1)/3)*3
	for candidate in ordered:
		var error = s.build(candidate.cell, root_type)
		if error.is_empty():
			var tower = s.towers[-1]
			tower.desired_type = family
			tower.targeting = "weakest"
			promote(s, tower)
			return true
		deployment_failures[error] = int(deployment_failures.get(error, 0))+1
	return false

func cast_magic(s) -> void:
	if not magic_enabled: return
	var danger = 0
	var imminent = false
	for enemy in s.enemies:
		if enemy.hp <= 0 or enemy.base < 0: continue
		if enemy.pos.distance_to(s.bases[enemy.base].pos) < 5.0*float(s.map.hex_h): danger += 1
		if enemy.pos.distance_to(s.bases[enemy.base].pos) < 6.0*float(s.map.hex_h) and float(enemy.def.damage) >= float(s.bases[enemy.base].hp)*0.25: imminent = true
	if danger < 4 and s.base_fraction() > 0.9 and not imminent: return
	if s.clock_ms >= s.defense_until and int(s.abilities.get("m_actdef", 0)) > 0: s.use_ability("m_actdef")
	if s.clock_ms < s.defense_until and s.clock_ms >= s.disco_until and int(s.abilities.get("m_lsd", 0)) > 0: s.use_ability("m_lsd")
	elif danger >= 1 and s.clock_ms >= s.freeze_until and int(s.abilities.get("m_freeze", 0)) > 0: s.use_ability("m_freeze")

func family_for(air: bool, count: int) -> int:
	if strategy=="air_sniper" and air:return 15
	if strategy=="air_mixed" and air:return [15,3,15,5,3,15][count%6]
	if strategy == "wide" and air: return 13 if count < 2 or count%3 != 0 else 15
	if strategy == "defense": return 13 if count%4 == 2 else 3
	if strategy == "swarm": return 13 if air and count%3 == 2 else 8 if not air and count%5 == 4 else 2
	if strategy == "mixed": return [15, 3, 9, 8, 5, 12][count%6]
	if strategy == "chemical" and not air: return [3, 9, 8, 5][count%4]
	return 15 if air and count%2 == 0 else 5 if not air and count%4 == 2 else 3

func remember_blocked(s) -> void:
	for event in s.events:
		if event.kind == "blocked": rejected_cells[s.nearest(event.pos)] = true

func run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--configs="): selected_configs = Array(arg.trim_prefix("--configs=").split(","))
		elif arg.begins_with("--strategy="): strategy = arg.trim_prefix("--strategy=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--earned-profile="): earned_profile = arg.trim_prefix("--earned-profile=")
		elif arg.begins_with("--purchase="): diagnostic_shopping=Array(arg.trim_prefix("--purchase=").split(","))
	magic_enabled = "--magic" in OS.get_cmdline_user_args()
	content = root.get_node("Content")
	profile = root.get_node("Profile")
	profile.path = "user://verification/campaign-strategy-profile.json"
	hashes = source_hashes()
	var account = profile.fresh()
	if not earned_profile.is_empty():
		account = profile._decode(earned_profile)
		if account.is_empty(): push_error("Earned strategy profile is invalid.");quit(1);return
		profile.data=account
		for id in diagnostic_shopping:
			var offers=content.catalog.shopList.filter(func(o):return str(o.shopitemid)==str(id))
			if offers.is_empty() or not profile.purchase(offers[0]).begins_with("Purchased "):push_error("Diagnostic purchase is unavailable or unaffordable.");quit(1);return
		account=profile.data.duplicate(true)
	else:
		for type in range(1, 19):
			for level in range(1, 4):
				var tower = content.tower(type, level)
				if tower.has("unlock"): account.unlocks.append(tower.unlock)
		account.abilities = {"m_freeze": 5, "m_lsd": 5, "m_actdef": 5} if magic_enabled else {}
		for key in content.catalog.tower_upgrades:
			if key != "up_friends": account.upgrades[key] = 10
	for mission in content.catalog.offlineConfigs:
		if mission.waves.is_empty() or str(mission.configid) == "1": continue
		if not selected_configs.is_empty() and str(mission.configid) not in selected_configs: continue
		var s = Simulation.new()
		deployment_failures = {}
		rejected_cells = {}
		s.setup(content.catalog, content.maps[mission.map], mission, account, 114, content.animations)
		var positions = candidates(s)
		var air_slots = 0
		var all_slots = 0
		for wave in mission.waves:
			for id in wave.creep_ids:
				if int(id) == 21 or int(id) >= content.catalog.tower_creeps.size(): continue
				all_slots += 1
				if str(content.catalog.tower_creeps[int(id)].get("class", "ground")) == "air": air_slots += 1
		var air_heavy = int(mission.gametype) == 6 or (strategy != "wide" and air_slots > all_slots/4)
		for i in range(10):
			var family = family_for(air_heavy, i)
			if not deploy(s, positions, family): break
			s.advance(300) # All preserved first-wave countdowns are at least30 seconds.
			remember_blocked(s)
			positions = candidates(s)
			s.events.clear()
		var peak = 0
		var iterations = 0
		var placement_count = -1
		while s.outcome == "playing" and s.clock_ms < 1800000:
			# Placement changes ground routes. Re-evaluate the exposed route
			# instead of exhausting only the original path's neighboring cells.
			if s.towers.size() != placement_count:
				positions = candidates(s)
				placement_count = s.towers.size()
			var family = family_for(air_heavy, s.towers.size())
			if s.towers.size() < tower_limit: deploy(s, positions, family)
			if int(mission.settings.get("survive_time", 0)) == 0 and s.running_waves.is_empty() and s.enemies.is_empty() and s.wave_index < mission.waves.size(): s.next_wave(true)
			cast_magic(s)
			s.advance(900)
			var rejected_before = rejected_cells.size()
			remember_blocked(s)
			if rejected_before != rejected_cells.size(): placement_count = -1
			peak = maxi(peak, s.enemies.size())
			s.events.clear()
			iterations += 1
		var row = {"config": mission.configid, "map": mission.map, "mode": mission.gametype,
			"outcome": s.outcome, "ms": s.clock_ms, "waves": s.wave_index, "kills": s.kills,
			"base_health": s.base_fraction(), "money": s.money, "towers": s.towers.size(), "tower_forms": s.towers.map(func(t): return {"cell": t.cell, "type": t.type, "level": t.level}), "deployment_failures": deployment_failures, "peak_enemies": peak, "magic_left": s.abilities, "survivors": s.enemies.map(func(e): return {"id": e.id, "type": e.type, "hp": e.hp, "base": e.base, "pos": e.pos}), "replay": s.replay, "digest": s.digest()}
		rows.append(row)
		write_report(false)
		print("CAMPAIGN_STRATEGY ", rows.size(), " config=", mission.configid, " ", s.outcome, " hp=", s.base_fraction(), " towers=", s.towers.size())
		await process_frame
	write_report(true)
	quit(0)

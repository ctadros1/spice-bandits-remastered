extends RefCounted

# AchTracker::checkForMedals0x3a0a8 and setInLiveGame0x3a4d4 use native
# catalog IDs, deduplicate a match, and keep the lowest numeric grade per key.
static func identity(m: Dictionary) -> String:
	return "%s:%d" % [str(m.key), int(m.grade)]

static func select(catalog: Array, values: Dictionary) -> Array[Dictionary]:
	var selected: Dictionary = {}
	for m in catalog:
		var key = str(m.key)
		if not values.has(key) or int(values[key]) < int(m.param): continue
		if not selected.has(key) or int(m.grade) < int(selected[key].grade): selected[key] = m
	var result: Array[Dictionary] = []
	# Keep the source catalog order; presentation and reward order use it.
	for m in catalog:
		if selected.get(str(m.key), {}) == m: result.append(m)
	return result

static func secret_condition(key: String, towers: Array, perfect: bool) -> bool:
	# CWinLoseScreen::CheckForSpiceMedals0xbf448 examines surviving towers.
	# Descriptions such as "without building" do not override that code.
	match key:
		"won_sd_only_mg": return not towers.is_empty() and towers.all(func(t): return int(t.type) <= 3)
		"won_normal_lvl_1": return not towers.is_empty() and towers.all(func(t): return int(t.level) <= 1)
		"won_normal_with_star": return perfect
		"won_sd_only_one_tower": return towers.size() == 1
		"won_sd_without_mg": return not towers.is_empty() and towers.all(func(t): return int(t.type) < 1 or int(t.type) > 3)
		"won_normal_duke_nuke": return towers.any(func(t): return int(t.type) == 5 and int(t.level) == 3)
		"won_normal_3_gsuperguns": return towers.filter(func(t): return int(t.type) == 2 and int(t.level) == 3).size() >= 3
		"won_normal_5_freeze": return towers.filter(func(t): return int(t.type) == 8).size() >= 5
		"won_air_without_aa_tower": return not towers.is_empty() and towers.all(func(t): return int(t.type) < 13 or int(t.type) > 15)
	return false

static func battle_values(sim, stats: Dictionary, catalog: Array) -> Dictionary:
	var values = {}
	if sim.outcome != "victory" or str(sim.config.configid) == "1": return values
	# Global counters qualify only if the matching event occurred in this
	# battle. Winning a later match with no build/use is not another event.
	var used = false
	var families = {}
	var build_keys = {1: "built_mg", 4: "built_missiles", 7: "built_acid", 10: "built_electricity", 13: "built_aa", 16: "built_support"}
	var magic_keys = {"m_freeze": "use_freeze", "m_lsd": "use_lsd", "m_actdef": "use_actdef", "m_mine": "use_mines", "m_portal": "use_teleport"}
	for action in sim.replay:
		if action.kind == "build":
			var type = int(action.args.type)
			families[int((type-1)/3)] = true
			if build_keys.has(type): values[build_keys[type]] = int(stats.get(build_keys[type], 0))
		elif action.kind == "magic":
			used = true
			var key = magic_keys.get(str(action.args.key), "")
			if not key.is_empty(): values[key] = int(stats.get(key, 0))
	if used:
		values.used_magic = 1
		values.use_total_magic = int(stats.get("use_total_magic", 0))
	if families.size() == 6: values.built_all = 1
	values.upgrade_top = int(sim.upgrade_top_count)
	values.money_left = int(sim.money)
	values.kills_row = int(sim.closed_kill_chain)
	var mode = {1: "won_games_normal", 3: "won_games_sd", 6: "won_games_air"}.get(int(sim.config.gametype), "")
	if not mode.is_empty(): values[mode] = int(stats.get(mode, 0))
	# Open0xbcd20 uses>=1,>=.75,>=.5 and sends10,7,5 respectively.
	var fraction = float(sim.early_wave_count)/maxi(1, sim.config.waves.size())
	if fraction >= 0.5: values.won_all_early = 10 if fraction >= 1 else 7 if fraction >= 0.75 else 5
	if int(sim.config.gametype) == 3 and fraction >= 1: values.won_sd_all_early = 1
	for m in catalog:
		if int(m.get("location", -1)) == int(sim.config.location) and int(m.get("gametype", -1)) == int(sim.config.gametype):
			if secret_condition(str(m.key), sim.towers, sim.perfect_game()): values[str(m.key)] = 1
			break # Native function returns after the first matching source entry.
	return values

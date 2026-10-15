extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var content
var profile
var rejected_cells: Dictionary = {}
var rows: Array = []
var hashes: Dictionary = {}
var stop_after = 80
var resumed = false
var starting_snapshot: Dictionary = {}
var shopping_signature = ""
var grind_remaining = 0
var grind_config="8"
var failed_missions: Dictionary = {}
var failed_technology: Dictionary = {}
var wide_strategy = false
var recipes: Dictionary={}
var recipe_paths: Array[String]=[]
var planned_purchases: Array=[]
var planned_exchanges=0
var allocation_keys=["up_range","up_damage","up_gun_rof"]

func _initialize() -> void: run.call_deferred()

func compare_saved(a, b, trail: String = "") -> bool:
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not compare_saved(a[key], b.get(key), trail+"/"+str(key)): return false
		return a.size() == b.size()
	if a is Array and b is Array:
		for i in range(mini(a.size(), b.size())):
			if not compare_saved(a[i], b[i], trail+"/"+str(i)): return false
		return a.size() == b.size()
	if a != b:
		print("SAVE_DIFFERENCE ", trail, " before=", JSON.stringify(a, "", true, true), " after=", JSON.stringify(b, "", true, true))
		return false
	return true

func source_hashes() -> Dictionary:
	var result = {"harness": FileAccess.get_sha256(get_script().resource_path)}
	for path in ["res://scripts/simulation.gd", "res://scripts/targeting.gd", "res://scripts/creep_view.gd", "res://scripts/profile.gd", "res://data/catalog.json", "res://data/maps.json", "res://data/animations.json", "res://native/bin/libspice_hotpaths.dylib", "res://../native/hotpaths.cpp"]: result[path] = FileAccess.get_sha256(path)
	for path in recipe_paths:result[path]=FileAccess.get_sha256(path)
	return result

func technology_signature() -> String:
	var owned=profile.data.unlocks.duplicate();owned.sort()
	return JSON.stringify({"unlocks":owned,"upgrades":profile.data.upgrades})

func retry_allowed(id: String) -> bool:
	return str(failed_technology.get(id,""))!=technology_signature()

func candidates(s) -> Array:
	var points = []
	for source in s.sources:
		for base in s.bases:
			if base.hp <= 0: continue
			if s.bases.any(func(b): return int(b.get("mustsurvive", 0)) == 1) and int(base.get("mustsurvive", 0)) != 1: continue
			for air in ([false,true] if wide_strategy else [false]):
				var path=s.route(Vector2i(int(source.x),int(source.y)),Vector2i(int(base.x),int(base.y)),air)
				for i in range(path.size()):points.append({"pos":s.center(path[i].x,path[i].y),"weight":0.25+float(i)/maxi(1,path.size()) if wide_strategy else 1.0})
	var result = []
	for y in range(int(s.map.hex_height)):
		for x in range(int(s.map.hex_width)):
			var cell = Vector2i(x, y)
			if not s.buildable(cell) or rejected_cells.has(cell): continue
			var value = 0.0
			var pos = s.center(x, y)
			for point in points: value += float(point.weight)*maxf(0, (12.0 if wide_strategy else 3.0)-pos.distance_to(point.pos)/float(s.map.hex_h))
			var nearby=0
			for tower in s.towers:
				if wide_strategy:
					if s.in_range(tower.pos,pos,float(tower.def.range)/1000.0*float(s.bonuses(tower).range)):nearby+=1
				elif s.in_range(tower.pos, pos, 2.2): value /= 2.0
			if wide_strategy:value/=pow(1.0+nearby,2)
			if value > 0: result.append({"cell": cell, "value": value})
	result.sort_custom(func(a, b): return a.value > b.value)
	return result

func buy_technology(s = null) -> void:
	var signature = "%d:%d:%d" % [int(profile.data.level), int(profile.data.spice), profile.data.unlocks.size()]
	if signature == shopping_signature: return
	shopping_signature = signature
	# Purchase only recovered offers whose level, prerequisites and cost are
	# already satisfied. Keep a small reserve for battle consumables.
	var wanted = ["T1L3", "T2L1", "T2L2", "T3L1", "T3L2", "T4L1", "T4L2", "T4L3", "T5L1", "T5L2", "T13L1", "T13L2", "T13L3", "T5L3", "T3L3", "T2L3"]
	for token in wanted:
		if profile.unlocked(token): continue
		var offers = content.catalog.shopList.filter(func(i): return str(i.unlockstring) == token)
		if offers.is_empty(): continue
		var offer = offers[0]
		if int(profile.data.level) < int(offer.levellock) or not profile.unlocked(str(offer.needsunlock)): continue
		if int(profile.data.spice) < int(offer.pricespice)+3: continue
		profile.purchase(offer)
	if s != null:
		for token in profile.data.unlocks:
			if token not in s.unlocks: s.unlocks.append(token)

func allocate_points() -> void:
	for cycle in range(40):
		var changed = false
		for key in allocation_keys:
			if not content.catalog.tower_upgrades.has(key) or key=="up_friends":continue
			var count = int(profile.data.upgrades.get(key, 0))
			if count >= 10 or int(profile.data.level) < int(content.catalog.tower_upgrades[key].level): continue
			if int(profile.data.specpoints) < int(content.catalog.tower_upgrade_costs[str(count+1)]): continue
			profile.upgrade(key)
			changed = true
		if not changed: break

func promote(s, tower: Dictionary) -> void:
	var choices = s.upgrade_options(tower)
	for choice in choices:
		if int(choice[0]) in [8,14,15]:continue
		if int(tower.type)==1 and int(tower.level)==3:
			var preferred=3 if wide_strategy or int(tower.id)%3==0 else 2
			if int(choice[0])!=preferred and s.can_unlock(s.tower_data(preferred,1)):continue
		if s.can_unlock(s.tower_data(choice[0], choice[1])):
			s.upgrade_tower(tower.id, choice[0], choice[1])
			return
		if wide_strategy and int(tower.type)==4 and int(tower.level)==3 and int(choice[0])==5 and s.can_unlock(s.tower_data(5,1)):
			s.upgrade_tower(tower.id,5,1)

func emergency_magic(s) -> void:
	var danger = s.enemies.filter(func(e): return e.hp > 0 and e.base >= 0 and e.pos.distance_to(s.bases[e.base].pos) < 3.5*float(s.map.hex_h)).size()
	if danger < 4 or s.base_fraction() > 0.6: return
	for key in ["m_actdef", "m_lsd", "m_freeze"]:
		if (key == "m_actdef" and s.clock_ms < s.defense_until) or (key == "m_lsd" and s.clock_ms < s.disco_until) or (key == "m_freeze" and s.clock_ms < s.freeze_until): continue
		# Use earned stock if available; save currency for permanent technology
		# instead of exhausting the same reserve on another failed strategy.
		if s.ability_error(key).is_empty() and profile.consume_magic(key): s.use_ability(key)

func next_mission() -> Dictionary:
	for id in recipes:
		if not profile.data.completed.has(id) and profile.available(content.mission(id)) and retry_allowed(id):return content.mission(id)
	# The pass is available through the original shop offers. Resolve it before
	# an optional bonus mission can monopolize the next-mission search.
	if profile.unlocked("mo6_sp") and not profile.unlocked("pass7_af"):
		for offer in content.catalog.shopList:
			if str(offer.unlockstring)=="pass7_af" and int(profile.data.level)>=int(offer.levellock) and int(profile.data.spice)>=int(offer.pricespice):
				profile.purchase(offer)
				break
	var normal=content.catalog.offlineConfigs.filter(func(c):return int(c.gametype)==1 and not c.waves.is_empty() and not profile.data.completed.has(str(c.configid)) and profile.available(c) and retry_allowed(str(c.configid)))
	normal.sort_custom(func(a,b):return int(str(a.grantsunlock).trim_prefix("mo").get_slice("_",0))<int(str(b.grantsunlock).trim_prefix("mo").get_slice("_",0)))
	if not normal.is_empty():return normal[0]
	# The recovered campaign explicitly requires mo5_sd after mo4_sp before
	# its next Normal mission. Advance required non-Normal modes too.
	for c in content.catalog.offlineConfigs:
		if int(c.gametype) in [3, 6] and not c.waves.is_empty() and not profile.data.completed.has(str(c.configid)) and profile.available(c) and retry_allowed(str(c.configid)): return c
	for offer in content.catalog.shopList:
		if str(offer.unlockstring) == "pass7_af" and not profile.unlocked("pass7_af") and int(profile.data.level) >= int(offer.levellock) and int(profile.data.spice) >= int(offer.pricespice):
			profile.purchase(offer)
			break
	for c in content.catalog.offlineConfigs:
		if int(c.gametype) == 1 and not c.waves.is_empty() and not profile.data.completed.has(str(c.configid)) and profile.available(c) and retry_allowed(str(c.configid)): return c
	# Retry deferred missions only after every newly opened path is exercised.
	# A grind win may finance different technology; identical failed actions
	# are not used to block the other original campaign branches.
	# Repeating Desert earns real currency for the next useful purchase.
	# Failed missions wait for a technology/upgrade change before retrying.
	return content.mission("8")

func required_stock(recipe: Array) -> Dictionary:
	var needed={}
	for action in recipe:
		if action.kind=="magic":needed[action.args.key]=int(needed.get(action.args.key,0))+1
	return needed

func stock_refill_cost(needed: Dictionary) -> int:
	var cost=0
	for key in needed:
		var missing=int(needed[key])-int(profile.data.abilities.get(key,0))
		while missing>0:
			var offers=content.catalog.shopList.filter(func(o):return str(o.tag)==str(key) and int(o.consumableamount)>0)
			offers.sort_custom(func(a,b):return int(a.pricespice)*ceili(float(missing)/int(a.consumableamount))<int(b.pricespice)*ceili(float(missing)/int(b.consumableamount)))
			if offers.is_empty():return 2147483647
			cost+=int(offers[0].pricespice);missing-=int(offers[0].consumableamount)
	return cost

func write_report(complete: bool) -> void:
	var f = FileAccess.open("res://../builds/fresh-campaign-probe.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"complete": complete, "endpoint_reached": profile.data.completed.has("13"), "resumed": resumed, "starting_snapshot": starting_snapshot, "method": "Fresh saved profile. Tutorial outcome comes from the headless UI replay; subsequent battles use legal money, owned technology only, live kill XP, and local reward/shop transactions. Includes repeated battles for earned currency and progression; not original-device parity or proof of the unavailable server level curve.", "profile_path": profile.path, "profile": profile.data, "source_hashes_before": hashes, "source_hashes_after": source_hashes(), "resources_unchanged": hashes == source_hashes(), "battles": rows}, "\t"))
	f.close()

func run() -> void:
	await process_frame
	content = root.get_node("Content")
	profile = root.get_node("Profile")
	profile.path = "user://verification/fresh-campaign-profile.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--battles="): stop_after = int(arg.trim_prefix("--battles="))
		if arg.begins_with("--grind="): grind_remaining = int(arg.trim_prefix("--grind="))
		if arg.begins_with("--grind-config="):grind_config=arg.trim_prefix("--grind-config=")
		if arg.begins_with("--purchase="):planned_purchases=Array(arg.trim_prefix("--purchase=").split(","))
		if arg.begins_with("--exchange="):planned_exchanges=maxi(0,int(arg.trim_prefix("--exchange=")))
		if arg.begins_with("--allocate="):allocation_keys=Array(arg.trim_prefix("--allocate=").split(","))
		if arg.begins_with("--recipe="):
			recipe_paths.append(arg.trim_prefix("--recipe="))
			var recipe_file=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--recipe=")))
			if recipe_file is Dictionary and recipe_file.get("resources_unchanged",false):
				for row in recipe_file.configurations:
					if str(row.outcome)=="victory":recipes[str(row.config)]=row.replay
	resumed = "--resume" in OS.get_cmdline_user_args()
	hashes=source_hashes()
	wide_strategy="--strategy=wide" in OS.get_cmdline_user_args()
	if resumed:
		profile.load_profile()
		var old = JSON.parse_string(FileAccess.get_file_as_string("res://../builds/fresh-campaign-probe.json"))
		if old is Dictionary: rows = old.get("battles", [])
		for row in rows:
			if str(row.outcome)!="victory":failed_missions[str(row.config)]=int(failed_missions.get(str(row.config),0))+1
		starting_snapshot = profile.data.duplicate(true)
		for i in range(planned_exchanges):
			if not profile.exchange_points().begins_with("Added "):push_error("Earned point exchange is unavailable or unaffordable.");quit(1);return
		for id in planned_purchases:
			var offers=content.catalog.shopList.filter(func(o):return str(o.shopitemid)==str(id))
			if offers.is_empty() or not profile.purchase(offers[0]).begins_with("Purchased "):push_error("Planned campaign purchase is unavailable or unaffordable.");quit(1);return
		if "--retry-failed" not in OS.get_cmdline_user_args():
			for key in failed_missions:failed_technology[key]=technology_signature()
		await play_battles()
		return
	profile.data = profile.fresh()
	profile.data.settings.music = false
	profile.data.settings.sound = false
	# The full UI replay exposes its winning original-budget simulation.
	var tutorial = load("res://scripts/tutorial_verify.gd").new()
	root.add_child(tutorial)
	var status = {"value": -1}
	tutorial.completed.connect(func(value): status.value = value)
	await tutorial.run()
	if status.value != 0: quit(1); return
	profile.path = "user://verification/fresh-campaign-profile.json"
	profile.data = profile.fresh()
	profile.data.settings.music = false
	profile.data.settings.sound = false
	if not profile.settle(tutorial.app.sim): quit(1); return
	rows.append({"config": "1", "outcome": tutorial.app.sim.outcome, "score": tutorial.app.sim.score, "xp": profile.data.xp, "spice": profile.data.spice, "level": profile.data.level})
	tutorial.app.queue_free()
	tutorial.queue_free()
	await play_battles()

func play_battles() -> void:
	var last_failed = ""
	for attempt in range(stop_after):
		buy_technology()
		allocate_points()
		var mission = next_mission()
		var forced_grind=grind_remaining>0
		if forced_grind: mission = content.mission(grind_config);grind_remaining -= 1
		if str(mission.configid) == last_failed: mission = content.mission("8")
		if str(mission.configid)=="8" and profile.data.completed.has("8") and not forced_grind and planned_purchases.is_empty():
			# No remaining strategy opens an unlocked path. Return the saved
			# checkpoint for a new diagnostic instead of repeating an unrelated
			# battle indefinitely. Budget deferrals below still earn needed funds.
			print("FRESH_CAMPAIGN_STRATEGY_STALLED unlocks=",profile.data.unlocks)
			write_report(true);quit(2);return
		if not profile.available(mission): push_error("Selected mission is not legitimately unlocked."); quit(1); return
		var recipe=recipes.get(str(mission.configid),[])
		# Recovered winning input recipes consume only actually purchased stock.
		# Refill before a later recipe only when its recorded casts require it.
		var needed=required_stock(recipe)
		var refill_cost=stock_refill_cost(needed)
		if int(profile.data.spice)<refill_cost:
			print("RECIPE_BUDGET_DEFERRED config=",mission.configid," stock_cost=",refill_cost," earned_spice=",profile.data.spice)
			# Finance original supplies through a real repeat victory. The next
			# iteration retries the unlocked recipe; nothing is granted or settled
			# for the deferred mission. A supplied fast-grind recipe is optional.
			mission=content.mission("10" if recipes.has("10") and profile.available(content.mission("10")) else "8")
			recipe=recipes.get(str(mission.configid),[])
			needed=required_stock(recipe)
		for key in needed:
			while int(profile.data.abilities.get(key,0))<int(needed[key]):
				var missing=int(needed[key])-int(profile.data.abilities.get(key,0))
				var offers=content.catalog.shopList.filter(func(o):return str(o.tag)==str(key) and int(o.consumableamount)>0)
				offers.sort_custom(func(a,b):return int(a.pricespice)*(ceili(float(missing)/int(a.consumableamount)))<int(b.pricespice)*(ceili(float(missing)/int(b.consumableamount))))
				if offers.is_empty() or not profile.purchase(offers[0]).begins_with("Purchased "):push_error("Earned recipe cannot afford required original consumables.");quit(1);return
		var s = Sim.new()
		s.setup(content.catalog, content.maps[mission.map], mission, profile.data, 114, content.animations)
		var initial_xp = int(profile.data.xp)
		var credited_score = 0.0
		var credited_kills = 0
		rejected_cells = {}
		var positions = candidates(s)
		var done = 0
		var rejected_count = 0
		var air_slots = 0
		var action_at=0
		for wave in mission.waves:
			for id in wave.creep_ids:
				if int(id) < content.catalog.tower_creeps.size() and str(content.catalog.tower_creeps[int(id)].get("class", "ground")) == "air": air_slots += 1
		while s.outcome == "playing" and s.clock_ms < 1800000:
			buy_technology(s)
			if not recipe.is_empty():
				while action_at<recipe.size() and int(recipe[action_at].ms)<=s.clock_ms:
					var action=recipe[action_at];var error=""
					match str(action.kind):
						"build":
							error=s.build(Vector2i(int(action.args.x),int(action.args.y)),int(action.args.type))
							if error.is_empty():s.towers[-1].targeting="weakest";s.record("targeting",{"id":s.towers[-1].id,"value":"weakest"})
						"upgrade":error=s.upgrade_tower(int(action.args.id),int(action.args.type),int(action.args.level))
						"wave":
							# Ordinary launches are emitted by the simulation itself.
							if bool(action.args.early):s.next_wave(true)
						"magic":
							var key=str(action.args.key)
							var point=action.args.get("pos",[0,0])
							error=s.ability_error(key)
							if error.is_empty():
								if not profile.consume_magic(key):error="Could not save the magic charge."
								else:error=s.use_ability(key,Vector2(point[0],point[1]))
					if not error.is_empty():push_error("Earned replay action failed at "+str(s.clock_ms)+": "+error+" "+JSON.stringify(action));quit(1);return
					action_at+=1
			else:
				pass
			var upgrade_pending=false
			if recipe.is_empty():
				for tower in s.towers:
					var wanted=3 if wide_strategy and int(tower.type) in [1,3] else 5 if wide_strategy and int(tower.type) in [4,5] else 13 if int(tower.type) in [13,14,15] else int(tower.type)
					var choices=s.upgrade_options(tower).filter(func(choice):return (int(choice[0])==int(tower.type) or int(choice[0])==wanted) and s.can_unlock(s.tower_data(choice[0],choice[1])))
					if choices.is_empty():continue
					upgrade_pending=true
					promote(s,tower)
					break
			if recipe.is_empty() and not upgrade_pending and s.money >= 20 and s.towers.size() < 60:
				var family = 13 if int(mission.gametype)==6 and s.can_unlock(s.tower_data(13,1)) else 4 if s.towers.size()%6 == 4 and s.can_unlock(s.tower_data(4, 1)) else 13 if air_slots > 0 and s.towers.size()%6 == 5 and s.can_unlock(s.tower_data(13, 1)) else 1
				for candidate in positions:
					if s.build(candidate.cell, family).is_empty():
						if wide_strategy:s.towers[-1].targeting="weakest";s.record("targeting",{"id":s.towers[-1].id,"value":"weakest"})
						break
			if recipe.is_empty() and int(mission.settings.get("survive_time", 0)) == 0 and s.running_waves.is_empty() and s.enemies.is_empty() and s.wave_index < mission.waves.size(): s.next_wave(true)
			if recipe.is_empty():emergency_magic(s)
			var increment=600
			if action_at<recipe.size():increment=mini(increment,maxi(30,int(recipe[action_at].ms)-s.clock_ms))
			s.advance(increment)
			var earned: Array[Dictionary] = []
			for event in s.events:
				if event.kind == "blocked": rejected_cells[s.nearest(event.pos)] = true
				if event.kind == "build" and not s.tower_at(s.nearest(event.pos)).is_empty(): profile.record_build(int(event.type))
				if event.kind == "kill": earned.append(event); credited_score += float(event.reward); credited_kills += 1
			if not earned.is_empty() and not profile.credit_battle_kills(earned, str(mission.configid)): push_error("Live campaign XP save failed."); quit(1); return
			if s.towers.size() != done or rejected_cells.size() != rejected_count:
				positions = candidates(s)
				done = s.towers.size()
				rejected_count = rejected_cells.size()
			s.events.clear()
		if not profile.settle(s, credited_score, credited_kills, initial_xp): push_error("Fresh result could not be saved."); quit(1); return
		last_failed = str(mission.configid) if s.outcome != "victory" else ""
		if s.outcome!="victory":failed_missions[str(mission.configid)]=int(failed_missions.get(str(mission.configid),0))+1
		if s.outcome!="victory":failed_technology[str(mission.configid)]=technology_signature()
		rows.append({"config": str(mission.configid), "outcome": s.outcome, "score": s.score, "base": s.base_fraction(), "money": s.money, "towers": s.towers.size(), "xp": profile.data.xp, "spice": profile.data.spice, "level": profile.data.level, "ms": s.clock_ms, "replay": s.replay})
		write_report(false)
		print("FRESH_CAMPAIGN ", attempt, " config=", mission.configid, " ", s.outcome, " xp=", profile.data.xp, " spice=", profile.data.spice, " level=", profile.data.level)
		var expected = profile.data.duplicate(true)
		profile.load_profile()
		if not compare_saved(expected, profile.data): push_error("Fresh campaign save did not reload exactly."); quit(1); return
		if profile.data.completed.has("13"): break
		await process_frame
	write_report(true)
	quit()

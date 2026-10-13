extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var content
var profile
var failures: Array[String] = []
var checks: int = 0
var report: Dictionary = {"scenarios": [], "campaign": []}

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		failures.append(name)
		push_error(name)

func make_sim(id: String = "8", all_unlocked: bool = true) -> BanditSimulation:
	var s = Sim.new()
	var p = profile.fresh()
	if all_unlocked:
		for type in range(1, 19):
			for level in range(1, 4):
				var t = content.tower(type, level)
				if t.has("unlock"): p.unlocks.append(t.unlock)
		p.abilities = {"m_freeze": 5, "m_lsd": 5, "m_actdef": 5, "m_mine": 5, "m_portal": 5}
	var c = content.mission(id)
	s.setup(content.catalog, content.maps[c.map], c, p)
	return s

func exercise_tower_forms() -> void:
	report.tower_forms = []
	for type in range(1, 19):
		for level in range(1, 4):
			var s = make_sim()
			s.next_wave_ms = 1000000
			s.build(Vector2i(10, 9), 1)
			var tower = s.towers[0]
			tower.type = type
			tower.level = level
			tower.def = s.tower_data(type, level)
			tower.ready_ms = 0
			tower.shot_ms = 0
			if type >= 16:
				s.build(Vector2i(10, 10), 1)
				var recipient = s.towers[1]
				var bonus = s.bonuses(recipient)
				check(is_equal_approx(bonus.damage, 1.0+float(tower.def.dmg_bonus)/100.0), "support damage component %d:%d" % [type, level])
				check(is_equal_approx(bonus.range, 1.0+float(tower.def.range_bonus)/100.0), "support range component %d:%d" % [type, level])
				check(is_equal_approx(bonus.rof, 1.0+float(tower.def.rof_bonus)/100.0), "support reload component %d:%d" % [type, level])
				report.tower_forms.append({"type": type, "level": level, "bonus": bonus})
				continue
			var air_only = int(tower.def.aim) == 2
			var victim = s.spawn_enemy(2 if air_only else 5, 0, "")
			victim.speed = 0
			victim.hp = 5000
			victim.max_hp = 5000
			victim.pos = tower.pos+Vector2(10, 0)
			s.advance(60 if type == 8 else 2400)
			if type == 8:
				check(victim.slow < 1.0 and victim.hp == 5000, "Goo slows without direct damage %d" % level)
			elif type == 11:
				check(victim.float_until > s.clock_ms and victim.hp == 5000, "Gravity immobilizes without direct damage %d" % level)
			else:
				check(victim.hp < 5000, "combat effect for original tower form %d:%d" % [type, level])
			if int(tower.def.aim) != 0:
				var excluded = s.spawn_enemy(5 if air_only else 2, 0, "")
				excluded.pos = tower.pos
				s.enemies.erase(victim)
				check(s.choose_target(tower, 3.0).is_empty(), "tower respects ground/air restriction %d:%d" % [type, level])
			report.tower_forms.append({"type": type, "level": level, "damage": 5000-victim.hp, "slow": victim.slow, "float_until": victim.float_until})

func run() -> void:
	await process_frame
	content = root.get_node("Content")
	profile = root.get_node("Profile")
	profile.path = "user://verification/profile.json"
	var started = Time.get_ticks_msec()
	check(content.catalog.tower_towers.size() == 19, "18 tower forms and sentinel")
	check(content.maps.size() == 67, "66 numbered maps and world map")
	for type in range(1, 19):
		for level in range(1, 4):
			var def = content.tower(type, level)
			check(not content.frame("towers/"+str(def.filename), "Idle").is_empty(), "original tower frame %d:%d" % [type, level])
	for i in range(content.catalog.tower_creeps.size()):
		var c = content.catalog.tower_creeps[i]
		if not c.has("filename"): continue
		var states = content.animations["creeps/"+str(c.filename)].states
		check(not content.frame("creeps/"+str(c.filename), states.keys()[0], 0, c.get("color", "")).is_empty(), "original enemy frame %d" % i)
	for i in range(20): check(not content.frame("bases/base"+str(i), "Idle").is_empty(), "original base frame %d" % i)
	var s = make_sim()
	check(s.center(4, 11) == Vector2(108, 493), "code-traced hex source coordinates")
	check(s.center(16, 8) == Vector2(900, 307), "code-traced hex base coordinates")
	check(s.money == 200.0, "data-confirmed initial money")
	check(s.config.waves.size() == 10, "Desert Freighter authored ten-wave schedule")
	var links = make_sim()
	links.map = links.map.duplicate(true)
	for cell in links.map.cells: cell.w = 1
	var short_path = links.route(Vector2i(8, 5), Vector2i(10, 5))
	check(short_path == [Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5)], "native goal-to-source shortcut corner insertion")
	check(links.route_cost(short_path, false) == 264, "native base selection adds the 132 pixel f score twice")
	links.map.cells[links.cell_index(Vector2i(9, 4))].w = 0
	check(not links.link_allowed(Vector2i(8, 5), Vector2i(10, 5), false), "horizontal ground shortcut checks the second common cell")
	check(links.link_allowed(Vector2i(8, 5), Vector2i(10, 5), true), "horizontal air shortcut ignores ground blockers")
	check(links.ordinary_links(Vector2i(8, 5)) == [Vector2i(8, 4), Vector2i(9, 5), Vector2i(7, 5), Vector2i(8, 6), Vector2i(7, 4), Vector2i(9, 4)], "native interior neighbor order preserves route ties")
	for mission in content.catalog.offlineConfigs:
		for wave in mission.waves:
			if wave.type == "slow": check(wave.indicator == 4, "native exact matcher leaves stale slow label as ordinary")
	check(s.in_range(Vector2.ZERO, Vector2(178, 0), 2), "code-traced ellipse horizontal interior")
	check(not s.in_range(Vector2.ZERO, Vector2(179, 0), 2), "code-traced ellipse horizontal exclusion")
	check(not s.in_range(Vector2.ZERO, Vector2(0, 125), 2), "elliptical range vertical exclusion")
	check(s.build(Vector2i(10, 9), 1).is_empty(), "legal minigun placement")
	check(s.money == 180.0, "20 money minigun cost")
	var id = int(s.towers[0].id)
	s.advance(1020)
	check(s.upgrade_tower(id, 1, 2).is_empty(), "minigun mk2 upgrade")
	s.advance(1020)
	check(s.upgrade_tower(id, 1, 3).is_empty(), "minigun mk3 upgrade")
	s.advance(1020)
	check(s.upgrade_tower(id, 2, 1).is_empty(), "supergun branch")
	check(s.sell_price(s.find_tower(id)) == 30, "recursive refund includes parent branch: 20+10+10+20 at 50 percent")
	var old_money = s.money
	check(s.sell(id).is_empty() and s.money == old_money+30, "sell applies refund once")
	check(s.sell(id).is_empty() and s.money == old_money+30, "selling twice cannot duplicate money")
	var locked = make_sim("8", false)
	check(not locked.build(Vector2i(10, 9), 4).is_empty(), "tech shop unlock is enforced")
	var target = make_sim()
	target.build(Vector2i(10, 9), 1)
	var t = target.towers[0]
	var a = target.spawn_enemy(1, 0, "")
	var b = target.spawn_enemy(9, 0, "")
	a.pos = t.pos+Vector2(5, 0)
	b.pos = t.pos+Vector2(8, 0)
	a.speed = 1500.0
	b.speed = 800.0
	t.targeting = "fastest"
	check(target.choose_target(t, 2).id == a.id, "F selects highest speed")
	t.targeting = "strongest"
	check(target.choose_target(t, 2).id == b.id, "S selects highest current HP")
	t.targeting = "weakest"
	check(target.choose_target(t, 2).id == a.id, "W selects lowest current HP")
	target.paused = true
	var paused = target.digest()
	target.advance(15000)
	check(paused == target.digest(), "pause preserves simulation state")
	target.paused = false
	target.upgrades = {"up_wizard": 1, "up_freeze": 1}
	check(abs(target.duration("freeze_duration", "up_freeze")-11025) <= 1, "code-traced multiplicative Freeze and Wizard duration")
	var pos = a.pos
	target.use_ability("m_freeze")
	target.advance(300)
	check(a.pos == pos, "Freeze stops enemy movement")
	check(target.abilities.m_freeze == 4, "Freeze consumes one item")
	check(not target.use_ability("m_freeze").is_empty() and target.abilities.m_freeze == 4, "active Freeze cannot double consume")
	var source_guard = make_sim()
	check(source_guard.spawn_enemy(1, 9, "").is_empty(), "native missing-source guard skips slot")
	check(source_guard.spawn_enemy(21, 0, "").is_empty(), "native null resource guard skips unused enemy")
	var numeric = source_guard.spawn_enemy(9, 0, "fast")
	check(numeric.def.hp == 118 and numeric.def.price == 3 and numeric.speed == 800, "NSNumber truncation and indicator-only wave label")
	var clouds = make_sim()
	clouds.next_wave_ms = 1000000
	var slowed = clouds.spawn_enemy(5, 0, "")
	slowed.speed = 0
	var goo = clouds.tower_data(8, 1)
	clouds.zones.append({"pos": slowed.pos, "def": goo, "until": 5000, "owner": 1, "type": 8})
	clouds.zones.append({"pos": slowed.pos, "def": goo, "until": 5000, "owner": 2, "type": 8})
	clouds.advance(30)
	check(is_equal_approx(slowed.slow_pending, 0.375), "native diminishing overlap: 50 percent then 25 percent yields 0.375")
	clouds.zones.clear()
	clouds.advance(60)
	check(slowed.slow == 1.0, "leaving all clouds clears slowdown on following update")
	var portal_test = make_sim()
	var origin = portal_test.center(8, 9)
	var exit = portal_test.center(12, 9)
	check(not portal_test.use_ability("m_portal", origin).is_empty() and portal_test.abilities.m_portal == 5, "portal entry alone does not consume item")
	portal_test.cancel_portal_placement()
	check(portal_test.portals.is_empty() and portal_test.abilities.m_portal == 5, "cancelling entry restores empty placement without debit")
	portal_test.use_ability("m_portal", origin)
	check(portal_test.use_ability("m_portal", exit).is_empty() and portal_test.abilities.m_portal == 4, "completed portal pair consumes exactly once")
	var authored = make_sim("202")
	check(authored.mines.size() == 8 and authored.static_portals.size() == 2, "authored static mines and portal pairs loaded")
	check(make_sim("13").survival_remaining_ms == 900000, "code-traced fifteen minutes equals 900000 milliseconds")
	var supply = make_sim()
	supply.money = 1000
	supply.build(Vector2i(10, 9), 1)
	supply.build(Vector2i(10, 10), 16)
	supply.advance(1020)
	check(is_equal_approx(supply.bonuses(supply.towers[0]).damage, 1.1), "Phonograph adds ten percent damage")
	supply.towers[1].type = 18
	supply.towers[1].def = supply.tower_data(18, 1)
	check(is_equal_approx(supply.bonuses(supply.towers[0]).rof, 1.3), "Ammo Supply supplies 1.3 divisor, not 0.7 interval multiplier")
	var marine_test = make_sim()
	marine_test.next_wave_ms = 1000000
	var marine = marine_test.spawn_enemy(1, 0, "")
	marine.path_at = marine.path.size()
	marine.cell = Vector2i(int(marine_test.bases[0].x), int(marine_test.bases[0].y))
	marine.pos = marine_test.bases[0].pos
	marine_test.advance(30)
	check(marine_test.bases[0].hp == 95 and marine_test.enemies.is_empty() and marine_test.kills == 0, "marine kamikaze hits base once without kill reward")
	var standing = make_sim()
	standing.next_wave_ms = 1000000
	var tank = standing.spawn_enemy(5, 0, "")
	tank.path_at = tank.path.size()-1
	tank.cell = tank.path[-2]
	tank.pos = standing.center(tank.cell.x, tank.cell.y)
	check(not standing.movement_point_allowed(tank), "tank stops before the final ordinary base link")
	tank.path = [Vector2i(8, 5), Vector2i(10, 5)]
	tank.path_at = 1
	tank.cell = Vector2i(8, 5)
	check(standing.movement_point_allowed(tank), "stand-off permits a final horizontal shortcut under the native half-count rule")
	var held = Vector2i(10, 9)
	var held_center = standing.center(10, 9)
	var first_point = standing.displace_point(held, held_center+Vector2(300, 0), 701, held_center)
	check(first_point.is_equal_approx(held_center+Vector2(62.0/3.0, 0)), "native displacement selects the nearest free point toward the base")
	var second_point = standing.displace_point(held, held_center+Vector2(300, 0), 702, held_center)
	check(second_point != first_point, "two attackers cannot reserve the same displacement point")
	standing.release_displacement(701)
	check(standing.displace_point(held, held_center+Vector2(300, 0), 703, held_center) == first_point, "released displacement can be reserved again")
	tank.path_at = tank.path.size()
	tank.attacking = true
	tank.attack_point = tank.pos
	tank.speed = 0
	standing.advance(1980)
	check(standing.bases[tank.base].hp == 100, "tank reload begins after alignment instead of an immediate hit")
	standing.advance(30)
	check(standing.bases[tank.base].hp == 97, "tank hits once at the authored two-second reload")
	var blasts = make_sim()
	var aerial = blasts.spawn_enemy(2, 0, "")
	var nearby = blasts.spawn_enemy(5, 0, "")
	aerial.pos = Vector2(500, 300)
	nearby.pos = aerial.pos+Vector2(31, 0)
	var aerial_hp = aerial.hp
	var ground_hp = nearby.hp
	blasts.impact({"pos": aerial.pos, "target": aerial.id, "def": blasts.tower_data(4, 1), "owner": 1, "boost": 1.0, "type": 4, "divisor": 1.0})
	check(aerial.hp == aerial_hp-20, "ordinary missile directly hits an air target despite ground-only splash")
	check(is_equal_approx(nearby.hp, ground_hp-19.5), "native circular splash subtracts normalized half-cell distance from twenty damage")
	var volley = {"id": 21, "type": 14, "level": 1, "pos": Vector2(490, 300), "def": blasts.tower_data(14, 1), "shot_ms": 0, "angle": 0.0}
	blasts.shoot(volley, aerial, {"damage": 1.0, "range": 1.0, "rof": 1.0})
	check(blasts.missiles.size() == 2 and blasts.missiles[0].divisor == 6.0, "AA missile level one launches two sixth-damage missiles")
	volley.type = 6
	volley.level = 3
	volley.def = blasts.tower_data(6, 3)
	blasts.missiles.clear()
	blasts.shoot(volley, nearby, {"damage": 1.0, "range": 1.0, "rof": 1.0})
	check(blasts.missiles.size() == 4 and blasts.missiles[0].divisor == 4.0, "Katyusha level three launches four quarter-damage missiles")
	var replay_a = make_sim()
	var replay_b = make_sim()
	for one in [replay_a, replay_b]:
		for c in [Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 9)]: one.build(c, 1)
		one.next_wave()
	replay_a.advance(30000)
	for i in range(1000): replay_b.advance(30)
	check(replay_a.digest() == replay_b.digest(), "replay is independent of render batching and speed")
	report.replay_digest = replay_a.digest()
	exercise_tower_forms()
	# A narrow corridor fixture validates deferred rollback independently of map art.
	var blocked = make_sim()
	blocked.map = blocked.map.duplicate(true)
	for cell in blocked.map.cells: cell.w = 0; cell.b = 0
	blocked.sources.clear()
	blocked.sources.append({"x": "8", "y": "9", "pos": blocked.center(8, 9)})
	blocked.bases.clear()
	blocked.bases.append({"x": "10", "y": "9", "pos": blocked.center(10, 9), "hp": 100.0, "hpmax": 100.0})
	for cell in [Vector2i(8, 9), Vector2i(9, 9), Vector2i(10, 9)]: blocked.map.cells[blocked.cell_index(cell)] = {"w": 1, "b": 1, "p": 0}
	check(blocked.build(Vector2i(9, 9), 1).is_empty(), "blocking tower enters deferred validation")
	blocked.advance(240)
	check(blocked.towers.size() == 1, "path validation does not run before 250 ms")
	blocked.advance(30)
	check(blocked.towers.is_empty() and blocked.money == 200.0, "blocking tower rollback returns full cost")
	content.maps = content.read_json("res://data/maps.json")
	for id_value in ["1", "8"]:
		var loss = make_sim(id_value)
		while loss.outcome == "playing" and loss.clock_ms < 900000:
			if loss.wave_index < loss.config.waves.size() and loss.running_waves.is_empty(): loss.next_wave()
			loss.advance(300)
			loss.events.clear()
		check(loss.outcome == "defeat", "unprotected base produces defeat: "+id_value)
		report.scenarios.append({"config": id_value, "kind": "natural-defeat", "ms": loss.clock_ms, "outcome": loss.outcome})
	var win = make_sim("8")
	for c in [Vector2i(15, 8), Vector2i(15, 7), Vector2i(15, 9), Vector2i(16, 7), Vector2i(14, 7)]: win.build(c, 1)
	win.advance(1020)
	for tower in win.towers: win.upgrade_tower(tower.id, 1, 2)
	win.advance(1020)
	for tower in win.towers: win.upgrade_tower(tower.id, 1, 3)
	win.advance(1020)
	check(win.money == 0, "five fully upgraded miniguns spend exactly the original 200 budget")
	while win.outcome == "playing" and win.clock_ms < 900000:
		if win.enemies.is_empty() and win.running_waves.is_empty() and win.wave_index < win.config.waves.size(): win.next_wave()
		win.advance(300)
		win.events.clear()
	check(win.outcome == "victory", "Desert Freighter can be won within original starting budget")
	report.scenarios.append({"config": "8", "kind": "legal-budget-victory", "ms": win.clock_ms, "outcome": win.outcome, "base": win.base_fraction(), "money": win.money, "kills": win.kills})
	# Load every authored mission and exercise every spawn slot, including recorded defects.
	var missions = 0
	for c in content.catalog.offlineConfigs:
		if c.waves.is_empty(): continue
		missions += 1
		var instance = make_sim(c.configid)
		check(instance.paths_valid(), "campaign source-to-base routes "+str(c.configid))
		var slots = 0
		for wave in c.waves:
			for i in range(wave.creep_ids.size()):
				var source = int(wave.source_ids[i]) if i < wave.source_ids.size() else 0
				var enemy = instance.spawn_enemy(int(wave.creep_ids[i]), source, str(wave.type))
				if not enemy.is_empty():
					check(not enemy.path.is_empty(), "campaign enemy navigation %s:%d" % [c.configid, slots])
					instance.enemies.clear()
				slots += 1
		instance.advance(300)
		report.campaign.append({"config": c.configid, "slots": slots, "discrepancies": instance.discrepancies})
	check(missions == 148, "148 nonempty authored offline missions")
	profile.data = profile.fresh()
	profile.data.spice = 17
	profile.data.unlocks = ["tut"]
	check(profile.save_profile(), "transactional save succeeds")
	profile.data.spice = 19
	check(profile.save_profile(), "second save preserves backup")
	profile.data = {}
	profile.load_profile()
	check(profile.data.spice == 19 and "tut" in profile.data.unlocks, "profile reload retains exact balances and unlocks")
	var damaged = FileAccess.open(profile.path, FileAccess.WRITE)
	damaged.store_string("broken")
	damaged.close()
	profile.load_profile()
	check(profile.data.spice == 17, "damaged profile recovers verified backup")
	check(profile.save_profile(), "backup recovery can save again")
	report.checks = checks
	report.failures = failures
	report.duration_ms = Time.get_ticks_msec()-started
	var report_path = "res://../builds/verification.json"
	var f = FileAccess.open(report_path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(report, "\t")); f.close()
	print("VERIFICATION ", JSON.stringify({"checks": checks, "failures": failures, "ms": report.duration_ms}))
	quit(0 if failures.is_empty() else 1)

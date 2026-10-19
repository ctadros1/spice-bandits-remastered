extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var content
var profile
var failures: Array[String] = []
var checks: int = 0
var report: Dictionary = {"scenarios": [], "campaign": []}

func _initialize() -> void:
	watchdog.call_deferred()
	run.call_deferred()

func watchdog() -> void:
	create_timer(60.0).timeout.connect(func(): push_error("Simulation verification exceeded its60-second bound."); quit(1))

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
	s.setup(content.catalog, content.maps[c.map], c, p, 114, content.animations)
	return s

func reset_xp_fixture() -> void:
	profile.data = profile.fresh()
	# Isolate XP arithmetic from already-earned medal awards in these cases.
	for medal in content.catalog.tower_medals: profile.data.medals.append(profile.medal_id(medal))

func exercise_unlocks() -> void:
	var parser = preload("res://scripts/unlocks.gd")
	check(parser.has_unlock("", []) and not parser.has_unlock("a", []), "native empty unlock is available and missing literal token is locked")
	check(parser.has_unlock("a,b", ["a"]) and parser.has_unlock("a,b", ["b"]) and not parser.has_unlock("a,b", []), "native ordinary comma tokens are alternatives")
	check(parser.has_unlock("!a,!b", ["a", "b"]) and not parser.has_unlock("!a,!b", ["a"]), "native exclamation marks require positive ownership of every marked token")
	check(parser.has_unlock("a,!b", ["b"]) and not parser.has_unlock("a,!b", ["a"]), "native required positive token overrides earlier ordinary alternative")
	check(not parser.has_unlock("!a", ["a"]), "native no-comma path compares exclamation literally")
	var before = profile.data
	profile.data = profile.fresh()
	profile.data.unlocks = ["mo6_sp"]
	check(not profile.available(content.mission("65")), "Barricade stays locked without the Africa pass")
	profile.data.unlocks.append("pass7_af")
	check(profile.available(content.mission("65")), "Barricade opens with Buenos Aires and Africa pass")
	profile.data.unlocks = ["mo31_ao"]
	check(profile.available(content.mission("63")), "Rubber Factory opens through Air Attack alternative")
	profile.data.unlocks = ["mo41_sp"]
	check(profile.available(content.mission("48")), "bonus Football opens through its offline Normal alternative")
	profile.data.unlocks = ["mo31_ao", "mo30_sd"]
	check(profile.available(content.mission("81")) and not profile.unlocked("30_sd"), "offline Hello Mario prerequisite bridge does not fabricate an owned token")
	profile.data.unlocks = ["mo40_sp"]
	check(profile.available(content.mission("286")) and not profile.unlocked("mo40_ao"), "offline Fracture access bridge uses corresponding Normal win without claiming absent Air mission completion")
	var endpoint = []
	for mission in content.catalog.offlineConfigs:
		var token = str(mission.get("grantsunlock", ""))
		if not token.is_empty() and token not in endpoint: endpoint.append(token)
	endpoint.append("pass7_af")
	profile.data.unlocks = endpoint
	var available = 0
	var source_available = 0
	for mission in content.catalog.offlineConfigs:
		if mission.waves.is_empty(): continue
		if parser.has_unlock(str(mission.get("needsunlock", "")), endpoint): source_available += 1
		if profile.available(mission): available += 1
		else: report.campaign_unlock_gaps = report.get("campaign_unlock_gaps", [])+[mission.configid]
	check(available == 148, "all148 offline missions are reachable from recovered offline completion tokens plus Africa pass")
	check(source_available == 146, "preserved prerequisites expose exactly two offline access defects before explicit bridges")
	profile.data = before

func exercise_targeting() -> void:
	var targeting = preload("res://scripts/targeting.gd")
	var path = ProjectSettings.globalize_path("res://").path_join("../tests/fixtures/native-target-reference.json")
	var reference = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(reference.original_unchanged and reference.cases.size() == 164, "native target reference retains164 original ARM cases")
	for row in reference.cases:
		var actual = targeting.select(row.entries, Vector2.ZERO, row.mode, bool(row.gravity), int(row.aim), int(row.owner), row.collect)
		check(actual.selected == int(row.selected) and actual.collected == Array(row.collected.map(func(i): return int(i))), "native ARM record-distance target selection "+str(row.mode))
		var native = SpiceNative.select_target(row.entries,{"cell":Vector2.ZERO,"mode":row.mode,"gravity":bool(row.gravity),"aim":int(row.aim),"owner":int(row.owner),"collect":row.collect},Callable())
		check(native==actual,"C++ target selection matches164 preserved ARM fixtures")

func exercise_native_hotpaths() -> void:
	var s=make_sim()
	var room=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-room-reference.json")))
	check(room.original_unchanged and room.cases.size()==22,"original room probe retains22 bounded dispatch/timer cases")
	for row in room.cases:
		var frame=make_sim("13")
		frame.clock_ms=1000;frame.survival_remaining_ms=5000
		frame.advance_frame(float(row.dt))
		check(frame.clock_ms==int(row.clock) and frame.survival_remaining_ms==int(row.survival),"live single-player frame retains originalf32 room/survival timer truncation")
		check(row.calls.size()==10 and row.calls.map(func(call):return call.name)==["waves","spawn","players","creeps","ambient","towers","kill_chain","mines","portals","bases"],"original offline routine dispatches one ordered subsystem update at each elapsed time")
	var random=RandomNumberGenerator.new();random.seed=114
	for i in range(5000):
		var a=Vector2(random.randf_range(-10000,10000),random.randf_range(-10000,10000))
		var radius=random.randf_range(0.001,20)
		var axes=s.range_axes(radius)
		var angle=random.randf()*TAU
		# Include values on both sides of the rounded native ellipse boundary.
		var b=a+Vector2(cos(angle)*axes.x,sin(angle)*axes.y)*(1.0+float(i%3-1)*0.0000001)
		check(s.in_range(a,b,radius)==s.reference_in_range(a,b,radius),"native C++ ellipse retains scalar32-bit boundary decision")
	var math=preload("res://scripts/particle_math.gd")
	for definition in content.particles.systems.values():
		for i in range(12):
			var p={"pos":Vector2(random.randf_range(-100,100),random.randf_range(-100,100)),"velocity":Vector2(random.randf_range(-300,300),random.randf_range(-300,300)),"rotation":random.randf_range(-4,4),"rot_speed":random.randf_range(-20,20)}
			var reference=p.duplicate(true)
			var age=math.f32(random.randf_range(0,float(definition.get("life_cycle",1))))
			var dt=math.f32([0.001,0.01667,0.03,0.1,0.133333,0.333333][i%6])
			math.update_particle(p,definition,dt,age)
			math.reference_update_particle(reference,definition,dt,age)
			check(p==reference,"native particle kernel matches scalar reference across all90 authored definitions")
	var fx_script=load("res://scripts/particle_fx.gd")
	var native_fx=fx_script.new();var reference_fx=fx_script.new()
	native_fx.reset();reference_fx.reset();reference_fx.reference_emission=true
	for name in ["RadiationDebris","Creep1ExplosionParts","PoisonCloud","GooCloud","MissileRail","CreepFreeze","CreepLSD"]:
		check(content.particles.systems.has(name),"emitter order fixture uses an authored particle definition")
		native_fx.emit_system(name,Vector2(200,300),"blue","",1200)
		reference_fx.emit_system(name,Vector2(200,300),"blue","",1200)
	for i in range(80):
		var dt=math.f32([0.001,0.01667,0.03,0.1,0.133333][i%5])
		native_fx.clock_seconds=math.f32(native_fx.clock_seconds+dt);reference_fx.clock_seconds=math.f32(reference_fx.clock_seconds+dt)
		native_fx.clock_ms=native_fx.clock_seconds*1000.0;reference_fx.clock_ms=reference_fx.clock_seconds*1000.0
		SpiceNative.advance_systems(native_fx.systems,native_fx.clock_ms,native_fx.emit_system,native_fx.emit_batch,native_fx.random,dt)
		reference_fx.reference_advance_tick(dt)
		check(native_fx.systems==reference_fx.systems and native_fx.random.state==reference_fx.random.state,"native emitter batching retains child order, RNG, particles and expiration")
	# Keep the correction/replay driver covered separately from live frames.
	native_fx.reset();reference_fx.reset()
	for name in ["RadiationDebris","Creep1ExplosionParts","PoisonCloud","GooCloud","MissileRail","CreepFreeze","CreepLSD"]:
		native_fx.emit_system(name,Vector2(200,300),"blue","",1200)
		reference_fx.emit_system(name,Vector2(200,300),"blue","",1200)
	for i in range(80):
		native_fx.clock_ms+=30;reference_fx.clock_ms+=30
		SpiceNative.advance_systems(native_fx.systems,native_fx.clock_ms,native_fx.emit_system,native_fx.emit_batch,native_fx.random)
		reference_fx.reference_advance_tick()
		check(native_fx.systems==reference_fx.systems and native_fx.random.state==reference_fx.random.state,"fixed replay emitter updates retain order, RNG and expiry independently of live frame timing")
	native_fx.free();reference_fx.free()

func same_saved_value(a,b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_saved_value(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not same_saved_value(a[i],b[i]):return false
		return true
	return a==b

func exercise_history_compaction() -> void:
	var original=profile.data;var original_path=profile.path
	profile.path="user://verification/history-compaction-profile.json"
	profile.data=profile.fresh()
	profile.data.spice=83;profile.data.xp=profile.f32(13569.458984375);profile.data.level=37
	profile.data.unlocks=["T5L2","mo9_sp"]
	profile.data.completed={"8":1}
	for i in range(1500):profile.data.transactions.append({"kind":"battle-xp","config":"8","score":i,"kills":1})
	profile.data.transactions.insert(2,{"kind":"promotion","level":2,"spice":5,"points":3})
	profile.data.transactions.append({"kind":"promotion","level":37,"spice":0,"points":1})
	var full=profile.data.duplicate(true)
	check(profile.save_profile(),"large transaction history saves with a verified full-state archive")
	check(profile.data.transactions.size()==258 and profile.data.transactions.filter(func(r):return r.kind=="promotion").size()==2,"compaction retains256 recent ordinary records and every promotion")
	check(profile.data.spice==83 and profile.data.xp==full.xp and profile.data.unlocks==full.unlocks and profile.data.completed==full.completed,"history compaction changes no currency, XP, technology or victories")
	var archive=profile._decode(profile.path+".history/"+str(profile.data.history_head)+".json")
	check(same_saved_value(archive,full),"content-addressed snapshot retains the entire pre-compaction profile and history")
	var compact=profile.data.duplicate(true);profile.load_profile()
	check(same_saved_value(profile.data,compact),"compacted profile reloads exactly with its archive reference")
	for i in range(100):profile.data.transactions.append({"kind":"battle-xp","score":1,"kills":1})
	check(profile.save_profile() and profile.data.history_head==compact.history_head and profile.data.transactions.size()==358,"ordinary saves reuse the archive head until the1024-event threshold")
	for i in range(800):profile.data.transactions.append({"kind":"battle-xp","score":1,"kills":1})
	check(profile.save_profile() and profile.data.history_head!=compact.history_head,"later history batches create a new verified snapshot")
	var linked=profile._decode(profile.path+".history/"+str(profile.data.history_head)+".json")
	check(linked.history_head==compact.history_head and linked.transactions.size()==1158,"full snapshots link all prior history without growing the live index")
	profile.data=full.duplicate(true);profile.read_only=true
	check(not profile.save_profile() and profile.data==full,"read-only storage leaves full live history unchanged")
	profile.read_only=false;profile.data=original;profile.path=original_path

func exercise_medals() -> void:
	var logic = preload("res://scripts/medals.gd")
	var identities = {}
	for m in content.catalog.tower_medals: identities[profile.medal_id(m)] = true
	check(identities.size() == 78, "all78 native medal identities remain distinct despite shared secret artwork")
	var s = make_sim()
	s.outcome = "victory"
	s.upgrade_top_count = 10
	s.closed_kill_chain = 60
	s.money = 2000
	var before = profile.data
	profile.data = profile.fresh()
	var selected = logic.select(content.catalog.tower_medals, logic.battle_values(s, profile.data.stats, content.catalog.tower_medals))
	check(selected.size() == 3 and selected.all(func(m): return int(m.grade) == 1), "native match collector keeps gold alone for60-chain,10 top upgrades and2000 money")
	check(profile.award_battle_medals(s) == 21 and is_equal_approx(profile.data.xp, 2.1), "native medal raw awards sum once before addXP divides by10")
	check(profile.award_battle_medals(s) == 21 and is_equal_approx(profile.data.xp, 4.2) and profile.medal_count(selected[0]) == 2, "repeated qualifying victories increment medal count and earn repeat medal XP")
	var awarded = profile.data.duplicate(true)
	profile.read_only = true
	check(not profile.settle(s) and profile.data == awarded, "failed victory save rolls back medal counts, XP and completion together")
	profile.read_only = false
	s.outcome = "defeat"
	check(logic.battle_values(s, profile.data.stats, content.catalog.tower_medals).is_empty() and profile.award_battle_medals(s) == 0, "defeat cannot settle pending medals")
	var tutorial = make_sim("1")
	tutorial.outcome = "victory"
	tutorial.money = 2000
	tutorial.upgrade_top_count = 10
	check(logic.battle_values(tutorial, profile.data.stats, content.catalog.tower_medals).is_empty(), "tutorial victory excludes native achievements")
	var mg = {"type": 1, "level": 1}
	var eagle = {"type": 3, "level": 3}
	var missile = {"type": 4, "level": 1}
	check(logic.secret_condition("won_sd_only_mg", [mg, eagle], false) and not logic.secret_condition("won_sd_only_mg", [missile], false), "secret machinegun challenge includes branches1..3 and rejects other forms")
	check(not logic.secret_condition("won_sd_only_mg", [], false) and not logic.secret_condition("won_sd_without_mg", [], false), "native only/without challenges reject empty remaining tower lists")
	check(logic.secret_condition("won_normal_lvl_1", [mg, missile], false) and not logic.secret_condition("won_normal_lvl_1", [eagle], false), "secret level1 challenge examines final upgrade levels")
	check(logic.secret_condition("won_normal_with_star", [], true) and not logic.secret_condition("won_normal_with_star", [mg], false), "secret star challenge uses the recovered perfect-game flag")
	check(logic.secret_condition("won_sd_only_one_tower", [eagle], false) and not logic.secret_condition("won_sd_only_one_tower", [mg, eagle], false), "secret one-tower challenge counts surviving towers")
	check(logic.secret_condition("won_sd_without_mg", [missile], false) and not logic.secret_condition("won_sd_without_mg", [eagle], false), "secret no-machinegun challenge rejects all three machinegun forms")
	check(logic.secret_condition("won_normal_duke_nuke", [{"type": 5, "level": 3}], false) and not logic.secret_condition("won_normal_duke_nuke", [{"type": 5, "level": 2}], false), "Duke Nuke secret requires type5 level3")
	check(logic.secret_condition("won_normal_3_gsuperguns", [{"type": 2, "level": 3}, {"type": 2, "level": 3}, {"type": 2, "level": 3}], false), "Gatling secret requires three type2 level3 towers")
	check(logic.secret_condition("won_normal_5_freeze", [{"type": 8}, {"type": 8}, {"type": 8}, {"type": 8}, {"type": 8}], false), "freeze-tower secret accepts type8 at any level")
	check(logic.secret_condition("won_air_without_aa_tower", [mg], false) and not logic.secret_condition("won_air_without_aa_tower", [{"type": 15}], false), "Air challenge rejects all AA branches13..15")
	var secrets = content.catalog.tower_medals.filter(func(m): return int(m.get("secret", 0)) == 1)
	profile.data = profile.fresh()
	profile.data.medals = [profile.medal_id(secrets[0])]
	check(profile.has_medal(secrets[0]) and not profile.has_medal(secrets[1]), "earning one secret medal does not mark the others owned through shared artwork")
	profile.data.medals = [str(selected[0].image)]
	check(profile.has_medal(selected[0]) and profile.medal_count(selected[0]) == 1, "legacy unique-image medals retain their earned state without replacing the old save schema")
	var chain = make_sim()
	chain.kill_chain = 20
	for tick in range(10): chain.update_kill_chain()
	check(chain.kill_chain == 20 and chain.closed_kill_chain == 0, "native kill chain does not close at exactly300ms without targets")
	chain.update_kill_chain()
	check(chain.kill_chain == 0 and chain.closed_kill_chain == 20, "native kill chain closes strictly after300ms")
	var top = make_sim()
	top.money = 5000
	top.build(Vector2i(10, 9), 1)
	var tower = top.towers[0]
	for option in [[1, 2], [1, 3], [3, 1], [3, 2]]: top.upgrade_tower(tower.id, option[0], option[1])
	check(top.upgrade_top_count == 0, "root level3 with further branches does not count as a top upgrade")
	top.upgrade_tower(tower.id, 3, 3)
	top.sell(tower.id)
	check(top.upgrade_top_count == 1, "terminal level2-to3 upgrade counts even if later sold")
	profile.data = before
	var original = profile.data
	profile.data = profile.fresh()
	profile.data.xp = 10.0
	profile.advance_levels()
	check(profile.data.level == 2 and profile.data.specpoints == 3 and profile.data.spice == 5, "offline first promotion follows observed5-spice/3-point reward")
	profile.advance_levels()
	check(profile.data.specpoints == 3 and profile.data.spice == 5, "first promotion cannot be collected again by repeating settlement")
	var observed_progression=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/observed-progression.json")))
	check(observed_progression.observations.all(func(row):return int(row.level)==2 and float(row.xp_upper_display)==profile.level_threshold(2)),"two preserved main iPad states support55 total XP for the level2 threshold")
	profile.data.xp=40.0;profile.advance_levels()
	check(profile.data.level==2 and profile.data.specpoints==3,"old40XP estimate no longer promotes before the observed threshold")
	profile.data.xp=profile.f32(54.999);profile.advance_levels()
	check(profile.data.level==2,"fractional XP below55 retains level2")
	profile.data.xp=55.0;profile.advance_levels()
	check(profile.data.level==3 and profile.data.transactions[-1].threshold==55 and profile.data.transactions[-1].threshold_source=="observed-main-ipad","55XP promotes once and records the threshold evidence separately from the later reward fallback")
	var promoted_count=profile.data.transactions.size();profile.advance_levels()
	check(profile.data.transactions.size()==promoted_count and profile.data.specpoints==4 and profile.data.spice==5,"rechecking the observed threshold cannot duplicate its separately documented fallback reward")
	profile.data = profile.fresh()
	check(profile.career_progress() == {"towers": 0, "locations": 0}, "native fresh Career percentages are zero before any owned tokens")
	profile.data.unlocks = ["tut"]
	check(profile.career_progress().towers == 4, "native Career counts its two implicit tower forms once a first token exists")
	profile.data = original

func exercise_creep_view() -> void:
	var particle_math = preload("res://scripts/particle_math.gd")
	var particle_reference = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-particle-reference.json")))
	check(particle_reference.original_unchanged and particle_reference.cases.size()==192, "bounded native particle integration reference preserves the original executable")
	for row in particle_reference.cases:
		var definition={"life_cycle":1.6,"gravity":[0,30],"wind":[0,0],"wind_enabled":bool(row.wind),"fade_in_time":row.fade,"blend_delay":row.blend}
		var p={"pos":Vector2(100,200),"velocity":Vector2(10,-70),"rotation":0.5,"rot_speed":3.0}
		var dt=particle_math.f32(float(row.dt))
		particle_math.update_particle(p,definition,dt,particle_math.f32(particle_math.f32(float(row.age))+dt))
		for pair in [[p.pos.x,row.x],[p.pos.y,row.y],[p.velocity.x,row.vx],[p.velocity.y,row.vy],[p.rotation,row.rotation],[p.alpha,row.alpha]]:check(absf(pair[0]-pair[1])<0.00002,"native particle integration/opacity matches bounded ARM case")
	var mix = preload("res://scripts/audio_mix.gd").new()
	mix.update(20, false, 30)
	check(is_equal_approx(mix.multiple, 0.98), "native crowded sound mix falls0.02 per room update above15 sources")
	for i in range(7): mix.update(20, false, 30)
	check(is_equal_approx(mix.multiple, 0.84), "native crowd mix steps past its0.85 target before rising")
	mix.update(0, false, 30)
	check(is_equal_approx(mix.multiple, 0.85), "native crowd mix recovers0.01 per room update")
	mix.multiple = 1.0
	mix.update(1, true, 250)
	check(is_equal_approx(mix.important, 0.925), "native important sound eases halfway from1 to0.85 in250ms")
	check(is_equal_approx(mix.gain({"gain": 0.6}), 0.555) and is_equal_approx(mix.gain({"gain": 0.6, "important": 1}), 0.6), "important effects retain their gain while ordinary effects attenuate")
	mix.update(1, true, 250)
	check(is_equal_approx(mix.important, 0.85), "native important sound reaches0.85 in500ms")
	mix.update(1, false, 250)
	check(is_equal_approx(mix.important, 0.925), "native important sound recovers with the same500ms easing")
	mix.update(1, false, 250)
	check(is_equal_approx(mix.important, 1.0), "native important sound returns to full gain")
	var view = preload("res://scripts/creep_view.gd")
	var fixture_path = ProjectSettings.globalize_path("res://").path_join("../tests/fixtures/native-creep-reference.json")
	var reference = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(reference.original_unchanged and reference.turns.size() == 576, "isolated native ARM corner reference is complete and preserves the executable")
	for row in reference.turns:
		var values = view.turn_values(float(row.p), Vector2(row.semi[0], row.semi[1]), Vector2(row.current[0], row.current[1]))
		for field in ["rotation", "alpha", "blend_rotation", "blend_alpha"]:
			check(absf(float(values[field])-float(row[field])) < 0.00001, "native ARM turn %s p%s semi%s current%s" % [field, row.p, row.semi, row.current])
	for row in reference.corners:
		var current = Vector2(row.current[0], row.current[1])
		var future = Vector2(row.future[0], row.future[1])
		check(view.can_round(current, future) == bool(int(row.active)), "native ARM corner eligibility %s to%s" % [current, future])
		var target = current*100
		var end = view.corner_end(target, target+future*100, 0.75)
		check(end.distance_to(Vector2(row.end[0], row.end[1])) < 0.00001, "native ARM quarter-corner endpoint %s to%s" % [current, future])
	for row in reference.positions:
		var point = view.position(Vector2(row.logical[0], row.logical[1]), Vector2(row.start[0], row.start[1]), Vector2(row.end[0], row.end[1]), float(row.p))
		check(point.distance_to(Vector2(row.result[0], row.result[1])) < 0.00001, "native ARM projected body position p%s" % row.p)
	check(view.position(Vector2(1, 2), Vector2.ZERO, Vector2.ZERO, 0.8) == Vector2(1, 2), "degenerate reverse corner retains a finite logical body position")
	check(reference.movement.size() == 225, "isolated native ARM movement reference has225 speed, boundary and carry cases")
	for row in reference.movement:
		var value = view.movement_tick(Vector2(row.start[0], row.start[1]), Vector2(row.target[0], row.target[1]), Vector2(row.future[0], row.future[1]), float(row.p), float(row.carry), float(row.speed), int(row.dt), float(row.hex_height))
		for field in ["progress", "carry"]: check(absf(float(value[field])-float(row.result[field])) < 0.000001, "native ARM movement "+field)
		for field in ["position", "start", "target"]: check(value[field].distance_to(Vector2(row.result[field][0], row.result[field][1])) < 0.00002, "native ARM movement "+field)
	check(reference.variable_movement.size()==576,"original movement probe retains576 fractional/large live-frame cases")
	for row in reference.variable_movement:
		var value=view.movement_tick(Vector2(row.start[0],row.start[1]),Vector2(row.target[0],row.target[1]),Vector2(row.future[0],row.future[1]),float(row.p),float(row.carry),float(row.speed),view.f32(float(row.dt)),float(row.hex_height))
		for field in ["progress","carry"]:check(absf(float(value[field])-float(row.result[field]))<0.000001,"native ARM live-frame movement "+field)
		for field in ["position","start","target"]:check(value[field].distance_to(Vector2(row.result[field][0],row.result[field][1]))<0.00002,"native ARM live-frame movement "+field)
	var reroute = make_sim()
	reroute.next_wave_ms = 1000000
	var moving = reroute.spawn_enemy(1, 0, "", 7788, false)
	moving.cell = moving.path[1]
	moving.next_cell = moving.path[2]
	moving.path_at = 2
	var start = moving.cell
	var endpoint = moving.next_cell
	moving.move_start = reroute.center(start.x, start.y)
	moving.move_progress = 0.4
	moving.pos = reroute.vector_interpolate(moving.move_start, reroute.center(endpoint.x, endpoint.y), 0.4)
	var before_pos = moving.pos
	reroute.set_enemy_path(moving)
	check(moving.cell == start and moving.next_cell == endpoint and moving.move_progress == 0.4 and moving.pos == before_pos, "mid-cell reroute preserves logical position, progress and endpoint while replanning later links")
	# A forced obstacle represents a route invalidation; normal placement
	# refuses an occupied current/next enemy hex before reaching this state.
	reroute.towers.append({"id": -7788, "cell": endpoint, "type": 16, "level": 1, "pos": reroute.center(endpoint.x, endpoint.y), "def": reroute.tower_data(16, 1), "ready_ms": 0, "angle": 0.0, "targeting": "fastest"})
	reroute.path_cache.clear()
	reroute.set_enemy_path(moving)
	check(moving.cell == endpoint and moving.next_cell == start and is_equal_approx(moving.move_progress, 0.6) and moving.pos == before_pos, "blocked endpoint reverses the unfinished segment without teleporting its logical position")

func exercise_projectiles() -> void:
	var s = make_sim()
	s.next_wave_ms = 1000000
	var missile = s.new_missile(Vector2.ZERO, Vector2(200, 0), s.tower_data(4, 1), -1, 4, -1)
	check(missile.pos == Vector2(10, 0), "native missile constructor nudges launch ten pixels toward target")
	check(not s.update_missile(missile) and missile.pos == Vector2(10, 0) and missile.acceleration.is_equal_approx(Vector2(45, 0)), "native steering first tick changes acceleration without movement")
	s.update_missile(missile)
	check(is_equal_approx(missile.pos.x, 10.50625) and missile.velocity.is_equal_approx(Vector2(16.875, 0)), "native damping advances second tick by0.50625 pixels")
	var collision = {"pos": Vector2(19, 19), "previous": Vector2(30, 30), "destination": Vector2.ZERO, "age_ms": 30}
	check(s.missile_hits(collision), "missile impact uses axis rectangle instead of circular arrival distance")
	collision.merge({"pos": Vector2(25, 0), "previous": Vector2(-25, 0)}, true)
	check(s.missile_hits(collision), "missile impact catches a segment crossing the target rectangle")
	collision.merge({"pos": Vector2(200, 0), "previous": Vector2(200, 0), "age_ms": 8000}, true)
	check(not s.missile_hits(collision), "missile timeout is strictly greater than8000ms")
	collision.age_ms = 8030
	check(s.missile_hits(collision), "missile timeout triggers on next30ms tick")
	var nuke = s.new_missile(Vector2.ZERO, Vector2(200, 100), s.tower_data(5, 1), -1, 5, -1)
	check(nuke.origin == Vector2(0, 87) and nuke.nuke_velocity == 15000, "native nuke origin includes half154px texture plus10 and fivefold initial velocity")
	check(not s.update_missile(nuke) and is_equal_approx(nuke.up, 0.004) and is_equal_approx(nuke.pos.y, 85), "native nuke first ascent tick travels two pixels")
	var ticks = 1
	while nuke.up < 1.0 and ticks < 200: s.update_missile(nuke); ticks += 1
	check(ticks == 93 and nuke.pos == Vector2(0, -413) and nuke.nuke_velocity == 3000, "native nuke ascent clamps at500px after2790ms")
	var down_ticks = 0
	var arrived = false
	while not arrived and down_ticks < 100: arrived = s.update_missile(nuke); down_ticks += 1
	check(down_ticks == 51 and arrived and nuke.pos.x == 200, "native nuke descends above fixed target for1530ms, total flight4320ms")
	nuke.boost = 1.1
	s.impact(nuke)
	check(is_equal_approx(s.zones[0].damage_bonus, 70.0), "native radiation adds direct700-damage support bonus of70 to base10 poison damage")
	var chemical = make_sim()
	chemical.next_wave_ms = 1000000
	chemical.build(Vector2i(10, 9), 7)
	var tower = chemical.towers[0]
	var victim = chemical.spawn_enemy(5, 0, "")
	victim.pos = tower.pos+Vector2(120, 0)
	victim.move_start = victim.pos
	victim.visual_pos = victim.pos+Vector2(8, 0)
	# This fixture writes the drawn anchor directly; keep its retained
	# original aim field coherent with that deliberately supplied pose.
	victim.visual_aim = victim.visual_pos+victim.animator_offset
	victim.speed = 0
	victim.hp = 5000
	chemical.shoot(tower, victim, {"damage": 1.0, "rof": 1.0})
	chemical.towers.clear() # one-shot fixture; prevents another firing cycle
	var zone = chemical.zones[0]
	var bubble = chemical.bubbles[0]
	check(bubble.destination == chemical.enemy_visual_aim_point(victim) and bubble.destination != chemical.enemy_aim_point(victim), "chemical launch snapshots the drawn aim point while ordinary missiles retain the logical aim point")
	chemical.advance(510)
	check(bubble.flying and bubble.size == 64 and victim.hp == 5000 and zone.until == -1, "chemical bubble grows for510ms without starting cloud damage or lifetime")
	var destination: Vector2 = zone.pos
	victim.pos += Vector2(20, 0)
	victim.move_start = victim.pos
	while bubble.active and chemical.clock_ms < 3000: chemical.advance(30)
	check(zone.pos == destination and zone.has("bubble") and victim.hp == 5000, "chemical bubble retains launch target point and arrival does not damage in the same tick")
	chemical.advance(30)
	check(not zone.has("bubble") and victim.hp < 5000 and zone.until == chemical.clock_ms+int(zone.def.poison_duration)-30, "cloud lifetime and damage start on tick following bubble arrival")
	var retained = make_sim()
	retained.next_wave_ms = 1000000
	retained.build(Vector2i(10, 9), 7)
	var rt = retained.towers[0]
	var re = retained.spawn_enemy(5, 0, "")
	rt.targeting = "strongest"
	re.pos = rt.pos+Vector2(100, 0); re.speed = 0
	retained.advance(90)
	check(retained.bubbles.is_empty(), "nonrotating chemical tower retains native100ms acquisition delay")
	retained.advance(30)
	check(retained.bubbles.size() == 1 and rt.tracking.locked, "nonrotating chemical acquires at120ms without a200ms turret turn")
	retained.sell(int(rt.id))
	check(retained.bubbles.is_empty() and retained.zones.is_empty(), "selling destroys owned in-flight bubbles and pending clouds")
	var bbq = make_sim()
	bbq.next_wave_ms = 1000000
	bbq.build(Vector2i(10, 9), 10)
	var bt = bbq.towers[0]
	bt.type = 12; bt.def = bbq.tower_data(12, 3)
	var be = bbq.spawn_enemy(5, 0, "")
	be.pos = bt.pos+Vector2(10, 0); be.speed = 0; be.hp = 1000
	bbq.defense_until = 10000
	bbq.advance(30)
	check(is_equal_approx(be.hp, 998.5), "native BBQ branch keeps its50DPS area beam without an extra Active Defense bolt")
	var launch = make_sim()
	launch.next_wave_ms = 1000000
	launch.build(Vector2i(10, 9), 4)
	var nt = launch.towers[0]
	nt.type = 5
	nt.def = launch.tower_data(5, 1)
	nt.targeting = "strongest"
	nt.reload_ms = float(nt.def.rof)
	var target = launch.spawn_enemy(5, 0, "")
	target.pos = nt.pos+Vector2(100, 0)
	target.speed = 0
	launch.advance(30)
	check(nt.nuke.opening and launch.missiles.is_empty(), "nuke warning opens after reload threshold")
	target.pos += Vector2(20, 0)
	launch.advance(1950)
	check(launch.missiles.is_empty() and nt.nuke.destination == target.pos, "nuke warning tracks the moving target until launch")
	launch.advance(30)
	check(launch.missiles.size() == 1 and launch.missiles[0].destination == target.pos and nt.reload_ms == 0, "nuke launches at interval plus2000ms and snapshots target")
	var inherited = make_sim()
	inherited.build(Vector2i(10, 9), 4)
	var it = inherited.towers[0]
	it.type = 5; it.def = inherited.tower_data(5, 1); it.targeting = "strongest"
	var ie = inherited.spawn_enemy(5, 0, "")
	ie.pos = it.pos+Vector2(100, 0); ie.speed = 0
	inherited.advance(30)
	check(inherited.missiles.size() == 1, "native inherited100000ms reload can launch first nuke in its opening tick")
	check(content.animations["towers/tower6_1"].textures.missile.x == 45 and content.animations["towers/tower6_1"].textures.has("pad1"), "native texture-child iteration preserves older texture tags and Katyusha launch art")
	var extra = content.extra_frame("towers/tower5_1", "missile2")
	check(not extra.is_empty() and extra.texture.get_height() == 154, "descending nuke extra texture resolves authored crop and vertical flip")

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
			tower.targeting = "strongest"
			victim.speed = 0
			victim.hp = 5000
			victim.max_hp = 5000
			victim.pos = tower.pos+Vector2(10, 0)
			s.advance(9000 if type == 5 else 1500 if type == 8 else 2400)
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
	check(content.static_resources["lobby/location_res"].textures.size() == 38, "preserved static world texture set retains all38 authored entries")
	var world_icon = content.extra_frame("lobby/location_res", "icon_5")
	check(world_icon.offset == Vector2(22, -35) and world_icon.params.green_offset == [0.0, -12.0] and world_icon.texture.get_size() == Vector2(16, 16), "native world atlas crop, direct offset and nested green offset survive static import")
	exercise_unlocks()
	exercise_targeting()
	exercise_medals()
	exercise_creep_view()
	exercise_native_hotpaths()
	exercise_history_compaction()
	exercise_projectiles()
	check(content.catalog.tower_towers.size() == 19, "18 tower forms and sentinel")
	check(content.maps.size() == 67, "66 numbered maps and world map")
	for type in [13, 14, 15]:
		for level in range(1, 4):
			var name = "towers/tower%d_%d" % [type, level]
			check(content.animations[name].states.Rot.resolved_frames.size() == 40, "native mirrored turret stack %d:%d has40 frames" % [type, level])
	var aa = content.animations["towers/tower13_1"].states.Rot.resolved_frames
	check(aa[21].x == 1216 and aa[39].x == 64 and aa[39].fliph == 1, "AA mirrored half uses reversed frame stack and horizontal flip")
	check(content.frame("towers/tower13_1", "Rot", 39).offset == Vector2(4, -4), "stack offset replaces animation default instead of adding it twice")
	var cached = content.frame("towers/tower1_1", "Rot", 0).texture
	var cache_size = content.frame_cache.size()
	for iteration in range(1000): content.frame("towers/tower1_1", "Rot", iteration*40)
	check(content.frame_cache.size() == cache_size and content.frame("towers/tower1_1", "Rot", 40000).texture == cached, "animation loop reuses bounded authored-frame cache")
	var mirrored_creep = content.frame("creeps/creep1", "RunUpLeft", 0).texture.get_image()
	mirrored_creep.flip_x()
	check(mirrored_creep.get_data() == content.frame("creeps/creep1", "RunUpRight", 0).texture.get_image().get_data(), "native animation-level mirroring remains active with resolved added frames")
	var gun = content.tower(1, 1)
	check(content.tower_presentation(gun, 8.99, 0).frame == 0 and content.tower_presentation(gun, 9, 0).frame == 1, "native turret frame selection truncates at9 degrees")
	check(content.tower_presentation(gun, 359, 0).frame == 39 and content.tower_presentation(gun, 360, 0).frame == 0, "native turret frame40 wraps to0")
	check(content.tower_presentation(content.tower(16, 1), 0, 100).frame == 1, "support tower advances its authored Idle animation")
	check(content.animations["towers/tower14_1"].params.shoot_points["1"].Points.size() == 2, "nested missile launch vectors are retained")
	var snow_start = content.tower_foundation("snow", Vector2i(4, 4), 0)
	var snow_mid = content.tower_foundation("snow", Vector2i(4, 4), 1000)
	check(snow_start.size() == 2 and snow_start[0].frame == 0 and snow_mid[0].frame == 3 and snow_mid[1].alpha == 0.5, "snow foundation finishes four frames while its overlay fades over2 seconds")
	check(content.tower_foundation("snow", Vector2i(4, 4), 2000).size() == 1 and content.tower_foundation("forest", Vector2i(7, 4), 0)[0].name.ends_with("6"), "native foundation fade and coordinate-selected variant")
	var active_build = make_sim()
	active_build.next_wave_ms = 1000000
	check(active_build.build(Vector2i(10, 9), 1).is_empty() and active_build.towers[0].ready_ms == active_build.clock_ms, "native placed tower activates without invented construction delay")
	check(active_build.upgrade_tower(active_build.towers[0].id, 1, 2).is_empty(), "native upgrade has no separate one-second construction lock")
	var aiming = make_sim()
	aiming.next_wave_ms = 1000000
	aiming.build(Vector2i(10, 9), 1)
	var aiming_tower = aiming.towers[0]
	aiming_tower.targeting = "strongest"
	var aiming_victim = aiming.spawn_enemy(5, 0, "")
	aiming_victim.pos = aiming_tower.pos+Vector2(0, -107)
	aiming_victim.visual_pos = aiming_victim.pos
	aiming_victim.speed = 0
	# This targeting fixture supplies a stationary waiting owner. A state-0
	# owner still derives its position from its segment even at zero speed.
	preload("res://scripts/creep_state_view.gd").change(aiming_victim,1)
	aiming_victim.hp = 5000
	aiming_victim.max_hp = 5000
	aiming.advance(90)
	check(aiming_victim.hp == 5000 and aiming_tower.angle == 0, "native100ms acquisition precedes initial turret turn")
	aiming.advance(30)
	report.turret_turn = {"ms": aiming.clock_ms, "angle": aiming_tower.angle, "target_pos": [aiming_victim.pos.x, aiming_victim.pos.y], "state": aiming_tower.tracking.duplicate(true)}
	check(aiming_victim.hp == 5000 and aiming_tower.angle == aiming.f32(26.999177932739258), "native200ms initial turn retains the recovered axis constant and16-bit quantization")
	aiming.advance(180)
	check(aiming_victim.hp == 4998 and aiming_tower.angle == 179.9945068359375, "rotating gun fires only after its acquisition and turn finish at300ms")
	var original_target = aiming_tower.tracking.id
	var competitor = aiming.spawn_enemy(5, 0, "")
	competitor.pos = aiming_tower.pos+Vector2(0, 93)
	competitor.visual_pos = competitor.pos
	competitor.speed = 0
	preload("res://scripts/creep_state_view.gd").change(competitor,1)
	competitor.hp = 10
	aiming_tower.targeting = "weakest"
	aiming.advance(210)
	check(aiming_tower.tracking.id == original_target and competitor.hp == 10, "native FSW change retains a living in-range target until reacquisition")
	aiming_victim.pos = aiming_tower.pos+Vector2(1000, 0)
	# This explicit pose change moves the target's retained drawn anchor too;
	# native waiting/aligned updates do not derive it from logical position.
	aiming_victim.visual_pos = aiming_victim.pos
	# Queued tower-path validation legitimately restored state0 earlier.
	# Reassert this targeting-only fixture's stationary state after moving it.
	preload("res://scripts/creep_state_view.gd").change(aiming_victim,1)
	aiming.advance(30)
	check(aiming_tower.tracking.id == competitor.id and not aiming_tower.tracking.locked, "out-of-range target reacquires using the new FSW mode")
	check(aiming.normalize_degrees(-90) == 270.0 and aiming.normalize_degrees(360) == 0 and aiming.normalize_degrees(9) == 8.997802734375, "native angle normalization quantizes unsigned16-bit turns")
	check(aiming.interpolate_degrees(350, 10, 0.5) == 360 and aiming.interpolate_degrees(350, 10, 0.6) == 2, "native short-way degree interpolation truncates after wrap")
	check(aiming.native_angpos(Vector2.ZERO) == -99999 and aiming.native_angpos(Vector2.UP) == -1.570796012878418, "native AngPos sentinel and axis constants")
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
	var protected = make_sim("53")
	var protected_cell = Vector2i(int(protected.bases[0].x), int(protected.bases[0].y))
	for cell in protected.ordinary_links(protected_cell):
		check(not protected.buildable(cell), "authored build_around_base=0 protects ordinary adjacent cells")
	var multi = make_sim()
	multi.bases.append({"x": 10, "y": 9, "hp": 100.0, "hpmax": 100.0, "pos": multi.center(10, 9)})
	check(not multi.walkable(Vector2i(10, 9), Vector2i(8, 9), Vector2i(12, 9), false), "other live bases block a ground route during base selection")
	check(multi.walkable(Vector2i(10, 9), Vector2i(8, 9), Vector2i(10, 9), false), "chosen base center is temporarily walkable for its route")
	multi.config = multi.config.duplicate(true)
	multi.config.settings.allbaseswalkable = 1
	check(multi.walkable(Vector2i(10, 9), Vector2i(8, 9), Vector2i(12, 9), false), "authored allbaseswalkable bypasses other-base blockers")
	var melee = multi.spawn_enemy(9, 0, "")
	var kamikaze = multi.spawn_enemy(1, 0, "")
	check(melee.path[-1] != Vector2i(int(multi.bases[melee.base].x), int(multi.bases[melee.base].y)), "non-kamikaze path removes the base center before stand-off checks")
	check(kamikaze.path[-1] == Vector2i(int(multi.bases[kamikaze.base].x), int(multi.bases[kamikaze.base].y)), "kamikaze path retains the base center")
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
	a.cell = t.cell+Vector2i(2, 0)
	a.next_cell = a.cell
	b.cell = t.cell+Vector2i(1, 0)
	b.next_cell = b.cell
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
	var growth = make_sim()
	growth.next_wave_ms = 1000000
	var growing = growth.spawn_enemy(1, 0, "")
	var flying = growth.spawn_enemy(2, 0, "")
	var no_growth = growth.spawn_enemy(1, 0, "", -1, false)
	check(growth.spawn_presentation(growing).scale == 0.0, "ground spawn begins at zero scale")
	check(growth.spawn_presentation(flying).scale == 1.0 and growth.spawn_presentation(no_growth).scale == 1.0, "air and disabled-constructor spawns retain full scale")
	var unchanged_hp = growing.hp
	growth.freeze_until = 10000
	growth.advance(120)
	var presentation = growth.spawn_presentation(growing)
	check(is_equal_approx(presentation.alpha, 0.3) and is_equal_approx(presentation.scale, 0.16308), "native 120ms quintic spawn scale and linear alpha continue during Freeze")
	growth.advance(300)
	check(growth.spawn_presentation(growing).scale == 1.0 and growing.hp == unchanged_hp, "400ms spawn completion changes presentation without growing health")
	growing.cell = Vector2i(8, 6)
	growing.next_cell = Vector2i(9, 5)
	check(growth.creep_animation(growing) == "RunUpRight", "native signed diagonal uses RunUpRight")
	growing.next_cell = Vector2i(6, 6)
	check(growth.creep_animation(growing) == "TurnLeft", "native horizontal shortcut uses TurnLeft")
	growing.attacking = true
	growing.dir = Vector2.RIGHT
	check(growth.creep_animation(growing) == "TurnRight", "native attack facing includes horizontal frame")
	growing.dir = Vector2(0.5028, -0.8643)
	check(growth.creep_animation(growing) == "TurnUpRight", "native attack facing includes steep intermediate frame")
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
	check(marine_test.bases[0].hp == 95 and marine_test.enemies.size()==1 and int(marine.state)==3 and marine_test.kills == 0, "original SetDie(0) retains marine after one kamikaze impact without kill reward")
	marine_test.advance(2000)
	check(marine_test.bases[0].hp==95 and marine_test.enemies.is_empty() and marine_test.kills==0,"retained kamikaze finishes its actual tail and never repeats base damage or reward")
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
	preload("res://scripts/creep_state_view.gd").change(tank,4)
	tank.attack_point = tank.pos
	tank.speed = 0
	check(tank.attack_reload_ms == float(int(tank.def.rof)), "original constructor starts the tank reload already charged")
	standing.advance(30)
	check(standing.bases[tank.base].hp == 97 and tank.attack_reload_ms == 0, "charged tank attacks immediately after alignment and clears its reload")
	standing.advance(1980)
	check(standing.bases[tank.base].hp == 97, "tank waits the authored reload after its first immediate hit")
	standing.advance(30)
	check(standing.bases[tank.base].hp == 94, "tank hits again at the authored two-second reload")
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
	var flights = make_sim()
	flights.next_wave_ms = 1000000
	var bomber = flights.spawn_enemy(2, 0, "")
	bomber.cell = bomber.path[-1]
	bomber.pos = flights.center(bomber.cell.x, bomber.cell.y)
	bomber.path_at = bomber.path.size()
	var flight_base = int(bomber.base)
	var base_cell = Vector2i(int(flights.bases[flight_base].x), int(flights.bases[flight_base].y))
	var circles = flights.bases[flight_base].bomb_circles
	check(circles.size() == 6, "interior base constructs six native bombing rings")
	for circle in circles:
		check(circle.size() == 7 and circle[0] == base_cell and circle[-1] == base_cell, "bombing ring has six edges and closes at the base")
		for i in range(1, circle.size()): check(circle[i] in flights.ordinary_links(circle[i-1]), "bombing ring uses ordinary linked flight cells")
	flights.advance(30)
	check(bomber.bombing and bomber.path_at == 0 and bomber.path[0] == base_cell, "bomber begins a ring instead of parking outside the base")
	var began_at = bomber.pos
	flights.advance(12000)
	var drops = 0
	for event in flights.events:
		if event.kind == "enemy_shot": drops += 1
	check(drops >= 2 and bomber.pos != began_at, "bomber continues flying and drops on repeated base passes")
	var impacts = flights.events.filter(func(event): return event.kind == "enemy_impact").size()
	check(impacts > 0 and is_equal_approx(flights.bases[flight_base].hp, 100.0-impacts*float(bomber.def.damage)*0.5), "bomb rectangle-crossing impacts apply half the resource damage")
	report.bomber = {"drops": drops, "impacts": impacts, "base_hp": flights.bases[flight_base].hp, "ms": flights.clock_ms}
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
		# Combat-only defeat fixture bypasses the separate tutorial UI spawn gate.
		loss.spawn_hold = false
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
	profile.data.level = 18
	profile.data.specpoints = 30
	for level in range(10):
		check(profile.upgrade("up_career").contains("upgraded"), "native cost allocation buys upgrade level %d" % (level+1))
	check(profile.data.upgrades.up_career == 10 and profile.data.specpoints == 0, "all ten upgrade costs consume exactly30 points")
	check(profile.upgrade("up_career") == "Maximum level.", "upgrade allocation stops at level10")
	check(profile.refund_upgrade("up_career").begins_with("Returned 6"), "native minus action returns the entire level10 cost")
	for level in range(9, 0, -1):
		check(profile.refund_upgrade("up_career").begins_with("Returned"), "native refund at upgrade level %d" % level)
	check(profile.data.upgrades.up_career == 0 and profile.data.specpoints == 30, "per-level reallocation returns all30 spent points")
	var empty_refund = profile.data.duplicate(true)
	profile.refund_upgrade("up_career")
	check(profile.data == empty_refund, "zero-level refund cannot mint points")
	profile.upgrade("up_career")
	var failed_refund = profile.data.duplicate(true)
	profile.read_only = true
	check(profile.refund_upgrade("up_career") == "The refund could not be saved." and profile.data == failed_refund, "refund save failure preserves point balance and upgrade level")
	profile.read_only = false
	report.upgrade_reallocation = {"maximum_level": 10, "total_cost": 30, "refund_level10": 6, "save_failure_rollback": true}
	reset_xp_fixture()
	var credited_rows: Array[Dictionary] = [{"reward": 50.0, "type": 1}, {"reward": 50.0, "type": 1}]
	check(profile.credit_battle_kills(credited_rows, "8"), "live kill XP saves before a mission completes")
	profile.load_profile()
	check(profile.data.xp == 10.0 and profile.data.stats.kills == 2, "earned XP and kills survive reload before settlement")
	var xp_sim = make_sim()
	xp_sim.upgrades.up_career = 10
	xp_sim.score = 100.0
	xp_sim.kills = 2
	xp_sim.outcome = "victory"
	check(profile.settle(xp_sim, 100.0, 2, 0), "victory settles after live credit")
	check(is_equal_approx(profile.data.xp, 10.1) and profile.data.stats.kills == 2, "native Career rounding adds0.1 XP without double-crediting kills")
	reset_xp_fixture()
	xp_sim.score = 99.0
	check(profile.settle(xp_sim) and is_equal_approx(profile.data.xp, 9.9), "Career raw-score bonus below1 truncates to zero")
	reset_xp_fixture()
	xp_sim.score = 100.0
	xp_sim.outcome = "defeat"
	check(profile.settle(xp_sim) and profile.data.xp == 10.0, "defeat keeps kill XP and awards no Career completion bonus")
	reset_xp_fixture()
	profile.read_only = true
	var xp_before_failure = profile.data.duplicate(true)
	check(not profile.credit_battle_kills(credited_rows, "8") and profile.data == xp_before_failure, "live XP save failure rolls back balances and kill counts")
	profile.read_only = false
	report.live_xp = {"credited_before_settlement": 10.0, "career_level10_victory_xp": 10.1, "career_rounding_below_one": 0, "defeat_xp": 10.0, "no_duplicate_kills": true}
	profile.data = profile.fresh()
	profile.data.spice = 17
	profile.data.unlocks = ["tut"]
	check(profile.save_profile(), "transactional save succeeds")
	profile.data.spice = 19
	check(profile.save_profile(), "second save preserves backup")
	profile.data = {}
	profile.load_profile()
	check(profile.data.spice == 19 and "tut" in profile.data.unlocks, "profile reload retains exact balances and unlocks")
	for value in [134.100341796875, 10000.123046875, 0.10000000149011612, 446.19512939453125]:
		profile.data.xp = profile.f32(value)
		check(profile.save_profile(), "fractional native XP save succeeds")
		var precise = profile.data.duplicate(true)
		profile.load_profile()
		check(profile.data == precise, "complete profile preserves fractional XP exactly across reload")
	# Keep the following backup-recovery fixture's original balance pair.
	profile.data.spice = 17
	profile.save_profile()
	profile.data.spice = 19
	profile.save_profile()
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

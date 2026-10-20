extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Poison=preload("res://scripts/creep_poison.gd")
var checks=0
var failures=[]
var contexts=[]
func _initialize() -> void:
	create_timer(180).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func setup() -> Dictionary:
	var content=root.get_node("Content");var profile=root.get_node("Profile");profile.read_only=true
	var config=content.mission("8").duplicate(true);config.waves=[]
	var sim=Sim.new();sim.setup(content.catalog,content.maps[config.map],config,profile.fresh(),114,content.animations);sim.spawn_hold=true
	var actor=sim.spawn_enemy(1,0,"",9901,false);actor.speed=0;actor.hp=1000000;actor.max_hp=1000000
	return {"sim":sim,"actor":actor}
func actual_shot(type:int,tier:int) -> void:
	var ctx=setup();var sim=ctx.sim;var actor:Dictionary=ctx.actor;var definition:Dictionary=sim.tower_data(type,tier)
	var tower={"id":777,"pos":actor.pos-Vector2(100,0),"def":definition,"type":type,"level":tier}
	sim.shoot(tower,actor,{"rof":1.0,"damage":1.0})
	check(sim.zones.size()==(0 if type==5 else 1),"actual tower shot creates pending cloud or nuke missile")
	var zone={};var bubble={};var became_inactive=false;var deleted_hp=-1.0;var saw_tail=false;var seen_ready=false;var restored=false;var removed=false;var first_ready_ms=-1;var deletion_ms=-1;var removal_ms=-1
	if type!=5:
		zone=sim.zones[0];bubble=zone.bubble
		check(zone.managed_cloud and int(zone.tier)==tier and zone.roots.is_empty(),"actual bubble cloud has original tier and empty root vector")
		check(is_same(zone.bubble,sim.bubbles[0]),"pending cloud observes actual created bubble")
	for frame in 900:
		var bubble_was_active=not bubble.is_empty() and bool(bubble.active)
		var was_final=not zone.is_empty() and not bool(zone.active)
		sim.advance(30)
		if type==5 and zone.is_empty() and not sim.zones.is_empty():zone=sim.zones[0]
		if zone.is_empty():continue
		check(zone.managed_cloud and int(zone.tier)==tier,"actual cloud retains selected tier")
		if type!=5 and bubble_was_active:
			check(float(zone.age_ms)==0 and zone.roots.is_empty(),"pending parent pauses age and emission, including arrival tick")
		if zone.ready and (type==5 or not zone.has("bubble")):
			if not seen_ready:first_ready_ms=sim.clock_ms
			seen_ready=true
			if not zone.deleted:
				check(int(actor.poison_count)==(0 if type==8 else 1),"actual active cloud applies its separate damage exposure")
				check(int(actor.slow_count)==(1 if type==8 else 0),"actual active Goo applies separate slowdown exposure")
		if not restored and not zone.roots.is_empty():
			var old_system:Dictionary=zone.roots[0].system
			var frozen:Array[Dictionary]=sim.particle_state.systems.duplicate(true)
			sim.particle_state.replace_systems(frozen)
			check(not is_same(zone.roots[0].system,old_system),"held scene restoration replaces actual cloud system alias")
			for root_system in zone.roots:
				check(sim.particle_state.systems.any(func(v):return is_same(v,root_system.system)),"restored cloud points into renderer system registry")
			restored=true
			var frozen_zone=var_to_bytes(zone);var frozen_systems=var_to_bytes(sim.particle_state.systems)
			sim.paused=true;sim.advance(100);sim.paused=false
			check(var_to_bytes(zone)==frozen_zone and var_to_bytes(sim.particle_state.systems)==frozen_systems,"pause retains complete actual cloud/particle state")
		if zone.deleted:
			if deletion_ms<0:deletion_ms=sim.clock_ms;deleted_hp=float(actor.hp)
			check(float(actor.hp)==deleted_hp,"damage ends while real cloud tail remains")
			if zone.active and not zone.roots.is_empty():saw_tail=true
		if not zone.active:became_inactive=true
		if not sim.zones.any(func(v):return is_same(v,zone)):
			check(was_final,"inactive cloud is removed on the following manager pass")
			removed=true;removal_ms=sim.clock_ms;break
	check(seen_ready and restored and became_inactive and removed,"actual normal gameplay cloud reaches all lifecycle phases")
	check(saw_tail and removal_ms>deletion_ms,"actual normal gameplay retains particle tail after damage")
	check(zone.roots.is_empty() and zone.creeps_in_range.is_empty(),"actual manager destructor clears retained roots and tracked actors")
	check(sim.particle_state.cloud_roots.is_empty() and not sim.particle_state.systems.any(func(v):return v.get("cloud_managed",false)),"actual final cleanup unregisters renderer and restoration roots")
	check(int(Poison.particle_root(actor,"radiation" if type==5 else "poison").rate)==0,"actual final global Stop reaches creature effect")
	check(sim.trace.filter(func(v):return v.kind=="cloud_active").size()==(0 if type==5 else 1),"original parent release sound request occurs once")
	contexts.append({"type":type,"tier":tier,"ready_ms":first_ready_ms,"damage_deleted_ms":deletion_ms,"manager_removed_ms":removal_ms,"tail_observed":saw_tail,"held_restore_verified":restored})
	sim.particle_state.reset();sim.enemies.clear();sim.zones.clear();sim.bubbles.clear()
func mixtures() -> void:
	for types in [[7,5],[8,7],[7,7]]:
		var ctx=setup();var sim=ctx.sim;var actor:Dictionary=ctx.actor
		for i in types.size():
			var point=actor.pos+Vector2(10000,0) if types==[7,7] and i==1 else actor.pos
			sim.new_cloud(sim.tower_data(types[i],2),point,777+i,types[i],2,0.0)
		sim.advance(30)
		check(int(actor.poison_count)==(1 if types==[8,7] or types==[7,7] else 2),"actual managed overlap exposure count")
		check(int(actor.slow_count)==(1 if 8 in types else 0),"actual managed Goo count remains independent")
		check(int(Poison.particle_root(actor,"poison").rate)==(0 if types==[7,7] else 1),"actual managed same-kind last-outside stop order")
		check(int(Poison.particle_root(actor,"radiation").rate)==(1 if 5 in types else 0),"actual managed different aliases independent")
		var fx=load("res://scripts/particle_fx.gd").new();fx.use_state(sim.particle_state)
		var before=var_to_bytes(sim.particle_state.systems);var serial=sim.particle_state.serial
		fx.refresh_owners(sim)
		check(var_to_bytes(sim.particle_state.systems)==before and sim.particle_state.serial==serial and fx.timers.is_empty(),"actual presentation refresh creates no duplicate legacy cloud systems")
		fx.free()
		sim.destroy_enemy_owner(actor);sim.enemies.erase(actor)
		for zone in sim.zones:
			check(zone.creeps_in_range.is_empty(),"actual managed clouds erase destroyed actor references")
			sim.destroy_cloud(zone)
		sim.zones.clear();sim.particle_state.reset()
func cleanup() -> void:
	var ctx=setup();var sim=ctx.sim
	var zone=sim.new_cloud(sim.tower_data(7,2),ctx.actor.pos,777,7,2,0.0)
	sim.advance(30)
	check(not zone.roots.is_empty() and not sim.particle_state.cloud_roots.is_empty(),"real cleanup context allocated actual cloud")
	sim.destroy_cloud(zone);sim.zones.erase(zone)
	check(zone.roots.is_empty() and zone.creeps_in_range.is_empty() and sim.particle_state.cloud_roots.is_empty(),"explicit owner destruction clears actual cloud state")
	check(not sim.particle_state.systems.any(func(v):return v.get("cloud_managed",false)),"explicit owner destruction unregisters actual systems")
	sim.particle_state.reset();sim.enemies.clear()
	ctx=setup();sim=ctx.sim
	zone=sim.new_cloud(sim.tower_data(7,2),ctx.actor.pos,777,7,2,0.0);sim.advance(30)
	sim.towers.append({"id":777,"type":7,"level":2,"pos":ctx.actor.pos,"receipts":[30]})
	check(sim.sell(777).is_empty(),"actual tower sell completes")
	check(sim.zones.is_empty() and sim.particle_state.cloud_roots.is_empty(),"actual tower sale destroys its managed clouds")
	check(not sim.particle_state.systems.any(func(v):return v.get("cloud_managed",false)),"actual tower sale unregisters real renderer particles")
	sim.particle_state.reset();sim.enemies.clear()
func run() -> void:
	var content=root.get_node("Content");var definitions=var_to_bytes(content.particles.systems)
	for type in [7,8,9,5]:
		for tier in [1,2]:actual_shot(type,tier)
	mixtures()
	cleanup()
	check(var_to_bytes(content.particles.systems)==definitions,"all shared authored particle resources unchanged")
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"failures":failures,"contexts":contexts,"scope":"Actual Simulation shoot/bubble/nuke/managed-cloud/retained particles across chemical, Goo, FART and radiation tiers. Parent pause/arrival-next-tick, damage expiry, real particle tails, next-pass removal, pause, held-system restoration aliases, global Stop, cleanup and definition preservation. Existing bubble flight, projectile resource/support and per-room scheduling remain adapters; no original complete bubble ownership/nuke current-resource/global RNG/GPU/audio/video/performance acceptance."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)

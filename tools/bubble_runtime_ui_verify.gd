extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Bubble=preload("res://scripts/bubble_lifecycle.gd")
var checks=0
var failures=[]
var contexts=[]
var view
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
func validate(sim,b:Dictionary,label:String) -> void:
	check(sim.particle_state.bubble_roots.size()==b.roots.size(),label+" retained bubble roots registered")
	for root_system in b.roots:
		var sys:Dictionary=root_system.system
		check(sys.bubble_managed and not sys.get("cloud_managed",false),label+" distinct bubble ownership tag")
		check(is_same(sim.particle_state.bubble_roots[int(sys.id)],root_system),label+" real wrapper registry")
		check(sim.particle_state.systems.any(func(v):return is_same(v,sys)),label+" actual renderer dictionary")
		check(is_same(sys.particles,sys.owned_tree.particles),label+" renderer uses actual physics array")
		check(root_system.active_count==sys.particles.size(),label+" actual particle status")
		check(int(sys.object_owner)==int(b.owner),label+" actual tower owner")
	var pose=view.bubble_draw_pose(b)
	check(pose.quads.size()==(2 if b.active else 0),label+" active body and shadow only")
	if b.active:
		check(pose.quads[0].texture.slot==0x4c and pose.quads[1].texture.slot==0x50,label+" actual Main draws body before shadow")
		check(pose.quads[0].texture.size==Vector2i(b.size,b.size),label+" equal body dimensions")
		check(pose.quads[1].texture.size==Vector2i(20,16),label+" original shadow proportions")
		check(pose.color==Color(1,1,1,b.alpha),label+" decoded straight-alpha modulation")
		if not b.flying:
			var y=Bubble.f32(float(b.shadow_origin.y)+Bubble.f32(Bubble.f32(float(b.start_y)-float(b.pos.y))*.5))
			check(pose.quads[1].pos==Vector2(b.shadow_origin.x-10,Bubble.f32(y-8)),label+" actual Main moving lift shadow")
		else:check(pose.quads[1].pos==b.shadow-Vector2(10,8),label+" actual Main evolving dive shadow")
func shot(type:int,tier:int) -> void:
	var ctx=setup();var sim=ctx.sim;var actor:Dictionary=ctx.actor;var d:Dictionary=sim.tower_data(type,tier)
	var tower={"id":777,"pos":actor.pos-Vector2(100,0),"def":d,"type":type,"level":tier}
	sim.shoot(tower,actor,{"rof":1.0,"damage":1.0})
	check(sim.bubbles.size()==1 and sim.zones.size()==1,"actual normal shot creates bubble/cloud")
	var b:Dictionary=sim.bubbles[0];var zone:Dictionary=sim.zones[0];var target:Vector2=b.target;var label=str([type,tier])
	check(b.managed_bubble and b.follow_target==0,label+" original ordinary creator disables tracking")
	check(is_same(zone.bubble,b) and not zone.parent30.is_empty(),label+" actual cloud observes actual bubble")
	check(b.roots.size()==2 and sim.particle_state.cloud_roots.is_empty(),label+" two retained constructor roots, separate cloud registry")
	validate(sim,b,label+" constructor")
	var inactive_ms=-1;var saw_tail=false;var restored=false;var saw_stars=false;var stopped=false
	for frame in 900:
		sim.advance(30)
		check(b.target==target,label+" ordinary shot target remains cached")
		validate(sim,b,label+"/"+str(frame))
		for root_system in b.roots:
			if "Stars" in str(root_system.system.name) and int(root_system.active_count)>0:saw_stars=true
		if frame==5:
			var old=b.roots[0].system;var held=sim.particle_state.systems.duplicate(true);sim.particle_state.replace_systems(held)
			check(not is_same(old,b.roots[0].system),label+" actual held system replaced")
			validate(sim,b,label+" immediate held restore");restored=true
			var before=sim.digest();var particles=var_to_bytes(sim.particle_state.systems);sim.paused=true;sim.advance(100);sim.paused=false
			check(sim.digest()==before and var_to_bytes(sim.particle_state.systems)==particles,label+" pause preserves actual state")
			var fx=load("res://scripts/particle_fx.gd").new();fx.use_state(sim.particle_state);var count=sim.particle_state.serial;particles=var_to_bytes(sim.particle_state.systems);fx.refresh_owners(sim)
			check(sim.particle_state.serial==count and var_to_bytes(sim.particle_state.systems)==particles,label+" no duplicate legacy bubble/cloud emitters");fx.free()
		if not b.active:
			if inactive_ms<0:inactive_ms=sim.clock_ms
			if b.roots.any(func(v):return int(v.active_count)>0):saw_tail=true
		if not sim.zones.any(func(v):return is_same(v,zone)) and b.roots.size()==2 and b.roots.all(func(v):return v.rate==0 and v.active_count==0 and v.disable_after_seconds==0):stopped=true;break
	check(inactive_ms>0 and saw_tail and saw_stars and restored and stopped,label+" real shot/tails/stars/dormant phases complete")
	check(sim.bubbles.any(func(v):return is_same(v,b)),label+" manager retains actual zero-disable dormant roots")
	check(sim.particle_state.cloud_roots.is_empty() and sim.particle_state.bubble_roots.size()==2,label+" cloud cleanup remains distinct")
	check(sim.trace.filter(func(v):return v.kind=="bubble_impact").size()==1,label+" actual arrival event once")
	check(sim.trace.filter(func(v):return v.kind=="cloud_active").size()==1,label+" original next-pass parent release once")
	contexts.append({"type":type,"tier":tier,"inactive_ms":inactive_ms,"dormant_ms":sim.clock_ms,"stars_observed":saw_stars,"actual_inactive_tail":saw_tail,"held_restore":restored})
	# Use the actual existing sale path after retaining all normal owned roots.
	tower.receipts=[30];sim.towers.append(tower)
	check(sim.sell(777).is_empty(),label+" actual sale completes")
	check(sim.bubbles.is_empty() and sim.zones.is_empty() and sim.particle_state.bubble_roots.is_empty() and sim.particle_state.cloud_roots.is_empty(),label+" actual owner destruction clears both registries")
	check(not sim.particle_state.systems.any(func(v):return int(v.object_owner)==777),label+" actual owner destruction unregisters all renderer roots")
	sim.particle_state.reset();sim.enemies.clear()
func run() -> void:
	view=load("res://scripts/main.gd").new();var content=root.get_node("Content");var definitions=var_to_bytes(content.particles.systems)
	for type in [7,8,9]:
		for tier in [1,2,3]:shot(type,tier)
	check(var_to_bytes(content.particles.systems)==definitions,"all shared original definitions unchanged")
	view.free()
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report")
	var report={"checks":checks,"failures":failures,"contexts":contexts,"passed":failures.is_empty(),"scope":"Actual normal Simulation creation/manager/owned bubble particles/Main body-shadow poses, retained inactive tails/dormant roots/held state/pause/no duplicate FX/actual sale. Supplied tower placement/actor; original resource factory/global RNG/GPU/audio/room/video identity not claimed."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

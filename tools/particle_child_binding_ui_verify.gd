extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Freeze=preload("res://scripts/creep_freeze_view.gd")
const Disco=preload("res://scripts/creep_disco_view.gd")
var checks=0
var failures=[]
var child_updates_without_parent_emission=0
var pool_reuses=0
class Trace extends RefCounted:
	var state
	var events=[]
	func particle(tree:Dictionary,index:int,fresh:bool,old:Dictionary) -> Dictionary:
		events.append({"kind":"particle","name":str(tree.name),"index":index,"fresh":fresh,"old_id":old.get("id")})
		return state.make_owned_particle(tree,index,fresh,old)
	func child(name:String,texture:Texture2D,variation:String) -> Dictionary:
		events.append({"kind":"child","name":name,"texture":texture.resource_path,"variation":variation})
		return state.make_owned_child(name,texture,variation)
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func normalize(value):
	if value is Dictionary:
		var result={}
		for key in value:result[key]=normalize(value[key])
		return result
	if value is Array:
		var result=[]
		for item in value:result.append(normalize(item))
		return result
	if value is Resource:return {"class":value.get_class(),"path":value.resource_path}
	return value
func state_hash(state,actor:Dictionary) -> String:
	return var_to_bytes(normalize({"actor":actor,"systems":state.systems,"rng":str(state.random.state),"serial":state.serial,"owned_serial":state.owned_serial})).hex_encode().sha256_text()
func advance(state,roots:Array,dt:float,deferred:bool,trace:Trace=null) -> bool:
	var particle:Callable=state.make_owned_particle if trace==null else trace.particle
	var child:Callable=state.make_owned_child if trace==null else trace.child
	# Both branches advance every root; false selects the preserved eager
	# callback binding and true skips only demonstrably unused bindings.
	return SpiceNative.advance_creep_particles(roots,state.clock_ms,dt,particle,child,state.owned_prepared,deferred)
func make_sim():
	var content=root.get_node("Content");var sim=Sim.new();var config=content.mission("8").duplicate(true);config.waves=[]
	sim.setup(content.catalog.duplicate(true),content.maps[config.map],config,root.get_node("Profile").fresh(),114,content.animations);sim.spawn_hold=true
	return sim
func sequence(number:int,prepared:bool,deferred:bool) -> Array:
	var sim=make_sim();var content=root.get_node("Content");var resource="creeps/creep"+str(number)
	var actor=sim.spawn_enemy(1,0,"",9001,false);var state=sim.particle_state;state.destroy_creep(actor)
	actor.def.filename="creep"+str(number);actor.def.traits=content.catalog.resource_params[resource]
	state.initialize_creep(actor,1);state.owned_prepared=prepared
	actor.hp=100;actor.max_hp=100;actor.pos=Vector2(330.5,220.5);actor.dir=Vector2(.6,.8)
	var trace=Trace.new();trace.state=state;var rows=[]
	var last_root:Array=actor.particle_roots.duplicate();last_root.append({"retain_for_owner":false})
	var before=state_hash(state,actor)
	check(not advance(state,last_root,30,deferred,trace),"invalid later root rejects before any mutation")
	check(state_hash(state,actor)==before and trace.events.is_empty(),"validation is transactional")
	for frame in 64:
		var dt=[0.0,1.0,16.667,30.0,100.0,133.333][frame%6]
		if frame==2:Freeze.use_freeze(actor)
		if frame==3:actor.hp=30
		if frame==4:
			for sys in actor.particle_roots:sys.owned_tree.delay_seconds=Vector2(.04,0).x
		if frame==8:actor.hp=100
		if frame==10:sim.disco_state.remaining=600;sim.use_disco_on(actor)
		if frame==15:sim.disco_state.remaining=0;Disco.process(actor)
		if frame==18:actor.state=3;state.begin_creep_death(actor,actor.pos)
		if frame in [20,22]:
			for sys in actor.particle_roots:sys.owned_tree.wind_enabled=frame==22
		if frame in [24,40]:
			for sys in actor.particle_roots:sys.owned_tree.rate=0
		if frame==30:
			for sys in actor.particle_roots:
				if str(sys.creep_alias).contains("explosion"):
					SpiceNative.owned_particle_restart(sys.owned_tree)
					# Restart only pools parents; explicitly supply a new emission
					# window so the original disable_after limit does not stop it.
					sys.owned_tree.clock_seconds=0.0;sys.owned_tree.release_seconds=0.0;sys.owned_tree.first_release=true
					sys.owned_tree.rate=1;sys.owned_tree.interval_seconds=Vector2(.01,0).x
		if frame<18:
			actor.slow_pending=.5 if frame in [5,9] else -1.0
			Freeze.advance_fields(actor,dt,1000 if frame<8 else 0);state.refresh_creep(sim,actor)
		state.update_creep_fields(actor,actor.pos,actor.dir)
		trace.events=[]
		check(advance(state,actor.particle_roots,dt,deferred,trace),"actual retained roots accepted")
		for event in trace.events:
			if event.kind=="particle" and not event.fresh:pool_reuses+=1
			if event.kind=="particle" and str(event.name).contains("DebrisSmoke"):
				if actor.particle_roots.any(func(sys):return int(sys.owned_tree.rate)==0 and not sys.owned_tree.particles.is_empty()):child_updates_without_parent_emission+=1
		for sys in actor.particle_roots:check(is_same(sys.particles,sys.owned_tree.particles),"system retains actual active-array alias")
		check(is_same(actor.disco_root,actor.particle_roots.filter(func(sys):return str(sys.creep_alias)=="lsd")[0].owned_tree),"Disco root alias preserved")
		rows.append({"resource":number,"prepared":prepared,"requested_deferred":deferred,"frame":frame,"state_sha256":state_hash(state,actor),"requests_sha256":var_to_bytes(trace.events).hex_encode().sha256_text()})
	state.destroy_creep(actor);check(actor.particle_roots.is_empty() and actor.disco_root.is_empty(),"final destruction drops retained aliases")
	return rows
func pooled_boundary(rate:int,prepared:bool,deferred:bool) -> String:
	var sim=make_sim();var state=sim.particle_state;var actor=sim.spawn_enemy(1,0,"",9002,false)
	state.owned_prepared=prepared
	# Explosion roots are created by SetDie, not at ordinary spawn.
	state.begin_creep_death(actor,actor.pos)
	var candidates=actor.particle_roots.filter(func(sys):return not str(sys.owned_tree.definition.get("child_system","")).is_empty())
	check(not candidates.is_empty(),"supplied creep has a child-bearing retained root")
	if candidates.is_empty():
		state.destroy_creep(actor)
		return ""
	var sys:Dictionary=candidates[0];var tree:Dictionary=sys.owned_tree;var trace=Trace.new();trace.state=state
	# Clear the immediate authored death burst, then supply a single parent.
	tree.particles=[];tree.pool=[]
	SpiceNative.owned_particle_emit(tree,1,trace.particle,trace.child.bind(sys.texture,str(sys.variation)))
	var parent:Dictionary=tree.particles[0];var child:Dictionary=parent.child
	check(not child.is_empty(),"fresh parent owns an actual child system")
	SpiceNative.owned_particle_emit(child,1,trace.particle,trace.child.bind(sys.texture,str(sys.variation)))
	check(not child.particles.is_empty(),"retained child owns actual particle state")
	SpiceNative.owned_particle_restart(tree)
	tree.rate=rate;tree.clock_seconds=0.0;tree.release_seconds=0.0;tree.first_release=true
	tree.delay_seconds=0.0;tree.interval_seconds=Vector2(.001,0).x
	var retained=var_to_bytes(normalize(tree.pool)).hex_encode().sha256_text();trace.events=[]
	check(advance(state,[sys],30,deferred,trace),"empty active root with retained child pool accepted")
	check(tree.particles.is_empty() and tree.pool.size()==1,"nonpositive count does not reactivate pooled parents")
	check(var_to_bytes(normalize(tree.pool)).hex_encode().sha256_text()==retained,"pooled parent and child state untouched")
	check(trace.events.is_empty(),"nonpositive count makes no factory request")
	check(tree.advance_calls==1 and tree.clock_seconds>0.0 and tree.release_seconds==tree.clock_seconds,"empty root still advances clock and nonpositive Emit release")
	check(tree.first_release,"nonpositive Emit preserves first-release flag")
	check(is_same(tree.pool[0],parent) and is_same(tree.pool[0].child,child),"retained parent and child aliases survive")
	check(is_same(sys.particles,tree.particles),"empty active-array alias retained")
	var result=state_hash(state,actor)
	state.destroy_creep(actor)
	return result
func run() -> void:
	var rows=[]
	for prepared in [false,true]:
		for number in range(1,11):
			var eager=sequence(number,prepared,false);var deferred=sequence(number,prepared,true)
			check(eager.size()==deferred.size(),"same trace length")
			for i in eager.size():
				check(eager[i].state_sha256==deferred[i].state_sha256 and eager[i].requests_sha256==deferred[i].requests_sha256,"full state and callback order exact")
			rows.append_array(eager);rows.append_array(deferred)
	var baseline_path="res://../tests/reference/particle-child-binding-r169.json"
	var provenance=JSON.parse_string(FileAccess.get_file_as_string(baseline_path.get_basename()+"-provenance.json"))
	check(FileAccess.get_sha256(baseline_path)==str(provenance.baseline_sha256),"immutable independently repeated R169 baseline")
	var baseline=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	check(rows.size()==baseline.rows.size(),"same complete historical row count")
	for i in mini(rows.size(),baseline.rows.size()):
		for key in rows[i]:check(rows[i][key]==baseline.rows[i][key],"exact historical state/request row "+str(i)+"/"+str(key))
	check(child_updates_without_parent_emission>0,"active children emit while parent rate is zero")
	check(pool_reuses>0,"retained pools are reused")
	# Additional synthetic boundaries do not change any immutable historical row.
	for prepared in [false,true]:
		for rate in [0,-3]:
			check(pooled_boundary(rate,prepared,false)==pooled_boundary(rate,prepared,true),"complete eager/deferred pooled-child boundary state exact")
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"failures":failures,"rows":rows,"child_births_without_parent_emission":child_updates_without_parent_emission,"pool_reuses":pool_reuses,"scope":"R169 behavior preservation: normalized complete actor/system/key/numeric state, ordered callback requests, RNG/serials/aliases. Ten supplied resources including unused creep7, both prepared paths, variable delta, delay/freeze/slow/Disco/health/death/child tails/pool reuse. Eager/deferred bindings compared. Additional zero/negative-count empty roots retain actual pooled parents and children, advance clocks/release timestamps, and preserve aliases without factory calls. Independent immutable R169 rows remain unchanged; original full game/GPU remains separate."}
	if not output.is_empty() and not FileAccess.file_exists(output):
		var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CHILD_BINDING ",JSON.stringify({"checks":checks,"failures":failures,"rows":rows.size(),"child_births_without_parent_emission":child_updates_without_parent_emission,"pool_reuses":pool_reuses}));quit(1 if not failures.is_empty() else 0)

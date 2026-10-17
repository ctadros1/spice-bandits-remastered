extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=[]
var checks=0
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func median(values:Array) -> float:
	values.sort();return float(values[values.size()/2])
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func run() -> void:
	var content=root.get_node("Content");var profile=root.get_node("Profile");var phases=[];var final_states=[]
	for reference in [true,false,false,true]:
		var sim=Sim.new();var config=content.mission("8").duplicate(true);config.waves=[]
		sim.setup(content.catalog,content.maps[config.map],config,profile.fresh(),114,content.animations);sim.spawn_hold=true
		var state=sim.particle_state;state.reference_owner_dispatch=reference;state.reference_owner_fields=reference;var actors=[]
		for i in 32:
			var actor=sim.spawn_enemy([1,2,3,4,5,6,9,15][i%8],i%sim.sources.size(),"",10000+i,false)
			actor.hp=30;actor.max_hp=100;actors.append(actor)
			state.update_creep_fields(actor,actor.pos,actor.dir)
		var samples=[]
		for sample in 8:
			var started=Time.get_ticks_usec()
			for repeat in 64:
				for actor in actors:
					state.update_creep_fields(actor,actor.pos,actor.dir)
					state.advance_creep(actor,30)
			if sample>=2:samples.append((Time.get_ticks_usec()-started)/2048.0)
		check(actors.size()==32 and actors.all(func(actor):return not actor.particle_roots.is_empty()),"all32owners have actual roots")
		check(actors.all(func(actor):return actor.particle_roots.all(func(sys):return int(sys.owned_tree.advance_calls)==512)),"every inactive and active root advanced exactly512times")
		final_states.append({"systems":var_to_bytes(state.systems).hex_encode().sha256_text(),"rng":str(state.random.state),"serial":state.owned_serial})
		phases.append({"reference_dispatch":reference,"samples":6,"owner_calls_per_sample":2048,"median_us_per_owner":median(samples)})
		for actor in actors:state.destroy_creep(actor)
	for ending in final_states:check(ending==final_states[0],"full final serialized system state/RNG/serials exact between dispatch paths")
	var report={"checks":checks,"failures":failures,"phases":phases,"scope":"Bounded headless ABBA32 supplied owners, native physics on both paths,64repeats/sample, first2warmups omitted. Compares script owner-field/per-root dispatch with native owner-field/batched dispatch. Complete final system/RNG/serial bytes must match. Does not measure live whole-game performance; unchanged33.34ms native gate remains mandatory."}
	var f=FileAccess.open("res://../builds/creep-particle-dispatch-r153-benchmark.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

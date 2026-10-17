extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=[]
var checks=0
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
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
func run() -> void:
	var content=root.get_node("Content");var profile=root.get_node("Profile");var phases=[];var summaries=[]
	for damaged in [false,true]:
		var endings=[]
		for deferred in [false,true,true,false]:
			var sim=Sim.new();var config=content.mission("8").duplicate(true);config.waves=[]
			sim.setup(content.catalog,content.maps[config.map],config,profile.fresh(),114,content.animations);sim.spawn_hold=true
			var state=sim.particle_state;var actors=[]
			for i in 32:
				var actor=sim.spawn_enemy([1,2,3,4,5,6,9,15][i%8],i%sim.sources.size(),"",10000+i,false)
				actor.hp=30 if damaged else 100;actor.max_hp=100;actors.append(actor)
			var samples=[]
			for sample in 10:
				var started=Time.get_ticks_usec()
				for repeat in 64:
					for actor in actors:
						state.update_creep_fields(actor,actor.pos,actor.dir)
						SpiceNative.advance_creep_particles(actor.particle_roots,state.clock_ms,30,state.make_owned_particle,state.make_owned_child,state.owned_prepared,deferred)
				if sample>=2:samples.append((Time.get_ticks_usec()-started)/2048.0)
			check(actors.all(func(actor):return actor.particle_roots.all(func(sys):return int(sys.owned_tree.advance_calls)==640)),"all active and empty roots advanced640times")
			var idle=0;var roots=0
			for actor in actors:
				for sys in actor.particle_roots:
					roots+=1
					if int(sys.owned_tree.rate)<=0 and sys.owned_tree.particles.is_empty():idle+=1
			endings.append(var_to_bytes(normalize({"systems":state.systems,"actors":actors,"rng":str(state.random.state),"serial":state.owned_serial})).hex_encode().sha256_text())
			var ordered=samples.duplicate();ordered.sort()
			phases.append({"damaged":damaged,"deferred":deferred,"samples_us_per_owner":samples,"median_us_per_owner":ordered[ordered.size()/2],"roots":roots,"eligible_empty_roots":idle})
			for actor in actors:state.destroy_creep(actor)
		for ending in endings:check(ending==endings[0],"complete final actor/system/RNG/serial state exact in ABBA branches")
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit benchmark report")
	var report={"checks":checks,"failures":failures,"phases":phases,"scope":"Controlled headless ABBA32actualowners, healthy/damaged workloads. Eight measured2048owner-call samples per phase after two warmups; includes actual owner-field update and root/child physics. Every root640updates and complete final normalized actor/system/key/numeric bytes/RNG/serial hashes exact. No live FPS or isolated inter-package speedup claim; unchanged33.34ms gate remains required."}
	if not output.is_empty() and not FileAccess.file_exists(output):
		var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CHILD_BINDING_BENCHMARK ",JSON.stringify(report));quit(1 if not failures.is_empty() else 0)

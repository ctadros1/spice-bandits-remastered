extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize() -> void:run.call_deferred()
func normalized(value):
	if value is Dictionary:
		var result={}
		for key in value:result[key]=normalized(value[key])
		return result
	if value is Array:return value.map(normalized)
	if value is Resource:return {"class":value.get_class(),"path":value.resource_path}
	if value is Callable:return {"method":str(value.get_method())}
	return value
func signature(sim) -> String:
	return var_to_bytes(normalized({"actors":sim.enemies,"systems":sim.particle_state.systems,"rng":str(sim.particle_state.random.state),"serial":sim.particle_state.serial,"owned_serial":sim.particle_state.owned_serial,"clock":sim.clock_ms,"bases":sim.bases,"events":sim.events})).hex_encode().sha256_text()
func run() -> void:
	var content=root.get_node("Content");var config=content.mission("13").duplicate(true);config.waves=[]
	var plain=Sim.new();var instrumented=load("res://../builds/creep_profile_sim_r188.gd").new()
	for sim in [plain,instrumented]:
		sim.setup(content.catalog.duplicate(true),content.maps[config.map].duplicate(true),config,root.get_node("Profile").fresh(),188,content.animations);sim.spawn_hold=true;sim.tutorial_finished=false
		if sim==instrumented:sim.particle_state=load("res://../builds/creep_profile_particles_r188.gd").new();sim.particle_state.reset()
		for i in range(16):sim.spawn_enemy([1,2,3,4,5,6,9,15][i%8],i%sim.sources.size(),"",10000+i,false)
	var checks=0;var failures=[]
	for frame in range(48):
		for sim in [plain,instrumented]:sim.tick_ms=[16.666667,30.0,50.0,100.0][frame%4];sim.step()
		checks+=1
		if signature(plain)!=signature(instrumented):failures.append(frame)
	for sim in [plain,instrumented]:
		for actor in sim.enemies:sim.particle_state.destroy_creep(actor)
		sim.enemies.clear()
	var result={"checks":checks,"failures":failures,"scope":"Diagnostic subclasses call retained super methods only;48advancing states compare full normalized actor/particle/room events,RNG and serials to base Simulation. Resource handles normalize to class/path and callable object identities to method name. Native frame-time is not benchmark acceptance."}
	var f=FileAccess.open("res://../builds/creep-profile-r188-passthrough.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();print("PROFILE_PASSTHROUGH ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

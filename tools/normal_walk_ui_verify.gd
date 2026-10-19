extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
var sample_keys={}
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<20:failures.append(label)
func compare(sim,a:Dictionary,label:String) -> void:
	var expected=a.duplicate(true);var actual=a.duplicate(true)
	sim.reference_normal_walk=true;sim.update_normal_creep_movement(expected)
	sim.reference_normal_walk=false;sim.update_normal_creep_movement(actual)
	var equal=var_to_bytes(expected)==var_to_bytes(actual);check(equal,label)
	if not equal and sample_keys.size()<12:
		var changed=[]
		for key in expected:
			if var_to_bytes(expected[key])!=var_to_bytes(actual.get(key)):changed.append({"key":key,"expected":str(expected[key]),"actual":str(actual.get(key))})
		sample_keys[label]=changed
func actor(sim,p:float,speed:float,slow:float,carry:float) -> Dictionary:
	var a=Vector2i(2,2);var b=Vector2i(2,4);var c=Vector2i(3,5)
	var start=sim.center(a.x,a.y);var target=sim.center(b.x,b.y)
	return {"state":0,"base":-1,"attacking":false,"speed":speed,"slow":slow,"path":[a,b,c,Vector2i(4,6),Vector2i(5,7)],"path_at":1,"cell":a,"next_cell":b,"move_start":start,"move_target":target,"move_progress":p,"move_carry":carry,"pos":sim.vector_interpolate(start,target,p),"dir":Vector2(0,1),"def":{"traits":{},"base_distance":1},"disco_until":0,"draw_light":0.3,"corner":{"enabled":true,"start":start,"end":target},"corner_key":1,"semi":{"enabled":true,"direction":Vector2(1,1),"incoming":Vector2(0,1),"outgoing":Vector2(1,1)},"semi_key":1,"unchanged":{"marker":19}}
func run() -> void:
	var content=root.get_node("Content");var config=content.mission("13").duplicate(true);config.waves=[]
	var sim=Sim.new();sim.setup(content.catalog,content.maps[config.map].duplicate(true),config,root.get_node("Profile").fresh(),187,content.animations);sim.spawn_hold=true
	for p in [-0.3,-0.0,0.05,0.25,0.5,0.7,0.75,0.9999999701976776,0.99999999999,1.0]:
		for speed in [-20.0,0.0,78.5,1000.0,3000.123]:
			for slow in [0.1,1.0,2.0]:
				for carry in [-0.1,0.0,0.3]:
					for dt in [0.0,1.0,16.666667,30.0,133.333,5000.0]:
						sim.tick_ms=dt;compare(sim,actor(sim,p,speed,slow,carry),str([p,speed,slow,carry,dt]))
	# Nonuniform/missing/off-map light fields retain the same fallbacks.
	for lights in [[0.15,0.8],[1.0,0.1],[0.5,0.5],[0.0,1.0]]:
		sim.map.cells[2*int(sim.map.hex_width)+2].l=lights[0];sim.map.cells[4*int(sim.map.hex_width)+2].l=lights[1]
		for p in [0.1,0.5,0.9]:sim.tick_ms=30;compare(sim,actor(sim,p,78.5,1,0),"light"+str([lights,p]))
	for endpoint in [Vector2i(3,3),Vector2i(4,2),Vector2i(1,3),Vector2i(2,0)]:
		for p in [0.05,0.3,0.55,0.8]:
			for dt in [0.0,30.0,133.333]:
				var value=actor(sim,p,78.5,1,0);value.next_cell=endpoint;value.path[1]=endpoint;value.move_target=sim.center(endpoint.x,endpoint.y);value.pos=sim.vector_interpolate(value.move_start,value.move_target,p);sim.tick_ms=dt;compare(sim,value,"endpoint"+str([endpoint,p,dt]))
	for endpoints in [[Vector2(-0.0,-50.125),Vector2(900.001,-0.0)],[Vector2(100000.125,-20000.25),Vector2(-30000.75,10.125)]]:
		for p in [-0.0,0.05,0.55,0.8]:
			var value=actor(sim,p,78.5,1,0);value.move_start=endpoints[0];value.move_target=endpoints[1];value.pos=sim.vector_interpolate(value.move_start,value.move_target,p);sim.tick_ms=30;compare(sim,value,"supplied cached endpoints"+str([endpoints,p]))
	for kind in ["current_offmap","target_offmap","missing_carry","missing_light","integer_inputs"]:
		var value=actor(sim,0.55,78.5,1,0)
		if kind=="current_offmap":value.cell=Vector2i(-1,-1)
		if kind=="target_offmap":value.next_cell=Vector2i(-1,-1)
		if kind=="missing_carry":value.erase("move_carry")
		if kind=="missing_light":value.erase("draw_light")
		if kind=="integer_inputs":value.speed=1000;value.slow=1;value.move_carry=0
		sim.tick_ms=30;compare(sim,value,kind)
	var original_cells=sim.map.cells.duplicate(true)
	for kind in ["missing_current_l","missing_target_l","null_current","null_target"]:
		sim.map.cells=original_cells.duplicate(true)
		var current_index=2*int(sim.map.hex_width)+2;var target_index=4*int(sim.map.hex_width)+2
		if kind=="missing_current_l":sim.map.cells[current_index].erase("l")
		if kind=="missing_target_l":sim.map.cells[target_index].erase("l")
		if kind=="null_current":sim.map.cells[current_index]=null
		if kind=="null_target":sim.map.cells[target_index]=null
		sim.tick_ms=30;compare(sim,actor(sim,0.55,78.5,1,0),kind)
	sim.map.cells=original_cells
	var direct=actor(sim,0.2,78.5,1,0);check(SpiceNative.advance_normal_walk(direct,30,sim.map),"valid direct fields accepted")
	for patch in [{"state":1},{"state":4},{"move_progress":1.0},{"move_progress":NAN},{"move_progress":INF},{"speed":NAN},{"speed":INF},{"slow":INF},{"move_start":Vector2.INF},{"move_target":Vector2.INF},{"move_target":sim.center(2,2)},{"cell":Vector2.ZERO},{"corner":false}]:
		var value=actor(sim,0.2,78.5,1,0);value.merge(patch,true);var before=var_to_bytes(value)
		check(not SpiceNative.advance_normal_walk(value,30,sim.map),"unusual input rejects"+str(patch));check(var_to_bytes(value)==before,"rejection is transactional"+str(patch))
	for key in ["move_start","move_target","move_progress","speed","slow"]:
		var value=actor(sim,0.2,78.5,1,0);value.erase(key);var before=var_to_bytes(value);check(not SpiceNative.advance_normal_walk(value,30,sim.map),"missing input rejects "+key);check(var_to_bytes(value)==before,"missing input unchanged "+key)
	for kind in ["bad_cells","bad_height","bad_width","zero_rows","bad_current_light","bad_target_light"]:
		var bad_map=sim.map.duplicate(true);var value=actor(sim,0.2,78.5,1,0);var before=var_to_bytes(value)
		if kind=="bad_cells":bad_map.cells="invalid"
		if kind=="bad_height":bad_map.hex_h=NAN
		if kind=="bad_width":bad_map.hex_width=NAN
		if kind=="zero_rows":bad_map.hex_height=0
		if kind=="bad_current_light":bad_map.cells[2*int(sim.map.hex_width)+2].l=INF
		if kind=="bad_target_light":bad_map.cells[4*int(sim.map.hex_width)+2].l=NAN
		check(not SpiceNative.advance_normal_walk(value,30,bad_map),"invalid late map rejects "+kind);check(var_to_bytes(value)==before,"late map rejection unchanged "+kind)
	for dt in [NAN,INF,-INF]:
		var value=actor(sim,0.2,78.5,1,0);var before=var_to_bytes(value);check(not SpiceNative.advance_normal_walk(value,dt,sim.map),"invalid time rejects");check(var_to_bytes(value)==before,"invalid time unchanged")
	var actual_cases=0;var attempted=0
	for number in content.catalog.tower_creeps.size():
		if not content.catalog.tower_creeps[number].has("filename"):continue
		attempted+=1;var value=sim.spawn_enemy(number,0,"",10000+number,false)
		if sim.normal_creep_movement(value):
			for frame in range(5):
				if int(value.state)!=0:break
				sim.tick_ms=30;sim.update_living_enemy(value)
				if SpiceNative.advance_normal_walk(value.duplicate(true),30,sim.map):compare(sim,value,"actual constructor "+str(number));actual_cases+=1;break
		sim.particle_state.destroy_creep(value)
	sim.enemies.clear()
	var phases=[];var hashes=[]
	for reference in [true,false,false,true]:
		var values=[]
		for i in range(32):values.append(actor(sim,[0.05,0.3,0.55,0.8][i%4],78.5,1,0))
		sim.tick_ms=0;sim.reference_normal_walk=reference;var samples=[]
		for sample in range(8):
			var start=Time.get_ticks_usec()
			for repeat in range(128):
				for value in values:sim.update_normal_creep_movement(value)
			samples.append(float(Time.get_ticks_usec()-start)/(128*values.size()))
		samples.sort();phases.append({"reference":reference,"median_us_per_actor":samples[4]});hashes.append(var_to_bytes(values).hex_encode().sha256_text())
	check(hashes.all(func(h):return h==hashes[0]),"all ABBA final full actor bytes exact")
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit output")
	var result={"checks":checks,"failures":failures,"differences":sample_keys,"actual_constructors_attempted":attempted,"actual_normal_nonboundary_cases":actual_cases,"ABBA":phases,"scope":"Exact full actor serialization against retained GDScript nonboundary normal update, transactional fallback, actual constructor inputs and controlled CPU timing. Original oracle gates/native whole-app performance still required; no whole-game/GPU identity."}
	if not output.is_empty():var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	print("NORMAL_WALK ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

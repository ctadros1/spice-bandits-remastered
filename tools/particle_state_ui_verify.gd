extends SceneTree
var checks=0
var failures=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<25:failures.append(label)
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(1));run.call_deferred()
func run() -> void:
	check(FileAccess.get_sha256("res://../tests/reference/particle_fx_r141.gd")=="55babdcc207641a6974d44f17482c8f2004dbfc4518f3177abf3ab29553cf92d","immutable R141 baseline hash")
	var old_script=load("res://../tests/reference/particle_fx_r141.gd")
	var script=load("res://scripts/particle_fx.gd")
	var state_script=load("res://scripts/particle_state.gd")
	var content=root.get_node("Content")
	var names=content.particles.systems.keys();names.sort()
	for reference in [false,true]:
		for name in names:
			var old=old_script.new();var current=script.new();var state=state_script.new()
			var instances=[old,current,state]
			for obj in instances:
				obj.reference_emission=reference;obj.random.seed=114
				obj.emit_system(name,Vector2(113.25,-41.5),"blue","controlled",0)
			for dt in [0.0,.03,.07,.5,1.0,2.0,1.0,.18]:
				for obj in instances:
					obj.clock_seconds=Vector2(obj.clock_seconds+Vector2(dt,0).x,0).x;obj.clock_ms=obj.clock_seconds*1000.0
					SpiceNative.advance_systems(obj.systems,obj.clock_ms,obj.emit_system,obj.emit_batch,obj.random,dt)
				for obj in [current,state]:
					check(var_to_bytes(obj.systems)==var_to_bytes(old.systems),"complete state "+str(name))
					check(obj.random.state==old.random.state and obj.serial==old.serial and obj.owned_serial==old.owned_serial,"RNG/identity "+str(name))
			for obj in instances:obj.reset()
			check(current.systems.is_empty() and state.systems.is_empty(),"reset shared state")
			old.free();current.free()
	var out={"checks":checks,"failures":failures,"definitions":names.size(),"reference_and_native":true,"old_source":"tests/reference/particle_fx_r141.gd","scope":"Exact complete systems/RNG/identity versus preserved pre-extraction controller and standalone state across all authored definitions, eight steps and both emission paths. Not full game/original-device equivalence."}
	print(JSON.stringify(out));quit(0 if failures.is_empty() else 1)

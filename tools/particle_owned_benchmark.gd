extends SceneTree
var checks=0
var failures=[]
func _initialize():
	create_timer(90).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok and failures.size()<20:failures.append(label)
func median(values:Array) -> float:
	values.sort();return float(values[int(values.size()/2)])
func run():
	var content=root.get_node("Content");var fx_script=load("res://scripts/particle_fx.gd");var actual_cases=0
	for name in content.particles.systems:
		var d:Dictionary=content.particles.systems[name];var child=str(d.get("child_system",""))
		if child.is_empty() or not content.particles.systems.has(child):continue
		var former=fx_script.new();var prepared=fx_script.new();former.reset();prepared.reset();former.owned_prepared=false
		former.emit_system(str(name),Vector2(101.25,203.5),"","",1200);prepared.emit_system(str(name),Vector2(101.25,203.5),"","",1200)
		check(former.systems==prepared.systems and former.random.state==prepared.random.state,"authored cached/unprepared initial packet "+str(name))
		for frame in range(60):
			var dt=Vector2([.001,.01667,.03,.1,.133333][frame%5],0).x
			for fx in [former,prepared]:
				fx.clock_seconds=Vector2(fx.clock_seconds+dt,0).x;fx.clock_ms=fx.clock_seconds*1000.0
				SpiceNative.advance_systems(fx.systems,fx.clock_ms,fx.emit_system,fx.emit_batch,fx.random,dt)
			check(former.systems==prepared.systems and former.random.state==prepared.random.state and former.owned_serial==prepared.owned_serial,"all authored active/pool/child fields andRNG exact "+str(name)+" frame"+str(frame))
		former.free();prepared.free();actual_cases+=1
	check(actual_cases==19,"all19resolved authored cached definitions covered")
	var fx=fx_script.new();fx.reset();fx.emit_system("Creep1ExplosionParts",Vector2(101.25,203.5),"","",1200)
	for frame in range(9):fx.clock_seconds=Vector2(fx.clock_seconds+.03,0).x;fx.clock_ms=fx.clock_seconds*1000.0;SpiceNative.advance_systems(fx.systems,fx.clock_ms,fx.emit_system,fx.emit_batch,fx.random,.03)
	var baseline:Dictionary=fx.systems[0].owned_tree.duplicate(true);var baseline_rng=fx.random.state;var baseline_serial=fx.owned_serial
	var phases=[];var expected=PackedByteArray();var expected_rng=0;var expected_serial=0
	var make_particle=fx.make_owned_particle;var make_child=fx.make_owned_child.bind(baseline.texture,str(baseline.variation))
	for optimized in [false,true,true,false]:
		var samples=[]
		for sample in range(8):
			var trees=[]
			for i in range(64):trees.append(baseline.duplicate(true))
			fx.random.state=baseline_rng;fx.owned_serial=baseline_serial
			var started=Time.get_ticks_usec()
			for frame in range(4):
				for tree in trees:SpiceNative.owned_particle_advance(tree,.03,make_particle,make_child,1.0,optimized)
			samples.append(float(Time.get_ticks_usec()-started)/256.0)
			var serialized=var_to_bytes(trees)
			if expected.is_empty():expected=serialized;expected_rng=fx.random.state;expected_serial=fx.owned_serial
			check(serialized==expected and fx.random.state==expected_rng and fx.owned_serial==expected_serial,"controlled cached/unprepared complete tree bytes andRNG exact")
		phases.append({"prepared":optimized,"samples":8,"root_calls_per_sample":256,"median_us_per_root_call_including_recursive_children":median(samples)})
	fx.free()
	var report={"checks":checks,"failures":failures,"authored_cases":actual_cases,"phases":phases,"scope":"All19authored child roots:61full-state/RNG comparisons each across varied frame intervals. Controlled64cloned authored root trees from270ms,4updates/sample,8samples inABBA order; cloning/checks outside timedregion. Prepared uses immutable imported coefficient cache plus dynamic wind flag; previous dictionary-copy/reconstruction stays selectable. Exact current state/math only; no isolated live inter-build speedup or originalGPU/wholeowner equivalence."}
	var f=FileAccess.open("res://../builds/particle-owned-r139-benchmark.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("PARTICLE_OWNED_BENCHMARK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

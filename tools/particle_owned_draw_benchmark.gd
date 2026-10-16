extends SceneTree
var checks=0
var failures=[]
func _initialize():
	create_timer(70).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok and failures.size()<20:failures.append(label)
func median(values:Array) -> float:
	values.sort();return float(values[int(values.size()/2)])
func primitives(groups:Array) -> Array:
	var result=[]
	for g in groups:
		if g.get("fallback",false):result.append(g);continue
		for i in range(0,g.indices.size(),3):
			var triangle=[g.texture.get_rid().get_id()]
			for j in range(3):
				var at=int(g.indices[i+j]);triangle.append(g.vertices[at]);triangle.append(g.uvs[at]);triangle.append(g.colors[at])
			result.append(triangle)
	return result
func run():
	var content=root.get_node("Content");var fx=load("res://scripts/particle_fx.gd").new();fx.reset()
	for name in content.particles.systems:
		var d:Dictionary=content.particles.systems[name];var c=str(d.get("child_system",""))
		if not c.is_empty() and content.particles.systems.has(c):
			for i in range(3):fx.emit_system(str(name),Vector2(101.25+i*13.25,203.5),"blue","",1200)
	for name in ["PoisonCloud","MissileRail","CreepFreeze","CreepLSD"]:fx.emit_system(name,Vector2(203.5,101.25),"","",1200)
	for frame in range(9):
		fx.clock_seconds=Vector2(fx.clock_seconds+.03,0).x;fx.clock_ms=fx.clock_seconds*1000.0
		SpiceNative.advance_systems(fx.systems,fx.clock_ms,fx.emit_system,fx.emit_batch,fx.random,.03)
	var baseline=fx.systems.duplicate(true);var old_groups=0;var new_groups=0
	for transform in [[Vector2.ZERO,1.0],[Vector2(120.125,-73.6),.5],[Vector2(-.137,12.25),1.3]]:
		for quantized in [false,true]:
			var old=baseline.duplicate(true);var merged=baseline.duplicate(true)
			for held in range(2):
				for premul in [false,true]:
					var former=SpiceNative.particle_batches(old,premul,fx.clock_ms,transform[0],transform[1],quantized,false,false)
					var prepared=SpiceNative.particle_batches(merged,premul,fx.clock_ms,transform[0],transform[1],quantized,false,true)
					check(var_to_bytes(primitives(former))==var_to_bytes(primitives(prepared)),"exact ordered texture/triangle/position/UV/color bytes across grouping")
					check(var_to_bytes(old)==var_to_bytes(merged),"held recursive childcolor mutation unchanged")
					old_groups+=former.size();new_groups+=prepared.size()
				var keyed_a=merged.duplicate(true);var keyed_b=merged.duplicate(true)
				for premul in [false,true]:
					check(var_to_bytes(SpiceNative.particle_batches(keyed_a,premul,fx.clock_ms,transform[0],transform[1],quantized,true,true))==var_to_bytes(SpiceNative.particle_batches(keyed_b,premul,fx.clock_ms,transform[0],transform[1],quantized,false,true)),"lookup paths still exact serialized groups")
	check(new_groups<old_groups and new_groups>0,"fixture actually coalesces repeated owned textures")
	# Fallbacks, owner hiding and empty roots remain order/material boundaries.
	var special=baseline.duplicate(true)
	var legacy:Dictionary=special[-1].duplicate(true);legacy.particles=[legacy.particles[0].duplicate(true)];legacy.particles[0].region=Rect2(-2,-1,18,19);special.insert(2,legacy)
	special[0].owner_hidden=true
	var empty:Dictionary=special[1].duplicate(true);empty.owned_tree.particles=[];empty.particles=[];special.insert(4,empty)
	for premul in [false,true]:
		var a=special.duplicate(true);var b=special.duplicate(true)
		check(var_to_bytes(primitives(SpiceNative.particle_batches(a,premul,fx.clock_ms,Vector2(12,-7),.85,true,false,false)))==var_to_bytes(primitives(SpiceNative.particle_batches(b,premul,fx.clock_ms,Vector2(12,-7),.85,true,false,true))),"fallback/hidden/empty boundaries preserve exact ordered primitives")
	var phases=[];var expected=PackedByteArray()
	for coalesced in [false,true,true,false]:
		var samples=[]
		for sample in range(8):
			var systems=baseline.duplicate(true);var started=Time.get_ticks_usec()
			for repeat in range(8):
				for premul in [false,true]:SpiceNative.particle_batches(systems,premul,fx.clock_ms,Vector2(120.125,-73.6),.85,true,false,coalesced)
			samples.append(float(Time.get_ticks_usec()-started)/8.0)
			var actual=var_to_bytes(systems)
			if expected.is_empty():expected=actual
			check(actual==expected,"CPU sample leaves exact complete held state")
		phases.append({"coalesced":coalesced,"samples":8,"both_layers_per_sample":8,"median_us_both_layers":median(samples)})
	var report={"checks":checks,"failures":failures,"systems":baseline.size(),"old_groups_total":old_groups,"coalesced_groups_total":new_groups,"phases":phases,"scope":"Exact ordered texture and triangle position/UV/RGBA bytes plus full held color mutation across3transforms/2quantization modes/2held renders/all19authored child roots and legacy effects. Exact key-path group serialization retained; fallback/hidden/empty boundaries covered. ABBA identical authored state, cloning/comparison outside timing. No originalGPU/wholeowner equivalence or isolated live inter-build speedup."}
	var f=FileAccess.open("res://../builds/particle-draw-r140-benchmark.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("PARTICLE_OWNED_DRAW ",JSON.stringify(report));fx.free();quit(0 if failures.is_empty() else 1)

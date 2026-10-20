extends SceneTree
const Cloud=preload("res://scripts/cloud_lifecycle.gd")
const Bridge=preload("res://scripts/cloud_particles.gd")
const State=preload("res://scripts/particle_state.gd")
var checks=0
var key_representation_checks=0
var failures=[]
var timelines=[]
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func adapters(bridge) -> Dictionary:
	return {"factory":bridge.factory.bind(43),"advance":bridge.advance,"destroy":bridge.destroy,"rand":func():return 0,"random":func():return 0,"vector":func():return Vector2(1,0),"modulo":func(a,b):return a%b if b else 0,"decals":func(_z):check(false,"unexpected parent decals"),"sound":func(_n,_p,_a):check(false,"unexpected parent sound"),"damage":func(_e,_o,_d,_a,_t):check(false,"unexpected supplied actor damage")}
func context(kind:int,tier:int,duration:float,reference:bool) -> Dictionary:
	var state=State.new();state.reset();state.reference_emission=reference
	var bridge=Bridge.new(state)
	var zone=Cloud.construct({"poison_duration":duration,"poison_range":2000.0,"poison_damage":10.0,"slowdown":50.0},Vector2(100,150),43,2.5,kind==5,tier,kind==8)
	return {"state":state,"bridge":bridge,"zone":zone,"adapters":adapters(bridge)}
func validate_roots(ctx:Dictionary,label:String) -> void:
	check(ctx.state.systems.size()==ctx.zone.roots.size(),label+" all retained systems belong to the cloud")
	for root_system in ctx.zone.roots:
		var system:Dictionary=root_system.system;var tree:Dictionary=system.owned_tree
		check(ctx.state.systems.any(func(v):return is_same(v,system)),label+" renderer registry keeps actual system dictionary")
		check(is_same(system.particles,tree.particles),label+" renderer observes the actual retained particles")
		check(root_system.active_count==tree.particles.size() and root_system.first_release==tree.first_release,label+" status derives from actual particle state")
		check(root_system.rate==tree.rate,label+" rate derives from actual particle update")
		check(tree.pos==root_system.pos and system.pos==tree.pos,label+" caller point reaches physics and renderer")
		check(tree.disable_after_seconds==root_system.disable_after_seconds,label+" exact raw seconds override bound")
		check(tree.interval_seconds==root_system.interval,label+" caller interval bound")
		check(float(tree.definition.color[3])==float(root_system.alpha),label+" caller raw alpha bound without clamp")
		check(int(system.object_owner)==43 and system.cloud_managed,label+" owner and phase registered")
func test_context(kind:int,tier:int,duration:float) -> void:
	var native=context(kind,tier,duration,false);var reference=context(kind,tier,duration,true)
	var prefix=str([kind,tier,duration]);var pattern=[0,.001,16.667,30,100,133.333]
	var clock=0.0;var deleted_at=-1.0;var inactive_at=-1.0;var saw_particles=false;var saw_owned_tail=false;var frames=0
	for i in 600:
		var delta=float(pattern[i%pattern.size()]);clock+=delta
		Cloud.update(native.zone,[],32.0,delta,native.adapters)
		Cloud.update(reference.zone,[],32.0,delta,reference.adapters)
		frames+=1
		var actual_zone=canonical_keys(native.zone);var expected_zone=canonical_keys(reference.zone)
		check(var_to_bytes(actual_zone)==var_to_bytes(expected_zone),prefix+" complete normalized-key cloud and real recursive tree bytes exact "+str(i)+" "+byte_difference(actual_zone,expected_zone))
		var actual_systems=canonical_keys(native.state.systems);var expected_systems=canonical_keys(reference.state.systems)
		check(var_to_bytes(actual_systems)==var_to_bytes(expected_systems),prefix+" complete normalized-key renderer systems bytes exact "+str(i)+" "+byte_difference(actual_systems,expected_systems))
		check(native.state.random.state==reference.state.random.state,prefix+" isolated spawn RNG consumption exact "+str(i))
		validate_roots(native,prefix+"/"+str(i))
		if i==0:
			check(native.zone.roots.size()==1,prefix+" first actual cloud system allocated without initial Emit")
			if not native.zone.roots.is_empty():
				var system:Dictionary=native.zone.roots[0].system
				check(int(system.owned_tree.advance_calls)==(1 if kind==5 else 26),prefix+" actual warmup and same-frame update count exact")
		for root_system in native.zone.roots:
			if root_system.active_count>0:saw_particles=true
		if native.zone.deleted and deleted_at<0:deleted_at=clock
		if native.zone.deleted and not native.zone.roots.is_empty():saw_owned_tail=true
		# The presentation phase must neither advance nor discard a managed
		# cloud. This check uses the actual unowned dispatcher after each tick.
		var before=var_to_bytes(native.state.systems)
		native.state.advance_unowned(Cloud.f32(delta*.001))
		check(var_to_bytes(native.state.systems)==before,prefix+" no duplicate presentation-phase particle update/removal "+str(i))
		if not native.zone.active:
			inactive_at=clock
			break
	check(inactive_at>=0 and deleted_at>=0,prefix+" actual retained systems eventually finish")
	check(saw_particles,prefix+" authored real particles emitted")
	check(saw_owned_tail and inactive_at>deleted_at,prefix+" cloud retains real tail after damage expiry")
	check(native.zone.roots.is_empty() and native.state.systems.is_empty(),prefix+" actual destruction unregisters all cloud roots")
	timelines.append({"kind":kind,"tier":tier,"duration_ms":duration,"frames":frames,"deleted_at_ms":deleted_at,"inactive_at_ms":inactive_at,"actual_particles_observed":saw_particles,"actual_tail_observed":saw_owned_tail})
	native.state.reset();reference.state.reset()
# Existing native/script factories deliberately use different Variant key
# representations (StringName/String). Preserve key text/order, all value types
# and every physical bit while canonicalizing only that known boundary.
func canonical_keys(value):
	if value is Dictionary:
		var result={}
		for key in value:
			key_representation_checks+=2
			if not (key is String or key is StringName):check(false,"particle dictionary key is text")
			if result.has(str(key)):check(false,"canonical key text remains unique")
			result[str(key)]=canonical_keys(value[key])
		return result
	if value is Array:
		var result=value.duplicate(false)
		for i in value.size():result[i]=canonical_keys(value[i])
		return result
	return value
func byte_difference(actual,expected,path:String="") -> String:
	if var_to_bytes(actual)==var_to_bytes(expected):return ""
	if typeof(actual)!=typeof(expected):return path+" types "+str(typeof(actual))+"/"+str(typeof(expected))
	if actual is Dictionary:
		if actual.keys()!=expected.keys():return path+" key representation/order "+str(actual.keys())+"/"+str(expected.keys())
		for key in actual:
			var diff=byte_difference(actual[key],expected[key],path+"/"+key)
			if not diff.is_empty():return diff
	if actual is Array:
		if actual.size()!=expected.size():return path+" sizes "+str(actual.size())+"/"+str(expected.size())
		for i in actual.size():
			var diff=byte_difference(actual[i],expected[i],path+"/"+str(i))
			if not diff.is_empty():return diff
	return path+" values "+str(actual)+"/"+str(expected)
func run() -> void:
	var content=root.get_node("Content");var original_definitions=var_to_bytes(content.particles.systems)
	for kind in [7,8,5]:
		for tier in [1,2]:
			for duration in [200.0,6000.0]:test_context(kind,tier,duration)
	check(var_to_bytes(content.particles.systems)==original_definitions,"all shared imported definitions remain byte exact")
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"key_representation_checks":key_representation_checks,"full_state_frame_pairs":timelines.reduce(func(total,v):return total+v.frames,0),"failures":failures,"contexts":timelines,"scope":"Actual retained authored PoisonCloud/GooCloud/RadiationDebris and recursive children execute through selected cloud controller, with native/reference complete state/RNG comparisons (only String/StringName key representation canonicalized; text/order/value types/bits preserved), original warmup/header writes, real status-derived tails/deletion, renderer aliases and unowned-phase exclusion. Caller random/vector supplied; particle spawn uses existing isolated RNG. Not yet called by Simulation, no original global RNG/resource/parent/room/GPU/audio/video or complete lifecycle identity acceptance."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)

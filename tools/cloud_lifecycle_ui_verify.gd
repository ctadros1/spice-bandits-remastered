extends SceneTree
const Cloud=preload("res://scripts/cloud_lifecycle.gd")
const Poison=preload("res://scripts/creep_poison.gd")
var checks=0
var failures=[]
class Recorder extends RefCounted:
	var actors=[]
	var events=[]
	var serial=0
	var tail_ms=2000
	var direct_status=false
	var random_value=0
	var vector_value=Vector2(1,0)
	func bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)
	func f32(v:float) -> float:return Vector2(v,0).x
	func label(actor:Dictionary) -> int:
		for i in actors.size():
			if is_same(actors[i],actor):return i
		return -1
	func effect(kind:String,actor:Dictionary,type:int) -> void:events.append({"kind":kind,"actor":label(actor),"type":type})
	func damage(actor:Dictionary,owner:int,amount:float,argument:bool,type:int) -> void:
		events.append({"kind":"damage_stub","actor":label(actor),"owner":owner,"damage_bits":bits(amount),"argument_b":int(argument),"damage_type":type})
	func root_system(name:String) -> Dictionary:
		serial+=1
		return {"id":serial,"name":name,"rate":3,"interval":f32(.08),"disable_after_seconds":0.0,"pos":Vector2(2.5,7.5),"alpha":1.0,"active_count":0,"first_release":true,"stub_update_calls":0,"stub_clock":0.0}
	func factory(name:String) -> Dictionary:
		var system=root_system(name)
		events.append({"kind":"factory_stub","id":system.id,"name":name})
		return system
	# Only the verifier supplies this finite-tail status callback. The controller
	# consumes real status through an adapter and contains no duration heuristic.
	func advance(system:Dictionary,seconds:float) -> void:
		system.stub_update_calls+=1
		system.stub_clock=f32(float(system.stub_clock)+seconds)
		system.first_release=false
		system.active_count=0 if direct_status else 2 if float(system.stub_clock)<f32(float(system.disable_after_seconds)+float(tail_ms)/1000.0) else 0
		events.append({"kind":"particle_update_stub","id":system.id,"dt_seconds_bits":bits(seconds),"active_after":system.active_count,"stub_clock_bits":bits(system.stub_clock)})
	func destroy(system:Dictionary) -> void:
		events.append({"kind":"particle_destructor_stub","id":system.id})
		events.append({"kind":"delete_stub","id":system.id})
	func rand_value() -> int:
		events.append({"kind":"random_stub","address":"0x36c7cc","value":random_value});return random_value
	func random_long() -> int:
		events.append({"kind":"random_stub","address":"0x36c7dc","value":random_value});return random_value
	func vector() -> Vector2:
		events.append({"kind":"vector_stub","bits":[bits(vector_value.x),bits(vector_value.y)]});return vector_value
	func modulo(left:int,right:int) -> int:
		var result=left%right if right else 0
		events.append({"kind":"signed_mod_stub","left":left,"right":right,"result":result});return result
	func decals(_zone:Dictionary) -> void:events.append({"kind":"AddDecals_stub"})
	func sound(name:String,pos:Vector2,argument:int) -> void:events.append({"kind":"sound_stub","name":name,"position_bits":[bits(pos.x),bits(pos.y)],"argument":argument})
	func adapters() -> Dictionary:return {"factory":factory,"advance":advance,"destroy":destroy,"rand":rand_value,"random":random_long,"vector":vector,"modulo":modulo,"decals":decals,"sound":sound,"damage":damage}
	func snapshot(zone:Dictionary) -> Dictionary:
		var systems=[]
		for system in zone.roots:
			systems.append({"id":system.id,"name":system.name,"rate":system.rate,"interval_bits":bits(system.interval),"disable_after_bits":bits(system.disable_after_seconds),"position_bits":[bits(system.pos.x),bits(system.pos.y)],"alpha_bits":bits(system.alpha),"active_count":system.active_count,"first_release":int(system.first_release),"stub_update_calls":system.stub_update_calls,"stub_clock_bits":bits(system.stub_clock)})
		var states=[]
		for actor in actors:states.append({"state":actor.state,"poison_count":actor.poison_count,"slow_count":actor.slow_count,"pending_bits":bits(actor.slow_pending),"rates":actor.particle_roots.map(func(v):return v.owned_tree.rate)})
		var creeps={"actors":states,"tracked":[zone.creeps_in_range.map(func(v):return label(v))],"events":events.duplicate(true)}
		return {"active":int(zone.active),"deleted":int(zone.deleted),"age_ms_bits":bits(zone.age_ms),"emit_age_ms_bits":bits(zone.emit_age_ms),"position_bits":[bits(zone.pos.x),bits(zone.pos.y)],"initial_position_bits":[bits(zone.initial_pos.x),bits(zone.initial_pos.y)],"bonus_bits":bits(zone.damage_bonus),"owner":zone.owner,"radiation":int(zone.radiation),"parent30_present":not zone.parent30.is_empty(),"parent40_present":not zone.parent40.is_empty(),"ready44":int(zone.ready),"roots":systems,"creeps":creeps,"events":events.duplicate(true)}
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func integer_frame(value):
	if value is Dictionary:
		var result={}
		for key in value:result[key]=integer_frame(value[key])
		return result
	if value is Array:
		var result=[]
		for item in value:result.append(integer_frame(item))
		return result
	if value is float:
		check(value==floor(value),"schema-defined frame/header/callback word exactly integral")
		return int(value)
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
func equal_frame(actual:Dictionary,raw:Dictionary,label:String) -> void:
	var expected=integer_frame(raw)
	check(var_to_bytes(actual)==var_to_bytes(expected),label+" complete serialized frame raw-word/ordered-callback bytes exact "+byte_difference(actual,expected))
	for key in actual:
		check(actual[key]==expected[key],label+"/"+key+(" actual "+str(actual[key])+" expected "+str(expected[key]) if actual[key]!=expected[key] else ""))
func context(inp:Dictionary) -> Dictionary:
	var record=Recorder.new();record.tail_ms=int(inp.get("tail_ms",2000))
	for i in 3:
		var roots=[]
		for j in 3:roots.append({"creep_alias":["poison","radiation","freeze"][j],"owned_tree":{"rate":7+j}})
		record.actors.append({"id":100+i,"state":0,"pos":Vector2(500,500) if i==1 else Vector2(100,150),"resource_kind":2 if i==2 else 1,"poison_count":0,"slow_count":0,"slow_pending":-1.0,"particle_roots":roots})
	var resource={"poison_range":float(inp.get("radius",2))*1000.0,"poison_duration":float(inp.get("duration",inp.get("duration_ms",200))),"poison_damage":10.0,"slowdown":50.0}
	var zone=Cloud.construct(resource,Vector2(100,150),43,2.5,bool(inp.get("radiation",0)),int(inp.get("word8",2)),bool(inp.get("slow",0)))
	return {"record":record,"zone":zone}
func sequence(row:Dictionary,index:int) -> void:
	var ctx=context(row.input);var record:Recorder=ctx.record;var zone:Dictionary=ctx.zone;var inp:Dictionary=row.input
	equal_frame(record.snapshot(zone),row.constructor,"constructor "+str(index))
	if inp.parent=="parent30_active":zone.parent30={"byte44":1}
	elif inp.parent=="parent40_zero":zone.parent40={"word4":0}
	var deltas=inp.get("deltas",[30])
	for i in row.frames.size():
		record.events=[]
		if i==3 and inp.parent!="none":
			if inp.parent=="parent30_active":zone.parent30.byte44=0
			else:zone.parent40.word4=1
		for actor in record.actors:actor.poison_count=0;actor.slow_count=0;actor.slow_pending=-1.0
		Cloud.update(zone,record.actors,32,float(deltas[i%deltas.size()]),record.adapters(),false,record.effect)
		var actual=record.snapshot(zone);actual["frame"]=i
		equal_frame(actual,row.frames[i],"sequence "+str(index)+"/"+str(i))
func direct_particles(row:Dictionary,index:int) -> void:
	var ctx=context({});var record:Recorder=ctx.record;var zone:Dictionary=ctx.zone;record.direct_status=true
	for supplied in row.input.roots:
		var system=record.root_system("supplied");system.active_count=int(supplied.active);system.first_release=bool(supplied.first);system.disable_after_seconds=float(supplied.disable);zone.roots.append(system)
	equal_frame(record.snapshot(zone),row.before,"direct before "+str(index))
	for i in 2:
		record.events=[];Cloud.update_particles(zone,float(row.input.dt_ms),record.adapters())
		equal_frame(record.snapshot(zone),row.frames[i],"direct "+str(index)+"/"+str(i))
func header(row:Dictionary,index:int) -> void:
	var ctx=context(row.input);var record:Recorder=ctx.record;var zone:Dictionary=ctx.zone
	record.random_value=int(row.input.random_value);record.vector_value=Vector2(row.input.vector[0],row.input.vector[1])
	Cloud.update(zone,record.actors,float(row.input.height),float(row.input.dt_ms),record.adapters(),false,record.effect)
	equal_frame(record.snapshot(zone),row.after,"header "+str(index))
func run() -> void:
	var path="res://../tests/fixtures/native-poison-lifecycle-reference.json"
	check(FileAccess.get_sha256(path)=="79fdc974b0c362b7413bcdcfe794f7860eff807ea55f10f200e3d11316e8ef7e","independently repeated original fixture exact hash")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	for i in data.sequences.size():sequence(data.sequences[i],i)
	for i in data.direct_particles.size():direct_particles(data.direct_particles[i],i)
	for i in data.emission_headers.size():header(data.emission_headers[i],i)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"failures":failures,"sequences":data.sequences.size(),"frames":data.sequences.reduce(func(sum,v):return sum+v.frames.size(),0),"particle_status_cases":data.direct_particles.size(),"emission_header_cases":data.emission_headers.size(),"scope":"Selected original cloud constructor, parent gating, float32 age/emission timers, emission header raw words, ordered apply/Emit/Stop callbacks, warmup, pre-update status/removal/compaction and post-tail global Stop. Factory/physics/status/random/vector/decal/sound/damage adapters explicitly supplied. Synthetic finite-tail callback confined to verifier. Not yet bound to Simulation; no actual particle physics/GPU/audio/full-game acceptance."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)

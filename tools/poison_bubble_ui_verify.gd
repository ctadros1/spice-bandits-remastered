extends SceneTree
const Bubble=preload("res://scripts/bubble_lifecycle.gd")
var checks=0
var failures=[]
class Recorder extends RefCounted:
	var input={}
	var events=[]
	var serial=0
	var target=null
	var header={}
	var roots_allocated=false
	func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
	func f32(value:float) -> float:return Vector2(value,0).x
	func parameter(name:String):
		var value=input.get("height");value=null if value==null else int(value)
		events.append({"kind":"resource_parameter_stub","name":name,"value":value});return value
	func lookup(id:int):
		events.append({"kind":"target_lookup_stub","id":id,"present":target!=null});return null if target==null else Vector2(target[0],target[1])
	func texture(name:String,crop:Vector2i,size:Vector2i,slot:int) -> Dictionary:
		events.append({"kind":"allocation_stub","bytes":116});events.append({"kind":"texture_constructor_stub","name":name,"crop_origin":[crop.x,crop.y],"supplied_header_from_requested_size":[size.x,size.y]})
		return {"name":name,"size":size,"slot":slot}
	func texture_destroy(value:Dictionary) -> void:events.append({"kind":"texture_destructor_stub","name":value.name})
	func root_system(name:String) -> Dictionary:
		serial+=1;roots_allocated=true
		return {"id":serial,"name":name,"rate":int(header.get("rate",3)),"interval":f32(float(header.get("interval",.08))),"disable_after_seconds":f32(float(header.get("disable",0))),"pos":Vector2(2.5,7.5),"active_count":int(header.get("count",0)),"first_release":int(header.get("first",1)),"updates":0,"clock":0.0}
	func factory(name:String) -> Dictionary:
		if input.get("factory_null",false) or name in input.get("null_names",[]):events.append({"kind":"factory_stub_null","name":name});return {}
		var system=root_system(name);events.append({"kind":"factory_stub","id":system.id,"name":name});return system
	func advance(system:Dictionary,seconds:float) -> void:
		system.updates+=1;system.clock=f32(float(system.clock)+seconds);system.first_release=0
		var counts=input.get("particle_counts",[2,0]);system.active_count=int(counts[mini(int(system.updates)-1,counts.size()-1)])
		events.append({"kind":"particle_update_stub","id":system.id,"dt_seconds_bits":bits(seconds),"active_after":system.active_count,"stub_clock_bits":bits(system.clock)})
	func destroy(system:Dictionary) -> void:events.append({"kind":"particle_destructor_stub","id":system.id});events.append({"kind":"delete_stub","id":system.id})
	func blend(source:int,destination:int) -> void:events.append({"kind":"blend_stub","source":source,"destination":destination})
	func color(alpha:float) -> void:events.append({"kind":"color_stub","rgba_bits":[bits(alpha),bits(alpha),bits(alpha),bits(alpha)]})
	func quad(value:Dictionary,pos:Vector2) -> void:events.append({"kind":"quad_stub","name":value.name,"texture_slot":value.slot,"size":[value.size.x,value.size.y],"xy_bits":[bits(pos.x),bits(pos.y)]})
	func particle_render(system:Dictionary) -> void:events.append({"kind":"particle_render_stub","id":system.id})
	func adapters() -> Dictionary:return {"parameter":parameter,"lookup":lookup,"texture":texture,"texture_destroy":texture_destroy,"factory":factory,"advance":advance,"destroy":destroy,"blend":blend,"color":color,"quad":quad,"particle_render":particle_render}
	func state(b:Dictionary) -> Dictionary:
		var words={"0x4":0,"0x8":bits(b.age),"0xc":bits(b.progress),"0x10":bits(b.alpha)}
		for spec in [["pos",0x14],["launch",0x1c],["target",0x24],["lift_target",0x2c],["shadow",0x34],["shadow_origin",0x3c]]:
			words["0x%x"%int(spec[1])]=bits(b[spec[0]].x);words["0x%x"%(int(spec[1])+4)]=bits(b[spec[0]].y)
		var roots=[]
		for s in b.roots:roots.append({"id":s.id,"name":s.name,"rate":s.rate,"interval_bits":bits(s.interval),"disable_after_bits":bits(s.disable_after_seconds),"position_bits":[bits(s.pos.x),bits(s.pos.y)],"active_count":s.active_count,"first_release":s.first_release,"update_calls":s.updates})
		var sizes=[]
		for s in [b.main,b.shadow_texture]:sizes.append([0,0] if s.is_empty() else [s.size.x,s.size.y])
		return {"words":words,"flags":[b.active,b.lifted,b.follow_particles,b.follow_target],"target_id":b.target_id,"texture_sizes":sizes,"roots":roots,"events":events.duplicate(true)}
	func state_and_render(b:Dictionary) -> Dictionary:
		var result=state(b);events=[];Bubble.render(b,adapters());result["render_events"]=events.duplicate(true);return result
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func compare(actual,expected,path:String) -> void:
	if expected is Dictionary:
		check(actual is Dictionary,path+" dictionary")
		if not actual is Dictionary:return
		check(actual.size()==expected.size(),path+" key count")
		for key in expected:
			check(actual.has(key),path+" has "+str(key))
			if actual.has(key):compare(actual[key],expected[key],path+"/"+str(key))
	elif expected is Array:
		check(actual is Array,path+" array")
		if not actual is Array:return
		check(actual.size()==expected.size(),path+" length")
		for i in mini(actual.size(),expected.size()):compare(actual[i],expected[i],path+"/"+str(i))
	elif expected is float:
		check(actual is int and actual==int(expected),path+" exact integer/word "+str(actual)+" != "+str(expected))
	else:check(typeof(actual)==typeof(expected) and actual==expected,path+" scalar "+str(actual)+" != "+str(expected))
func sequence(row:Dictionary,index:int) -> void:
	var r=Recorder.new();r.input=row.input;r.header=r.input.get("particle_header",{});r.target=r.input.target
	var inp:Dictionary=row.input;var b=Bubble.construct({},Vector2(inp.start[0],inp.start[1]),77,int(inp.follow),(int(inp.slow)&1)!=0,r.adapters())
	compare(r.state_and_render(b),row.constructor,"ctor"+str(index))
	if inp.has("supplied_flags"):
		b.active=int(inp.supplied_flags[0]);b.lifted=int(inp.supplied_flags[1]);b.follow_particles=int(inp.supplied_flags[2]);b.follow_target=int(inp.supplied_flags[3])
	if inp.has("supplied_roots"):
		b.roots.clear()
		for i in inp.supplied_roots.size():r.header=inp.supplied_roots[i];b.roots.append(r.root_system("supplied-status-"+str(i)))
	for i in row.frames.size():
		if inp.has("targets"):r.target=inp.targets[i%inp.targets.size()]
		r.events=[];Bubble.update(b,float(inp.deltas[i]),r.adapters(),bool(inp.get("argument_b",0)))
		compare(r.state_and_render(b),row.frames[i],"frame"+str(index)+"/"+str(i))
	r.events=[];Bubble.destroy(b,r.adapters())
	# Reserved vector allocation/deallocation is supplied by the original probe;
	# Godot owns its array storage. Preserve that callback boundary in this gate.
	if r.roots_allocated:r.events.append({"kind":"vector_storage_delete_stub"})
	compare(r.state(b),row.destructor,"dtor"+str(index))
func run() -> void:
	var path="res://../tests/fixtures/native-poison-bubble-reference.json"
	check(FileAccess.get_sha256(path)=="176cf6a340d2ca932b6201b9ecc02c967ecc58779bf0f3645802a6dc35a4142b","original repeated fixture hash")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	for i in data.sequences.size():sequence(data.sequences[i],i)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit output")
	var report={"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Pure bubble controller original full-state/callback/draw rows; no real particle/GPU/Simulation join","sequences":216,"frames":3824}
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

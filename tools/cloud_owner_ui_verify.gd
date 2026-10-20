extends SceneTree
const Owner=preload("res://scripts/cloud_owner.gd")
var checks=0
var failures=[]
class Recorder extends RefCounted:
	var events=[]
	var action={}
	func bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)
	func cloud_update(cloud:Dictionary,dt:float,argument:bool) -> void:
		events.append({"kind":"cloud_update_stub","id":cloud.id,"dt_ms_bits":bits(dt),"argument_b":int(argument)})
		var change:Dictionary=action.get("cloud_updates",{}).get(str(cloud.id),{})
		if change.has("active"):cloud.active=int(change.active)
		if change.get("clear_ready_parent",false) and not cloud.parent30.is_empty() and not (int(cloud.parent30.active)&1):cloud.parent30={}
	func bubble_update(bubble:Dictionary,dt:float,argument:bool) -> void:
		events.append({"kind":"bubble_update_stub","id":bubble.id,"dt_ms_bits":bits(dt),"argument_b":int(argument)})
		var change:Dictionary=action.get("bubble_updates",{}).get(str(bubble.id),{})
		if change.has("active"):bubble.active=int(change.active)
		if change.has("particles"):bubble.particles=int(change.particles)
	func cloud_destroy(cloud:Dictionary) -> void:
		events.append({"kind":"cloud_destructor_stub","id":cloud.id})
		events.append({"kind":"delete_stub","object":"cloud","id":cloud.id})
	func bubble_destroy(bubble:Dictionary) -> void:
		events.append({"kind":"bubble_destructor_stub","id":bubble.id})
		events.append({"kind":"delete_stub","object":"bubble","id":bubble.id})
	func bubble_particles(bubble:Dictionary) -> int:return int(bubble.particles)
	func adapters() -> Dictionary:return {"cloud_update":cloud_update,"bubble_update":bubble_update,"cloud_destroy":cloud_destroy,"bubble_destroy":bubble_destroy,"bubble_particles":bubble_particles}
	func snapshot(clouds:Array,bubbles:Array) -> Dictionary:
		return {"clouds":clouds.map(func(c):return {"id":c.id,"active":c.active,"parent":null if c.parent30.is_empty() else c.parent30.id}),"bubbles":bubbles.map(func(b):return {"id":b.id,"active":b.active,"particles":b.particles}),"events":events.duplicate(true)}
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(2));run.call_deferred()
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
		check(value==floor(value),"schema-defined original frame word exactly integral")
		return int(value)
	return value
func equal_frame(actual:Dictionary,raw:Dictionary,label:String) -> void:
	var expected=integer_frame(raw)
	check(var_to_bytes(actual)==var_to_bytes(expected),label+" complete raw words/vector order/callback bytes exact")
	for key in actual:check(actual[key]==expected[key],label+"/"+key+" actual "+str(actual[key])+" expected "+str(expected[key]))
func sequence(row:Dictionary,index:int) -> void:
	var clouds=[];var bubbles=[];var record=Recorder.new();var inp:Dictionary=row.input
	for i in inp.bubbles.size():bubbles.append({"id":i,"active":int(inp.bubbles[i].active),"particles":int(inp.bubbles[i].particles)})
	for i in inp.clouds.size():
		var c:Dictionary=inp.clouds[i]
		clouds.append({"id":i,"active":int(c.active),"parent30":{} if c.parent==null else bubbles[int(c.parent)]})
	equal_frame(record.snapshot(clouds,bubbles),row.before,"before "+str(index))
	for i in inp.actions.size():
		record.events=[];record.action=inp.actions[i]
		Owner.update(clouds,bubbles,float(inp.dt_ms),bool(inp.argument_b),record.adapters())
		equal_frame(record.snapshot(clouds,bubbles),row.frames[i],"sequence "+str(index)+"/"+str(i))
func run() -> void:
	var path="res://../tests/fixtures/native-cloud-owner-reference.json"
	check(FileAccess.get_sha256(path)=="38ccc53d7ece3dd801acee26841e6f46a85d6cfbe5bf3ff94eb9927d592b3eb4","two independently repeated original manager captures exact hash")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	for i in data.sequences.size():sequence(data.sequences[i],i)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"failures":failures,"sequences":data.sequences.size(),"frames":data.sequences.reduce(func(total,v):return total+v.frames.size(),0),"scope":"Full selected original CTower.UpdatePoisons464bytes on supplied reserved vectors with explicit recording/status Update/D1/delete/memmove/exception callbacks. Complete before/after state/order/parent detach/raw argument comparisons include empty vectors, bit0 polarity, pre-update deletion/compaction, changed-status next-pass removal and first-non-null detach without pointer identity comparison. No actual cloud/bubble physics/destructor/room scheduling or Simulation integration acceptance."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)

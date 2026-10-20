extends SceneTree
const Owned=preload("res://scripts/particle_owned_view.gd")
const Reference=preload("res://scripts/particle_child_view.gd")
var checks=0
var failures=[]
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)
func from_bits(v:int) -> float:return PackedInt32Array([v]).to_byte_array().decode_float(0)
func no_spawn(_tree,_index,_fresh,_old) -> Dictionary:
	check(false,"unexpected particle emission outside original no-emission contexts");return {}
func no_child(_name) -> Dictionary:
	check(false,"unexpected child creation outside original no-emission contexts");return {}
func snapshot(tree:Dictionary) -> Dictionary:
	return {"rate":tree.rate,"clock_bits":bits(tree.clock_seconds),"release_bits":bits(tree.release_seconds),"delay_bits":bits(tree.delay_seconds),"first_release":int(tree.first_release),"active_count":tree.particles.size(),"disable_bits":bits(tree.disable_after_seconds)}
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
	var path="res://../tests/fixtures/native-particle-disable-reference.json"
	check(FileAccess.get_sha256(path)=="da491ccebf47cafa061285c56b1ed6269c83ee8e3d3e6addc45430707a70a6a2","two independently repeated original captures exact binding")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path));var pairs=0
	for i in data.cases.size():
		var row=data.cases[i];var inp=row.input
		var expected={}
		for key in row.output:
			check(float(row.output[key])==floor(float(row.output[key])),"schema-defined original word is exactly integral")
			expected[key]=int(row.output[key])
		for metadata in [from_bits(bits(inp.duration_ms)),12000.0]:
			var definition={"num_release":3,"max_particles":100,"release_interval":100.0,"life_cycle":1.0,"time_scale":float(inp.time_scale),"disable_after":metadata,"texture_list":[]}
			var definition_before=var_to_bytes(definition)
			var tree=Owned.initialize(definition,true,false,false)
			tree.clock_seconds=from_bits(int(inp.clock_bits));tree.delay_seconds=from_bits(bits(inp.delay_seconds));tree.first_release=bool(inp.first_release)
			tree.disable_after_seconds=from_bits(int(inp.disable_bits))
			var reference=tree.duplicate(true);var unprepared=tree.duplicate(true)
			Owned.advance(tree,float(inp.dt_seconds),no_spawn,no_child)
			Reference.advance(reference,float(inp.dt_seconds),no_spawn,no_child)
			SpiceNative.owned_particle_advance(unprepared,float(inp.dt_seconds),no_spawn,no_child,1.0,false)
			check(var_to_bytes(tree)==var_to_bytes(reference),"complete native/reference tree bytes exact "+str(i)+" "+byte_difference(tree,reference))
			check(var_to_bytes(tree)==var_to_bytes(unprepared),"complete prepared/reconstructed tree bytes exact "+str(i))
			var actual=snapshot(tree)
			check(var_to_bytes(actual)==var_to_bytes(expected),"complete original raw header/clock/status bytes exact "+str(i))
			for key in actual:check(actual[key]==expected[key],"original "+str(i)+"/"+key+" actual "+str(actual[key])+" expected "+str(expected[key]))
			check(var_to_bytes(definition)==definition_before,"raw header does not mutate shared imported definition")
			pairs+=1
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"failures":failures,"original_cases":data.cases.size(),"metadata_context_pairs":pairs,"scope":"Unchanged original PS.Update912 bytes on supplied empty roots, no Emit/child/resource/room/physics/GPU/audio. Exact raw seconds header, clock, rate, delay, first-release, release clock and active count compare across one-bit boundaries, supplied delays/time scales/deltas and zero/subnormal contexts. Native/reference and prepared/reconstructed complete tree bytes match; independent raw header never mutates imported metadata. Full retained cloud/Simulation integration remains separate."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)

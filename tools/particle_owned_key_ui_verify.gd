extends SceneTree
var checks=0
var failures=[]
func _initialize():
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func normalize(value):
	if value is Dictionary:
		var out={}
		for key in value:out[key]=normalize(value[key])
		return out
	if value is Array:
		var out=[]
		for item in value:out.append(normalize(item))
		return out
	if value is Object:
		return {"class":value.get_class(),"resource_path":value.resource_path if value is Resource else ""}
	return value
func check(ok:bool,label:String):
	checks+=1
	if not ok and failures.size()<20:failures.append(label)
func run():
	var capture="--capture-r146-baseline" in OS.get_cmdline_user_args()
	var content=root.get_node("Content");var script=load("res://scripts/particle_state.gd")
	var baseline_path="res://../tests/reference/particle-owned-update-r146.json"
	var names=content.particles.systems.keys();names.sort();var rows=[];var supplied_fallback=[]
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);var fallback=ImageTexture.create_from_image(image)
	for prepared in [false,true]:
		for name in names:
			var state=script.new();state.reset();state.owned_prepared=prepared
			var d=content.particles.systems[name];var texture=content.tex(str(d.texture))
			if texture==null:
				texture=fallback
				if not str(name) in supplied_fallback:supplied_fallback.append(str(name))
			state.emit_definition(str(name),d,texture,Vector2(101.25,203.5),"","trace",-1,Vector2(.6,.8),-1,true)
			var sys=state.systems[0];var tree=sys.owned_tree;sys.retain_for_owner=true
			for frame in range(21):
				if frame>0:
					if frame==3:tree.delay_seconds=Vector2(.045,0).x
					if frame==7:tree.motion_limited=true;tree.motion_seconds=Vector2(.08,0).x
					if frame==10:tree.rate=0
					if frame==12:tree.rate=int(tree.backup_rate)
					if frame==15:SpiceNative.owned_particle_restart(tree)
					var dt=[.0,.001,.01667,.03,.1,.133333][frame%6]
					state.clock_seconds=Vector2(state.clock_seconds+Vector2(dt,0).x,0).x;state.clock_ms=state.clock_seconds*1000.0
					state.advance_owned_system(sys,dt)
				var payload=var_to_bytes(normalize(state.systems))
				rows.append({"name":str(name),"prepared":prepared,"frame":frame,"state_sha256":payload.hex_encode().sha256_text(),"rng":str(state.random.state),"owned_serial":state.owned_serial,"serial":state.serial})
			state.reset()
	var report={"definitions":names.size(),"rows":rows.size(),"failures":failures,"checks":checks,"scope":"Complete normalized dictionary bytes including key types/order, nested particle/child/pool fields and callbacks/RNG/serials versus frozen R146 helper. Texture objects normalize only to class/resource path.90supplied definitions, both prepared paths,21frames, delay/motion/stop/resume/restart/reuse. Missing original textures use an explicitly supplied16px texture, not new game content. This is behavior preservation, not original game/GPU equivalence."}
	if capture:
		check(not FileAccess.file_exists(baseline_path),"never replace baseline")
		if failures.is_empty():
			var f=FileAccess.open(baseline_path,FileAccess.WRITE);f.store_string(JSON.stringify({"native_r146_sha256":FileAccess.get_sha256("res://native/bin/libspice_hotpaths.dylib"),"definitions":names.size(),"supplied_fallback":supplied_fallback,"rows":rows},"\t"));f.close()
	else:
		var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/reference/particle-owned-update-r146-provenance.json"))
		check(FileAccess.get_sha256(baseline_path)==str(provenance.baseline_sha256),"immutable independently reproduced R146 baseline hash")
		var expected=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		check(names.size()==int(expected.definitions) and rows.size()==expected.rows.size(),"same complete baseline coverage")
		for i in mini(rows.size(),expected.rows.size()):
			for key in rows[i]:check(rows[i][key]==expected.rows[i][key],"R146 exact "+str(rows[i].name)+"/"+str(rows[i].frame)+"/"+str(key))
	report.checks=checks;report.failures=failures
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

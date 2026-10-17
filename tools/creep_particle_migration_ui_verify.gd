extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Freeze=preload("res://scripts/creep_freeze_view.gd")
const Death=preload("res://scripts/creep_death_view.gd")
var checks=0
var failures=[]
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<25:failures.append(label)
func normalize(value):
	if value is Dictionary:
		var out={}
		for key in value:out[key]=normalize(value[key])
		return out
	if value is Array:
		var out=[]
		for item in value:out.append(normalize(item))
		return out
	if value is Resource:return {"class":value.get_class(),"resource_path":value.resource_path}
	return value
func run() -> void:
	var content=root.get_node("Content");var profile=root.get_node("Profile")
	var baseline="";var capture="--capture-r151-baseline" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="):baseline=arg.trim_prefix("--baseline=")
	check(not baseline.is_empty(),"explicit immutable baseline path")
	if baseline.is_empty():quit(1);return
	var rows=[]
	for prepared in [false,true]:
		for number in range(1,11):
			var s=Sim.new();var c=content.mission("8").duplicate(true);c.waves=[]
			s.setup(content.catalog,content.maps[c.map],c,profile.fresh(),114,content.animations);s.spawn_hold=true
			var e=s.spawn_enemy(1,0,"",9001,false);s.particle_state.destroy_creep(e)
			e.def.filename="creep"+str(number);e.def.traits=content.catalog.resource_params["creeps/"+str(e.def.filename)]
			s.particle_state.initialize_creep(e,1);s.particle_state.owned_prepared=prepared
			e.hp=100;e.max_hp=100;e.speed=50;e.pos=Vector2(330.5,220.5);e.dir=Vector2(.6,.8)
			for frame in 50:
				if frame>0:
					var dt_ms=[0.0,1.0,16.667,30.0,100.0,133.333][frame%6]
					if frame==1:Freeze.use_freeze(e)
					if frame==5:
						for sys in e.particle_roots:sys.owned_tree.delay_seconds=Vector2(.04,0).x
					if frame==6:e.hp=30
					if frame==12:e.hp=100
					if frame==18:e.state=3;e.hp=0;s.particle_state.begin_creep_death(e,e.pos)
					if frame in [22,25]:
						for sys in e.particle_roots:sys.owned_tree.wind_enabled=frame==25
					if int(e.state)==3:
						s.particle_state.stop_creep_smoke(e)
						e.state=Death.tail(3,null,e.particle_roots.map(func(sys):return sys.particles.size()),[],dt_ms).state
					elif int(e.state)!=2:
						e.slow_pending=.5 if frame in [4,9] else -1.0
						Freeze.advance_fields(e,dt_ms,1000 if frame<9 else 0);s.particle_state.refresh_creep(s,e)
					s.particle_state.update_creep_fields(e,e.pos,e.dir)
					s.particle_state.advance_creep(e,dt_ms)
				if frame==49:s.particle_state.destroy_creep(e)
				var fields={}
				for key in ["state","hp","freeze_attached","freeze_remaining","freeze_auxiliary_value","smoke_work_interval","smoke_base_interval","smoke_max_multiplier","smoke_rate","smoke_color_flag"]:fields[key]=e.get(key)
				var bytes=var_to_bytes(normalize({"actor_fields":fields,"systems":s.particle_state.systems}))
				rows.append({"resource":str(e.def.filename),"prepared":prepared,"frame":frame,"state_sha256":bytes.hex_encode().sha256_text(),"rng":str(s.particle_state.random.state),"serial":s.particle_state.serial,"owned_serial":s.particle_state.owned_serial})
	var report={"checks":checks,"rows":rows.size(),"failures":failures,"scope":"R151 behavior preservation, not original game parity. Complete normalized native system/actor field bytes preserve key types/order/numeric bits plus RNG/serials; only texture objects become class/path.10supplied resources/both prepared paths/50frames, constructor/freeze/slow/damage/heal/delay/wind/SetDie child bursts/pools/final destruction. Original caller/manager/GPU remain separate."}
	if capture:
		check(not FileAccess.file_exists(baseline),"never replace immutable R151 baseline")
		if failures.is_empty():
			var f=FileAccess.open(baseline,FileAccess.WRITE);f.store_string(JSON.stringify({"rows":rows,"native_helper_sha256":FileAccess.get_sha256("res://native/bin/libspice_hotpaths.dylib")},"\t"));f.close()
	else:
		var provenance=JSON.parse_string(FileAccess.get_file_as_string(baseline.get_basename()+"-provenance.json"))
		check(FileAccess.get_sha256(baseline)==str(provenance.baseline_sha256),"immutable independently reproduced frozen R151 baseline")
		var expected=JSON.parse_string(FileAccess.get_file_as_string(baseline))
		check(rows.size()==expected.rows.size(),"same complete migration coverage")
		for i in mini(rows.size(),expected.rows.size()):
			for key in rows[i]:check(rows[i][key]==expected.rows[i][key],"R151 exact "+str(rows[i].resource)+"/"+str(rows[i].prepared)+"/"+str(rows[i].frame)+"/"+str(key))
	report.checks=checks;report.failures=failures;print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

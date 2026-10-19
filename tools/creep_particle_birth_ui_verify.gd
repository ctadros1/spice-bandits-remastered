extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Freeze=preload("res://scripts/creep_freeze_view.gd")
const Death=preload("res://scripts/creep_death_view.gd")
var checks=0
var failures=[]
var content
func _initialize() -> void:
	create_timer(60).timeout.connect(func():quit(1));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<40:failures.append(label)
func bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)
func numeric_state(value):
	# Scalar/native helpers use String and StringName keys differently. Compare
	# every numeric bit and nested value; the immutable R146 gate separately
	# preserves the native dictionary key types/order and RNG/serial sequence.
	if value is Dictionary:
		var out={};var names=[]
		for key in value:names.append(str(key))
		names.sort()
		for name in names:out[name]=numeric_state(value[name])
		return out
	if value is Array:
		var out=[]
		for item in value:out.append(numeric_state(item))
		return out
	if value is Resource:return {"class":value.get_class(),"path":value.resource_path}
	return value
func make_sim():
	var s=Sim.new();var c=content.mission("8").duplicate(true);c.waves=[]
	s.setup(content.catalog,content.maps[c.map],c,root.get_node("Profile").fresh(),114,content.animations)
	s.spawn_hold=true;s.clock_ms=1000
	return s
func compare_owner_fields(state,e:Dictionary,row:Dictionary,label:String) -> void:
	check(bits(e.smoke_work_interval)==int(row.smoke_work_interval_bits),label+" smoke work interval")
	for k in 2:
		var sys=e.particle_roots[k];var t=sys.owned_tree;var x=row.roots[k]
		check(int(t.rate)==int(x.rate),label+" owner rate")
		check(bits(float(t.get("interval_seconds",t.definition.release_interval)))==int(x.interval_bits),label+" owner interval")
		for j in 3:check(bits(t.definition.color[j])==int(x.rgb_bits[j]),label+" owner RGB")
		for j in 2:check(bits(sys.pos[j])==int(x.position_bits[j]),label+" original bound position")
func owner_fields() -> void:
	var s=make_sim()
	if not s.particle_state.has_method("update_creep_fields"):
		check(false,"missing full original UpdateParticles owner fields");return
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-particle-owner-reference.json"))
	for c in fixture.cases:
		var a=c.input;var e={"state":int(a.state),"hp":float(a.hp),"max_hp":100,"smoke_work_interval":0.111,"smoke_base_interval":float(a.interval),"smoke_max_multiplier":float(a.multiplier),"smoke_rate":7,"smoke_color_flag":bool(a.enabled),"particle_roots":[]}
		for k in 2:
			var x=c.before.roots[k]
			var tree={"definition":{"color":[.25,.5,.75,1],"release_interval":.3},"rate":int(x.rate),"backup_rate":int(x.backup_rate)}
			tree.interval_seconds=PackedByteArray(PackedInt32Array([int(x.interval_bits)]).to_byte_array()).decode_float(0)
			e.particle_roots.append({"creep_alias":"smoke" if k==0 and a.smoke else "other","owned_tree":tree,"creep_binding":{"offsetX":3 if k==0 else -6,"offsetY":4 if k==0 else 8,"emitt_on_walking":bool(a.moving[k])},"pos":Vector2.ZERO})
		s.particle_state.update_creep_fields(e,Vector2(330.5,220.5),Vector2(.6,.8),bool(a.heavy))
		compare_owner_fields(s.particle_state,e,c.after,"original owner "+str(a))
func birth_tail() -> void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-owner-birth-tail-reference.json"))
	for c in fixture.cases:
		var s=make_sim();var e=s.spawn_enemy(1,0,"",9001,false)
		s.particle_state.destroy_creep(e);e.def.filename=str(c.resource).trim_prefix("creeps/");e.def.traits=content.catalog.resource_params[c.resource]
		if not s.particle_state.has_method("initialize_creep"):continue
		s.particle_state.initialize_creep(e,1);e.hp=100;e.max_hp=100;e.speed=0
		# Same explicit header subset as the original R150 execution. This
		# comparison covers chronology/counts, not authored trajectories.
		for sys in e.particle_roots:
			var old=sys.definition;var d={"texture_list":[],"variations":{},"time_scale":1,"velocity_var":0,"velocity":[0,0],"source_sha256":"supplied-r150-header","name":str(c.resource)+"/"+str(sys.creep_alias)}
			for key in ["max_particles","num_release","release_interval","life_cycle","size","color","rot_speed"]:d[key]=old.get(key,0)
			sys.definition=d;sys.owned_tree.definition=d;sys.owned_tree.native_coefficients=SpiceNative.compile_particle(d)
		Freeze.use_freeze(e)
		for sys in e.particle_roots:
			if str(sys.creep_alias)=="freeze":sys.owned_tree.rate=int(e.freeze_auxiliary_value)
		for row in c.frames:
			if int(row.frame)>0:
				if int(row.frame)==21:e.hp=30
				if int(row.frame)==40:e.hp=100
				if int(row.frame)==41:e.state=3
				if int(e.state)==3:
					for sys in e.particle_roots:
						if str(sys.creep_alias)=="smoke":sys.owned_tree.rate=0
					e.state=Death.tail(3,null,e.particle_roots.map(func(sys):return sys.particles.size()),[],float(c.dt_ms)).state
				else:
					Freeze.advance_fields(e,float(c.dt_ms),int(row.counter));s.particle_state.refresh_creep(s,e)
				# R150 retains the original binary's initialized heavy-disable byte1.
				# R148 independently crosses both values; live setting is separate.
				if s.particle_state.has_method("update_creep_fields"):s.particle_state.update_creep_fields(e,e.pos,e.dir,true)
				s.particle_state.advance_creep(e,float(c.dt_ms))
			check(int(e.state)==int(row.state),"original birth-tail state "+str(c.resource)+"/"+str(row.frame))
			for x in row.roots:
				var roots=e.particle_roots.filter(func(sys):return str(sys.creep_alias)==str(x.alias))
				check(roots.size()==1,"original birth-tail mapped root")
				if roots.size()!=1:continue
				var t=roots[0].owned_tree;var label=str(c.resource)+"/"+str(c.dt_ms)+"/"+str(row.frame)+"/"+str(x.alias)
				check(t.particles.size()==int(x.active) and t.pool.size()==int(x.pool_size),label+" actual active/pool counts")
				check(bits(t.clock_seconds)==int(x.clock_bits) and bits(t.release_seconds)==int(x.release_bits),label+" exact clock/release bits")
				check(int(t.rate)==int(x.rate) and int(t.first_release)==int(x.first_release),label+" actual rate/first release")
				check(t.particles.map(func(p):return bits(p.born_seconds))==x.active_birth_bits.map(func(v):return int(v)),label+" exact ordered parent births")
		s.particle_state.destroy_creep(e)
func transformed_headers() -> void:
	var before=var_to_bytes(content.particles)
	for number in range(1,11):
		var sims=[make_sim(),make_sim()];var actors=[]
		for s in sims:
			var e=s.spawn_enemy(1,0,"",9001,false);s.particle_state.destroy_creep(e)
			e.def.filename="creep"+str(number);e.def.traits=content.catalog.resource_params["creeps/"+str(e.def.filename)]
			s.particle_state.initialize_creep(e,1);e.hp=30;e.max_hp=100
			actors.append(e)
		sims[1].particle_state.reference_emission=true
		for sys in actors[0].particle_roots:
			check(int(sys.owned_tree.native_coefficients)!=SpiceNative.compile_particle(content.particles.systems[sys.name]),"transformed private header never reuses base coefficients")
		for frame in 100:
			for k in 2:
				var e=actors[k];var state=sims[k].particle_state
				state.update_creep_fields(e,Vector2(330.5,220.5),Vector2(.6,.8))
				state.advance_creep(e,30)
			check(var_to_bytes(numeric_state(sims[0].particle_state.systems))==var_to_bytes(numeric_state(sims[1].particle_state.systems)),"complete transformed native/reference numeric fields resource"+str(number)+" frame"+str(frame))
			check(sims[0].particle_state.random.state==sims[1].particle_state.random.state and sims[0].particle_state.owned_serial==sims[1].particle_state.owned_serial,"transformed native/reference RNG and serial")
		for k in 2:sims[k].particle_state.destroy_creep(actors[k])
	check(before==var_to_bytes(content.particles),"all authored particle templates immutable")
func map_themes() -> void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-map-theme-reference.json"))
	var theme=load("res://scripts/map_theme.gd") if FileAccess.file_exists("res://scripts/map_theme.gd") else null
	check(theme!=null,"missing original map theme selector")
	if theme!=null:
		for row in fixture.cases:check(theme.selector(row.input)==int(row.selector),"full original theme exact string mapping")
	var type=-1
	for i in content.catalog.tower_creeps.size():
		if str(content.catalog.tower_creeps[i].get("filename",""))=="creep5":type=i;break
	check(type>0,"preserved hover resource has populated catalog entry")
	if type<0:return
	for row in fixture.preserved_imported_maps:
		var s=make_sim();s.map=s.map.duplicate(true);s.map.theme=content.maps[row.map].get("theme")
		var e=s.spawn_enemy(type,0,"",9001,false)
		var roots=e.particle_roots.filter(func(sys):return str(sys.creep_alias) in ["hover_flow","hover_flow2"])
		check(roots.size()==2,"actual hover roots for imported map "+str(row.map))
		for sys in roots:
			var original=content.particles.systems[sys.name].color
			for k in 3:check(bits(sys.definition.color[k])==bits(1 if int(row.selector)==1 else original[k]),"actual constructor theme RGB "+str(row.map))
		s.particle_state.destroy_creep(e)
func run() -> void:
	content=root.get_node("Content")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-particle-constructor-reference.json"))
	for c in fixture.cases:
		var s=make_sim();var type=-1
		for i in content.catalog.tower_creeps.size():
			if str(content.catalog.tower_creeps[i].get("filename",""))==str(c.resource).trim_prefix("creeps/"):type=i;break
		var supplied=type<0
		var e=s.spawn_enemy(1 if supplied else type,0,"",9001,false)
		var expected_aliases=c.roots.map(func(r):return str(r.alias))
		if not supplied:
			check(e.get("particle_roots",[]).map(func(r):return str(r.creep_alias))==expected_aliases,"actual spawn constructs empty sorted roots "+str(c.resource))
		# Explicit raw map selector, independent of unresolved live map producer.
		# Resource7 is preserved but absent from the populated offline catalog.
		if s.particle_state.has_method("initialize_creep"):
			s.particle_state.destroy_creep(e)
			e.def.filename=str(c.resource).trim_prefix("creeps/")
			e.def.traits=content.catalog.resource_params[c.resource]
			s.particle_state.initialize_creep(e,int(c.map_field8))
		var roots:Array=e.get("particle_roots",[])
		check(roots.size()==c.roots.size(),"supplied constructor root count "+str(c.resource))
		for pair in [["smoke_work_interval","smoke_work_interval_bits"],["smoke_base_interval","smoke_base_interval_bits"],["smoke_max_multiplier","smoke_max_multiplier_bits"]]:
			check(bits(float(e[pair[0]]))==int(c.owner_fields[pair[1]]),"original constructor owner field "+str(c.resource)+"/"+str(pair[0]))
		check(int(e.smoke_rate)==int(c.owner_fields.smoke_rate),"original constructor owner smoke rate")
		check(int(e.smoke_color_flag)==int(c.owner_fields.smoke_color_flag),"original constructor owner smoke color selector")
		for x in c.roots:
			var matching=roots.filter(func(r):return str(r.creep_alias)==str(x.alias))
			check(matching.size()==1,"mapped owner alias "+str(c.resource)+"/"+str(x.alias))
			if matching.size()!=1:continue
			var sys=matching[0];var t=sys.owned_tree;var d=t.definition
			check(t.particles.is_empty() and t.pool.is_empty(),"constructor never Emits "+str(x.alias))
			for pair in [["clock_seconds","clock_bits"],["release_seconds","release_bits"],["delay_seconds","delay_bits"]]:
				check(bits(t[pair[0]])==int(x[pair[1]]),"zero constructor "+str(pair[0]))
			check(int(t.rate)==int(x.rate) and int(t.backup_rate)==int(x.backup_rate),"original constructor rates "+str(x.alias))
			check(int(t.first_release)==int(x.first_release),"original first-release flag")
			for pair in [["life_cycle","life_bits"],["size","size_bits"],["release_interval","interval_bits"],["velocity_var","velocity_var_bits"],["rot_speed","rotation_speed_bits"]]:
				check(bits(float(d.get(pair[0],0)))==int(x[pair[1]]),"original transformed "+str(c.resource)+"/"+str(x.alias)+"/"+str(pair[0]))
			for k in 3:check(bits(d.color[k])==int(x.rgb_bits[k]),"original constructor RGB")
			check(bits(d.color[3])==int(x.alpha_bits),"original constructor alpha")
		s.particle_state.destroy_creep(e)
	owner_fields();birth_tail();transformed_headers();map_themes()
	# ProcessSpeed must also turn on the existing freeze alias for consumed slow.
	for reference in [true,false]:
		var e={"grow_ms":400,"speed":1000,"slow_pending":.6,"freeze_auxiliary_present":true,"freeze_auxiliary_value":17}
		if reference:Freeze.reference_fields(e,30,0)
		else:Freeze.advance_fields(e,30,0)
		check(e.freeze_auxiliary_value==1,"original ProcessSpeed consumed-slow rate in actual field bridge")
	var report={"checks":checks,"failures":failures,"original_constructor_cases":fixture.cases.size(),"owner_cases":720,"birth_tail_sequences":30,"scope":"Actual spawn, supplied R149 constructor fields, R148 UpdateParticles fields and R150 shared owner methods with identical explicit header subset. Raw map selector supplied; full manager/trajectories/parser/GPU remain open."}
	var f=FileAccess.open("res://../builds/creep-particle-birth-r151-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

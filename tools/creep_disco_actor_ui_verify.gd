extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failure_count=0
var failures=[]
func _initialize() -> void:
	create_timer(60).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failure_count+=1
		if failures.size()<30:failures.append(label)
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func run() -> void:
	var content=root.get_node("Content")
	var before=var_to_bytes(content.particles)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-disco-emission-reference.json"))
	for c in fixture.cases:
		var s=Sim.new();var config=content.mission("8").duplicate(true);config.waves=[]
		s.setup(content.catalog.duplicate(true),content.maps[config.map],config,root.get_node("Profile").fresh(),114,content.animations)
		s.spawn_hold=true;s.clock_ms=1000;s.abilities.m_lsd=1;s.catalog.tower_magic.lsd_duration=600
		var e=s.spawn_enemy(1,0,"",9001,false);s.particle_state.destroy_creep(e)
		e.def.filename=str(c.resource).get_file();e.def.traits=content.catalog.resource_params[c.resource];e.hp=100;e.max_hp=100;e.speed=0
		s.particle_state.initialize_creep(e,1)
		# Same explicitly selected headers as the R150/R159 probe. Particle
		# trajectories and unrelated roots are outside this comparison.
		for sys in e.particle_roots:
			var old=sys.definition;var d={"texture_list":[],"variations":{},"time_scale":1,"velocity_var":0,"velocity":[0,0],"source_sha256":"supplied-r159-header","name":str(c.resource)+"/"+str(sys.creep_alias)}
			for key in ["max_particles","num_release","release_interval","life_cycle","size","color","rot_speed"]:d[key]=old.get(key,0)
			sys.definition=d;sys.owned_tree.definition=d;sys.owned_tree.native_coefficients=SpiceNative.compile_particle(d)
		check(s.use_ability("m_lsd").is_empty(),"actual Disco activation "+str(c.resource))
		for row in c.frames:
			if int(row.frame)>0:s.advance_frame(float(c.delta))
			var label=str(c.resource)+"/"+str(c.delta)+"/"+str(row.frame)
			check(int(e.state)==int(row.state),label+" original actor state")
			check(maxi(0,s.disco_until-s.clock_ms)==int(row.counter),label+" original shared counter")
			check(bool(e.get("disco_attached",false))==bool(row.timer_attached),label+" actual timer attachment")
			var roots=e.particle_roots.filter(func(sys):return str(sys.creep_alias)=="lsd")
			check(roots.size()==1,label+" actual constructor alias")
			if roots.size()!=1:continue
			var x=row.roots.filter(func(r):return r.alias=="lsd")[0];var t=roots[0].owned_tree
			check(t.particles.size()==int(x.active) and t.pool.size()==int(x.pool_size),label+" active/pool counts")
			check(bits(t.clock_seconds)==int(x.clock_bits) and bits(t.release_seconds)==int(x.release_bits),label+" exact clock/release bits")
			check(int(t.rate)==int(x.rate) and int(t.first_release)==int(x.first_release),label+" actual rate/first release")
			check(t.particles.map(func(p):return bits(p.born_seconds))==x.active_birth_bits.map(func(v):return int(v)),label+" exact ordered particle births")
		s.particle_state.destroy_creep(e)
	check(before==var_to_bytes(content.particles),"preserved authored particle templates unchanged")
	var report={"checks":checks,"failure_count":failure_count,"failures":failures,"cases":fixture.cases.size(),"scope":"Actual simulation activation/actor state/shared timer/LSD alias chronology on original selected headers. No complete pathfinder/trajectories/GPU parity."}
	var f=FileAccess.open("res://../builds/creep-disco-actor-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("CREEP_DISCO_ACTOR ",JSON.stringify(report));quit(1 if failure_count else 0)

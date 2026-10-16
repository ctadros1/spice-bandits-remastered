extends SceneTree
var checks=0
var failures=[]
var output="res://../builds/particle-life-verification.json"
var explicit_output=false
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--life-proof-output="):
			output=arg.trim_prefix("--life-proof-output=");explicit_output=true
	create_timer(30).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func run():
	assert(not explicit_output or not FileAccess.file_exists(output))
	var content=root.get_node("Content")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-particle-life-reference.json"))
	check(FileAccess.get_sha256("res://data/particles.json")==fixture.content_sha256,"fixture authored content hash")
	var cases=0
	for name in content.particles.systems:
		var definition=content.particles.systems[name]
		var life_bits=PackedFloat32Array([float(definition.get("life_cycle",1))]).to_byte_array().decode_u32(0)
		var rows=fixture.cases.filter(func(c):return int(c.life_bits)==life_bits)
		check(rows.size()==3,"all below/exact/above original boundaries available for "+str(name))
		for c in rows:
			cases+=1
			var age=PackedInt32Array([int(c.age_bits)]).to_byte_array().decode_float(0)
			var clock=age*1000.0
			check(PackedFloat32Array([clock/1000.0]).to_byte_array().decode_u32(0)==int(c.output.clock_bits),"exact supplied original clock "+str(name))
			var p={"pos":Vector2(100,200),"velocity":Vector2(10,-70),"rotation":0.5,"rot_speed":3.0,"alpha":0.0,"born":0.0,"child_released":0.0}
			var direct=[p.duplicate(true)]
			SpiceNative.update_particles(direct,definition,0.0,clock)
			check(direct.size()==int(c.output.active),"direct native life boundary "+str(name)+" agebits"+str(c.age_bits))
			var sys={"id":1,"definition":definition,"native_coefficients":SpiceNative.compile_particle(definition),"born":0.0,"until":0.0,"released":0.0,"emitting":false,"particles":[p.duplicate(true)],"phase":0.0,"variation":""}
			var systems=[sys]
			SpiceNative.advance_systems(systems,clock,func(_n,_p,_v):pass,func(_s):pass,null,0.0)
			check(sys.particles.size()==int(c.output.active),"cached system life boundary "+str(name)+" agebits"+str(c.age_bits))
			check(systems.size()==int(c.output.active),"expired system removal follows original active count "+str(name))
	var report={"checks":checks,"cases":cases,"authored_systems":content.particles.systems.size(),"original_boundary_cases":fixture.cases.size(),"failures":failures,"passed":failures.is_empty(),"scope":"All authored definitions use independent original one-bit below/exact/above lifetime boundaries. Actual direct native integration and cached system path compare active count/removal; exact input clock bits mandatory. Child callbacks omitted as in supplied oracle; no original trajectories, whole owners/room, RNG or GPU acceptance."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("PARTICLE_LIFE ",JSON.stringify(report));quit(0 if report.passed else 1)

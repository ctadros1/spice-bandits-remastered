extends SceneTree
var checks=0
var clock_checks=0
var clock_failures=0
var count_checks=0
var count_failures=0
var geometry_checks=0
var geometry_failures=0
var examples=[]
var output="res://../builds/particle-local-clock-verification.json"
var explicit_output=false
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clock-proof-output="):
			output=arg.trim_prefix("--clock-proof-output=");explicit_output=true
	create_timer(45).timeout.connect(func():quit(2));run.call_deferred()
func run():
	assert(not output.is_empty() and (not explicit_output or not FileAccess.file_exists(output)))
	var fx_script=load("res://scripts/particle_fx.gd")
	var math_script=load("res://scripts/particle_math.gd")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-death-tail-reference.json"))
	var zero_geometry={}
	var cases=0
	for birth in [0.0,1.234,30.0,300.0,3000.0]:
		for case_index in range(fixture.cases.size()):
			var c=fixture.cases[case_index];cases+=1
			var fx=fx_script.new();fx.random.seed=114;fx.clock_seconds=Vector2(birth,0).x;fx.clock_ms=fx.clock_seconds*1000.0
			fx.emit_creep_death_burst(str(c.resource),Vector2(333.25,219.75))
			var parents=fx.systems.duplicate();assert(parents.size()==c.frames[0].output.systems.size())
			var dt=Vector2(Vector2(float(c.dt_ms),0).x*Vector2(.001,0).x,0).x
			var previous_counts=[]
			for row in c.frames:
				if int(row.frame)>0:
					fx.clock_seconds=Vector2(fx.clock_seconds+dt,0).x;fx.clock_ms=fx.clock_seconds*1000.0
					# The original supplied tail deliberately has no child pointers.
					SpiceNative.advance_systems(fx.systems,fx.clock_ms,func(_n,_p,_v):pass,fx.emit_batch,fx.random,dt)
				for i in range(parents.size()):
					var parent=parents[i];var original=row.output.systems[i];assert(parent.name==original.name)
					count_checks+=1
					if parent.particles.size()!=int(original.active):count_failures+=1
					# ParticleFX removes empty parents immediately. Original owner
					# retention updates them longer; that remains a separate gap.
					# Never skip a count row, or use actual counts to select clocks.
					if int(row.frame)==0 or previous_counts[i]>0:
						var clock=float(parent.get("view_clock_ms",fx.clock_ms));var age=math_script.age(clock,float(parent.born))
						var bits=PackedFloat32Array([age]).to_byte_array().decode_u32(0);clock_checks+=1
						if bits!=int(original.clock_bits):
							clock_failures+=1
							if examples.size()<8:examples.append({"birth_seconds":birth,"resource":c.resource,"dt_ms":c.dt_ms,"frame":row.frame,"system":parent.name,"actual_age_bits":bits,"original_clock_bits":original.clock_bits})
				previous_counts=row.output.systems.map(func(s):return int(s.active))
				for premultiplied in [false,true]:
					var geometry=var_to_bytes(SpiceNative.particle_batches(parents,premultiplied,fx.clock_ms,Vector2.ZERO,1.0,true,false))
					var key="%d:%d:%s"%[case_index,int(row.frame),str(premultiplied)]
					if birth==0:zero_geometry[key]=geometry
					else:
						geometry_checks+=1
						if geometry!=zero_geometry[key]:geometry_failures+=1
			fx.free()
		await process_frame
	checks=clock_checks+count_checks+geometry_checks
	var report={"checks":checks,"cases":cases,"clock_checks":clock_checks,"clock_failures":clock_failures,"count_checks":count_checks,"count_failures":count_failures,"geometry_checks":geometry_checks,"geometry_failures":geometry_failures,"examples":examples,"passed":clock_failures==0 and count_failures==0 and geometry_failures==0,"scope":"Actual death bursts at five room birth times versus unchanged independent original local-clock bits while live/on removal update, and ALL original parent-count rows. Exact geometry bytes must equal the same zero-birth case with identical isolated RNG. Original supplied oracle omits child pointers and supplies parent-count/clock expectations. Current native path additionally runs owned children; geometry invariance now includes them. Empty-system retention/owner lifetime, original random stream, caller/update chronology, whole owner scheduling and GPU remain separate gaps."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("PARTICLE_LOCAL_CLOCK ",JSON.stringify(report));quit(0 if report.passed else 1)

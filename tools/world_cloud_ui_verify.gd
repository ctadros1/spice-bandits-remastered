extends SceneTree
const View=preload("res://scripts/world_cloud_math.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-world-cloud-reference.json")))
	for i in range(View.GENERATORS.size()):
		var source=View.setup_record(View.GENERATORS[i]);var expected=original.generators[i]
		for key in ["position","radius","lifetime_ms","rate","capacity","color_override","color_gain"]:check(source[key]==expected[key],"original generator "+key)
		var ctor=original.constructors[i].result
		check(ctor.initial_productions.size()==50,"original constructor precreates50 systems")
		check(ctor.initial_productions.all(func(p):return p.initial==1 and not p.color_override and p.gain==1),"initial clouds precede the caller color override")
		check(View.particle_step(source.rate,1.0)==View.f32(ctor.particle_dt_per_ms),"original generator clock scale")
	for case in original.cases:
		var actual=View.produce(case.generator,Vector2(case.direction[0],case.direction[1]),int(case.random_radius),case.clock_ratio,bool(case.initial))
		for k in range(2):check(actual.position[k]==View.f32(case.result.position[k]),"original cloud emitter coordinate")
		for k in range(4):check(actual.color[k]==View.f32(case.result.color[k]),"original cloud color override")
		for key in ["emission_seconds","clock_ratio","initial_emits","generator_spawn_timer"]:check(actual[key]==case.result[key],"original cloud "+key)
	for case in original.visibility:
		var visible=[]
		for i in range(View.GENERATORS.size()):
			if View.intersects(View.GENERATORS[i],case.zoom,Vector2(case.origin[0],case.origin[1]),Vector2(case.size[0],case.size[1])):visible.append(i)
		check(visible==case.visible.map(func(i):return int(i)),"original viewport cloud culling")
	for case in original.updates:
		var timer=0.0
		for frame in case.frames:
			var step=View.spawn_step(timer,int(case.count),int(case.generator.capacity),frame.dt_ms);timer=step.timer
			check(timer==View.f32(frame.spawn_timer),"original generator spawn clock/reset")
			check(step.spawn==(frame.productions.size()==1),"original single spawn/capacity threshold")
			for dt in frame.particle_steps:check(View.particle_step(case.generator.rate,frame.dt_ms)==View.f32(dt),"original particle timestep")
	for case in original.expiry:
		var count=int(case.count);var timer=0.0
		for frame in case.frames:
			var step=View.spawn_step(timer,count,int(case.generator.capacity),frame.dt_ms);timer=step.timer
			check(step.spawn==(frame.productions.size()==1),"original capacity check precedes dead-system removal")
			check(timer==View.f32(frame.spawn_timer),"original expiry/spawn timer order")
			check(int(frame.remaining_systems)==int(case.count)-1,"original removes the already-dead system before updating it")
			count=int(frame.remaining_systems)
	var report={"checks":checks,"failures":failures,"method":"Original AddClouds/ProduceCloud/constructor/generator update/RenderClouds arithmetic and branches. Particle calls, allocation, RNG, insertion, OpenGL and whole scene are stubs; full particles/raster are separate reconstructed-runtime checks."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/world-cloud-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WORLD_CLOUD_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

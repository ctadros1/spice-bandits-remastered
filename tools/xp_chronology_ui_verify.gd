extends SceneTree
const Emitter=preload("res://scripts/xp_emitter_view.gd")
class ParticleApp extends Node:
	func view_size() -> Vector2:return Vector2(1024,768)
	func record_qa_time(_name:String,_started:int) -> void:pass
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-xp-chronology-reference.json")))
	var content=root.get_node("Content")
	var original=content.particles.systems.XpBarGrow
	var original_copy=original.duplicate(true)
	var app=ParticleApp.new()
	var frames=0
	for case in reference.cases:
		var particles=load("res://scripts/particle_fx.gd").new();particles.app=app
		var previous=Vector2(522,456)
		for frame in case.frames:
			if frame.events.any(func(e):return e.method=="factory"):Emitter.create(particles,original,content.tex(original.texture))
			check(particles.systems.size()==1,"original keeps one XP system, including zero/quiet/resumed phases")
			particles.advance_ui(float(case.dt_ms))
			var system=particles.systems[0]
			check(system.particles.size()==int(frame.active),"original active particle count "+str(case.pattern)+" frame"+str(frame.frame))
			check(particles.clock_seconds==Vector2(frame.system_clock,0).x,"original per-system clock")
			check(Vector2(float(system.released)/1000,0).x==Vector2(frame.last_release,0).x,"original release clock advances for count0 as well as count2")
			var born=system.particles.filter(func(p):return p.born==particles.clock_ms)
			var emissions=frame.events.filter(func(e):return e.method=="emit" and e.count>0)
			if emissions.is_empty():check(born.is_empty(),"no births before an enabled original update")
			else:
				var point=emissions[0].point
				check(born.all(func(p):return p.pos==Vector2(point[0],point[1])),"births retain the previous rendered bar tip")
			var tip=Vector2(frame.tip,456)
			Emitter.after_render(particles,previous,tip);previous=tip
			check(system.definition.num_release==int(frame.release_after_render),"float32 rendered X changes control the next release count")
			check(system.emitting,"idle zero-count emitter persists without generic particle cleanup changes")
			frames+=1
		particles.free()
	check(original==original_copy,"original particle definition remains unchanged")
	app.free()
	var report={"checks":checks,"failures":failures,"original_cases":reference.cases.size(),"frames":frames,"limit":"Supplied-tip chronology and actual particle counts/clocks; original rand0 differs from reconstruction RNG. No full resource loader, Open, GPU or original pixels."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/xp-chronology-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("XP_CHRONOLOGY_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

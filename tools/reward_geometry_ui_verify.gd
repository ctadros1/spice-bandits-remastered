extends SceneTree
const RewardView=preload("res://scripts/reward_view.gd")
class FxCanvas extends Node2D:
	func view_size() -> Vector2:return Vector2(1024,768)
	func record_qa_time(_key:String,_started:int) -> void:pass
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-reward-geometry-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var draws=[];var bursts=[];var source=Vector2(case.source[0],case.source[1]);var origin=Vector2(case.origin[0],case.origin[1])
		for i in range(6):
			var pose=RewardView.medal(source,i,case.slot,RewardView.f32(case.fraction),origin,0.75)
			if i<=case.slot:
				draws.append({"rect":[pose.rect.position.x,pose.rect.position.y,pose.rect.size.x,pose.rect.size.y],"alpha":pose.alpha})
				if pose.burst and not case.already_shown:bursts.append({"point":[pose.burst_point.x,pose.burst_point.y],"release_interval_seconds":5.0,"clock_multiplier":RewardView.f32(1.6),"count":10})
		checks+=1
		if draws.size()!=case.output.draws.size():failures.append("draw count")
		for i in range(draws.size()):
			for j in range(4):
				checks+=1
				if draws[i].rect[j]!=RewardView.f32(case.output.draws[i].rect[j]):failures.append("rect")
			checks+=1
			if draws[i].alpha!=RewardView.f32(case.output.draws[i].alpha):failures.append("alpha")
		checks+=2
		if bursts.size()!=case.output.bursts.size() or bursts.size()!=case.output.booms:failures.append("burst count")
		for i in range(bursts.size()):
			for j in range(2):
				checks+=1
				if bursts[i].point[j]!=RewardView.f32(case.output.bursts[i].point[j]):failures.append("burst point")
			for key in ["release_interval_seconds","clock_multiplier","count"]:
				checks+=1
				if bursts[i][key]!=RewardView.f32(case.output.bursts[i][key]):failures.append("burst "+key)
	var particle_reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-reward-particle-reference.json")))
	var canvas=FxCanvas.new();root.add_child(canvas)
	var fx=load("res://scripts/particle_fx.gd").new();fx.app=canvas;canvas.add_child(fx);fx.clock_multiplier=RewardView.f32(1.6)
	for case in particle_reference.cases:
		fx.reset();fx.clock_seconds=RewardView.f32(case.age);fx.clock_ms=fx.clock_seconds*1000
		var definition={"name":"RewardClockProbe%f%d"%[case.life,case.wind],"life_cycle":case.life,"gravity":[0,30],"wind_enabled":bool(case.wind),"wind":[0,0]}
		var particle={"pos":Vector2(100,200),"velocity":Vector2(10,-70),"rotation":0.5,"rot_speed":3.0,"alpha":0.0,"born":0.0}
		var particles=[particle]
		fx.systems.append({"id":1,"definition":definition,"native_coefficients":SpiceNative.compile_particle(definition),"particles":particles,"emitting":false,"until":-1,"born":0,"released":0,"phase":0})
		fx.advance_ui(float(case.elapsed_ms))
		checks+=1
		if fx.clock_seconds!=RewardView.f32(case.clock):failures.append("particle scaled clock")
		if case.clock<case.life:
			var fields={"x":particle.pos.x,"y":particle.pos.y,"vx":particle.velocity.x,"vy":particle.velocity.y,"rotation":particle.rotation,"alpha":particle.alpha}
			for key in fields:
				checks+=1
				if fields[key]!=RewardView.f32(case[key]):failures.append("particle "+key)
		else:
			checks+=1
			if not particles.is_empty():failures.append("expired reward particle")
	canvas.free()
	var report={"checks":checks,"failures":failures,"method":original.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/reward-geometry-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("REWARD_GEOMETRY_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

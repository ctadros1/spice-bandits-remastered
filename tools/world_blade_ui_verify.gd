extends SceneTree
const View=preload("res://scripts/world_blade_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-world-blade-reference.json")))
	var checks=0;var failures=[]
	for case in original.renders:
		for i in range(View.POINTS.size()):
			var points=View.geometry(View.POINTS[i],Vector2(case.offset[0],case.offset[1]))
			for j in range(4):
				for k in range(2):
					checks+=1
					if points[j][k]!=View.f32(case.result.quads[i][j][k]):failures.append("original blade world quad")
	for case in original.updates:
		var angles=case.initial_angles.duplicate()
		for frame in case.frames:
			View.advance_angles(angles,case.speeds,float(frame.dt_ms))
			for i in range(angles.size()):
				checks+=1
				if angles[i]!=View.f32(frame.angles[i]):failures.append("original blade angle update")
	var report={"checks":checks,"failures":failures,"method":"60 original windmill quads plus12 original five-angle update frames; texture loader, unrelated UI/map calls, RNG and OpenGL are stubs. UV rotation and rasterizer remain a separate native capture check."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/world-blade-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WORLD_BLADE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

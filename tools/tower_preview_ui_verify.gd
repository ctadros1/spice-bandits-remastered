extends SceneTree
const Preview=preload("res://scripts/tower_preview_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-tower-preview-reference.json")))
	var checks=0;var failures=[]
	for case in original.animation_cases:
		var state=Preview.initial(case.count,case.speed,bool(case.loop),case.multiplier,case.divisor)
		for frame in case.frames:
			Preview.advance(state,float(frame.dt_ms))
			for key in ["frame","phase","stopped"]:
				checks+=1
				var expected=frame[key]
				if expected is float:expected=Preview.f32(expected)
				if state[key]!=expected:failures.append("preview "+key)
	for case in original.inactive_cases:
		var tint=Preview.tint(case.valid)
		checks+=1
		if Preview.f32(float(case.frame)*9)!=Preview.f32(case.output.angle):failures.append("retained facing")
		for i in range(4):
			checks+=1
			if tint[i]!=Preview.f32(case.output.tint[i]):failures.append("tint")
	var report={"checks":checks,"failures":failures,"method":original.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/tower-preview-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TOWER_PREVIEW_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

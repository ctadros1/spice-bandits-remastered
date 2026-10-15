extends SceneTree
const Wave=preload("res://scripts/wave_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-wave-collapse-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var state=Wave.initial_collapse(case.current)
		for frame in case.frames:
			Wave.advance_collapse(state,frame.dt_ms,case.current,frame.elapsed,case.delay,case.total)
			for key in frame.fields:
				checks+=1
				var expected=frame.fields[key]
				if expected is float:expected=Wave.f32(expected)
				if state[key]!=expected:failures.append("collapse "+key)
			var rows=Wave.rows(case.current,frame.elapsed,case.delay,case.total,null,60,state)
			checks+=1
			if rows.size()!=frame.text_draws.size():failures.append("collapse row count")
			for i in range(rows.size()):
				checks+=2
				if rows[i].x+35!=frame.text_draws[i].x or rows[i].number!=frame.text_draws[i].object:failures.append("collapse row")
	var report={"checks":checks,"failures":failures,"method":original.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/wave-collapse-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WAVE_COLLAPSE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
const Fade=preload("res://scripts/tutorial_fade.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-tutorial-fade-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var state=Fade.initial();var pending=false
		for frame in case.frames:
			Fade.advance_in(state,float(frame.dt_ms))
			pending=pending or frame.request
			var switched=false
			if pending and Fade.advance_out(state):state=Fade.initial();pending=false;switched=true
			for key in frame.state:
				checks+=1
				var expected=frame.state[key]
				if expected is float:expected=Fade.f32(expected)
				if state[key]!=expected:failures.append("tutorial fade "+key)
			checks+=2
			if switched!=frame.switched or pending!=frame.pending:failures.append("tutorial page swap order")
	var report={"checks":checks,"failures":failures,"method":"Original page/interface fade arithmetic/order; page swap and end-condition callback stubbed, no UIKit raster equivalence."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/tutorial-fade-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TUTORIAL_FADE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

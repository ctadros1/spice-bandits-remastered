extends SceneTree
const MagicPanel=preload("res://scripts/magic_panel_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-magic-panel-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var state=MagicPanel.initial(768,int(case.panel_height))
		for frame in case.frames:
			if frame.action is String:
				if frame.action=="open":MagicPanel.open(state)
				else:MagicPanel.close(state)
			else:MagicPanel.advance(state,float(frame.action))
			for key in frame.state:
				checks+=1
				var expected=frame.state[key]
				if expected is float:expected=MagicPanel.f32(expected)
				if state[key]!=expected:failures.append("native magic panel "+key)
	var report={"checks":checks,"failures":failures,"method":"Original panel flags/float32 slide/easing with explicit iPad bounds; no whole UIKit/framebuffer equivalence."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/magic-panel-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAGIC_PANEL_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

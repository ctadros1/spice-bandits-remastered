extends SceneTree
const ModeItem=preload("res://scripts/mode_item_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-mode-item-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var state=ModeItem.initial(bool(case.opened))
		for frame in case.frames:
			ModeItem.advance(state,float(frame.dt_ms),Vector2(360,369),Vector2(case.offset[0],case.offset[1]))
			for key in frame.state:
				checks+=1
				if state[key]!=ModeItem.f32(float(frame.state[key])):failures.append("mode item "+key)
	var report={"checks":checks,"failures":failures,"method":"Initial original animation block with explicit bounds; sinf, configuration/services and font updates outside comparison."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/mode-item-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MODE_ITEM_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

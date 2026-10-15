extends SceneTree
const View=preload("res://scripts/upgrade_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-upgrade-layout-reference.json")))
	if original==null:push_error("Original upgrade fixture is missing or invalid.");quit(1);return
	var checks=0;var failures=[]
	for item in original.tablet:
		var pose=View.tablet(int(item.index))
		for k in range(2):
			checks+=1
			if pose.position[k]!=item.position[k]:failures.append("original tablet grid position")
		for key in ["mirrored","panel_x","name_x","cost_x","description_x"]:
			checks+=1
			if pose[key]!=item[key]:failures.append("original upgrade panel "+key)
	for item in original.selection_scroll:
		var wanted=float(item.scroll) if item.actions.is_empty() else float(item.actions[-1][1])
		checks+=1
		if View.selection_scroll(item.row,item.scroll,item.height)!=wanted:failures.append("original upgrade selection scroll")
	var report={"checks":checks,"failures":failures,"method":original.method+" The20 tablet layout cases and144 tablet selection-scroll cases are compared; phone records are supplemental evidence, not a new UI."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/upgrade-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("UPGRADE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

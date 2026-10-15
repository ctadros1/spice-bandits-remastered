extends SceneTree
func _initialize():run.call_deferred()
func run():
	var checked=0;var failures=[]
	for name in DirAccess.get_files_at("res://scripts"):
		if not name.ends_with(".gd"):continue
		var script=load("res://scripts/"+name)
		checked+=1
		if script==null or not script.can_instantiate():failures.append(name)
	var report={"checked":checked,"failures":failures,"scope":"Parse and instantiate-eligibility check only. No runtime behavior or original-game equivalence."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/runtime-scripts-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RUNTIME_SCRIPTS_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
const View=preload("res://scripts/world_camera_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-world-camera-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var point=View.bound_origin(Vector2(case.origin[0],case.origin[1]),case.zoom,Vector2(case.size[0],case.size[1]))
		for i in range(2):
			checks+=1
			if point[i]!=case.result[i]:failures.append("original lobby camera bound")
	var report={"checks":checks,"failures":failures,"method":original.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/world-camera-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WORLD_CAMERA_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

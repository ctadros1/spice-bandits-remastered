extends SceneTree
const Math=preload("res://scripts/story_math.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-story-reference.json")))
	var checks=0;var failures=[]
	for sample in fixture.cases:
		var node=sample.initial.duplicate(true)
		for key in ["position","start","direction","end"]:node[key]=Vector2(node[key][0],node[key][1])
		for key in ["scale","phase","alpha","initial_alpha"]:node[key]=Math.f32(float(node[key]))
		Math.advance(node,float(sample.dt_ms))
		for key in ["phase","alpha","initial_alpha","fade_in","finished"]:
			checks+=1
			var expected=sample.result[key]
			if expected is float:expected=Math.f32(expected)
			if node[key]!=expected:failures.append("native story "+key)
		checks+=1
		if node.position.distance_to(Vector2(sample.result.position[0],sample.result.position[1]))>0.00001:failures.append("native story position")
	var report={"checks":checks,"failures":failures,"method":"Original ARM story node fade/position execution with explicit fields; no global random stream or framebuffer parity."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/story-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("STORY_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

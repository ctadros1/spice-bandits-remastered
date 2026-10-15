extends SceneTree
var Bolt
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	create_timer(30).timeout.connect(func():push_error("Bolt clock verification timed out.");quit(1))
	run.call_deferred()
func run() -> void:
	Bolt=load("res://scripts/bolt_view.gd")
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-bolt-clock-reference.json")))
	for case in reference.cases:
		var state=case.initial.duplicate(true)
		for key in ["age","fade","opacity"]:state[key]=Bolt.f32(state[key])
		for frame in case.frames:
			if frame.action is String:Bolt.reset_clock(state)
			else:Bolt.advance_clock(state,float(frame.action))
			for key in ["enabled","alive","age","fade","opacity"]:
				check(state[key]==(frame.state[key] if frame.state[key] is bool else Bolt.f32(frame.state[key])),"original Update/reset "+key)
	for case in reference.anchors:
		var center=Vector2(case.center[0],case.center[1])
		var source=Bolt.source_point(center)
		for i in range(2):check(source[i]==Bolt.f32(case.tower[i]),"original tower source is seven pixels above logical cell center")
		var resource=Vector2(case.resource_offset[0],case.resource_offset[1]);var animator=Vector2(case.animator_offset[0],case.animator_offset[1])
		var aim=(center+resource)+animator
		for i in range(2):check(aim[i]==Bolt.f32(case.aim[i]),"original creep aim adds resource and supplied animator offsets to drawn position")
	var report={"checks":checks,"failures":failures,"method":reference.method+" Source clock comparisons do not establish complete room/tower/substep scheduling or original sounds."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/bolt-clock-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOLT_CLOCK_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
const RewardClock=preload("res://scripts/reward_clock_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-reward-clock-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var clock=RewardClock.initial(float(case.initial_delay),int(case.initial_state))
		for frame in case.frames:
			RewardClock.advance(clock,float(frame.dt_ms))
			for key in frame.fields:
				checks+=1
				var expected=frame.fields[key]
				if expected is float:expected=RewardClock.f32(expected)
				if clock[key]!=expected:failures.append("reward clock "+key)
	var report={"checks":checks,"failures":failures,"method":"Original update arithmetic with explicit delay/open flags; constructor/Open/callback initialization, particles, sound and whole render omitted."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/reward-clock-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("REWARD_CLOCK_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func fields(actual:Dictionary,expected:Dictionary,label:String) -> void:
	for key in expected:
		var value=expected[key]
		if value is float:value=Vector2(value,0).x
		check(actual[key]==value,label+" "+key)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-result-lifecycle-reference.json")))
	var app=load("res://scripts/main.gd").new()
	app.sim=load("res://scripts/simulation.gd").new()
	for case in reference.lifecycle_cases:
		fields(app.RewardClockView.initial(0,3),case.constructor,"original full constructor clock")
		app.screen="game";app.sim.paused=false;app.sim.outcome="playing";app.result_closed_delay=0
		for i in range(int(case.closed_steps)):app.advance_closed_result_clock(float(case.dt_ms))
		check(app.result_closed_delay==Vector2(case.closed.delay,0).x,"original timer accumulates while result screen is closed")
		app.elapsed_ui=0;app.result_started=-1;app.result_clock={};app.result_clock_age=0
		app.sim.outcome="victory";app.sync_result_clock()
		check(app.result_initial_delay==app.result_closed_delay,"opening preserves executed closed delay")
		for frame in case.frames:
			app.elapsed_ui+=float(frame.dt_ms)/1000;app.sync_result_clock()
			fields(app.result_clock,frame.fields,"original open update with preserved delay")
		var preserved=app.result_closed_delay;app.advance_closed_result_clock(100)
		check(app.result_closed_delay==preserved,"resolved game does not double advance the closed timer")
	var original_room_calls=0
	for case in reference.room_cases:
		var active=not case.paused and case.enabled and case.ready
		check(case.calls.size()==int(active),"original room pause/enable/ready gate")
		check(Vector2(case.closed_delay,0).x==Vector2(0.030000001192092896 if active else 0,0).x,"original caller sends unscaled30ms at all three speeds")
		original_room_calls+=case.calls.size()
	for speed in [1,2,4]:
		app.screen="game";app.speed=speed;app.sim.outcome="playing";app.sim.paused=false;app.result_closed_delay=0
		app.advance_closed_result_clock(30)
		check(app.result_closed_delay==Vector2(0.030000001192092896,0).x,"Main closed timer is independent of game speed")
		app.sim.paused=true;app.advance_closed_result_clock(300)
		check(app.result_closed_delay==Vector2(0.030000001192092896,0).x,"Main pause excludes closed timer updates")
		app.sim.paused=false;app.screen="loading";app.advance_closed_result_clock(300)
		check(app.result_closed_delay==Vector2(0.030000001192092896,0).x,"Main loading screen excludes room clock")
	check(original_room_calls==3 and reference.room_cases.size()==24 and reference.lifecycle_cases.size()==6,"all original caller/lifecycle cases consumed")
	app.free()
	var report={"checks":checks,"failures":failures,"original_room_cases":24,"original_room_calls":original_room_calls,"original_lifecycle_cases":6,"limit":"Original constructor/update/caller clocks with supplied opening flag; complete Open/service callback, particles, sound and original-device pixels remain separate."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/result-lifecycle-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RESULT_LIFECYCLE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

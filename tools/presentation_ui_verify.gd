extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	await process_frame
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app)
	var driver=load("res://scripts/presentation_verify.gd").new();driver.app=app;root.add_child(driver)
	driver.completed.connect(func(status):quit(status))
	create_timer(60).timeout.connect(func():if not driver.finished:push_error("Presentation QA timed out.");quit(1))
	driver.run()

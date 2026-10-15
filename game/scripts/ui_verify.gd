extends SceneTree

const Driver = preload("res://scripts/tutorial_verify.gd")

func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var driver = Driver.new()
	root.add_child(driver)
	driver.completed.connect(func(status: int): quit(status))
	create_timer(30.0).timeout.connect(func():
		if not driver.finished: push_error("Tutorial QA did not complete within30 seconds."); quit(1))
	driver.run()

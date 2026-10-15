extends SceneTree
func _initialize() -> void: start.call_deferred()
func start() -> void:
	var driver=load("res://scripts/menu_verify.gd").new()
	root.add_child(driver)
	driver.completed.connect(func(status):quit(status))
	create_timer(60.0).timeout.connect(func():if not driver.finished:push_error("Menu QA exceeded60 seconds.");quit(1))
	driver.run()

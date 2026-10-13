extends SceneTree

var app
var failures: Array[String] = []
var checks = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name); push_error(name)

func press(prefix: String) -> bool:
	for child in app.ui.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false

func tick(ms: int) -> void:
	for i in range(int(ms/30)):
		app._process(0.03)

func run() -> void:
	await process_frame
	root.get_node("Profile").data = root.get_node("Profile").fresh()
	# The headless Dummy audio backend cannot prove playback and can retain
	# asynchronous stream references at exit. Audio is audited in the native app.
	root.get_node("Profile").data.settings.music = false
	root.get_node("Profile").data.settings.sound = false
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	check(press("Play"), "fresh profile opens campaign from main menu")
	var point = app.world_origin()+Vector2(500, 1450)*app.world_zoom
	app.click_map(point)
	check(app.selected_location == "1", "world marker normalizes numeric location ID")
	check(press("Normal"), "fresh tutorial is accessible through world map")
	check(app.tutorial_step == 0, "tutorial opens at welcome")
	check(press("Continue"), "welcome can continue")
	app.select_build(4)
	check(app.build_type == 0, "tutorial rejects a different tower family")
	app.select_build(1)
	for cell in app.TUTORIAL_CELLS:
		app.click_map(app.map_origin()+app.sim.center(cell.x, cell.y)*app.map_scale())
		tick(30)
	check(app.sim.towers.size() == 4 and app.tutorial_step == 2, "four designated placements advance tutorial")
	tick(1020)
	check(press("Continue"), "money instruction can continue")
	for tower in app.sim.towers:
		app.selected_tower = tower.id
		app.refresh_controls()
		check(press("Minigun"), "tutorial upgrade button acts on selected tower")
		tick(1020)
	check(app.tutorial_step == 4, "all four upgrades advance to selling")
	check(press("Sell"), "designated unused tower can be sold")
	check(app.sim.towers.size() == 3 and app.tutorial_step == 5, "selling advances to Disco Magic")
	while app.sim.enemies.is_empty() and app.sim.clock_ms < 20000: tick(300)
	app.magic("m_lsd")
	check(app.tutorial_wait_until > 0, "Disco Magic starts and waits for expiry")
	tick(15300)
	check(app.tutorial_step == 6, "Disco expiry advances to Active Defense")
	app.magic("m_actdef")
	check(app.tutorial_step == 7, "Active Defense advances to mine introduction")
	app.magic("m_mine")
	app.click_map(app.map_origin()+app.sim.center(7, 6)*app.map_scale())
	check(app.tutorial_step == 8 and app.sim.tutorial_finished, "mine action releases tutorial completion gate")
	while app.sim.outcome == "playing" and app.sim.clock_ms < 300000: tick(300)
	check(app.sim.outcome == "victory", "tutorial reaches victory using its UI and original budget")
	var result = {"checks": checks, "failures": failures, "tutorial": {"ms": app.sim.clock_ms, "outcome": app.sim.outcome, "money": app.sim.money, "kills": app.sim.kills, "base": app.sim.base_fraction()}}
	var f = FileAccess.open("res://../builds/ui-verification.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t")); f.close()
	print("UI_VERIFICATION ", JSON.stringify(result))
	app.music.stop()
	app.music.stream = null
	for voice in app.voices: voice.stop(); voice.stream = null
	app.audio_cache.clear()
	await create_timer(0.1).timeout
	app.queue_free()
	app = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

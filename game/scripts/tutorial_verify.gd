extends Node

var app
var root: Window
signal completed(status: int)
var failures: Array[String] = []
var checks = 0
var capture_root = ""
var captures: Array[Dictionary] = []
var captured: Dictionary = {}
var finished = false

func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name); push_error(name)

func press(prefix: String, parent: Node = null) -> bool:
	if parent == null: parent = app.ui
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
		if press(prefix, child): return true
	return false

func tick(ms: int) -> void:
	for i in range(int(ms/30)):
		app.qa_real_seconds += 0.03
		app._process(0.03)

func settle_instruction() -> void:
	if app.tutorial==null:return
	var frames=0
	while (app.tutorial.transition_pending or app.tutorial.fade_state.alpha<1 or app.portrait_view.layers.any(func(l):return l.closing or l.age<app.portrait_view.DURATION)) and frames<90:
		tick(30);frames+=1

func snapshot(name: String) -> void:
	settle_instruction()
	if capture_root.is_empty() or captured.has(name): return
	captured[name] = true
	await get_tree().process_frame
	# A covered macOS window can skip frame_post_draw indefinitely. Force
	# the actual offscreen OpenGL frame before requesting its pixels.
	RenderingServer.force_draw(true)
	var path = capture_root.path_join(name+".png")
	var error = root.get_texture().get_image().save_png(path)
	captures.append({"name": name, "error": error, "path": path.get_file()})
	check(error == OK, "native tutorial capture "+name)

func click_button(prefix: String, parent: Node = null) -> bool:
	if parent == null: parent = app.ui
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = child.get_global_rect().get_center()
			event.pressed = true
			root.push_input(event, true)
			event = event.duplicate()
			event.pressed = false
			root.push_input(event, true)
			return true
		if click_button(prefix, child): return true
	return false

func run() -> void:
	root = get_tree().root
	await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-tutorial-capture-root="): capture_root = arg.trim_prefix("--qa-tutorial-capture-root=")
	if not capture_root.is_empty(): DirAccess.make_dir_recursive_absolute(capture_root)
	root.get_node("Profile").data = root.get_node("Profile").fresh()
	# The headless Dummy audio backend cannot prove playback and can retain
	# asynchronous stream references at exit. Audio is audited in the native app.
	root.get_node("Profile").data.settings.music = false
	root.get_node("Profile").data.settings.sound = false
	if app == null:
		root.get_node("Profile").path = "user://verification/tutorial-profile.json"
		app = load("res://scenes/main.tscn").instantiate()
		app.set_meta("qa_fixture", true)
		root.add_child(app)
	else: app.navigate("menu")
	check(app.test_session, "tutorial harness always uses QA behavior")
	var isolated_path = root.get_node("Profile").path
	root.get_node("Profile").path = "user://profile.json"
	check(not root.get_node("Profile").save_profile(), "verification write guard refuses the normal save even if a driver assigns its path")
	root.get_node("Profile").path = isolated_path
	check(root.get_node("Profile").path != "user://profile.json", "tutorial harness cannot write the normal profile")
	app.set_process(false)
	app.qa_real_seconds = 0.0
	app.notice_until = 0
	check(press("Play"), "fresh profile opens campaign from main menu")
	var point = app.world_origin()+Vector2(500, 1450)*app.world_zoom
	app.click_map(point)
	check(app.selected_location == "1", "world marker normalizes numeric location ID")
	app._process(0.7)
	check(press("Training"), "fresh tutorial is accessible through world map")
	check(app.tutorial_step == 0, "tutorial opens at welcome")
	await snapshot("page-00")
	check(click_button("Continue") and app.tutorial_step == 1, "one viewport press/release advances welcome exactly one page")
	check(app.tutorial.display_page==0 and app.tutorial.transition_pending,"logical page changes before the previous page finishes fading")
	app.acknowledge_tutorial()
	check(app.tutorial_step==1,"repeated dismissal cannot skip the pending tutorial transition")
	await snapshot("page-01")
	check(press("Continue"), "base and source explanation can continue")
	await snapshot("page-02")
	check(press("Continue"), "speed and money explanation reaches building page")
	settle_instruction()
	var build_labels=app.tutorial_layout.gl_items.filter(func(item):return item.kind=="text" and item.value.begins_with("Now build 4"))
	check(build_labels.size()==1 and build_labels[0].formatted=="Now build 4\nminigun towers\nin the designated\nlocations.","build instruction retains the four lines seen in the main recording and CoreText measurement")
	check(build_labels.size()==1 and build_labels[0].native_rect.size.x==180 and build_labels[0].phase=="screen","native180px callout width needs no5px expansion or second UILabel wrap")
	await snapshot("page-03")
	app.select_build(4)
	check(app.build_type == 0, "tutorial rejects a different tower family")
	app.notice_until = 0
	app.select_build(1)
	for cell in app.TUTORIAL_CELLS:
		app.click_map(app.map_origin()+app.sim.center(cell.x, cell.y)*app.map_scale())
		tick(30)
	check(app.sim.towers.size() == 4 and app.tutorial_step == 4, "four native placements start first wave")
	await snapshot("page-04")
	while app.tutorial_step < 6 and app.sim.clock_ms < 60000:
		tick(300)
		await snapshot("page-%02d" % app.tutorial_step)
	check(app.tutorial_step == 6 and app.sim.kills == 4, "native first-wave and money pages complete before upgrade selection")
	app.click_map(app.map_origin()+app.sim.center(8, 6)*app.map_scale())
	check(app.tutorial_step == 7, "selecting tower at 8,6 opens its upgrade cue")
	await snapshot("page-07")
	check(press("Minigun"), "native designated first upgrade")
	check(app.tutorial_step == 8, "first upgrade introduces other fighting towers")
	tick(390)
	check(app.selected_tower>=0 and app.tower_panel_alpha()<0.03,"original upgrade panel fades for400ms")
	tick(30)
	check(app.selected_tower==-1,"finished upgrade panel removes its hit areas before selecting neighboring towers")
	await snapshot("page-08")
	for cell in [Vector2i(7, 4), Vector2i(6, 7)]:
		app.click_map(app.map_origin()+app.sim.center(cell.x, cell.y)*app.map_scale())
		check(press("Minigun"), "other fighting tower upgrade")
		tick(1020)
	check(app.tutorial_step == 9 and app.sim.tower_at(Vector2i(11, 3)).level == 1, "only three fighting towers require upgrades")
	await snapshot("page-09")
	app.click_map(app.map_origin()+app.sim.center(11, 3)*app.map_scale())
	check(app.tutorial_step == 10, "select unused fourth tower for sale")
	await snapshot("page-10")
	check(press("Sell"), "sale opens confirmation")
	check(app.tutorial_step == 11 and app.sim.towers.size() == 4, "tower and funds are retained before confirming")
	tick(270)
	await snapshot("page-11")
	var pending_id = app.pending_sale
	app.click_map(app.map_origin()+app.sim.center(8, 6)*app.map_scale())
	check(app.pending_sale == pending_id and app.selected_tower == pending_id, "confirmation prevents a battlefield selection underneath")
	check(click_button("Cancel") and app.sim.towers.size() == 4, "cancel leaves the tower intact")
	settle_instruction()
	app.click_map(app.map_origin()+app.sim.center(11, 3)*app.map_scale())
	settle_instruction()
	check(press("Sell"),"unused tower reopens its confirmation")
	tick(270)
	check(click_button("Confirm sale"), "unused tower sale is explicitly confirmed")
	settle_instruction()
	check(app.sim.towers.size() == 3 and app.tutorial_step == 12, "confirmed sale starts second wave and introduces Disco")
	await snapshot("page-12")
	while app.sim.enemies.is_empty() and app.sim.clock_ms < 60000: tick(300)
	app.magic("m_lsd")
	check(app.tutorial_step == 13, "Disco starts its instructional wait")
	check(app.tutorial.hint_visible and app.tutorial_layout.labels.any(func(h):return str(h.value).replace("\n"," ").begins_with("You are doing really well")),"Disco wait preserves the previous instructional portrait")
	await snapshot("page-13")
	while app.qa_real_seconds-app.tutorial.wait_started<2.97:tick(30)
	check(app.tutorial_step == 13, "instruction waits the traced three real seconds")
	tick(90)
	check(app.tutorial_step == 14 and app.sim.clock_ms < app.sim.disco_until, "Active Defense is introduced while Disco remains active")
	await snapshot("page-14")
	app.magic("m_actdef")
	check(app.tutorial_step == 15, "Active Defense enters wave-completion wait")
	check(app.tutorial.hint_visible and app.tutorial_layout.labels.any(func(h):return str(h.value).begins_with("Sweet, isn't it?")),"Active Defense wait preserves its instructional portrait")
	await snapshot("page-15")
	while app.tutorial_step < 16 and app.sim.clock_ms < 200000: tick(300)
	check(app.tutorial_step == 16 and app.sim.enemies.is_empty(), "second wave completes before mine instruction")
	await snapshot("page-16")
	app.magic("m_mine")
	app.click_map(app.map_origin()+app.sim.center(7, 6)*app.map_scale())
	check(app.tutorial_step==17 and app.tutorial.transition_pending and not app.sim.tutorial_finished,"mine requests the boss page while its old pointers fade")
	var paused_fade=app.tutorial.fade_state.duplicate()
	var paused_clock=app.sim.clock_ms
	app.sim.paused=true
	tick(1800)
	check(app.sim.clock_ms==paused_clock and app.tutorial.fade_state==paused_fade,"pausing during mine transition freezes battle and instructional fade")
	check(app.tutorial.transition_pending and app.tutorial.display_page==16 and app.sim.wave_index==2 and not app.sim.tutorial_finished,"pause retains the pending boss launch without opening its completion gate")
	app.sim.paused=false
	settle_instruction()
	check(app.tutorial_step == 17 and app.sim.tutorial_finished and app.sim.wave_index == 3, "placed mine starts boss wave and releases completion gate")
	tick(600)
	check(app.sim.wave_index==3,"resuming the mine transition launches the boss exactly once")
	await snapshot("page-17")
	while app.sim.outcome == "playing" and app.sim.clock_ms < 300000: tick(300)
	check(app.sim.outcome == "victory", "tutorial reaches victory using its UI and original budget")
	check(app.tutorial_layout.labels.any(func(h):return str(h.value).begins_with("Great job cadet!")),"original tutorial victory guidance points back to the world map")
	tick(900) # Capture readable result labels after the native opening fade.
	await snapshot("victory")
	# A separate combat fixture verifies that visual effects follow the game
	# clock during pause and speed changes, without altering tutorial results.
	var tutorial_sim = app.sim
	var tutorial_flow = app.tutorial
	var saved_effects: Array[Dictionary] = app.effects.duplicate()
	var mission = root.get_node("Content").mission("8")
	app.sim = load("res://scripts/simulation.gd").new()
	app.sim.setup(root.get_node("Content").catalog, root.get_node("Content").maps[mission.map], mission, root.get_node("Profile").fresh())
	app.tutorial = null
	app.effects.clear()
	app.continuous_beams.clear()
	app.handle_event({"kind": "beam", "from": Vector2.ZERO, "to": Vector2.ONE, "type": 10, "ms": 0})
	app.sim.paused = true
	tick(300)
	check(app.effects.size() == 1, "combat effect remains frozen while game is paused")
	app.sim.paused = false
	tick(360)
	check(app.effects.is_empty(), "combat effect expires as simulation resumes")
	# The room clock truncates fractional milliseconds; the native particle
	# seconds clock must retain them and receive one live update per frame.
	app.sim.live_updates=true
	app.particle_fx.reset()
	app._process(0.01667)
	check(app.particle_fx.clock_ms>16.66 and app.particle_fx.clock_ms<16.68,"live particles retain fractional time independently of the integer room clock")
	var particle_clock=app.particle_fx.clock_ms
	app.sim.paused=true
	app._process(0.25)
	check(app.particle_fx.clock_ms==particle_clock,"live particle clock holds exactly through pause")
	app.sim.paused=false
	app.speed=4
	app._process(0.01667)
	check(app.particle_fx.clock_ms>83.34 and app.particle_fx.clock_ms<83.36,"live particle clock receives the original4x elapsed frame multiplier")
	app.speed=1
	app.sim.live_updates=false
	var saved_camera=app.camera
	var saved_zoom=app.zoom
	app.zoom=1.5
	app.pan(Vector2(100000,100000))
	check(app.map_origin().x<=0.01 and app.map_origin().y<=35.01,"dragging toward the map edge stays inside the battle viewport")
	app.pan(Vector2(-200000,-200000))
	var map_extent=Vector2(float(app.sim.map.width_pixels),float(app.sim.map.height_pixels))*app.map_scale()
	check(app.map_origin().x+map_extent.x>=app.view_size().x-0.01 and app.map_origin().y+map_extent.y>=app.view_size().y-60.01,"opposite map edges stay covered after a large pan")
	app.zoom_at(app.view_center(),0.001)
	check(absf(app.map_origin().x+(float(app.sim.map.width_pixels)*app.map_scale())/2.0-app.view_center().x)<0.01,"a map smaller than the viewport centers when zooming out")
	app.zoom=saved_zoom;app.camera=saved_camera
	# Exercise live XP, leaving a battle, failed saves and settlement through
	# the same app methods, with a separate verification profile.
	var profile = root.get_node("Profile")
	var saved_profile = profile.data.duplicate(true)
	var saved_path = profile.path
	var saved_progress_flag = app.qa_persist_progress
	var saved_result_flag = app.result_saved
	var saved_initial_xp = app.battle_initial_xp
	var saved_credited_score = app.credited_score
	var saved_credited_kills = app.credited_kills
	profile.path = "user://verification/live-ui-profile.json"
	profile.data = profile.fresh()
	profile.data.settings.music = false
	profile.data.settings.sound = false
	for medal in root.get_node("Content").catalog.tower_medals: profile.data.medals.append(profile.medal_id(medal))
	app.qa_persist_progress = true
	profile.data.level = 2
	profile.data.spice = 3
	app.sim.abilities.m_freeze = 0
	app.magic("m_freeze")
	check(profile.data.spice == 0 and profile.data.abilities.m_freeze == 5 and app.sim.abilities.m_freeze == 5 and app.sim.freeze_until == 0, "empty magic click buys the original5-charge refill without activating it")
	profile.read_only = true
	check(not app.activate_magic("m_freeze").is_empty() and app.sim.freeze_until == 0 and app.sim.abilities.m_freeze == 5 and profile.data.abilities.m_freeze == 5, "failed charge save cannot activate magic or debit either stock")
	profile.read_only = false
	check(app.activate_magic("m_freeze").is_empty() and app.sim.freeze_until > app.sim.clock_ms and app.sim.abilities.m_freeze == 4 and profile.data.abilities.m_freeze == 4, "successful activation saves the charge before applying the effect")
	check(not app.activate_magic("m_freeze").is_empty() and profile.data.abilities.m_freeze == 4, "invalid repeated activation cannot consume a saved charge")
	profile.data.level = 3
	profile.data.spice = 7
	app.sim.money = 200
	app.sim.build(Vector2i(15, 8), 1)
	var shop_tower = app.sim.towers[0]
	app.sim.upgrade_tower(shop_tower.id, 1, 2)
	app.request_technology(app.sim.tower_data(1, 3))
	await snapshot("technology-unlock")
	profile.read_only = true
	app.buy_pending_technology()
	check(profile.data.spice == 7 and not app.sim.can_unlock(app.sim.tower_data(1, 3)), "failed in-battle technology save rolls back spice and leaves the tower locked")
	profile.read_only = false
	app.buy_pending_technology()
	check(profile.data.spice == 0 and app.sim.can_unlock(app.sim.tower_data(1, 3)) and shop_tower.level == 2 and app.sim.money == 170, "in-battle technology purchase unlocks permanently without paying the separate battle upgrade")
	check(app.sim.upgrade_tower(shop_tower.id, 1, 3).is_empty() and app.sim.money == 160, "unlocked tower still pays its original battle-money upgrade cost")
	profile.data = profile.fresh()
	profile.data.settings.music = false
	profile.data.settings.sound = false
	for medal in root.get_node("Content").catalog.tower_medals: profile.data.medals.append(profile.medal_id(medal))
	app.result_saved = false
	app.credited_score = 0.0
	app.credited_kills = 0
	app.battle_initial_xp = 0
	app.sim.score = 100.0
	app.sim.kills = 2
	app.handle_event({"kind": "kill", "id": 100, "pos": Vector2.ZERO, "type": 1, "reward": 50.0, "ms": 60})
	app.handle_event({"kind": "kill", "id": 101, "pos": Vector2.ZERO, "type": 1, "reward": 50.0, "ms": 60})
	check(app.displayed_xp() == 10.0 and profile.data.xp == 0.0, "pending kill XP is immediately visible before the save batch")
	profile.read_only = true
	check(not app.flush_pending_xp() and app.sim.paused and app.pending_xp.size() == 2 and profile.data.xp == 0.0, "failed live save retains pending XP and pauses battle")
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(app.quit_pending and press("Keep playing"), "failed quit save gives an explicit keep-playing option")
	profile.read_only = false
	app.navigate("world")
	check(app.screen == "world" and app.pending_xp.is_empty() and profile.data.xp == 10.0, "leaving an unfinished mission saves earned XP")
	profile.load_profile()
	check(profile.data.xp == 10.0 and profile.data.stats.kills == 2, "unfinished mission XP and kills survive profile reload")
	app.sim.outcome = "defeat"
	check(app.save_result() and profile.data.xp == 10.0 and profile.data.stats.kills == 2, "defeat settlement does not duplicate live credit")
	profile.path = saved_path
	profile.data = saved_profile
	app.qa_persist_progress = saved_progress_flag
	app.result_saved = saved_result_flag
	app.battle_initial_xp = saved_initial_xp
	app.credited_score = saved_credited_score
	app.credited_kills = saved_credited_kills
	app.screen = "game"
	app.sim = tutorial_sim
	app.tutorial = tutorial_flow
	app.effects = saved_effects
	app.notice_until = 0
	app.refresh_controls()
	var result = {"checks": checks, "failures": failures, "tutorial": {"ms": app.sim.clock_ms, "outcome": app.sim.outcome, "money": app.sim.money, "kills": app.sim.kills, "base": app.sim.base_fraction(), "pages": app.tutorial.history}}
	var f = FileAccess.open("res://../builds/ui-verification.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t")); f.close()
	print("UI_VERIFICATION ", JSON.stringify(result))
	if not capture_root.is_empty():
		f = FileAccess.open(capture_root.path_join("manifest.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "captures": captures, "verification": result}, "\t")); f.close()
	app.music.stop()
	app.music.stream = null
	for voice in app.voices: voice.stop(); voice.stream = null
	app.audio_cache.clear()
	await get_tree().create_timer(0.1).timeout
	finished = true
	completed.emit(0 if failures.is_empty() else 1)

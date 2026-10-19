extends SceneTree
var app
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var content=root.get_node("Content");var profile=root.get_node("Profile");profile.path="user://qa/creep-profile-r188.json";profile.data=profile.fresh();profile.read_only=true
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app)
	profile.data.settings.music=false;profile.data.settings.sound=false;app.music.stop()
	for voice in app.voices:voice.stop()
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	app.get_viewport().gui_disable_input=true
	app.start_mission("13",true,false)
	var baseline=app.sim
	var sim=load("res://../builds/creep_profile_sim_r188.gd").new()
	sim.setup(baseline.catalog,baseline.map.duplicate(true),baseline.config.duplicate(true),profile.data,int(baseline.rng.seed),content.animations)
	sim.live_updates=baseline.live_updates
	assert(sim.live_updates and sim.digest()==baseline.digest(),"Diagnostic must preserve live Main setup and combat digest")
	sim.particle_state=load("res://../builds/creep_profile_particles_r188.gd").new();sim.particle_state.reset()
	app.particle_fx.reset();app.sim=sim;app.particle_fx.use_state(sim.particle_state)
	baseline=null
	app.sim.profile_hotpaths=true
	app.sim.next_wave_ms=1000000
	app.sim.money=100000
	for base in app.sim.bases:base.hp=1000000.0;base.hpmax=1000000.0
	var cells=[]
	for y in range(int(app.sim.map.hex_height)):
		for x in range(int(app.sim.map.hex_width)):
			var cell=Vector2i(x,y)
			if app.sim.buildable(cell):cells.append(cell)
	for i in range(54):
		var cell=cells[posmod(i*7,cells.size())]
		var type=int(i/3)+1
		var level=i%3+1
		app.sim.towers.append({"id":i+1,"type":type,"level":level,"cell":cell,"pos":app.sim.center(cell.x,cell.y),"def":app.sim.tower_data(type,level),"angle":float(i%9)*40,"ready_ms":0,"shot_ms":0,"reload_ms":100000.0,"born_ms":0,"foundation_ms":0,"targeting":"weakest","receipts":[]})
	for i in range(200):
		var e=app.sim.spawn_enemy([1,2,3,4,5,6,9,15][i%8],i%app.sim.sources.size(),"",10000+i,false)
		e.hp=1500.0;e.max_hp=2500.0
		if e.path.size()>1:
			e.move_progress=float(i%20)/20.0
			e.pos=app.sim.vector_interpolate(e.move_start,app.sim.center(e.next_cell.x,e.next_cell.y),e.move_progress)
	app.sim.defense_until=60000
	app.sim.disco_until=0
	app.camera=Vector2(app.sim.map.width_pixels/2.0,app.sim.map.height_pixels/2.0)
	app.zoom=0.85
	app.refresh_controls()
	var stages=[]
	for rate in [1,2,4]:
		app.speed=rate;var deadline=Time.get_ticks_msec()+1000
		while Time.get_ticks_msec()<deadline:await process_frame
		app.sim.detail.clear();app.sim.particle_state.detail.clear();app.sim.hotpath_timings.clear();app.qa_timings.clear()
		var initial=app.sim.clock_ms;var last_sim=initial;var advancing=0;var stalled=0;var observed=[];var previous=Time.get_ticks_usec();deadline=Time.get_ticks_msec()+2000
		while Time.get_ticks_msec()<deadline:
			await process_frame
			var now=Time.get_ticks_usec();observed.append(float(now-previous)/1000.0);previous=now
			if app.sim.clock_ms>last_sim:advancing+=1
			else:stalled+=1
			last_sim=app.sim.clock_ms
		observed.sort();var states={}
		for actor in app.sim.enemies:states[str(actor.state)]=int(states.get(str(actor.state),0))+1
		assert(app.sim.live_updates and not app.sim.paused and app.sim.outcome=="playing" and advancing>=observed.size()-2,"Diagnostic must advance the actual live-frame path")
		stages.append({"speed":rate,"live_updates":app.sim.live_updates,"advancing_observations":advancing,"stalled_observations":stalled,"observed_frames":observed.size(),"observed_median_ms":observed[observed.size()/2],"initial_sim_ms":initial,"final_sim_ms":app.sim.clock_ms,"simulation_detail":app.sim.detail.duplicate(true),"particle_detail":app.sim.particle_state.detail.duplicate(true),"simulation_sections":app.sim.hotpath_timings.duplicate(true),"Main_timings":app.qa_timings.duplicate(true),"actor_states":states})
	var result={"stages":stages,"diagnostic_only":true,"performance_limit_evaluated":false,"scope":"Separate advancing live-frame source-native battle with R187 dense geometry/actor fixture inputs with muted audio; diagnostic subclasses time super methods. Timers/virtual wrappers add overhead and alter real-time trajectories. Nested animation/factory measurements overlap parent sections. These are phase observations, not another numeric performance acceptance or isolated interbuild comparison."}
	var f=FileAccess.open("res://../builds/creep-profile-r188-native-live.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();print("CREEP_PHASE_PROFILE ",JSON.stringify(result))
	app.sim.particle_state.reset();app.sim.enemies.clear();app.free();await process_frame;quit()

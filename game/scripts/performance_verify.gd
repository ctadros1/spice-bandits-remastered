extends Node

var app
var samples: Array[float]=[]
var measuring=false
var output=""
var captures: Array=[]
var failures: Array=[]
var last_frame_us=0
var rendering_comparisons=[]
var last_sim_ms=0
var advancing_frames=0
var stalled_frames=0

func bolt_metrics() -> Dictionary:
	var renderer=app.bolt_renderer
	var visible=renderer.slots.filter(func(s):return s.visible)
	var used=0
	var types={}
	for slot in visible:
		if slot.has_broad:used+=int(slot.atlas_rect.get_area())
		types[str(slot.effect.type)]=int(types.get(str(slot.effect.type),0))+1
	return {"live_slots":visible.size(),"pooled_slots":renderer.slots.size(),"by_type":types,"broad_tile_pixels":used,"atlas_size":[renderer.product.size.x,renderer.product.size.y],"subviewports":renderer.find_children("*","SubViewport",true,false).size()}

func _process(delta: float) -> void:
	var now=Time.get_ticks_usec()
	if measuring and last_frame_us>0:
		samples.append(float(now-last_frame_us)/1000.0)
		if app.screen=="game":
			if app.sim.clock_ms>last_sim_ms:advancing_frames+=1
			else:stalled_frames+=1
			last_sim_ms=app.sim.clock_ms
	last_frame_us=now

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-performance-root="):output=arg.trim_prefix("--qa-performance-root=")
	if output.is_empty():push_error("Performance QA requires an output directory.");get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	# Shared-Mac input must not pause or change an automated stress scene.
	# This affects only this QA driver; ordinary and interactive QA input stays on.
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	app.get_viewport().gui_disable_input=true
	app.start_mission("13",true,false)
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
		app.speed=rate
		app.refresh_controls()
		var deadline=Time.get_ticks_msec()+1000
		while Time.get_ticks_msec()<deadline:await get_tree().process_frame
		var sample_start_ms=app.sim.clock_ms
		last_sim_ms=sample_start_ms;advancing_frames=0;stalled_frames=0
		samples.clear();last_frame_us=Time.get_ticks_usec();measuring=true
		app.qa_timings.clear()
		app.sim.hotpath_timings.clear()
		deadline=Time.get_ticks_msec()+3000
		while Time.get_ticks_msec()<deadline:await get_tree().process_frame
		measuring=false
		var sample_end_ms=app.sim.clock_ms
		var live_advanced=sample_end_ms-sample_start_ms>=2000*rate and advancing_frames>=samples.size()-2 and not app.sim.paused and app.sim.outcome=="playing"
		if not live_advanced:failures.append("Dense%dx fixture did not advance its live simulation throughout measurement." % rate)
		var input_isolated=not app.is_processing_input() and not app.is_processing_unhandled_input() and app.get_viewport().gui_disable_input
		if not input_isolated:failures.append("Automated performance input was not isolated.")
		samples.sort()
		var median=samples[int(samples.size()/2)] if not samples.is_empty() else 0.0
		var p95=samples[mini(samples.size()-1,int(samples.size()*0.95))] if not samples.is_empty() else 0.0
		var filename="dense-%dx.png" % rate
		RenderingServer.force_draw(true)
		var error=get_tree().root.get_texture().get_image().save_png(output.path_join(filename))
		captures.append({"path":filename,"error":error,"speed":rate})
		# Freeze the same simulation/effect objects while comparing the existing
		# per-particle renderer with ordered batches. Redraw notifications need
		# scene frames; stop app processing so neither state nor UI clocks move.
		app.set_process(false)
		var reference_before=app.particle_fx.reference_draws
		app.particle_fx.reference_rendering=true
		for layer in app.particle_fx.layers:layer.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var reference_error=get_tree().root.get_texture().get_image().save_png(output.path_join("reference-%dx.png" % rate))
		app.particle_fx.reference_rendering=false
		app.particle_fx.direct_triangles=false
		for layer in app.particle_fx.layers:layer.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var mesh_image=get_tree().root.get_texture().get_image()
		var mesh_error=mesh_image.save_png(output.path_join("mesh-reference-%dx.png" % rate))
		app.particle_fx.direct_triangles=true
		var batch_before=app.particle_fx.batch_draws
		for layer in app.particle_fx.layers:layer.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var batch_error=get_tree().root.get_texture().get_image().save_png(output.path_join("batch-%dx.png" % rate))
		var exact_mesh=mesh_image.get_data()==get_tree().root.get_texture().get_image().get_data()
		if mesh_error!=OK or not exact_mesh:failures.append("Direct particle triangles differ from the frozen mesh reference.")
		var reference_draws=app.particle_fx.reference_draws-reference_before
		var batch_draws=app.particle_fx.batch_draws-batch_before
		rendering_comparisons.append({"speed":rate,"reference":"reference-%dx.png" % rate,"mesh_reference":"mesh-reference-%dx.png" % rate,"batch":"batch-%dx.png" % rate,"reference_error":reference_error,"mesh_error":mesh_error,"batch_error":batch_error,"exact_mesh_rgba":exact_mesh,"reference_draws":reference_draws,"batch_draws":batch_draws,"sim_ms":app.sim.clock_ms})
		if reference_draws<2 or batch_draws<2 or reference_error!=OK or batch_error!=OK:failures.append("Particle comparison did not render both layers in both modes.")
		app.set_process(true)
		stages.append({"speed":rate,"frames":samples.size(),"median_frame_ms":median,"p95_frame_ms":p95,"maximum_frame_ms":samples[-1] if not samples.is_empty() else 0.0,"reported_fps":Engine.get_frames_per_second(),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"enemies":app.sim.enemies.size(),"towers":app.sim.towers.size(),"particle_systems":app.particle_fx.systems.size(),"sim_ms":app.sim.clock_ms,"sample_start_sim_ms":sample_start_ms,"sample_end_sim_ms":sample_end_ms,"advancing_frames":advancing_frames,"stalled_frames":stalled_frames,"live_advanced":live_advanced,"input_isolated":input_isolated,"bolts":bolt_metrics(),"timings":app.qa_timings.duplicate(true),"simulation_sections":app.sim.hotpath_timings.duplicate(true)})
		if samples.size()<45 or median>33.34 or error!=OK:failures.append("Dense%dx fixture did not sustain30 median frames/second or capture successfully." % rate)
	app.screen="world";app.selected_location="";app.world_camera=Vector2(2048,1536);app.world_zoom=0.2
	app.world_clouds.reset();app.refresh_controls()
	var deadline=Time.get_ticks_msec()+1000
	while Time.get_ticks_msec()<deadline:await get_tree().process_frame
	samples.clear();last_frame_us=Time.get_ticks_usec();measuring=true;app.qa_timings.clear()
	deadline=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline:await get_tree().process_frame
	measuring=false;samples.sort()
	var world_median=samples[int(samples.size()/2)] if not samples.is_empty() else 0.0
	var world_p95=samples[mini(samples.size()-1,int(samples.size()*0.95))] if not samples.is_empty() else 0.0
	RenderingServer.force_draw(true)
	var world_error=get_tree().root.get_texture().get_image().save_png(output.path_join("world-clouds.png"))
	captures.append({"path":"world-clouds.png","error":world_error,"kind":"world"})
	var cloud_count=0
	for generator in app.world_clouds.generators:cloud_count+=generator.systems.size()
	stages.append({"kind":"world","zoom":0.2,"visible_generators":app.world_clouds.rendered.size(),"cloud_systems":cloud_count,"frames":samples.size(),"median_frame_ms":world_median,"p95_frame_ms":world_p95,"maximum_frame_ms":samples[-1] if not samples.is_empty() else 0.0,"timings":app.qa_timings.duplicate(true)})
	if samples.size()<45 or world_median>33.34 or world_error!=OK:failures.append("Full world cloud fixture did not sustain30 median frames/second or capture successfully.")
	var file=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"method":"Native packaged synthetic stress fixture:54 tower forms,200 initial enemies, inflated base health, no profile rewards. Live elapsed-time frame updates at1x/2x/4x and a fully zoomed-out world with nine original cloud generators; three-second wall-clock sampling after one-second warmups. Apple Silicon measurement only, not original-game timing equivalence or RSS. Paused same-state legacy/mesh/direct captures compare reconstructed renderers; direct triangles must match mesh RGBA exactly. No original-device pixel claim.","stages":stages,"captures":captures,"rendering_comparisons":rendering_comparisons,"failures":failures},"\t"));file.close()
	print("PERFORMANCE_VERIFICATION ",JSON.stringify(stages))
	get_tree().quit(0 if failures.is_empty() else 1)

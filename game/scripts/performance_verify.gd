extends Node

var app
var samples: Array[float]=[]
var measuring=false
var output=""
var captures: Array=[]
var failures: Array=[]
var last_frame_us=0
var rendering_comparisons=[]
var creep_layer_comparisons=[]
var frame_lookup_comparisons=[]
var last_sim_ms=0
var advancing_frames=0
var stalled_frames=0

var decal_render_comparisons=[]
var particle_key_comparisons=[]
var owned_group_comparisons=[]
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
		# Keep live CPU totals separate from supplemental frozen redraws.
		var live_timings=app.qa_timings.duplicate(true)
		var live_sections=app.sim.hotpath_timings.duplicate(true)
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
		# Original recursive Render mutates child RGBA. Give every compared path
		# the same complete held state, rather than comparing successive renders.
		var held_particle_systems=app.particle_fx.systems.duplicate(true)
		# Held live geometry: both native lookup paths must retain every byte.
		for premul in [false,true]:
			for quantized in [false,true]:
				var fx=app.particle_fx
				var geometry_origin=app.map_origin()-fx.position
				fx.systems=held_particle_systems.duplicate(true)
				var original_groups=SpiceNative.particle_batches(fx.systems,premul,fx.clock_ms,geometry_origin,app.map_scale(),quantized,true)
				fx.systems=held_particle_systems.duplicate(true)
				var prepared_groups=SpiceNative.particle_batches(fx.systems,premul,fx.clock_ms,geometry_origin,app.map_scale(),quantized,false)
				var exact_geometry=var_to_bytes(original_groups)==var_to_bytes(prepared_groups)
				particle_key_comparisons.append({"speed":rate,"premultiplied":premul,"quantized":quantized,"exact_geometry_bytes":exact_geometry,"groups":prepared_groups.size(),"systems":fx.systems.size()})
				if not exact_geometry or prepared_groups.is_empty():failures.append("Particle lookup paths differ in held live geometry or fixture was empty.")
		var reference_before=app.particle_fx.reference_draws
		app.particle_fx.systems=held_particle_systems.duplicate(true)
		app.particle_fx.reference_rendering=true
		for layer in app.particle_fx.layers:layer.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var reference_error=get_tree().root.get_texture().get_image().save_png(output.path_join("reference-%dx.png" % rate))
		app.particle_fx.reference_rendering=false
		app.particle_fx.systems=held_particle_systems.duplicate(true)
		app.particle_fx.direct_triangles=false
		for layer in app.particle_fx.layers:layer.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var mesh_image=get_tree().root.get_texture().get_image()
		var mesh_error=mesh_image.save_png(output.path_join("mesh-reference-%dx.png" % rate))
		app.particle_fx.systems=held_particle_systems.duplicate(true)
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
		# The live1x sample can legitimately contain no recent death. Add one
		# real authored burst AFTER live timing and the existing comparisons.
		# Restore RNG/serial/ordinary systems afterward so later samples retain
		# their caller state; no gameplay event, sound or reward is generated.
		var ordinary_image=get_tree().root.get_texture().get_image()
		var fx=app.particle_fx
		var saved_rng=fx.random.state;var saved_serial=fx.serial;var saved_owned_serial=fx.owned_serial
		var saved_clocks=[fx.clock_ms,fx.clock_seconds]
		fx.systems=held_particle_systems.duplicate(true)
		var first_injected=fx.systems.size()
		var point=(app.view_size()*0.5-app.map_origin())/app.map_scale()
		fx.emit_creep_death_burst("creeps/creep1",point,"blue")
		var injected=fx.systems.slice(first_injected)
		for step in range(4):SpiceNative.advance_systems(injected,fx.clock_ms,fx.emit_system,fx.emit_batch,fx.random,0.03)
		var grouping_state=fx.systems.duplicate(true)
		var owned_roots=grouping_state.filter(func(s):return s.has("owned_tree") and not s.get("owner_hidden",false) and s.owned_tree.particles.any(func(p):return p.alpha>0)).size()
		var injected_owned=injected.filter(func(s):return s.has("owned_tree") and not s.owned_tree.particles.is_empty()).size()
		var groups=[]
		for coalesced in [false,true]:
			var snapshot=grouping_state.duplicate(true);var count=0
			for premul in [false,true]:count+=SpiceNative.particle_batches(snapshot,premul,fx.clock_ms,app.map_origin()-fx.position,app.map_scale(),true,false,coalesced).size()
			groups.append(count)
		fx.systems=grouping_state.duplicate(true);fx.coalesce_owned=true
		for layer in fx.layers:layer.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var coalesced_image=get_tree().root.get_texture().get_image();var coalesced_name="coalesced-owned-%dx.png"%rate
		var coalesced_error=coalesced_image.save_png(output.path_join(coalesced_name))
		var injected_visible=coalesced_image.get_data()!=ordinary_image.get_data()
		fx.systems=grouping_state.duplicate(true);fx.coalesce_owned=false
		for layer in fx.layers:layer.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var unmerged_name="unmerged-owned-%dx.png"%rate
		var unmerged_image=get_tree().root.get_texture().get_image();var unmerged_error=unmerged_image.save_png(output.path_join(unmerged_name))
		var owned_exact=coalesced_image.get_data()==unmerged_image.get_data()
		fx.coalesce_owned=true;fx.systems=held_particle_systems.duplicate(true)
		fx.random.state=saved_rng;fx.serial=saved_serial;fx.owned_serial=saved_owned_serial
		var caller_restored=fx.random.state==saved_rng and fx.serial==saved_serial and fx.owned_serial==saved_owned_serial and [fx.clock_ms,fx.clock_seconds]==saved_clocks
		owned_group_comparisons.append({"speed":rate,"unmerged":unmerged_name,"coalesced":coalesced_name,"error":unmerged_error,"coalesced_error":coalesced_error,"exact_rgba":owned_exact,"visible_owned_roots":owned_roots,"injected_owned_roots":injected_owned,"injected_visible_change":injected_visible,"unmerged_groups":groups[0],"coalesced_groups":groups[1],"caller_state_restored":caller_restored})
		if not owned_exact or unmerged_error!=OK or coalesced_error!=OK or owned_roots<1 or injected_owned<2 or not injected_visible or groups[1]>=groups[0] or not caller_restored:failures.append("Owned grouping must exercise visible authored roots/fewer groups/exact frozenRGBA and restore caller state.")
		for layer in fx.layers:layer.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		# Use the same frozen actors to verify that the former eager fallback
		# and prepared layer path both actually draw and retain exact pixels.
		app.probe_creep_layers=true;app.creep_layer_usage={"cached":0,"reference":0};app.creep_layer_actor_ids={"cached":{},"reference":{}}
		var actor_states=app.sim.enemies.map(func(e):return {"id":int(e.id),"state":int(e.get("state",0))})
		app.reference_creep_layers=true;app.sim.reference_spawn_presentation=true;app.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var legacy_creeps=get_tree().root.get_texture().get_image()
		var legacy_name="legacy-creeps-%dx.png" % rate
		var legacy_error=legacy_creeps.save_png(output.path_join(legacy_name))
		app.reference_creep_layers=false;app.sim.reference_spawn_presentation=false;app.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var prepared_creeps=get_tree().root.get_texture().get_image()
		var prepared_name="prepared-creeps-%dx.png" % rate
		var prepared_error=prepared_creeps.save_png(output.path_join(prepared_name))
		var usage=app.creep_layer_usage.duplicate(true)
		var exact_creeps=legacy_creeps.get_data()==prepared_creeps.get_data()
		creep_layer_comparisons.append({"speed":rate,"legacy":legacy_name,"prepared":prepared_name,"legacy_error":legacy_error,"prepared_error":prepared_error,"exact_rgba":exact_creeps,"usage":usage,"enemies":app.sim.enemies.size(),"actor_states":actor_states,"drawn_actor_ids":{"cached":app.creep_layer_actor_ids.cached.keys(),"reference":app.creep_layer_actor_ids.reference.keys()},"sim_ms":app.sim.clock_ms})
		if not exact_creeps or legacy_error!=OK or prepared_error!=OK or int(usage.cached)<1 or int(usage.reference)<1:failures.append("Prepared creep layers did not render both paths with exact frozen RGBA.")
		app.probe_creep_layers=false
		Content.probe_frame_lookup=true;Content.frame_lookup_usage={"cached":0,"reference":0}
		Content.reference_frame_lookup=true;app.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var reference_frames=get_tree().root.get_texture().get_image()
		var reference_frame_name="reference-frames-%dx.png"%rate
		var reference_frame_error=reference_frames.save_png(output.path_join(reference_frame_name))
		Content.reference_frame_lookup=false;app.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var prepared_frames=get_tree().root.get_texture().get_image()
		var prepared_frame_name="prepared-frames-%dx.png"%rate
		var prepared_frame_error=prepared_frames.save_png(output.path_join(prepared_frame_name))
		var exact_frames=reference_frames.get_data()==prepared_frames.get_data()
		frame_lookup_comparisons.append({"speed":rate,"reference":reference_frame_name,"prepared":prepared_frame_name,"reference_error":reference_frame_error,"prepared_error":prepared_frame_error,"exact_rgba":exact_frames,"usage":Content.frame_lookup_usage.duplicate(true),"sim_ms":app.sim.clock_ms})
		if not exact_frames or reference_frame_error!=OK or prepared_frame_error!=OK or int(Content.frame_lookup_usage.cached)<1 or int(Content.frame_lookup_usage.reference)<1:failures.append("Prepared animation-frame lookup did not redraw both paths with exact frozen RGBA.")
		Content.probe_frame_lookup=false
		app.probe_decal_rendering=true;app.decal_render_usage={"cached":0,"reference":0,"cached_frames":0,"reference_frames":0}
		app.reference_decal_rendering=true;app.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var reference_decals=get_tree().root.get_texture().get_image();var reference_decal_name="reference-decals-%dx.png"%rate
		var reference_decal_error=reference_decals.save_png(output.path_join(reference_decal_name))
		app.reference_decal_rendering=false;app.queue_redraw()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
		var prepared_decals=get_tree().root.get_texture().get_image();var prepared_decal_name="prepared-decals-%dx.png"%rate
		var prepared_decal_error=prepared_decals.save_png(output.path_join(prepared_decal_name));var exact_decals=reference_decals.get_data()==prepared_decals.get_data()
		var decal_usage=app.decal_render_usage.duplicate(true);var decal_count=app.sim.decals.items.size()
		decal_render_comparisons.append({"speed":rate,"reference":reference_decal_name,"prepared":prepared_decal_name,"reference_error":reference_decal_error,"prepared_error":prepared_decal_error,"exact_rgba":exact_decals,"usage":decal_usage,"decals":decal_count,"sim_ms":app.sim.clock_ms})
		if not exact_decals or reference_decal_error!=OK or prepared_decal_error!=OK or min(int(decal_usage.cached_frames),int(decal_usage.reference_frames))<1 or (decal_count>0 and min(int(decal_usage.cached),int(decal_usage.reference))<decal_count):failures.append("Prepared decal rendering did not render both paths with exact frozen RGBA.")
		app.probe_decal_rendering=false
		app.set_process(true)
		stages.append({"speed":rate,"frames":samples.size(),"median_frame_ms":median,"p95_frame_ms":p95,"maximum_frame_ms":samples[-1] if not samples.is_empty() else 0.0,"reported_fps":Engine.get_frames_per_second(),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"enemies":app.sim.enemies.size(),"towers":app.sim.towers.size(),"particle_systems":app.particle_fx.systems.size(),"sim_ms":app.sim.clock_ms,"sample_start_sim_ms":sample_start_ms,"sample_end_sim_ms":sample_end_ms,"advancing_frames":advancing_frames,"stalled_frames":stalled_frames,"live_advanced":live_advanced,"input_isolated":input_isolated,"bolts":bolt_metrics(),"timings":live_timings,"simulation_sections":live_sections,"decals":app.sim.decals.items.size(),"decal_cache":app.decal_render_cache.size(),"timing_scope":"Live sampling only; frozen comparison redraws excluded."})
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
	file.store_string(JSON.stringify({"method":"Native packaged synthetic stress fixture:54 tower forms,200 initial enemies, inflated base health, no profile rewards. Live elapsed-time frame updates at1x/2x/4x and a fully zoomed-out world with nine original cloud generators; three-second wall-clock sampling after one-second warmups. Apple Silicon measurement only, not original-game timing equivalence or RSS. Paused same-state legacy/mesh/direct captures compare reconstructed renderers; direct triangles must match mesh RGBA exactly. Separate frozen eager/prepared creep-layer/growth and original/prepared frame-lookup paths must both redraw and match full RGBA. No original-device pixel claim.","stages":stages,"captures":captures,"rendering_comparisons":rendering_comparisons,"creep_layer_comparisons":creep_layer_comparisons,"frame_lookup_comparisons":frame_lookup_comparisons,"decal_render_comparisons":decal_render_comparisons,"particle_key_comparisons":particle_key_comparisons,"owned_group_comparisons":owned_group_comparisons,"failures":failures},"\t"));file.close()
	print("PERFORMANCE_VERIFICATION ",JSON.stringify(stages))
	get_tree().quit(0 if failures.is_empty() else 1)

extends Node
signal completed(status:int)
const Bolt=preload("res://scripts/bolt_view.gd")
var app
var finished=false
var checks=0
var failures=[]
var captures=[]
var core_blend_samples=[]
var ordered_blend_samples=[]
var window_restoration={}
var destination=""
var death_burst_parents=[]
var death_burst_owner={}

class BlendFixture extends Node2D:
	var screen="game"
	var sim={"clock_ms":0}
	var effects=[]
	func map_origin() -> Vector2:return Vector2.ZERO
	func map_scale() -> float:return 1.0
	func view_size() -> Vector2:return Vector2(64,64)

func check(value:bool,name:String) -> void:
	checks+=1
	if not value:failures.append(name);push_error(name)

func advance_result_until(time:float) -> void:
	while app.elapsed_ui<time:
		app._process(minf(0.03,time-app.elapsed_ui))
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)

func decal_birth(type:int,id:int,point:Vector2) -> Dictionary:
	var enemy=app.sim.spawn_enemy(type,0,"",id,false)
	enemy.pos=point;enemy.visual_pos=point;enemy.path=[]
	app.sim.damage(enemy,float(enemy.max_hp)*10,0,2)
	app.sim.advance_frame(0)
	return app.sim.decals.items[-1]

func snapshot(name:String,settle_portrait:bool=true,already_rendered:bool=false) -> void:
	var prior_result_renders=app.qa_result_render_count
	if settle_portrait:app.portrait_view.advance(0.5)
	# Result ticks already executed their real bar Render. Read that frame
	# without submitting an extra Render that would stop the source emitter.
	if not already_rendered:app.queue_redraw();app.battle_overlay.queue_redraw()
	app.bolt_renderer.prepare()
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var path=destination.path_join(name+".png")
	var image=get_viewport().get_texture().get_image()
	if image==null:
		check(false,"viewport readback "+name);return
	var error=image.save_png(path)
	check(error==OK,"capture "+name)
	var record={"name":name,"path":name+".png","error":error}
	if already_rendered:
		check(app.qa_result_render_count==prior_result_renders,"result capture reads the existing native frame without another emitter gate")
		record.xp_render_count=app.qa_result_render_count;record.xp_render_age=app.qa_result_render_age
	record.window_size=[app.get_window().size.x,app.get_window().size.y]
	record.image_size=[image.get_width(),image.get_height()]
	record.canvas_stretch=[app.get_viewport().get_stretch_transform().x.x,app.get_viewport().get_stretch_transform().y.y]
	if name.begins_with("tower-depth"):
		record.draw_order=app.battle_objects().filter(func(o):return o.has("tower") or o.has("enemy")).map(func(o):return {"kind":"tower" if o.has("tower") else "enemy","id":o.get("tower",o.get("enemy",{})).id,"depth":o.y})
		record.limit="Synthetic overlapping positions; tower depth follows original ARM fields. Creep depth and original whole-map tie/registration/owner interleaving remain open."
	if name.begins_with("base-depth"):
		record.draw_order=app.battle_objects().filter(func(o):return o.has("tower") or o.has("enemy") or o.has("base")).map(func(o):return {"kind":"base" if o.has("base") else "tower" if o.has("tower") else "enemy","type":o.get("base",o.get("tower",o.get("enemy",{}))).type,"depth":o.y})
		record.limit="Synthetic overlapping base positions. Base/tower depth follows bounded original ARM fields; creep depth, whole-map registration/ties and complete post-pass owner/air interleaving remain open."
	if name.begins_with("air-depth"):
		record.ground_enemy_ids=app.battle_objects().filter(func(o):return o.has("enemy")).map(func(o):return o.enemy.id)
		record.air_enemy_ids=app.battle_air_objects().map(func(e):return e.id)
		record.enemies=app.sim.enemies.map(func(e):return {"id":e.id,"type":e.type,"native_air":e.native_air,"air":e.air,"position":[e.pos.x,e.pos.y]})
		record.limit="Synthetic body overlap. Separate resource-class air pass and manager vector order follow original ARM routing; exact creep depth, shadows, preview/selection/owner interleaving and original pixels remain open."
	if name.begins_with("selection-range"):
		var pose=app.selected_range_pose()
		record.selected_tower=app.selected_tower
		record.panel_alpha=app.tower_panel_alpha()
		record.range_draws=pose.get("draws",[]).map(func(d):return {"filled":d.filled,"axes":[d.axes.x,d.axes.y],"color":[d.color.r,d.color.g,d.color.b,d.color.a]})
		record.limit="Synthetic selected range after ground/before air bodies. Original routing and oval submissions execute with explicit GL stubs; Godot raster, supply bonus and full panel clock/owner behavior remain open."
	if name.begins_with("creep-depth"):
		record.draw_order=app.battle_objects().filter(func(o):return o.has("tower") or o.has("enemy")).map(func(o):return {"kind":"tower" if o.has("tower") else "enemy","id":o.get("tower",o.get("enemy",{})).id,"depth":o.y})
		record.enemies=app.sim.enemies.map(func(e):return {"id":e.id,"type":e.type,"position":[e.pos.x,e.pos.y],"drawn":[e.visual_pos.x,e.visual_pos.y],"depth":app.creep_depth(e)})
		record.limit="Synthetic Marine/tank overlap. Original initial animation height and supplied position truncation/key are bounded ARM comparisons; full birth/corner/jitter/owner lifetime and original pixels remain open."
	if name.begins_with("result-room"):
		record.result_age=app.elapsed_ui-app.result_started
		record.initial_delay=app.result_initial_delay
		record.result_clock=app.result_clock.duplicate(true)
		record.limit="Forced8XP/3sp renderer sequence, original unscaled room delay preserved. No earned rewards, original RNG or device-pixel equivalence."
	if name.begins_with("animator-"):
		record.animators=[]
		var owners=app.sim.mines+app.sim.towers
		for portal in app.battle_portal_objects():owners.append(portal.gate)
		for owner in owners:
			for key in owner.get("render_animators",{}):
				var state=owner.render_animators[key]
				record.animators.append({"key":key,"phase":state.phase,"frame":state.frame,"stopped":state.stopped,"name":state.name})
		record.limit="Controlled source clock increments and supplied owner states; actual imported frames and blend recipe. Full room clock/culling/lifecycle/original GPU equivalence remains separate."
	if name.begins_with("death-burst-"):
		record.death_burst={"clock_bits":PackedFloat32Array([app.particle_fx.clock_seconds]).to_byte_array().decode_u32(0),"parents":death_burst_parents.map(func(p):return {"name":p.name,"active":p.particles.size(),"released_bits":PackedFloat32Array([p.released]).to_byte_array().decode_u32(0)}),"global_systems":app.particle_fx.systems.size(),"paused":app.sim.paused,"owner_state":death_burst_owner.get("state",-1),"owner_retained":app.sim.enemies.has(death_burst_owner),"sprite_life_bits":death_burst_owner.get("death_sprites",[]).map(func(owned):return PackedFloat32Array([owned.life]).to_byte_array().decode_u32(0))}
		record.death_burst.splashes=death_burst_owner.get("death_sprites",[]).map(splash_fields)
		record.limit="Actual lethal Simulation event/Main kill/ParticleFX newborn parent packets; independent original fullCreep.Update count/clock rows. Actual shared owner counts, local clocks, splash state, retained state2 and final destruction are checked. Full original construction/attached-smoke/owner render/culling/sharedRNG/GPU remain incomplete."
	if name.begins_with("decal-"):
		record.decals=app.sim.decals.items.map(func(d):return {"id":d.id,"texture":d.texture,"position":[d.position.x,d.position.y],"scale_bits":PackedFloat32Array([d.scale]).to_byte_array().decode_u32(0),"clock_bits":PackedFloat32Array([d.clock]).to_byte_array().decode_u32(0),"alpha_bits":PackedFloat32Array([d.alpha]).to_byte_array().decode_u32(0),"deleted":d.deleted,"fading":d.fading,"variant":d.get("variant","")})
		record.decal_cells=app.sim.decals.cells.values().map(func(members):return members.size())
		record.limit="Controlled actual Simulation lethal callback/zero-delta cleanup and original-decal clock poses, real preserved textures under Main ground/owner passes. This isolated crater fixture uses damage kind2 to omit the separately verified splash. Retained owner state now runs in the shared simulation. No original global RNG/GPU/whole owner/death fidelity claim."
	if name.begins_with("creep-hit-"):
		record.hit_fields=app.sim.enemies.map(func(e):return {"id":e.id,"active":e.get("hit_active",false),"running":e.get("hit_running",false),"elapsed_bits":PackedFloat32Array([e.get("hit_elapsed",0.0)]).to_byte_array().decode_u32(0),"last_kind":e.get("hit_last_kind",0),"freeze_remaining":e.get("freeze_remaining",0),"native_air":e.native_air})
		record.ordered_canvas=app.battle_uses_ordered_canvas
		record.ordered_spans=app.ordered_battle_canvas.spans.filter(func(span):return span.visible and app.ordered_battle_canvas.visible).map(func(span):return span.material!=null)
		record.paused=app.sim.paused
		record.limit="Controlled preserved creep frames, fixed pose/delta and zero-amount original damage calls (which also trigger flash), actual Simulation/Main fields and per-owner ordered ONE/ONE pass. Full original caller/death/culling/GPU/equivalent-input fidelity remains open."
	if name.begins_with("creep-clock-"):
		var creep=app.sim.enemies[0]
		record.creep_clocks=[]
		for state in app.creep_animation_owners.get(int(creep.id),{}).get("clocks",[]):
			if state.is_empty():continue
			record.creep_clocks.append({"phase_bits":PackedFloat32Array([state.phase]).to_byte_array().decode_u32(0),"frame":state.frame,"stopped":state.stopped,"name":state.name})
		record.creep_freeze={"remaining":creep.freeze_remaining,"attached":creep.freeze_attached,"room_active":app.sim.freeze_state.room_active,"divisor":creep.animation_divisor,"multiplier":creep.animation_multiplier}
		record.limit="Controlled fixed-position Marine, actual imported12-frame17FPS art and owned render clocks. Real isolated simulation slow/freeze/expiry bridge; supplied direction/attack inputs and delta. Full callers/culling/room clock producer/original GPU remain open."
	if name.begins_with("creep-hover-"):
		var creep=app.sim.enemies[0];var authored=creep.def.traits.get("offset",[0,0])
		var offset:Vector2=creep.get("animator_offset",Vector2(authored[0],authored[1]))
		var body:Vector2=app.creep_animator_position(creep);var health:Vector2=app.creep_health_layout(creep).origin
		record.creep_hover={"resource":str(creep.def.filename),"phase_bits":splash_bits(float(creep.get("hover_phase",0))),"offset_bits":[splash_bits(offset.x),splash_bits(offset.y)],"body_bits":[splash_bits(body.x),splash_bits(body.y)],"raw_position":[creep.visual_pos.x,creep.visual_pos.y],"health_bits":[splash_bits(health.x),splash_bits(health.y)],"multiplier_bits":splash_bits(creep.animation_multiplier),"freeze_attached":creep.freeze_attached,"freeze_remaining":creep.freeze_remaining,"paused":app.sim.paused}
		record.limit="Real Light Tank resource flags/authored offset and owner hover/Freeze/pause updates on a supplied fixed position. Exact original constructor-derived tail phase/offset bits; unscaled body anchor and raw health anchor. Animation frame held for visual comparison; full original movement/state callers/Fly/portal/audio/GPU remain open."
	if name.begins_with("creep-status"):
		record.status=app.sim.enemies.map(func(e):return {"id":e.id,"state":e.state,"light":e.draw_light,"freeze_remaining":app.sim.freeze_until-app.sim.clock_ms,"slow_pending":e.slow_pending,"coefficient":app.CreepStatus.coefficient(e.draw_light),"active":app.CreepStatus.active(e.state,app.sim.freeze_until-app.sim.clock_ms,e.slow_pending),"layers":app.CreepStatus.layers(e.visual_layers).size()})
		record.limit="Supplied status states and original direct-frame screen pass. Full lifecycle/additive hit/GPU equivalence remain open."
	if name.begins_with("creep-light"):
		record.creep_lights=app.sim.enemies.map(func(e):
			var tint=app.creep_body_tint(e)
			return {"id":e.id,"type":e.type,"native_air":e.native_air,"draw_light":e.draw_light,"tint":[tint.r,tint.g,tint.b,tint.a]})
		record.limit="Supplied normal-body brightness from original GL caller. Frozen actor pose; original GPU, birth/status overlays and full owner ordering remain open."
	if name.begins_with("creep-health"):
		record.creep_health=app.sim.enemies.map(func(e):
			var health=app.creep_health_layout(e)
			return {"id":e.id,"hp":e.hp,"max_hp":e.max_hp,"visible":not health.is_empty(),"origin":[health.origin.x,health.origin.y] if not health.is_empty() else [],"fill_size":[health.fill.size.x,health.fill.size.y] if not health.is_empty() else [],"alpha":health.color.a if not health.is_empty() else 0})
		record.limit="Supplied normal/air/lift/growth health poses; preserved32x16 textures at original animator anchor and float32 crop. Complete portal/state lifetime and original GPU remain open."
	if name.begins_with("air-missile-owner"):
		var phases=app.enemy_missile_passes()
		record.owner_body_count=phases.body.get(920,[]).size()
		record.before_air_count=phases.before_air.size()
		record.limit="Supplied live owner and original body flag; body pass versus cleared-flag before-air submission. No original GPU/collision/death-lifetime equivalence."
	if name.begins_with("placement-phase"):
		record.draw_trace=app.placement_draw_trace.duplicate()
		record.grid=app.show_grid
		record.build_type=app.build_type
		record.limit="Synthetic aircraft/drag-preview overlap; actual draw trace compared to original full room/map routing. Mine/portal body registration, original GPU and whole owner order remain open."
	if name.begins_with("magic-depth"):
		record.body_order=app.battle_objects().filter(func(o):return o.has("mine") or o.has("tower")).map(func(o):return {"kind":"mine" if o.has("mine") else "tower","depth":o.y,"preview":o.get("preview",false)})
		record.portal_before=app.battle_portal_objects().map(func(p):return {"position":[p.pos.x,p.pos.y],"depth":p.depth,"preview":p.preview})
		record.limit="Supplied registered-mine depth/portal-before poses. Original constructor/position/vtable routing is independently probed; whole registry ties, portal growth/expiry and GPU equivalence remain open."
	if name.begins_with("portal-lifecycle"):
		record.lifecycle=app.sim.portals[0].presentation.duplicate(true) if not app.sim.portals.is_empty() else {}
		record.registered_gates=app.sim.portals.size()
		record.rendered_gates=app.battle_portal_objects().map(func(p):return {"state":p.gate_state,"scale":p.scale,"frame":p.frame,"preview":p.preview})
		record.limit="Real isolated portal placement/pause/expiry bridge with original float32 scale/state/timer fixture. Complete creep transfer, animator clock/raster, registry ties and GPU equivalence remain open."
	if name.begins_with("portal-creep"):
		var e=app.sim.enemies[0]
		var pose=e.portal_pose
		var owners=app.particle_fx.systems.filter(func(system):return str(system.owner).begins_with("enemy:%d:"%int(e.id)))
		record.portal_creep={"state":pose.state,"clock":pose.clock,"scale":[pose.scale.x,pose.scale.y],"base_scale":[app.sim.creep_portal_base(e).x,app.sim.creep_portal_base(e).y],"alpha":pose.anim_alpha,"particles_visible":pose.particles_visible,"systems":owners.size(),"hidden_systems":owners.filter(func(system):return bool(system.get("owner_hidden",false))).size(),"particles":owners.reduce(func(total,system):return total+system.particles.size(),0),"native_groups":SpiceNative.particle_batches(owners,false,app.particle_fx.clock_ms,Vector2.ZERO,1).size()+SpiceNative.particle_batches(owners,true,app.particle_fx.clock_ms,Vector2.ZERO,1).size()}
		record.limit="Supplied fixed-position mature Marine transit ages and owner freeze particles. Source float32 body/shadow/health/particle-visibility fields are independently checked; real simulation queue/path bridge is separately exercised. No original path/GPU/complete owner-interleaving equivalence."
	if name.begins_with("electricity") or name=="active-defense":
		record.towers=app.sim.towers.map(func(t):return {"type":t.type,"level":t.level,"filename":t.def.filename,"position":[t.pos.x,t.pos.y]})
		record.bolts=app.effects.filter(func(e):return e.kind=="shot").map(func(e):return {"texture":e.texture,"source":[e.points[0].x,e.points[0].y],"target":[e.points[-1].x,e.points[-1].y],"ball_source":[e.ball_source.x,e.ball_source.y],"ball":e.ball,"scatter":e.scatter,"ribbon_alpha":e.get("ribbon_alpha",1),"clock":e.get("bolt_clock",{}).duplicate(true)})
		record.render_slots=app.bolt_renderer.slots.filter(func(s):return s.visible).map(func(s):return {"texture":s.effect.texture,"atlas_pixels":[s.product.size.x,s.product.size.y],"atlas_rect":[s.atlas_rect.position.x,s.atlas_rect.position.y,s.atlas_rect.size.x,s.atlas_rect.size.y],"rectangle":[s.screen_rect.position.x,s.screen_rect.position.y,s.screen_rect.size.x,s.screen_rect.size.y]})
	captures.append(record)

func splash_fields(owned:Dictionary) -> Dictionary:
	var resource=Content.animations.get("creeps/"+str(death_burst_owner.def.filename),{})
	var texture=Content.tex(str(resource.get("textures",{}).get(str(owned.texture),{}).get("texture","")))
	var size=texture.get_size()*owned.scale
	return {"life_bits":splash_bits(owned.life),"scale_bits":[splash_bits(owned.scale.x),splash_bits(owned.scale.y)],"rgba_bits":[splash_bits(1),splash_bits(1),splash_bits(1),splash_bits(owned.alpha)],"size_bits":[splash_bits(size.x),splash_bits(size.y)]}
func splash_bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)

func pose_beam_tower(type:int,level:int) -> void:
	var tower=app.sim.towers[0]
	tower.type=type;tower.level=level;tower.def=app.sim.tower_data(type,level);tower.depth_filename=tower.def.filename
	check(tower.def.filename=="tower"+str(type)+"_"+str(level),"beam fixture uses the matching authored tower form")

func mouse(pos:Vector2,pressed:bool) -> void:
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=pos;event.pressed=pressed
	get_viewport().push_input(event,true)

func motion(pos:Vector2) -> void:
	var event=InputEventMouseMotion.new();event.position=pos;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event,true)

func verify_core_blend() -> void:
	# Exercise the actual shared beam material, texture alpha, vertex opacity
	# and native OpenGL framebuffer. The expected SRC_ALPHA,ONE arithmetic
	# uses explicit synthetic texels, not an original-device pixel oracle.
	for alpha in [64,128]:
		for opacity in [0.5,1.0]:
			var viewport=SubViewport.new();viewport.size=Vector2i(16,8);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
			var background=ColorRect.new();background.size=Vector2(16,8);background.color=Color(26/255.0,26/255.0,26/255.0,1);viewport.add_child(background)
			var source=Image.create(4,4,false,Image.FORMAT_RGBA8);source.fill(Color(1,64/255.0,0,alpha/255.0))
			var texel=source.get_pixel(0,0)
			var quad=TextureRect.new();quad.texture=ImageTexture.create_from_image(source);quad.size=Vector2(16,8);quad.material=app.bolt_renderer.additive_material;quad.modulate.a=opacity;viewport.add_child(quad)
			await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
			var image=viewport.get_texture().get_image()
			check(image!=null,"native beam blend readback")
			if image!=null:
				var actual=image.get_pixel(8,4);var expected=Color(background.color.r+texel.r*texel.a*texel.a*opacity,background.color.g+texel.g*texel.a*texel.a*opacity,background.color.b+texel.b*texel.a*texel.a*opacity,1)
				for i in range(3):check(absf(actual[i]-expected[i])<2.5/255.0,"original premultiplied SRC_ALPHA,ONE core blend")
				core_blend_samples.append({"texture_alpha_byte":alpha,"vertex_opacity":opacity,"actual":[actual.r,actual.g,actual.b],"expected":[expected.r,expected.g,expected.b]})
			viewport.queue_free();await get_tree().process_frame

func verify_ordered_blend() -> void:
	# Actual BoltRenderer slots, cropped product targets and shared shaders.
	# Uniform synthetic texels and straight ribbons make the center pixel's
	# expected native blend arithmetic independent of original GPU raster.
	var ball_key="res://assets/sfx/bolt_ball3_small.png"
	var original_ball=Content.tex(ball_key)
	var ball_texel=Color(51/255.0,77/255.0,102/255.0,128/255.0)
	var ball_image=Image.create(4,4,false,Image.FORMAT_RGBA8);ball_image.fill(ball_texel)
	ball_texel=ball_image.get_pixel(0,0);Content.texture_cache[ball_key]=ImageTexture.create_from_image(ball_image)
	var texels=[Color(1,102/255.0,102/255.0,64/255.0),Color(102/255.0,102/255.0,1,230/255.0)]
	for i in range(2):
		var image=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(texels[i]);texels[i]=image.get_pixel(0,0)
		Content.texture_cache["res://qa-beam-"+str(i)]=ImageTexture.create_from_image(image)
	for order in [[0,1],[1,0]]:
		for source_ball in [false,true]:
			var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
			var background=ColorRect.new();background.size=Vector2(64,64);background.color=Color(26/255.0,38/255.0,51/255.0,1);viewport.add_child(background)
			var fixture=BlendFixture.new();viewport.add_child(fixture)
			var renderer=load("res://scripts/bolt_renderer.gd").new();renderer.app=fixture;fixture.add_child(renderer)
			var expected=Vector3(background.color.r,background.color.g,background.color.b)
			for index in order:
				var opacity=1.0 if index==0 else 0.7
				var path=PackedVector2Array()
				for i in range(7):path.append(Vector2(4+i*56.0/6.0,32))
				fixture.effects.append({"kind":"shot","type":10,"points":path,"texture":"qa-beam-"+str(index),"born":0,"ribbon_alpha":opacity,"ball":source_ball,"ball_source":Vector2(32,32),"ball_flip":Vector2i.ZERO,"bolt_clock":{"alive":true,"opacity":opacity}})
				if source_ball:
					expected+=Vector3(ball_texel.r,ball_texel.g,ball_texel.b)*ball_texel.a*ball_texel.a*opacity
				var texel=texels[index];var broad=Vector3(texel.r,texel.g,texel.b)*texel.a*float(int(opacity*255*0.25))/255.0
				expected=expected*(Vector3.ONE-broad)+broad
				expected+=Vector3(texel.r,texel.g,texel.b)*texel.a*texel.a*opacity
				expected=expected.clamp(Vector3.ZERO,Vector3.ONE)
			renderer.prepare()
			check(renderer.slots[0].product==renderer.slots[1].product and renderer.find_children("*","SubViewport",true,false).size()==1,"ordered bolts share a single broad-product atlas")
			check(not renderer.slots[0].atlas_rect.intersects(renderer.slots[1].atlas_rect),"independent broad products occupy nonoverlapping atlas tiles")
			for i in range(2):
				var slot=renderer.slots[i]
				check(slot.ball.get_index()<slot.remaining.get_index() and slot.remaining.get_index()<slot.ink.get_index() and slot.ink.get_index()<slot.core.get_index(),"actual slot preserves source/broad/core ordering")
				check(slot.get_index()<renderer.slots[1].get_index() if i==0 else slot.effect.texture==fixture.effects[1].texture,"actual slot order preserves the effect sequence")
			await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw(true)
			var image=viewport.get_texture().get_image()
			check(image!=null,"ordered native blend readback")
			if image!=null:
				var pixel=image.get_pixel(32,32);var actual=Vector3(pixel.r,pixel.g,pixel.b)
				for channel in range(3):check(absf(actual[channel]-expected[channel])<3.5/255.0,"per-bolt broad attenuation of earlier additive ink")
				ordered_blend_samples.append({"order":order,"source_ball":source_ball,"actual":[actual.x,actual.y,actual.z],"expected":[expected.x,expected.y,expected.z]})
			viewport.queue_free();await get_tree().process_frame
	Content.texture_cache[ball_key]=original_ball
	for i in range(2):Content.texture_cache.erase("res://qa-beam-"+str(i))
	for ball in [false,true]:
		var samples=ordered_blend_samples.filter(func(c):return c.source_ball==ball)
		check(absf(samples[0].actual[0]-samples[1].actual[0])>0.005,"reversing colored beams changes native pixels as required by the original noncommutative passes")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):destination=arg.trim_prefix("--capture-root=")
	if destination.is_empty():destination=ProjectSettings.globalize_path("res://../builds/presentation-gallery")
	DirAccess.make_dir_recursive_absolute(destination)
	check(app.test_session and Profile.path!="user://profile.json","isolated presentation fixture")
	app.set_process(false)
	app.transition.set_process(false)
	app.map_underlay.story.set_process(false)
	Profile.data=Profile.fresh();Profile.data.settings.music=false;Profile.data.settings.sound=false
	await verify_core_blend()
	await verify_ordered_blend()
	app.start_mission("1",true,false)
	app.sim.paused=false
	app.tutorial.pose(3);app.tutorial_step=3;app.refresh_controls()
	app.map_underlay.prepare()
	check(not app.map_underlay.water.visible,"Training uses the stable water appearance observed in the main visual guide")
	app.qa_water=true
	var mask_bounds=Content.maps["1"].water.mask_uv
	check(mask_bounds.size()==4 and float(mask_bounds[0])==0 and float(mask_bounds[1])==2 and float(mask_bounds[2])==0 and float(mask_bounds[3])==2,"native mask frame bounds retain the water texture512 frame on the256 mask")
	check(Vector2(Content.maps["1"].water.segments[0],Content.maps["1"].water.segments[1])==Vector2(15,28),"even authored water columns remain unchanged")
	await snapshot("water-training-000")
	app.sim.advance_frame(333)
	var phase=app.sim.water_phase
	check(absf(phase-0.08325000107288361)<0.000001,"native float32 water update in live battle time")
	app.sim.paused=true;app.sim.advance_frame(2000)
	check(app.sim.water_phase==phase,"paused battle freezes water phase")
	app.sim.paused=false
	app.sim.water_phase=0.5;await snapshot("water-training-200")
	app.sim.map=Content.maps["814"];app.camera=Vector2(512,512);app.sim.water_phase=0;await snapshot("water-814-000")
	app.sim.water_phase=0.5;await snapshot("water-814-200")
	app.qa_water=false
	app.start_mission("1",true,false);app.sim.paused=false;app.tutorial.pose(3);app.tutorial_step=3;app.refresh_controls()
	check(app.ClassicUI.dock_origin(app)==Vector2(321,702),"native tablet tray origin")
	for i in range(6):
		var frame=app.ClassicUI.tower_icon(app,app.Simulation.ROOT_TYPES[i])
		check(not frame.is_empty(),"authored root icon "+str(i))
	await snapshot("tutorial-tray")
	var original_money=app.sim.money;var original_spice=Profile.data.spice
	var initial_plate=app.ClassicUI.wallet_pose(app).plate_position.x
	app.sim.money=123456;Profile.data.spice=10001;app.refresh_controls()
	check(app.ClassicUI.wallet_pose(app).plate_position.x<initial_plate,"native money plate expands left for wider currency text")
	await snapshot("hud-wide-wallet")
	Profile.data.spice=original_spice;app.sim.money=0;app.select_build(1)
	app.ClassicUI.Wallet.flash_advance(app.hud_money_flash,210.62)
	check(app.hud_money_flash.active and app.ClassicUI.Wallet.flash_color(app.hud_money_flash).g<0.000001,"unaffordable tray choice reaches original red money pulse")
	await snapshot("hud-money-flash-red")
	app.ClassicUI.Wallet.flash_advance(app.hud_money_flash,1800);app.sim.money=original_money;app.build_type=0;app.refresh_controls()
	check(not app.hud_money_flash.active,"money flash returns white after two scaled seconds")
	await snapshot("hud-money-flash-expired")
	app.tutorial.fade_state={"alpha":0.0,"previous_ms":0.0,"opaque":false};app.refresh_controls()
	app.tutorial.Fade.advance_in(app.tutorial.fade_state,200)
	app.tutorial.Fade.advance_in(app.tutorial.fade_state,200)
	app.refresh_controls();await snapshot("tutorial-fade-020")
	check(app.tutorial.fade_state.alpha==0.5,"native tutorial fade uses the previous elapsed frame")
	app.start_mission("1",true,false)
	app.portrait_view.advance(0.25)
	check(app.portrait_view.layers.size()==1 and absf(app.portrait_view.alpha(app.portrait_view.layers[0])-0.5)<0.000001,"UIKit-style portrait opening has an independent500ms clock")
	await snapshot("portrait-opening-025",false)
	app.portrait_view.advance(0.25)
	var portrait_point=app.desired_portrait.layout.hit_rect.get_center()
	mouse(portrait_point,true);motion(portrait_point+Vector2(20,0));mouse(portrait_point+Vector2(20,0),false)
	check(app.tutorial.page==0 and not app.portrait_view.layers[0].closing,"a20-point portrait drag does not dismiss")
	mouse(portrait_point,true);mouse(portrait_point+Vector2(20,0),false)
	check(app.tutorial.page==0,"release displacement is checked even without a preceding motion event")
	mouse(portrait_point,true);motion(portrait_point+Vector2(19.9,0));mouse(portrait_point+Vector2(19.9,0),false)
	check(app.tutorial.page==1,"a short portrait release advances exactly once")
	app.portrait_view.advance(0.25)
	check(app.portrait_view.layers[0].closing and app.tutorial.page==1 and app.tutorial.display_page==0,"portrait removal begins immediately while the old GL page remains")
	await snapshot("portrait-closing-025",false)
	app.start_mission("1",true,false);app.tutorial.pose(3);app.tutorial_step=3;app.refresh_controls();app.portrait_view.advance(0.5)
	app.tutorial.pose(3);app.refresh_controls()
	check(app.TutorialView.layout(app).images.filter(func(i):return "line_pointer_" in i.path).size()==1,"unbuilt tablet tutorial shows its single orientation arrow")
	var point=app.map_origin()+app.sim.center(7,4)*app.map_scale()
	var before=app.sim.money;var camera=app.camera
	mouse(app.ClassicUI.tower_rect(app,0).get_center(),true)
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;get_viewport().push_input(cancel,true)
	mouse(point,false)
	check(not app.tower_drag and app.sim.towers.is_empty() and app.sim.money==before,"cancel before the first motion consumes its release")
	mouse(app.ClassicUI.tower_rect(app,0).get_center(),true)
	check(app.tower_drag,"tray press starts drag")
	motion(point)
	check(app.tower_drag_moved and app.camera==camera,"drag moves preview without panning")
	await snapshot("drag-preview")
	check(app.build_hex_view.shape.quads.size()>1 and app.build_hex_view.shape.lines.size()>20,"native moving preview includes neighboring blocked fills and outline/cross submissions")
	app._process(0.45)
	await snapshot("drag-preview-045")
	check(app.tower_preview_state.frame==4 and app.tower_preview_facing==36,"inactive preview plays the original Rot frames at10FPS")
	mouse(point,false)
	check(app.sim.towers.size()==1 and app.sim.money==before-20 and not app.tower_drag and app.build_type==0,"legal drop builds exactly one tower and debits20")
	check(app.sim.towers[0].angle==36,"placed tower retains the last rendered preview facing")
	check(not app.TutorialView.layout(app).images.any(func(i):return "line_pointer_" in i.path),"first actual drop removes both build orientation arrows")
	await snapshot("drag-placed")
	mouse(app.ClassicUI.tower_rect(app,0).get_center(),true);motion(point);mouse(point,false)
	check(app.sim.towers.size()==1 and app.sim.money==before-20,"occupied drop is rejected without debit")
	check(app.notice_until<=app.ui_time_ms(),"occupied drag rejection does not add an invented status banner")
	mouse(app.ClassicUI.tower_rect(app,0).get_center(),true);motion(Vector2(20,400));mouse(Vector2(20,400),false)
	check(app.sim.towers.size()==1 and app.sim.money==before-20,"invalid terrain drop is rejected without debit")
	mouse(app.ClassicUI.tower_rect(app,0).get_center(),true);motion(point+Vector2(70,70))
	var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;get_viewport().push_input(escape,true)
	mouse(point+Vector2(70,70),false)
	check(not app.tower_drag and app.sim.towers.size()==1,"cancel consumes pending drag release")
	app.notice_until=0
	var preview_sim=app.sim;var preview_tutorial=app.tutorial;var preview_step=app.tutorial_step
	var preview_profile=Profile.data.duplicate(true)
	# Isolated renderer fixture: normal campaign stock/level gates are not
	# bypassed by the game, and this is not an earned progression result.
	Profile.data.level=15;Profile.data.abilities.m_mine=5;Profile.data.abilities.m_portal=5
	app.start_mission("8",true,false)
	app.sim.next_wave_ms=1000000
	var mine_point=app.map_origin()+app.sim.center(8,9)*app.map_scale()
	app.magic("m_mine");motion(mine_point)
	check(app.magic_preview_position==mine_point,"magic preview follows the delivered viewport pointer")
	await snapshot("mine-preview")
	check(app.magic_placement=="m_mine" and not app.build_hex_view.shape.lines.is_empty(),"mine placement renders original70px neighborhood and inactive sprite")
	mouse(mine_point,true);mouse(mine_point,false)
	check(app.sim.mines.size()==1 and app.sim.abilities.m_mine==4,"native viewport mine placement consumes exactly one stock")
	await snapshot("mine-arming-000")
	app.sim.advance(2520)
	await snapshot("mine-arming-250")
	app.sim.advance(2520)
	check(app.sim.clock_ms>=app.sim.mines[0].ready,"placed mine reaches its original arming deadline")
	await snapshot("mine-armed")
	app.magic("m_portal");motion(mine_point+Vector2(65,0))
	await snapshot("portal-preview-entry")
	var entry_point=app.map_origin()+app.sim.center(12,9)*app.map_scale()
	mouse(entry_point,true);mouse(entry_point,false)
	motion(mine_point)
	await snapshot("portal-preview-exit")
	check(app.sim.portals.size()==1 and app.sim.abilities.m_portal==5 and app.magic_placement=="m_portal","entry preview changes to red without consuming portal stock")
	check(app.notice_until<=app.ui_time_ms(),"portal exit preview has no invented status banner")
	await snapshot("portal-lifecycle-pending")
	app.sim.mines.clear()
	mouse(mine_point,true);mouse(mine_point,false)
	check(app.sim.portals.size()==2 and app.sim.abilities.m_portal==4 and app.magic_placement.is_empty(),"native second gate connects and consumes portal stock once")
	await snapshot("portal-lifecycle-connected-000")
	app.sim.advance_frame(250)
	check(app.battle_portal_objects().all(func(p):return p.scale==0.75 and p.gate_state==2),"native portal bodies use original half-open scale")
	await snapshot("portal-lifecycle-open-250")
	app.sim.advance_frame(250)
	check(app.battle_portal_objects().all(func(p):return p.scale==1 and p.gate_state==2),"native portal bodies complete original growth")
	await snapshot("portal-lifecycle-open-500")
	var portal_state=app.sim.portals[0].presentation
	portal_state.remaining=250
	app.sim.advance_frame(250)
	check(portal_state.gates[0].state==4 and portal_state.gates[0].scale==0.75,"native portal expiry starts original closing clock")
	await snapshot("portal-lifecycle-closing-250")
	app.sim.advance_frame(500)
	await snapshot("portal-lifecycle-closing-750")
	app.sim.advance_frame(250)
	check(portal_state.deleted and app.sim.portals.size()==2 and app.battle_portal_objects().is_empty(),"native zero-sized deleted gates hide before manager removal")
	await snapshot("portal-lifecycle-hidden-1000")
	app.sim.advance_frame(30)
	check(app.sim.portals.is_empty(),"native deleted pair leaves manager on following update")
	await snapshot("portal-lifecycle-removed")
	app.effects.clear();app.particle_fx.reset()
	var transported=app.sim.spawn_enemy(1,0,"",1142,false)
	transported.pos=app.sim.center(10,9);transported.visual_pos=transported.pos;transported.draw_light=1;transported.hp=transported.max_hp*0.5
	transported.portal_pose=app.sim.CreepPortal.create(app.sim.creep_portal_base(transported),1,float(transported.def.traits.get("shadow_scale_factor",1)))
	# Constructor roots start empty. Warm their actual clock and slow-admission
	# phases before holding the seven controlled portal poses for comparison.
	for frame in 18:
		transported.slow_pending=.5
		app.sim.CreepFreeze.advance_fields(transported,30,0)
		app.sim.particle_state.refresh_creep(app.sim,transported)
		app.sim.particle_state.update_creep_fields(transported,app.sim.enemy_visual_aim_point(transported),transported.dir)
		app.sim.particle_state.advance_creep(transported,30)
	check(transported.particle_roots.size()==5 and transported.particle_roots.any(func(sys):return str(sys.creep_alias)=="freeze" and not sys.particles.is_empty()),"native portal fixture warms original empty constructor freeze root")
	app.sim.particle_state.refresh_creep(app.sim,transported);app.particle_fx.advance(app.sim,0)
	await snapshot("portal-creep-normal")
	transported.portal_pose.state=1
	var transit_age=0
	for age in [75,150,300]:
		app.sim.CreepPortal.advance(transported.portal_pose,age-transit_age,app.sim.creep_portal_base(transported),1,float(transported.def.traits.get("shadow_scale_factor",1)))
		transit_age=age;app.sim.particle_state.refresh_creep(app.sim,transported);app.particle_fx.advance(app.sim,0)
		await snapshot("portal-creep-enter-%03d"%age)
	check(transported.portal_pose.state==3 and transported.portal_pose.anim_alpha==0,"native waiting transit retains zero-size/alpha body and health")
	transported.portal_pose.state=2;transported.portal_pose.clock=0;transit_age=0
	for age in [75,150,300]:
		app.sim.CreepPortal.advance(transported.portal_pose,age-transit_age,app.sim.creep_portal_base(transported),1,float(transported.def.traits.get("shadow_scale_factor",1)))
		transit_age=age;app.sim.particle_state.refresh_creep(app.sim,transported);app.particle_fx.advance(app.sim,0)
		await snapshot("portal-creep-exit-%03d"%age)
	check(transported.portal_pose.state==0 and transported.portal_pose.anim_alpha==1,"native exit pose restores original full body and health")
	Profile.data=preview_profile
	app.magic_placement="";app.sim=preview_sim;app.tutorial=preview_tutorial;app.tutorial_step=preview_step
	app.particle_fx.reset();app.particle_fx.advance(app.sim,0)
	app.build_hex_view.reset();app.refresh_controls()
	app.transition.open(0,3)
	app.transition.advance(0.1)
	await snapshot("transition-cover-010")
	var count=app.sim.towers.size()
	mouse(app.ClassicUI.tower_rect(app,0).get_center(),true);motion(point+Vector2(60,0));mouse(point+Vector2(60,0),false)
	check(not app.tower_drag and app.sim.towers.size()==count,"transition blocks battlefield and tray input")
	app.transition.advance(0.15)
	await snapshot("transition-cover-025")
	while app.transition.phase!=1:app.transition.advance(0.01)
	app.screen="loading";app.loading_name="Tutorial";app.loading_started=0
	app.notice_until=0
	app.refresh_controls()
	app.transition.close()
	app.transition.advance(0.1)
	await snapshot("transition-reveal-010")
	app.transition.advance(0.25)
	await snapshot("transition-reveal-035")
	while app.transition.phase!=3:app.transition.advance(0.01)
	for time in [0.25,1.0,2.5]:
		app.elapsed_ui=time
		await snapshot("loading-%03d"%int(time*100))
	app.loading_kind="departure";app.elapsed_ui=0;app.reward_fx.reset();app.start_departure_particles();app.refresh_controls()
	for time in [0.25,1.0,2.5]:
		while app.elapsed_ui<time:app._process(minf(0.03,time-app.elapsed_ui))
		await snapshot("departure-%03d"%int(time*100))
	app.screen="game";app.sim.outcome="victory";app.sim.built_count=4;app.sim.kills=20;app.sim.upgrade_top_count=0
	app.tutorial.pose(17);app.tutorial_step=17
	app.reward_fx.reset();app.reward_bar_emitting=false;app.result_previous_xp=0
	app.reward_bar_releasing=false;app.reward_bar_previous_tip=Vector2.ZERO
	app.reset_reward_bursts()
	Profile.data.xp=8;app.battle_initial_xp=0;app.result_started=0;app.elapsed_ui=0
	# Explicit zero-delay arithmetic fixture retained for the historical poses.
	# The ordinary result lifecycle inherits the active room's closed timer.
	app.result_closed_delay=0;app.result_initial_delay=0
	app.notice_until=0;app.refresh_controls()
	var result_control_count=app.ui.get_child_count()
	for time in [0.5,2.0,4.0]:
		await advance_result_until(time)
		await snapshot("result-%03d"%int(time*100),true,true)
	check(app.ui.get_children().filter(func(n):return n.has_meta("result_spice")).all(func(n):return n.modulate.a==0),"spice reward waits for the original post-XP clock")
	var spice_rows=app.ui.get_children().filter(func(n):return n.has_meta("result_spice"))
	check(spice_rows.size()==1 and spice_rows[0].text==app.result_spice_text() and spice_rows[0].get_theme_font("font")==app.font and spice_rows[0].get_theme_font_size("font_size")==20,"spice reward uses one original regular20pt text object")
	await advance_result_until(5.025)
	await snapshot("result-spice-entering",true,true)
	await advance_result_until(5.25)
	check(spice_rows[0].modulate.a>0 and spice_rows[0].modulate.a<1 and spice_rows[0].scale.x>1 and spice_rows[0].position.x<app.results_origin().x+332,"native spice reveal enters enlarged and centered before settling")
	await snapshot("result-spice-growing",true,true)
	await advance_result_until(5.55)
	check(app.result_clock.spice_phase>=1 and app.ui.get_children().filter(func(n):return n.has_meta("result_spice")).all(func(n):return n.modulate.a==1),"spice reveal completes after its native500ms phase")
	check(app.ui.get_child_count()==result_control_count,"result UI does not accumulate tutorial labels each frame")
	check(app.reward_spice_burst and app.reward_burst_fx.systems.size()==7,"spice reveal emits seven original burst systems once")
	check(app.reward_burst_fx.systems.all(func(s):return s.definition.release_interval==5.0) and is_equal_approx(app.reward_burst_fx.clock_multiplier,1.6),"result bursts use the native release interval and particle clock")
	await snapshot("result-spice-555",true,true)
	app.battle_medals=[Content.catalog.tower_medals[0],Content.catalog.tower_medals[1]];app.refresh_controls()
	await advance_result_until(7.75)
	await snapshot("result-medal-growing",true,true)
	var growing=app.ui.get_children().filter(func(n):return n is TextureRect and n.has_meta("result_medal") and n.get_meta("result_medal")==0)[0]
	check(growing.size.x>43 and growing.size.x<60 and growing.modulate.a>0 and growing.modulate.a<1,"medal reveal shrinks from its native enlarged size")
	await advance_result_until(8.0)
	check(app.result_clock.medal_clock>0 and app.result_clock.medal_clock<1.5,"first medal's native slot opens before the second")
	await snapshot("result-medal-first",true,true)
	await advance_result_until(10.0)
	check(app.reward_medal_bursts.size()==2,"each revealed medal creates one original object burst")
	check(app.reward_burst_fx.systems.filter(func(s):return s.name=="WinSpiceBump").is_empty(),"spice burst has expired before the medal sequence finishes")
	check(app.ui.get_children().filter(func(n):return n.has_meta("result_medal")).all(func(n):return n.size==Vector2(43,43)),"completed medals use native truncated0.8 source size")
	await snapshot("result-medals",true,true)
	app.selected_medal=app.battle_medals[0].duplicate(true);app.refresh_controls();await snapshot("result-medal-description");app.selected_medal={};app.refresh_controls()
	var fractional_xp=Profile.data.xp;Profile.data.xp=9.5
	await snapshot("result-fractional-xp")
	check(SpiceNative.format_xp(app.displayed_xp(),false)=="10","result XP rounds fractional totals with the original libc format")
	Profile.data.xp=fractional_xp
	# Separate incremental sequence after an active room has already passed
	# the two-second delay, matching the recorded normal-length battle.
	app.elapsed_ui=0;app.result_started=-1;app.result_clock={};app.result_clock_age=0
	app.result_closed_delay=3;app.result_initial_delay=0;app.result_previous_xp=0
	app.reward_bar_releasing=false;app.reward_bar_previous_tip=Vector2.ZERO
	app.reward_fx.reset();app.reward_bar_emitting=false;app.reset_reward_bursts()
	app.battle_medals.clear();app.battle_spice_reward=3;app.refresh_controls()
	for time in [0.5,0.72,0.9,1.5,2.4,3.0,3.6,4.2,4.8,5.4,6.0]:
		await advance_result_until(time)
		if time==0.5:check(app.result_clock.xp_phase==0,"ordinary result XP waits for the opening fade")
		if time==0.9:check(app.result_clock.xp_phase>0 and app.result_clock.spice_phase==0,"ordinary result XP starts after fade without a new two-second delay")
		if time==3.0:check(app.result_clock.xp_phase>1 and app.result_clock.spice_phase==0,"ordinary result completes XP before the separate spice phase")
		if time==4.8:check(app.result_clock.spice_phase>=1 and app.reward_spice_burst,"ordinary result spice text and once-only burst reveal at the inherited clock age")
		await snapshot("result-room-%03d"%roundi(time*100),true,true)
	app.screen="world";app.selected_location="";app.elapsed_ui=0
	var decor_camera=app.world_camera;var decor_zoom=app.world_zoom
	app.world_camera=Vector2(1290,1720);app.world_zoom=0.625;app.world_decor.reset();app.world_decor_dt_ms=0
	check(Content.maps.lobby_map.animated_objects.size()==8,"all eight authored animated world objects are imported")
	for object in Content.maps.lobby_map.animated_objects:check(Content.tex(object.texture)!=null,"original world scenery texture resolves "+object.texture)
	app.refresh_controls();await snapshot("world-scenery-000")
	app.world_decor_dt_ms=250
	await snapshot("world-scenery-moving")
	app.world_camera=Vector2(940,1400);app.world_zoom=1
	app.world_blades.angles=[0.0,90.0,180.0,270.0,45.0]
	app.world_blades.speeds=[0.7,0.8,0.9,1.0,1.4]
	app.world_decor_dt_ms=0
	await snapshot("world-windmills-000")
	check(app.world_blades.visible and app.world_blades.items.size()==5,"world map renders all five original windmill quads")
	app.world_blades.advance(250)
	await snapshot("world-windmills-025")
	check(app.world_blades.angles[0]>29 and app.world_blades.angles[0]<30,"world windmill rotates with the original elapsed-time multiplier")
	app.world_camera=Vector2(400,400);app.world_zoom=1;app.world_clouds.reset();app.world_clouds.prepare()
	check(app.world_clouds.generators.size()==9 and app.world_clouds.generators.all(func(g):return g.systems.size()==50),"all nine original cloud generators start with50 systems")
	check(app.world_clouds.generators[6].systems.all(func(r):return r.systems[0].definition.color[0]==0.5),"initial clouds precede the native later color override")
	await snapshot("world-clouds-000")
	app.world_clouds.generators[7].systems[0].systems.clear()
	app.world_clouds.advance(80);app.world_clouds.prepare()
	check(app.world_clouds.generators[7].systems.size()==49,"native cloud capacity check occurs before dead-system removal")
	app.world_clouds.advance(0);app.world_clouds.prepare()
	check(app.world_clouds.generators[7].systems.size()==50 and app.world_clouds.generators[7].systems[-1].systems[0].particles.is_empty(),"replacement clouds retain the original delayed first emission")
	for i in range(60):app.world_clouds.advance(1000.0/30.0);app.world_clouds.prepare()
	check(app.world_clouds.rendered.size()==1 and app.world_clouds.rendered[0]==app.world_clouds.generators[7],"world clouds update only inside the original viewport circle")
	check(app.world_clouds.generators[0].systems[0].clock_ms==0,"offscreen world clouds retain their clock")
	check(app.world_clouds.generators[7].systems.all(func(r):return r.clock_ms>699 and r.clock_ms<1041),"world cloud particle clocks retain separate0.7-to1.0 rates")
	await snapshot("world-clouds-200")
	for i in range(180):app.world_clouds.advance(1000.0/30.0);app.world_clouds.prepare()
	await snapshot("world-clouds-800")
	app.world_camera=Vector2(2048,1536);app.world_zoom=0.2
	for i in range(480):app.world_clouds.advance(1000.0/30.0);app.world_clouds.prepare()
	check(app.world_clouds.generators.all(func(g):return g.systems.size()<=50),"world cloud emitters expire and remain inside their original capacity")
	check(app.world_clouds.generators[6].systems.any(func(r):return r.systems[0].definition.color[0]==0.25),"later northern clouds use the original half color override")
	await snapshot("world-clouds-wide")
	var footer_level=Profile.data.level;var footer_xp=Profile.data.xp
	Profile.data.level=2;Profile.data.xp=10.0;app.refresh_controls()
	await snapshot("world-xp-footer")
	check(app.ui.get_children().any(func(n):return n is Label and n.text=="xp: 10 / 55"),"world footer uses separately rounded native XP values and observed level2 upper threshold")
	Profile.data.level=footer_level;Profile.data.xp=footer_xp
	app.world_camera=Vector2(-5000,-5000);app.world_zoom=1;app.pan(Vector2.ZERO)
	check(app.world_origin()==Vector2.ZERO,"world panning cannot expose the upper or left map margin")
	app.zoom_at(app.view_center(),0.001)
	check(app.world_zoom==0.25 and app.world_origin()==Vector2.ZERO,"native tablet minimum zoom keeps the complete world within the canvas")
	app.refresh_controls();await snapshot("world-camera-minimum")
	app.zoom_at(app.view_center(),100)
	check(app.world_zoom==1.0,"native tablet maximum zoom remains1.0")
	app.world_decor_dt_ms=0;app.world_camera=decor_camera;app.world_zoom=decor_zoom
	app.selected_location="1"
	var loc=Content.location("1");app.world_camera=Vector2(float(loc.x),float(loc.y))-(Vector2(360,384)-app.view_center())
	app.refresh_controls();await snapshot("tutorial-modes")
	check(app.ClassicUI.mode_rows(app).size()==1 and app.ClassicUI.mode_rows(app)[0].name=="Training","tutorial has the original single Training option")
	check(not app.reward_fx.visible,"result particles are hidden immediately on the map")
	var training=app.ClassicUI.mode_rows(app)[0].rect.get_center()
	mouse(training,true);mouse(training,false)
	check(app.screen=="game" and app.tutorial!=null and app.tutorial.page==0,"actual viewport click activates the grouped Training option")
	app.screen="world"
	Profile.data.unlocks.append("tut");app.selected_location="2";loc=Content.location("2");app.world_camera=Vector2(float(loc.x),float(loc.y))-(Vector2(360,384)-app.view_center());app.refresh_controls()
	await snapshot("desert-modes")
	check(app.ClassicUI.mode_rows(app)[0].mode==2,"available new mode uses original gold state")
	var multiplayer_rows=app.ClassicUI.mode_rows(app).filter(func(r):return r.player_count>1)
	check(multiplayer_rows.size()==3 and multiplayer_rows.all(func(r):return r.player_count==2 and not r.enabled),"Desert static2-player metadata does not enable multiplayer")
	var player_counts=app.ui.find_children("*","Label",true,false).filter(func(n):return str(n.get_meta("mode_part",""))=="player_count")
	check(player_counts.size()==3 and player_counts.all(func(n):return n.text=="2 players" and n.get_theme_font_size("font_size")==14),"native fan renders all three preserved2-player labels")
	var offline_captions=app.ui.find_children("*","Label",true,false).filter(func(n):return n.text==Content.interface_tutorials.mode_texts.offline)
	check(offline_captions.size()==3 and offline_captions.all(func(n):return n.autowrap_mode==TextServer.AUTOWRAP_OFF),"native offline multiplayer captions retain the original single-line text")
	var prior_completed=Profile.data.completed.duplicate(true);var prior_unlocks=Profile.data.unlocks.duplicate()
	Profile.data.unlocks.append("mo1_sp");Profile.data.completed["8"]=1;app.refresh_controls()
	check(app.ClassicUI.mode_rows(app)[0].mode==3 and app.ClassicUI.mode_rows(app)[0].star,"completed mode uses blue state and left title star")
	await snapshot("desert-modes-completed")
	Profile.data.completed=prior_completed;Profile.data.unlocks=prior_unlocks;app.refresh_controls()
	app.fan_opened=app.elapsed_ui;app.refresh_controls()
	for i in range(15):app.ClassicUI.update_modes(app,10)
	check(absf(app.mode_states[0].geometry_alpha-0.5)<0.000001 and app.mode_states[0].text_alpha==0,"mode art moves over300ms while its text waits")
	check(app.ui.get_children().filter(func(n):return n.has_meta("fan_index")).all(func(n):return n.get_children().filter(func(c):return c is Button).all(func(c):return c.disabled)),"moving mode items ignore activation")
	await snapshot("mode-opening-015")
	for i in range(20):app.ClassicUI.update_modes(app,10)
	check(app.mode_states[0].geometry_alpha==1 and app.mode_states[0].text_alpha>0 and app.mode_states[0].text_alpha<0.1,"mode labels fade separately after the move")
	await snapshot("mode-text-035")
	for i in range(35):app.ClassicUI.update_modes(app,10)
	var previous_pulse=app.mode_states[0].pulse_alpha
	app.ClassicUI.update_modes(app,12.5)
	check(app.mode_states[0].pulse_alpha!=previous_pulse,"settled mode plate retains original pulse")
	await snapshot("mode-pulse-071")
	app.close_mode_fan()
	for i in range(15):app.advance_mode_fan(10)
	check(app.selected_location=="2" and app.fan_closing and absf(app.mode_states[0].geometry_alpha-0.5)<0.000001,"outside-close retains location during the native inward item animation")
	await snapshot("mode-closing-015")
	for i in range(55):app.advance_mode_fan(10)
	check(app.selected_location.is_empty() and not app.fan_closing,"mode parent releases its selected location after700ms")
	app.screen="story";app.story_location=loc;app.story_mission="8";app.refresh_controls();await snapshot("desert-story")
	check(app.story_image_rect().size==Vector2(1024,483),"story artwork retains its intrinsic dimensions")
	check(app.map_underlay.story.nodes.size()==30,"story retains the native30 glow nodes")
	for i in range(20):app.map_underlay.story.advance(25)
	await snapshot("desert-story-050")
	for i in range(30):app.map_underlay.story.advance(25)
	await snapshot("desert-story-125")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	app.sim.build(Vector2i(7,4),1);app.selected_tower=app.sim.towers[0].id;app.refresh_controls();await snapshot("selected-tower")
	app.selected_tower=-1;app.set_magic_inventory(true)
	var previous_profile=Profile.data.duplicate(true)
	Profile.data.level=2;Profile.data.spice=3;Profile.data.abilities.m_freeze=0;app.sim.abilities.m_freeze=0;app.refresh_controls()
	check(app.magic_panel_state.y==707 and app.magic_panel_state.height==265,"opening inventory updates the constructor's335px height to five deduplicated abilities")
	app.advance_magic_panel(250)
	check(app.magic_panel_state.y==574.5 and not app.magic_panel_state.opened,"magic inventory follows native500ms easing and disables items while moving")
	var refill=Vector2(480,665)
	mouse(refill,true);mouse(refill,false)
	check(Profile.data.spice==3 and app.sim.abilities.m_freeze==0,"moving inventory ignores item clicks")
	await snapshot("magic-opening-025")
	app.advance_magic_panel(250)
	check(app.magic_panel_state.y==442 and app.magic_panel_state.opened and app.magic_panel_root.find_children("*","Label",true,false).any(func(n):return n.text=="Tap to use or buy magic for spice."),"opened inventory uses recovered title and265px body")
	await snapshot("magic-inventory")
	refill=Vector2(480,533)
	mouse(refill,true);mouse(refill,false)
	check(Profile.data.spice==0 and app.sim.abilities.m_freeze==5 and app.magic_panel_state.opened,"refill click accepts the item description area, purchases five charges for3sp and keeps the inventory open")
	await snapshot("magic-refilled")
	mouse(refill,true);mouse(refill,false)
	check(app.sim.abilities.m_freeze==4 and app.sim.freeze_until>app.sim.clock_ms and app.magic_panel_state.closing and not app.magic_panel_state.opened,"next click activates one owned charge and starts closing")
	app.advance_magic_panel(250);await snapshot("magic-closing-025");app.advance_magic_panel(250)
	check(not app.magic_panel_state.visible and app.magic_panel_root.get_child_count()==0,"closed inventory removes controls only after the native slide finishes")
	Profile.data=previous_profile
	app.effects.clear();app.continuous_beams.clear()
	var a=app.sim.center(7,4);var b=app.sim.center(11,5)
	pose_beam_tower(10,1)
	app.handle_event({"kind":"beam","from":a,"to":b,"type":10,"tower_id":1,"enemy_id":1,"filename":"tower10_1","ms":0})
	app.sim.clock_ms=0
	check(app.effects.size()==1 and app.effects[0].ball and not app.effects[0].scatter,"Tesla restores original source ball without endpoint scatter")
	check(app.effects[0].ball_source==a+Vector2(0,-47),"ordinary beam starts at original center-minus7 plus authored turret offset")
	app.bolt_renderer.prepare()
	var beam_slot=app.bolt_renderer.slots[0]
	check(beam_slot.ball.get_index()<beam_slot.remaining.get_index() and beam_slot.ink.get_index()<beam_slot.core.get_index() and beam_slot.ball.material==app.bolt_renderer.additive_material,"each source ball shares the verified premultiplied additive material before its own broad/core ribbons")
	await snapshot("electricity")
	for i in range(8):app.advance_bolt_effects(30)
	app.advance_bolt_effects(10);app.sim.clock_ms=250
	check(absf(app.effects[0].bolt_clock.opacity-0.35)<0.000001 and app.effects[0].ribbon_alpha==1.0,"source ball fades on native threshold frames while saved ribbon colors stay unchanged")
	check(captures.filter(func(c):return c.name=="electricity")[0].bolts[0].clock.age==0,"captured beam clock remains an immutable capture-time record after live aging")
	await snapshot("electricity-fading")
	app.effects.clear();app.continuous_beams.clear();app.sim.clock_ms=0
	pose_beam_tower(12,1)
	app.handle_event({"kind":"beam","from":a,"to":b,"type":12,"tower_id":1,"enemy_id":1,"filename":"tower12_1","ms":0})
	check(app.effects.size()==1 and app.effects[0].ball and app.effects[0].scatter,"Gateway restores source ball and endpoint scatter")
	check(app.effects[0].texture=="assets/sfx/electric_bolt_orange.png" and Content.tex(app.effects[0].texture) is Texture2D,"Gateway resolves the authored orange texture rather than an untextured white strip")
	var initial_ball_source=app.effects[0].ball_source
	app.handle_event({"kind":"beam","from":a+Vector2(5,0),"to":b,"type":12,"tower_id":1,"enemy_id":1,"filename":"tower12_1","ms":30})
	check(app.effects.size()==1 and app.effects[0].ball_source==initial_ball_source,"refreshed area bolt retains its constructor source anchor")
	app.sim.clock_ms=30;await snapshot("electricity-gateway")
	app.advance_bolt_effects(30)
	check(app.effects[0].bolt_clock.age==0,"eligible refreshed area beam does not advance its fade clock")
	for i in range(6):app.advance_bolt_effects(30)
	check(absf(app.effects[0].bolt_clock.opacity-0.7)<0.000001 and app.effects[0].ribbon_alpha==1.0,"unrefreshed area beam ages independently of its saved ribbon colors")
	app.handle_event({"kind":"beam","from":a,"to":b,"type":12,"tower_id":1,"enemy_id":1,"filename":"tower12_1","ms":210})
	app.advance_bolt_effects(30)
	check(absf(app.effects[0].ribbon_alpha-0.7)<0.000001 and app.effects[0].bolt_clock.age==180,"re-entering area target snapshots faded ink without resetting age or scalar opacity")
	app.sim.clock_ms=210;await snapshot("electricity-gateway-reenter")
	var held_clock=app.effects[0].bolt_clock.duplicate(true)
	app.sim.paused=true;app.advance_bolt_effects(1000)
	check(app.effects[0].bolt_clock==held_clock,"pause freezes the original bolt clock and retained vertex alpha")
	app.sim.paused=false
	for i in range(7):app.advance_bolt_effects(30)
	check(app.effects.is_empty() and app.continuous_beams.is_empty(),"native bolt death removes the area effect and its owner-target lookup")
	check(captures.filter(func(c):return c.name=="electricity-gateway")[0].bolts[0].clock.alive and captures.filter(func(c):return c.name=="electricity-gateway-reenter")[0].bolts[0].clock.age==180,"captured area clocks retain their distinct capture-time states after expiry")
	for filename in ["tower10_2","tower10_3","tower12_2","tower12_3"]:
		app.effects.clear();app.continuous_beams.clear()
		var form=filename.trim_prefix("tower").split("_")
		pose_beam_tower(int(form[0]),int(form[1]))
		app.handle_event({"kind":"beam","from":a,"to":b,"type":12 if filename.begins_with("tower12") else 10,"tower_id":1,"enemy_id":1,"filename":filename,"ms":30})
		check(Content.tex(app.effects[0].texture) is Texture2D,"higher authored Tesla/Gateway color resolves an actual texture")
		await snapshot("electricity-"+filename)
	app.effects.clear();app.continuous_beams.clear()
	pose_beam_tower(1,2)
	app.handle_event({"kind":"beam","from":a,"to":b,"type":10,"tower_id":1,"enemy_id":1,"ms":0})
	app.sim.clock_ms=0
	check(app.effects.size()==1 and not app.effects[0].ball and app.effects[0].scatter and app.effects[0].points[0]==a+Vector2(0,-7),"Active Defense uses the tower source, endpoint scatter and no ball")
	await snapshot("active-defense")
	app.effects.clear();app.continuous_beams.clear()
	pose_beam_tower(10,1)
	app.handle_event({"kind":"shot","from":a,"to":b,"visual_to":b+Vector2(5,-16),"type":10,"tower_id":1,"enemy_id":1,"filename":"tower10_1","ms":0})
	check(app.effects[0].points[-1].distance_to(b+Vector2(5,-16))<0.0002,"electrical endpoint follows explicit drawn aim rather than the logical path point")
	await snapshot("electricity-drawn-aim")
	app.effects.clear();app.continuous_beams.clear()
	var second_tower=app.sim.towers[0].duplicate(true)
	second_tower.id=2;second_tower.type=12;second_tower.level=1;second_tower.def=app.sim.tower_data(12,1)
	second_tower.pos=app.sim.center(11,4);second_tower.cell=Vector2i(11,4);app.sim.towers.append(second_tower)
	app.handle_event({"kind":"beam","from":a,"to":b,"type":10,"tower_id":1,"enemy_id":1,"filename":"tower10_1","ms":0})
	app.handle_event({"kind":"beam","from":second_tower.pos,"to":app.sim.center(7,5),"type":12,"tower_id":2,"enemy_id":2,"filename":"tower12_1","ms":0})
	await snapshot("electricity-overlap")
	var overlap_hash=FileAccess.get_sha256(destination.path_join("electricity-overlap.png"))
	app.effects.reverse()
	await snapshot("electricity-overlap-reversed")
	check(FileAccess.get_sha256(destination.path_join("electricity-overlap-reversed.png"))!=overlap_hash,"crossing authored beams change pixels when their complete draw order reverses")
	check(app.bolt_renderer.slots[0].effect.texture==app.effects[0].texture and app.bolt_renderer.slots[1].effect.texture==app.effects[1].texture,"crossing effect order reaches the actual per-bolt render slots")
	var original_window_size=app.get_window().size
	var before_resize=Image.load_from_file(destination.path_join("electricity-overlap-reversed.png"))
	for size in [Vector2i(1600,900),Vector2i(800,900),original_window_size]:
		app.get_window().size=size
		for i in range(4):await get_tree().process_frame
		var name="electricity-window-wide" if size.x==1600 else "electricity-window-tall" if size.x==800 else "electricity-window-restored"
		await snapshot(name)
		var image=get_viewport().get_texture().get_image()
		check(app.bolt_renderer.pixel_scale==get_viewport().get_stretch_transform().get_scale(),"beam layer uses actual root canvas scale after window resizing")
		check(app.bolt_renderer.canvas_pixels==Vector2(image.get_size()),"beam atlas clipping dimensions match native readback rather than stretched texture metadata")
		check(absf(float(image.get_width())/image.get_height()-4.0/3.0)<0.00001,"wide/tall window retains the original4:3 game canvas")
	var after_resize=Image.load_from_file(destination.path_join("electricity-window-restored.png"))
	# R85 whole-frame comparison exposed three1-byte differences in HUD
	# glyph antialiasing after resizing. Retain that separate raster limit;
	# this regression requires exact unchanged map/tray/beam pixels.
	var hud_pixels=int(ceil(33*get_viewport().get_stretch_transform().y.y))
	var battle_rect=Rect2i(0,hud_pixels,before_resize.get_width(),before_resize.get_height()-hud_pixels)
	var restored=before_resize.get_region(battle_rect).get_data()==after_resize.get_region(battle_rect).get_data()
	window_restoration={"rectangle":[battle_rect.position.x,battle_rect.position.y,battle_rect.size.x,battle_rect.size.y],"exact_pixels":restored,"limit":"HUD glyph raster excluded; r85 retains three red-channel1-byte differences after resizing. No original-device pixel equivalence."}
	check(restored,"restoring window size reproduces exact battle/tray/beam pixels below the HUD after cache/atlas invalidation")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	check(app.sim.build(Vector2i(7,4),1).is_empty(),"depth pose builds on a legal Training hex")
	var tall=app.sim.towers[0]
	var short_tower=tall.duplicate(true)
	short_tower.id=902;short_tower.type=5;short_tower.level=1;short_tower.def=app.sim.tower_data(5,1)
	short_tower.depth_filename=short_tower.def.filename
	short_tower.pos=tall.pos+Vector2(12,0);app.sim.towers.append(short_tower)
	var crossing=app.sim.spawn_enemy(1,0,"",903,false)
	# Marine's38px source height adds19px to its positive integer center.
	# Keep this tower-depth fixture between the25px and100px tower forms.
	crossing.pos=tall.pos+Vector2(6,11);crossing.visual_pos=crossing.pos
	var ordered=app.battle_objects().filter(func(o):return o.has("tower") or o.has("enemy"))
	check(ordered.size()==3 and ordered[0].get("tower",{}).get("id")==902 and ordered[1].has("enemy") and ordered[2].get("tower",{}).get("id")==tall.id,"native render list uses authored25px and100px tower depths around crossing enemy")
	await snapshot("tower-depth-overlap")
	var depth_before=get_viewport().get_texture().get_image()
	app.sim.towers.reverse()
	await snapshot("tower-depth-reversed-input")
	var depth_after=get_viewport().get_texture().get_image()
	var depth_rect=Rect2i(0,hud_pixels,depth_before.get_width(),depth_before.get_height()-hud_pixels)
	check(depth_before.get_region(depth_rect).get_data()==depth_after.get_region(depth_rect).get_data(),"distinct original tower depths retain exact battle pixels when tower input order reverses")
	var base=app.sim.bases[0].duplicate(true)
	base.type=0;base.pos=tall.pos+Vector2(8,0);base.hp=100;base.hpmax=100
	var small_base=base.duplicate(true)
	small_base.type=9;small_base.pos=tall.pos+Vector2(-24,10)
	app.sim.bases.assign([base,small_base])
	var base_order=app.battle_objects().filter(func(o):return o.has("base") or o.has("tower") or o.has("enemy"))
	check(base_order.size()==5 and base_order[1].get("base",{}).get("type")==9 and base_order[4].get("base",{}).get("type")==0,"native draw list puts distinct10px and94px base depths among tower/enemy bodies")
	await snapshot("base-depth-overlap")
	var base_before=get_viewport().get_texture().get_image()
	app.sim.bases.reverse()
	await snapshot("base-depth-reversed-input")
	var base_after=get_viewport().get_texture().get_image()
	check(base_before.get_region(depth_rect).get_data()==base_after.get_region(depth_rect).get_data(),"distinct original base depths retain exact battle pixels when base input order reverses")
	base.hp=50;small_base.hp=50
	await snapshot("base-depth-damaged")
	base.hp=base.hpmax;small_base.hp=small_base.hpmax
	var plane=app.sim.spawn_enemy(4,0,"",904,false)
	plane.pos=tall.pos+Vector2(0,-12);plane.visual_pos=plane.pos
	var bomber=app.sim.spawn_enemy(2,0,"",905,false)
	bomber.pos=plane.pos+Vector2(6,4);bomber.visual_pos=bomber.pos
	check(app.battle_air_objects().map(func(e):return e.id)==[904,905],"native air pass retains manager insertion order above every ground body")
	check(app.battle_objects().filter(func(o):return o.has("enemy")).map(func(o):return o.enemy.id)==[903],"native air resources leave the sorted map-body pass")
	await snapshot("air-depth-overlap")
	var air_before=get_viewport().get_texture().get_image()
	app.sim.enemies.reverse()
	await snapshot("air-depth-reversed-input")
	var air_after=get_viewport().get_texture().get_image()
	check(app.battle_air_objects().map(func(e):return e.id)==[905,904],"reversing manager input reverses aircraft body submission despite distinct Y")
	check(air_before.get_region(depth_rect).get_data()!=air_after.get_region(depth_rect).get_data(),"overlapping authored aircraft change battle pixels when manager body order reverses")
	crossing.air=true;crossing.float_until=app.sim.clock_ms+1000
	await snapshot("air-depth-lifted-ground")
	check(app.battle_objects().any(func(o):return o.has("enemy") and o.enemy.id==903) and not app.battle_air_objects().any(func(e):return e.id==903),"lifted ground resource stays in ground drawing pass")
	app.selected_tower=tall.id;app.refresh_controls()
	var selected_range=app.selected_range_pose()
	check(selected_range.draws.size()==4 and selected_range.draws[0].filled and selected_range.draws[0].color.a==0.25,"selected range retains original fill plus three outlines")
	check(selected_range.position==tall.pos,"selected range stays at logical cell center independently of artwork offset")
	await snapshot("selection-range-ground")
	app.tower_panel_close_at=app.elapsed_ui;app.elapsed_ui+=0.2;app.refresh_controls()
	check(absf(app.selected_range_pose().draws[0].color.a-0.125)<0.000001,"selected range fill follows half-opacity tower panel")
	await snapshot("selection-range-fading")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	check(app.sim.build(Vector2i(7,4),1).is_empty(),"creep-depth fixture builds on a legal Training hex")
	var depth_tower=app.sim.towers[0]
	var marine=app.sim.spawn_enemy(1,0,"",910,false)
	marine.pos=depth_tower.pos+Vector2(-5,0);marine.visual_pos=marine.pos
	var tank=app.sim.spawn_enemy(5,0,"",911,false)
	tank.pos=depth_tower.pos+Vector2(12,0);tank.visual_pos=tank.pos
	var creep_order=app.battle_objects().filter(func(o):return o.has("tower") or o.has("enemy"))
	check(creep_order.size()==3 and creep_order[0].get("enemy",{}).get("id")==910 and creep_order[1].has("tower") and creep_order[2].get("enemy",{}).get("id")==911,"native38px Marine and100px tank depths straddle the original Minigun at the same Y")
	await snapshot("creep-depth-overlap")
	var creep_before=get_viewport().get_texture().get_image()
	app.sim.enemies.reverse()
	await snapshot("creep-depth-reversed-input")
	var creep_after=get_viewport().get_texture().get_image()
	check(creep_before.get_region(depth_rect).get_data()==creep_after.get_region(depth_rect).get_data(),"distinct original creep depths retain exact battle pixels when enemy input reverses")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	await snapshot("air-missile-background")
	var missile_background=get_viewport().get_texture().get_image()
	var missile_owner=app.sim.spawn_enemy(2,0,"",920,false)
	missile_owner.pos=app.sim.center(7,4);missile_owner.visual_pos=missile_owner.pos;missile_owner.grow_ms=1000
	await snapshot("air-missile-body-only")
	var missile_body=get_viewport().get_texture().get_image()
	app.sim.enemies.clear()
	# Match the authored body lift; the logical ground point overlaps only
	# this aircraft's translucent shadow, not its opaque body.
	var aircraft_offset=missile_owner.def.traits.get("offset",[0,0])
	var aircraft_center=missile_owner.pos+Vector2(aircraft_offset[0],aircraft_offset[1])
	for offset in [Vector2.ZERO,Vector2(100,0)]:app.sim.enemy_missiles.append({"type":2,"owner":920,"pos":aircraft_center+offset,"angle":90.0})
	await snapshot("air-missile-projectiles-only")
	var missile_only=get_viewport().get_texture().get_image()
	app.sim.enemies.append(missile_owner)
	await snapshot("air-missile-under-body")
	var missile_combined=get_viewport().get_texture().get_image()
	var overlapping_pixels=0;var covered_pixels=0;var visible_pixels=0
	for y in range(depth_rect.position.y,missile_body.get_height()):
		for x in range(missile_body.get_width()):
			var background=missile_background.get_pixel(x,y);var body=missile_body.get_pixel(x,y);var projectile=missile_only.get_pixel(x,y);var combined=missile_combined.get_pixel(x,y)
			if projectile!=background and body==background and combined!=body:visible_pixels+=1
			if body==background or projectile==background or body==projectile:continue
			overlapping_pixels+=1
			if combined==body:covered_pixels+=1
	check(overlapping_pixels>=10 and covered_pixels>=10,"native opaque aircraft pixels cover overlapping aircraft missiles")
	check(visible_pixels>=10,"native aircraft missile remains visible outside the aircraft")
	captures[-1].overlap_probe={"overlapping_pixels":overlapping_pixels,"covered_pixels":covered_pixels,"visible_pixels":visible_pixels,"limit":"Synthetic native compositing test, not original-device pixels or missile lifetime."}
	for missile in app.sim.enemy_missiles:missile.body_flag=true
	check(app.enemy_missile_passes().body[920].size()==2 and app.enemy_missile_passes().before_air.is_empty(),"native new-owner missile flag selects body pass")
	await snapshot("air-missile-owner-body")
	var owner_front=get_viewport().get_texture().get_image()
	var changed_overlap=0
	for y in range(depth_rect.position.y,missile_body.get_height()):
		for x in range(missile_body.get_width()):
			if missile_body.get_pixel(x,y)!=missile_background.get_pixel(x,y) and missile_only.get_pixel(x,y)!=missile_background.get_pixel(x,y) and owner_front.get_pixel(x,y)!=missile_combined.get_pixel(x,y):changed_overlap+=1
	check(changed_overlap>=10,"native body-pass missiles visibly cover overlapping owner artwork")
	captures[-1].owner_overlap_pixels=changed_overlap
	for missile in app.sim.enemy_missiles:missile.body_flag=false
	await snapshot("air-missile-owner-cleared")
	check(get_viewport().get_texture().get_image().get_region(depth_rect).get_data()==missile_combined.get_region(depth_rect).get_data(),"cleared owner flags restore exact original before-air battle pixels")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	app.probe_placement_order=true;app.show_grid=false
	var placement_position=app.sim.center(7,4)
	var far_ground=app.sim.spawn_enemy(1,0,"",940,false)
	far_ground.pos=placement_position+Vector2(200,0);far_ground.visual_pos=far_ground.pos
	await snapshot("placement-phase-background")
	var placement_background=get_viewport().get_texture().get_image()
	app.build_type=1;app.tower_drag=true;app.tower_drag_position=app.map_origin()+placement_position*app.map_scale()
	await snapshot("placement-phase-preview-only")
	var preview_image=get_viewport().get_texture().get_image()
	app.build_type=0
	var preview_air=app.sim.spawn_enemy(2,0,"",941,false)
	var preview_offset=preview_air.def.traits.get("offset",[0,0])
	preview_air.pos=placement_position-Vector2(preview_offset[0],preview_offset[1])+Vector2(0,-7);preview_air.visual_pos=preview_air.pos
	await snapshot("placement-phase-air-only")
	var air_image=get_viewport().get_texture().get_image()
	app.build_type=1
	await snapshot("placement-phase-air-preview")
	var combined_preview=get_viewport().get_texture().get_image()
	var preview_overlap=0;var preview_covered=0
	for y in range(depth_rect.position.y,air_image.get_height()):
		for x in range(air_image.get_width()):
			var background=placement_background.get_pixel(x,y);var air=air_image.get_pixel(x,y);var preview=preview_image.get_pixel(x,y)
			if air==background or preview==background or air==preview:continue
			preview_overlap+=1
			if combined_preview.get_pixel(x,y)==air:preview_covered+=1
	check(preview_overlap>=10 and preview_covered>=10,"native aircraft opaque pixels cover the dragged tower preview")
	captures[-1].preview_overlap={"overlapping_pixels":preview_overlap,"covered_pixels":preview_covered}
	app.show_grid=true
	await snapshot("placement-phase-air-preview-grid")
	app.show_grid=false;app.probe_placement_order=false;app.build_type=0;app.tower_drag=false
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	await snapshot("magic-depth-background")
	var magic_background=get_viewport().get_texture().get_image()
	check(app.sim.build(Vector2i(7,4),1).is_empty(),"registered-mine fixture builds original Minigun")
	var magic_tower=app.sim.towers[0]
	await snapshot("magic-depth-tower-only")
	var magic_tower_image=get_viewport().get_texture().get_image()
	var magic_position=magic_tower.pos+Vector2(0,28)
	app.sim.towers.clear()
	var depth_mine={"pos":magic_position,"cell":app.sim.nearest(magic_position),"ready":app.sim.clock_ms,"born_ms":app.sim.clock_ms}
	app.sim.mines.append(depth_mine)
	await snapshot("magic-depth-mine-only")
	var mine_only=get_viewport().get_texture().get_image()
	app.sim.towers.append(magic_tower)
	check(app.battle_objects().filter(func(o):return o.has("mine") or o.has("tower")).map(func(o):return o.has("mine"))==[false,true],"registered mine height places front mine after tower")
	await snapshot("magic-depth-mine-front")
	var mine_front=get_viewport().get_texture().get_image()
	var mine_overlap=0;var mine_covered=0
	for y in range(depth_rect.position.y,mine_front.get_height()):
		for x in range(mine_front.get_width()):
			var bg=magic_background.get_pixel(x,y);var tower=magic_tower_image.get_pixel(x,y);var mine=mine_only.get_pixel(x,y)
			if tower==bg or mine==bg or tower==mine:continue
			mine_overlap+=1
			if mine_front.get_pixel(x,y)==mine:mine_covered+=1
	check(mine_overlap>=10 and mine_covered>=10,"native registered front mine covers overlapping tower pixels")
	captures[-1].mine_overlap={"overlapping_pixels":mine_overlap,"covered_pixels":mine_covered}
	depth_mine.pos=magic_tower.pos+Vector2(0,-12);depth_mine.cell=app.sim.nearest(depth_mine.pos)
	check(app.battle_objects().filter(func(o):return o.has("mine") or o.has("tower")).map(func(o):return o.has("mine"))==[true,false],"moving registered mine behind tower changes original depth order")
	await snapshot("magic-depth-mine-back")
	app.sim.mines.clear();app.magic_placement="m_mine";app.magic_preview_position=app.map_origin()+magic_position*app.map_scale()
	await snapshot("magic-depth-mine-preview")
	app.magic_placement="m_portal";app.magic_preview_position=app.map_origin()+magic_tower.pos*app.map_scale()
	check(app.battle_portal_objects().size()==1 and app.battle_portal_objects()[0].preview,"inactive portal participates in registered before pass")
	await snapshot("magic-depth-portal-preview")
	app.magic_placement=""
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	var lit_ground=app.sim.spawn_enemy(1,0,"",930,false)
	lit_ground.pos=app.sim.center(7,4);lit_ground.visual_pos=lit_ground.pos;lit_ground.grow_ms=400;lit_ground.draw_light=0.3
	await snapshot("creep-light-ground-030")
	var dark_ground=get_viewport().get_texture().get_image()
	lit_ground.draw_light=1
	await snapshot("creep-light-ground-100")
	preload("res://scripts/creep_view.gd").update(app.sim,lit_ground)
	check(lit_ground.visual_layers.size()==2,"controlled status actor has both original animation records")
	# Screen compositing is checked before later actors, with true source
	# premultiplied RGB and zero/partial/full opacity edges.
	var bright_ground=get_viewport().get_texture().get_image()
	check(dark_ground.get_region(depth_rect).get_data()!=bright_ground.get_region(depth_rect).get_data(),"native ground artwork responds to original scalar light")
	var status_plate=preload("res://scripts/creep_status_fixture.gd").new();app.add_child(status_plate)
	await snapshot("creep-status-blend-plate")
	var status_formula=status_plate.audit(get_viewport().get_texture().get_image(),app.get_viewport().get_stretch_transform())
	check(status_formula.sampled_rgb_channels==192 and status_formula.maximum_formula_byte_error<=1.0,"native status screen matches independent RGB equation within one8bit rounding step")
	check(status_formula.later_actor_exact_cover,"later actor exactly covers every status swatch")
	captures[-1].screen_formula=status_formula
	app.remove_child(status_plate);status_plate.free()
	app.sim.enemies.clear()
	await snapshot("creep-status-background")
	var status_background=get_viewport().get_texture().get_image()
	app.sim.enemies.append(lit_ground)
	lit_ground.draw_light=0.3
	await snapshot("creep-status-normal-030")
	app.sim.freeze_until=app.sim.clock_ms+1000
	app.sim.CreepFreeze.process_creep(lit_ground,1000)
	await snapshot("creep-status-freeze-030")
	var status_frozen=get_viewport().get_texture().get_image()
	lit_ground.draw_light=1
	await snapshot("creep-status-freeze-100")
	app.sim.freeze_until=0;app.sim.CreepFreeze.process_creep(lit_ground,0);lit_ground.draw_light=.3;lit_ground.slow_pending=.5
	await snapshot("creep-status-slow-030")
	check(status_frozen.get_data()==get_viewport().get_texture().get_image().get_data(),"same source freeze and pending-slow predicates produce exact complete-frame RGBA")
	lit_ground.slow_pending=-1
	var initial_layers=lit_ground.visual_layers.duplicate(true)
	lit_ground.visual_layers[0].alpha=0
	app.sim.freeze_until=app.sim.clock_ms+1000
	app.sim.CreepFreeze.process_creep(lit_ground,1000)
	await snapshot("creep-status-zero-primary")
	lit_ground.visual_layers=initial_layers.duplicate(true)
	lit_ground.visual_layers[0].alpha=.4;lit_ground.visual_layers[1].alpha=.6
	await snapshot("creep-status-secondary")
	lit_ground.visual_layers=initial_layers
	# Put a later ground actor across the frozen creep; the normal sorted
	# traversal, screen overlay and health all remain in the same CanvasItem.
	var status_budget=app.sim.money
	var cover_position=lit_ground.pos+Vector2(0,12)
	app.sim.build(app.sim.nearest(cover_position),1)
	check(app.sim.towers.size()==1,"controlled overlap legally builds its one covering tower")
	var cover_tower=app.sim.towers[-1];cover_tower.pos=cover_position;cover_tower.born_ms=app.sim.clock_ms-1000;cover_tower.foundation_ms=app.sim.clock_ms-1000
	await snapshot("creep-status-tower-cover")
	var status_cover=get_viewport().get_texture().get_image()
	app.sim.enemies.clear()
	await snapshot("creep-status-tower-only")
	var status_tower=get_viewport().get_texture().get_image()
	var status_overlap=0;var status_covered=0
	for y in range(depth_rect.position.y,status_cover.get_height()):
		for x in range(status_cover.get_width()):
			var bg=status_background.get_pixel(x,y);var creep=status_frozen.get_pixel(x,y);var tower=status_tower.get_pixel(x,y)
			if creep==bg or tower==bg or creep==tower:continue
			status_overlap+=1
			if status_cover.get_pixel(x,y)==tower:status_covered+=1
	check(status_overlap>=10 and status_covered>=10,"later ground tower exactly covers overlapping frozen creep pixels")
	captures[-1].status_overlap={"overlapping_pixels":status_overlap,"covered_pixels":status_covered}
	app.sim.freeze_until=0
	app.sim.money=status_budget
	check(app.sim.money==status_budget,"status overlap fixture restores its battle budget before subsequent poses")
	app.sim.towers.clear()
	app.sim.enemies.clear()
	var lit_air=app.sim.spawn_enemy(2,0,"",931,false)
	lit_air.pos=lit_ground.pos;lit_air.visual_pos=lit_air.pos;lit_air.draw_light=0.3
	await snapshot("creep-light-air-030")
	var dark_air=get_viewport().get_texture().get_image()
	lit_air.draw_light=1
	await snapshot("creep-light-air-100")
	var bright_air=get_viewport().get_texture().get_image()
	check(dark_air.get_region(depth_rect).get_data()==bright_air.get_region(depth_rect).get_data(),"native aircraft retain exact battle pixels when only source ground-light value changes")
	app.sim.enemies.clear()
	var damaged=app.sim.spawn_enemy(1,0,"",932,false)
	damaged.pos=app.sim.center(7,4);damaged.visual_pos=damaged.pos;damaged.max_hp=100;damaged.hp=25
	check(app.creep_health_layout(damaged).fill.size==Vector2(8,16),"health bar uses original eight-pixel crop at25percent")
	await snapshot("creep-health-ground-025")
	damaged.hp=0
	await snapshot("creep-health-empty")
	damaged.hp=100
	check(app.creep_health_layout(damaged).is_empty(),"full-health actor draws no life bar")
	await snapshot("creep-health-full")
	damaged.hp=25;damaged.float_until=app.sim.clock_ms+1000
	check(app.creep_health_layout(damaged).origin==damaged.visual_pos+Vector2(-16,16),"health bar retains original raw animator anchor independently of body lift")
	await snapshot("creep-health-lifted-025")
	damaged.float_until=0;damaged.grow_ms=200
	check(app.creep_health_layout(damaged).color.a==0.5,"health bar uses original halfway growth opacity")
	await snapshot("creep-health-growing-025")
	app.sim.enemies.clear()
	var damaged_air=app.sim.spawn_enemy(2,0,"",933,false)
	damaged_air.pos=damaged.pos;damaged_air.visual_pos=damaged_air.pos;damaged_air.max_hp=100;damaged_air.hp=50
	check(app.creep_health_layout(damaged_air).fill.size==Vector2(16,16),"aircraft uses same authored health crop")
	await snapshot("creep-health-air-050")
	var retained_animation_delta=app.animation_delta_ms
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	app.sim.enemies.clear();app.animation_delta_ms=0;app.animation_epoch+=1
	var animated_mine={"pos":app.sim.center(7,4),"cell":Vector2i(7,4),"ready":0,"born_ms":0,"static":false}
	app.sim.mines.append(animated_mine)
	await snapshot("animator-mine-000")
	var mine_initial=get_viewport().get_texture().get_image()
	for animator_phase in [25,50,75,100]:
		app.animation_epoch+=1;app.animation_delta_ms=50
		await snapshot("animator-mine-%03d"%animator_phase)
		check(animated_mine.render_animators.lights.phase==animator_phase/100.0,"native mine retains exact quarter-frame source phase")
		if animator_phase==25:check(mine_initial.get_data()==get_viewport().get_texture().get_image().get_data(),"original overlapping-frame curve retains opaque first frame through quarter phase")
		if animator_phase==75:check(mine_initial.get_data()!=get_viewport().get_texture().get_image().get_data(),"native mine light fades during source second half of frame")
	app.animation_epoch+=1;app.animation_delta_ms=1700
	await snapshot("animator-mine-loop")
	check(animated_mine.render_animators.lights.phase==0,"native looping mine discards overflow rather than carrying a fractional remainder")
	app.sim.mines.clear()
	app.sim.abilities.m_portal=5
	check(app.sim.use_ability("m_portal",app.sim.center(7,4))=="Choose the portal exit.","native animator gallery places the real portal entrance")
	var animated_portal=app.sim.portals[0].presentation
	app.animation_epoch+=1;app.animation_delta_ms=250
	await snapshot("animator-portal-stopped")
	check(animated_portal.gates[0].render_animators.portal.stopped and animated_portal.gates[0].render_animators.portal.phase==0,"native pending portal animator stays stopped")
	check(app.sim.use_ability("m_portal",app.sim.center(9,4)).is_empty(),"native animator gallery connects the real portal exit")
	app.sim.advance_frame(250)
	app.animation_epoch+=1;app.animation_delta_ms=250
	await snapshot("animator-portal-025")
	check(animated_portal.gates.all(func(g):return g.render_animators.portal.phase==.25 and not g.render_animators.portal.stopped),"both native connected portal animators resume after original growth-stage Play")
	app.sim.advance_frame(5000)
	app.animation_epoch+=1;app.animation_delta_ms=5000
	await snapshot("animator-portal-loop")
	check(animated_portal.gates.all(func(g):return g.render_animators.portal.phase==0),"both native portal clocks discard loop overflow")
	app.sim.portals.clear()
	check(app.sim.build(Vector2i(7,4),1).is_empty(),"synthetic animator gallery starts from a real legal tower record")
	var animated_nuke=app.sim.towers[0]
	animated_nuke.type=5;animated_nuke.level=1;animated_nuke.def=app.sim.tower_data(5,1);animated_nuke.depth_filename=animated_nuke.def.filename;animated_nuke.born_ms=-2000;animated_nuke.foundation_ms=-2000;animated_nuke.animation="Open";animated_nuke.animation_ms=app.sim.clock_ms
	app.animation_epoch+=1;app.animation_delta_ms=0
	await snapshot("animator-nuke-000")
	var nuke_initial=get_viewport().get_texture().get_image()
	app.animation_epoch+=1;app.animation_delta_ms=31.25
	await snapshot("animator-nuke-025")
	check(animated_nuke.render_animators["nuke-lights"].phase==.25,"native nuke lights retain authored8FPS fractional phase")
	check(nuke_initial.get_data()==get_viewport().get_texture().get_image().get_data(),"native nuke lights retain their opaque first frame through quarter phase")
	app.animation_epoch+=1;app.animation_delta_ms=62.5
	await snapshot("animator-nuke-075")
	check(animated_nuke.render_animators["nuke-lights"].phase==.75,"native nuke lights reach source three-quarter phase")
	check(nuke_initial.get_data()!=get_viewport().get_texture().get_image().get_data(),"native nuke light fades during original second half of frame")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	app.sim.enemies.clear()
	var animated_creep=app.sim.spawn_enemy(1,0,"",940,false)
	var creep_anchor=app.sim.center(8,6)
	animated_creep.speed=1000;animated_creep.grow_ms=400
	app.sim.abilities.m_freeze=1
	var creep_direction="RunDown"
	var creep_attack=false
	# The independent original ARM sequence fixture audits exact phase bits
	# after each real native render; the whole caller is not being emulated.
	for action in [{"name":"000","dt":0},{"name":"walk","dt":60},{"name":"turn","dt":0,"direction":"RunUp"},{"name":"slow","dt":30,"slow":.5},{"name":"paused","dt":30,"paused":true},{"name":"frozen","dt":30},{"name":"freeze-expiry","dt":30},{"name":"resume","dt":30},{"name":"attack","dt":30,"attack":true},{"name":"attack-resume","dt":30,"play":true},{"name":"loop","dt":1000},{"name":"secondary","dt":30}]:
		app.sim.paused=bool(action.get("paused",false))
		creep_direction=str(action.get("direction",creep_direction))
		if action.get("attack",false):creep_attack=true
		if action.get("play",false):creep_attack=false
		animated_creep.slow_pending=float(action.get("slow",-1))
		if action.name=="frozen":check(app.sim.use_ability("m_freeze").is_empty(),"native creep clock gallery attaches the real freeze ability")
		if action.name=="freeze-expiry":app.sim.freeze_state.remaining=1
		app.sim.advance_frame(float(action.dt))
		animated_creep.pos=creep_anchor;animated_creep.visual_pos=creep_anchor;animated_creep.attacking=creep_attack
		animated_creep.visual_layers=[{"state":creep_direction,"rotation":0.0,"alpha":.4 if action.name=="secondary" else 1.0,"born":0},{"state":creep_direction,"rotation":0.0,"alpha":.6 if action.name=="secondary" else 0.0,"born":0}]
		app.animation_epoch+=1;app.animation_delta_ms=float(action.dt)
		await snapshot("creep-clock-"+str(action.name))
		if action.name=="freeze-expiry":check(animated_creep.animation_multiplier==0 and animated_creep.freeze_remaining==0 and not animated_creep.freeze_attached,"native expiry frame holds animator before releasing the freeze pointer")
		if action.name=="resume":check(animated_creep.animation_multiplier==1 and not app.sim.freeze_state.room_active,"native following frame resumes the owned animator")
	await verify_normal_poses()
	app.sim.paused=false
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.sim.tutorial_finished=false;app.refresh_controls()
	app.sim.enemies.clear();app.animation_delta_ms=0
	var hovering=app.sim.spawn_enemy(5,0,"",944,false)
	hovering.pos=creep_anchor;hovering.visual_pos=creep_anchor;hovering.path=[];hovering.base=-1
	hovering.hp=50;hovering.max_hp=100;hovering.grow_ms=400;hovering.speed=1000
	app.sim.abilities.m_freeze=1
	for action in [{"name":"000","steps":0},{"name":"moving","steps":7},{"name":"frozen","steps":7},{"name":"paused","steps":1},{"name":"expiry","steps":1},{"name":"resume","steps":1}]:
		app.sim.paused=action.name=="paused"
		if action.name=="frozen":check(app.sim.use_ability("m_freeze").is_empty(),"native hover fixture attaches real Freeze ability")
		if action.name=="expiry":app.sim.freeze_state.remaining=1
		for step in int(action.steps):app.sim.advance_frame(100)
		hovering.pos=creep_anchor;hovering.visual_pos=creep_anchor
		hovering.visual_layers=[{"state":"RunDown","rotation":0.0,"alpha":1.0,"born":0}]
		app.animation_epoch+=1
		check(app.creep_health_layout(hovering).origin==creep_anchor+Vector2(-16,16),"native hovering body retains raw health anchor")
		await snapshot("creep-hover-"+str(action.name))
		if action.name=="frozen":
			check(hovering.animation_multiplier==0 and hovering.freeze_remaining>0,"native frozen hover retains stopped body animator")
		if action.name=="paused":
			# Compare like paused compositions. The pause overlay deliberately
			# darkens the earlier unpaused frozen image.
			var paused_image=get_viewport().get_texture().get_image()
			app.sim.advance_frame(100)
			app.queue_redraw();app.battle_overlay.queue_redraw();app.bolt_renderer.prepare()
			await get_tree().process_frame
			await get_tree().process_frame
			RenderingServer.force_draw(true)
			var exact=paused_image.get_region(depth_rect).get_data()==get_viewport().get_texture().get_image().get_region(depth_rect).get_data()
			captures[-1].paused_battle_rgba_exact=exact
			check(exact,"two native paused hover renders retain exact battle RGBA")
		if action.name=="expiry":check(hovering.animation_multiplier==0 and not hovering.freeze_attached,"native hover expiry preserves one-frame animator hold")
		if action.name=="resume":check(hovering.animation_multiplier==1,"native hover animator resumes on following frame")
	app.sim.paused=false
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls()
	app.sim.enemies.clear();app.animation_delta_ms=0
	var hit_creep=app.sim.spawn_enemy(1,0,"",950,false)
	hit_creep.pos=app.sim.center(8,6);hit_creep.visual_pos=hit_creep.pos;hit_creep.path=[];hit_creep.hp=500;hit_creep.max_hp=1000;hit_creep.grow_ms=400
	hit_creep.visual_layers=[{"state":"RunDown","rotation":0.0,"alpha":1.0,"born":0}]
	await snapshot("creep-hit-normal")
	var hit_normal=get_viewport().get_texture().get_image()
	app.sim.damage(hit_creep,0,0,0)
	await snapshot("creep-hit-000")
	check(hit_normal.get_data()!=get_viewport().get_texture().get_image().get_data(),"native original zero-amount call activates a visible additive creep flash")
	check(app.battle_uses_ordered_canvas and app.ordered_battle_canvas.spans.filter(func(span):return span.visible and span.material!=null).size()==1,"native flash owns one in-place additive span")
	app.sim.advance_frame(60)
	await snapshot("creep-hit-060")
	check(hit_creep.hit_active and hit_creep.hit_elapsed==60.0,"native hit survives exact original60ms boundary")
	app.sim.paused=true;app.sim.advance_frame(30)
	await snapshot("creep-hit-paused")
	check(hit_creep.hit_elapsed==60.0,"native pause retains current flash age")
	app.sim.paused=false;app.sim.advance_frame(.001)
	await snapshot("creep-hit-expired")
	check(not hit_creep.hit_active and not app.battle_uses_ordered_canvas,"native expired hit returns to ordinary renderer")
	app.sim.damage(hit_creep,0,0,3)
	await snapshot("creep-hit-poison-first")
	app.sim.advance_frame(60.001);app.sim.damage(hit_creep,0,0,3)
	await snapshot("creep-hit-poison-suppressed")
	check(not hit_creep.hit_active,"native consecutive poison cannot retrigger after source expiry")
	app.sim.damage(hit_creep,0,0,0)
	hit_creep.visual_layers=[{"state":"RunDown","rotation":0.0,"alpha":.4,"born":0},{"state":"RunRight","rotation":0.0,"alpha":.6,"born":0}]
	await snapshot("creep-hit-secondary")
	hit_creep.freeze_remaining=1000
	await snapshot("creep-hit-status")
	check(hit_creep.hit_active and hit_creep.freeze_remaining>0,"native additive hit and later screen status share owned frames")
	hit_creep.freeze_remaining=0
	check(app.sim.build(Vector2i(8,6),1).is_empty(),"native hit overlap fixture places an actual original minigun")
	await snapshot("creep-hit-tower-cover")
	app.sim.enemies.clear()
	var hit_air=app.sim.spawn_enemy(4,0,"",951,false)
	hit_air.pos=app.sim.center(8,6);hit_air.visual_pos=hit_air.pos;hit_air.path=[];hit_air.grow_ms=400
	app.sim.damage(hit_air,0,0,2)
	await snapshot("creep-hit-air")
	hit_air.freeze_remaining=1000
	await snapshot("creep-hit-air-status")
	check(hit_air.native_air and hit_air.hit_active and app.battle_uses_ordered_canvas,"native resource-class aircraft retain the ordered hit bridge")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls();app.sim.enemies.clear();app.animation_delta_ms=0
	var decal_point=app.sim.center(8,6)
	await snapshot("decal-background")
	var decal_background=get_viewport().get_texture().get_image()
	check(app.sim.build(Vector2i(8,6),1).is_empty(),"decal coverage fixture builds an original Minigun")
	var decal_cover_tower=app.sim.towers[0]
	await snapshot("decal-tower-only")
	var decal_tower_image=get_viewport().get_texture().get_image()
	app.sim.towers.clear()
	var decal_first=decal_birth(1,982,decal_point)
	await snapshot("decal-ground-000")
	var decal_only=get_viewport().get_texture().get_image()
	check(decal_first.clock==0 and decal_first.alpha==1 and decal_first.position==decal_point,"native lethal crater is fresh at original logical position")
	app.sim.towers.append(decal_cover_tower)
	await snapshot("decal-ground-tower-cover")
	var decal_combined=get_viewport().get_texture().get_image();var decal_overlap=0;var decal_covered=0
	for y in range(depth_rect.position.y,decal_only.get_height()):
		for x in range(decal_only.get_width()):
			var background=decal_background.get_pixel(x,y);var crater=decal_only.get_pixel(x,y);var tower=decal_tower_image.get_pixel(x,y)
			if crater==background or tower==background or crater==tower:continue
			decal_overlap+=1
			if decal_combined.get_pixel(x,y)==tower:decal_covered+=1
	check(decal_overlap>=20 and decal_covered>=20,"native opaque owner pixels cover overlapping crater art")
	captures[-1].decal_coverage={"overlap":decal_overlap,"covered":decal_covered}
	app.sim.towers.clear();app.sim.decals.setup(int(app.sim.map.width_pixels),int(app.sim.map.height_pixels))
	var decal_large_type=-1
	for type in Content.catalog.tower_creeps.size():
		if str(Content.catalog.tower_creeps[type].get("filename",""))=="creep5":decal_large_type=type;break
	var decal_large=decal_birth(decal_large_type,983,decal_point)
	await snapshot("decal-ground-large")
	check(decal_large.scale==preload("res://scripts/decal_view.gd").f32(1.6),"native actual resource retains the authored large-crater scale")
	app.sim.decals.setup(int(app.sim.map.width_pixels),int(app.sim.map.height_pixels))
	# Five same-point births: the fifth marks/unhooks the fourth traversed
	# older cell entry; actual manager cleanup runs on the following update.
	for index in range(5):
		var decal_enemy=app.sim.spawn_enemy(1,0,"",984+index,false);decal_enemy.pos=decal_point;decal_enemy.visual_pos=decal_point;decal_enemy.path=[]
		app.sim.damage(decal_enemy,float(decal_enemy.max_hp)*10)
	app.sim.enemies.clear()
	await snapshot("decal-ground-density")
	check(app.sim.decals.items.size()==5 and app.sim.decals.items.filter(func(d):return d.deleted).size()==1 and app.sim.decals.cells.values()[0].size()==4,"native original density replacement retains marked global decal until next update")
	app.sim.advance_frame(0)
	await snapshot("decal-ground-density-next")
	check(app.sim.decals.items.size()==4,"native following manager update removes marked density entry")
	app.sim.decals.setup(int(app.sim.map.width_pixels),int(app.sim.map.height_pixels))
	var decal_clock=decal_birth(1,990,decal_point)
	for index in range(133):app.sim.advance_frame(30)
	await snapshot("decal-ground-hold")
	check(decal_clock.clock==3990 and not decal_clock.fading and decal_clock.alpha==1,"native original crater hold lasts before exact4000ms switch")
	for index in range(67):app.sim.advance_frame(30)
	await snapshot("decal-ground-fade")
	check(decal_clock.fading and decal_clock.clock==2010 and decal_clock.alpha>0 and decal_clock.alpha<1,"native original switch frame consumes its full delta in fade")
	for index in range(68):app.sim.advance_frame(30)
	await snapshot("decal-ground-expired")
	check(app.sim.decals.items.is_empty(),"native expired crater is deleted by the following manager update")
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.refresh_controls();app.sim.enemies.clear()
	var burst_qa_gallery=app.qa_gallery;app.qa_gallery=false;app.sim.live_updates=true
	var burst_enemy=app.sim.spawn_enemy(1,0,"",995,false);burst_enemy.pos=app.sim.center(8,6);burst_enemy.visual_pos=burst_enemy.pos;burst_enemy.path=[]
	death_burst_owner=burst_enemy
	app.sim.damage(burst_enemy,float(burst_enemy.max_hp)*10)
	app._process(0)
	death_burst_parents=app.particle_fx.systems.filter(func(sys):return "explosion" in str(sys.get("creep_alias","")))
	var dormant_roots=app.particle_fx.systems.filter(func(sys):return not "explosion" in str(sys.get("creep_alias","")))
	check(dormant_roots.size()==5 and dormant_roots.all(func(sys):return sys.particles.is_empty()),"native lethal owner retains all five empty constructor roots")
	check(death_burst_parents.size()==3,"native actual lethal event creates three original death aliases")
	var owned_burst_roots=death_burst_parents.filter(func(p):return p.has("owned_tree") and not str(p.definition.get("child_system","")).is_empty())
	check(owned_burst_roots.size()==2,"native lethal burst connects both original owned-child roots")
	check(app.sim.enemies.has(burst_enemy) and int(burst_enemy.state)==3 and burst_enemy.death_sprites.size()==1,"native lethal flow retains actual owner and splash")
	check(owned_burst_roots.all(func(s):return s.owned_tree.particles.all(func(p):return p.child.particles.is_empty() and p.child.clock_seconds==0)),"native lethal child factories start empty with zero clocks")
	await snapshot("death-burst-0000")
	for index in range(5):app._process(.03)
	await snapshot("death-burst-0150")
	for index in range(5):app._process(.03)
	check(app.particle_fx.systems.size()==8 and dormant_roots.all(func(sys):return sys.particles.is_empty()) and owned_burst_roots.all(func(s):return s.owned_tree.particles.any(func(p):return not p.child.particles.is_empty())),"native child smoke emits inside parents without global orphan systems")
	await snapshot("death-burst-0300")
	for index in range(10):app._process(.03)
	await snapshot("death-burst-0600")
	var burst_before_pause=var_to_bytes(death_burst_parents)
	app.toggle_pause();app._process(.5)
	check(app.sim.paused,"native death-burst fixture uses actual Main pause controls")
	check(var_to_bytes(death_burst_parents)==burst_before_pause,"native paused death burst holds exact parent particle state")
	await snapshot("death-burst-paused")
	app.toggle_pause()
	check(not app.sim.paused,"native death-burst fixture resumes through actual Main controls")
	for index in range(11):app._process(.03)
	await snapshot("death-burst-0930")
	for index in range(14):app._process(.03)
	await snapshot("death-burst-1350")
	check(death_burst_parents.all(func(p):return p.particles.is_empty() and p.released==0.0),"native newborn death parents expire without a second smoke burst")
	check(app.sim.enemies.has(burst_enemy) and int(burst_enemy.state)==2 and app.particle_fx.systems.size()==8 and dormant_roots.all(func(sys):return sys.particles.is_empty()),"native newly complete owner retains empty roots until next manager pass")
	app._process(.03)
	check(not app.sim.enemies.has(burst_enemy) and app.particle_fx.systems.is_empty(),"native next manager pass destroys owner roots and child pools")
	await snapshot("death-burst-1380-removed")
	app.qa_gallery=burst_qa_gallery
	app.animation_delta_ms=retained_animation_delta
	app.start_mission("8",true,false);app.sim.spawn_hold=true
	app.sim.clock_ms=int(app.sim.config.wavedelay)/2
	check(app.ClassicUI.Wave.battle_rows(app.sim)[0].x==64,"normal wave countdown scrolls half a native60px slot")
	await snapshot("wave-scroll-050")
	app.sim.wave_index=1;app.sim.next_wave_ms=app.sim.clock_ms+int(app.sim.config.wavedelay)
	check(app.ClassicUI.Wave.battle_rows(app.sim)[0].number==2,"launched wave leaves the upcoming strip")
	app.handle_event({"kind":"wave","early":false,"ms":app.sim.clock_ms})
	check(app.wave_fx.layers.size()==4 and absf(app.wave_fx.layers[0].clock_ms-500)<0.001 and absf(app.wave_fx.layers[3].clock_ms-50)<0.001,"native wave burst uses four separately warmed systems")
	await snapshot("wave-launch-000")
	app.wave_fx.just_started=false
	for i in range(20):app.wave_fx.advance(25)
	await snapshot("wave-launch-050")
	app.start_mission("8",true,false);app.sim.spawn_hold=true
	var wave_key=InputEventKey.new();wave_key.keycode=KEY_N;wave_key.pressed=true
	app.sim.paused=true;get_viewport().push_input(wave_key,true)
	check(app.wave_collapse.is_empty() and app.sim.early_wave_count==0,"paused game rejects early launch")
	app.sim.paused=false;get_viewport().push_input(wave_key,true)
	check(not app.wave_collapse.is_empty() and app.sim.wave_index==0 and app.sim.early_wave_count==1,"early key starts the original collapse and counts its press before launch")
	get_viewport().push_input(wave_key,true)
	check(app.sim.early_wave_count==1,"repeated input during collapse cannot count another early wave")
	for i in range(5):app._process(0.03)
	check(app.sim.wave_index==0 and app.wave_collapse.first> -39,"enemies wait while the early wave cell slides away")
	await snapshot("wave-early-015")
	var collapsed=app.wave_collapse.distance
	app.sim.paused=true;app._process(0.5)
	check(app.wave_collapse.distance==collapsed and app.sim.wave_index==0,"pause freezes the pending collapse")
	app.sim.paused=false
	for i in range(10):app._process(0.03)
	await snapshot("wave-early-045")
	for i in range(30):
		if app.wave_collapse.is_empty():break
		app._process(0.03)
	check(app.wave_collapse.is_empty() and app.sim.wave_index==1 and app.sim.early_wave_count==1,"native-39 boundary launches once without counting twice")
	# Independent preserved ARM vertices, supplied only in the source audit.
	var fixture=ProjectSettings.globalize_path("res://../tests/fixtures/native-bolt-reference.json")
	if FileAccess.file_exists(fixture):
		var original=JSON.parse_string(FileAccess.get_file_as_string(fixture))
		for case in original.cases:
			var points=PackedVector2Array()
			for p in case.points:points.append(Vector2(p[0],p[1]))
			var strip=Bolt.ribbon(points,int(case["pass"]),float(case.alpha if int(case["pass"])==1 else case.intensity*4)/255.0)
			check(strip.vertices.size()==case.vertices.size(),"original ribbon vertex count")
			for i in range(mini(strip.vertices.size(),case.vertices.size())):
				var vertex=case.vertices[i]
				check(strip.vertices[i].distance_to(Vector2(vertex.pos[0],vertex.pos[1]))<0.0001,"original ribbon position")
				check(strip.uvs[i]==Vector2(vertex.uv[0],vertex.uv[1]),"original ribbon UV")
				var tint=strip.colors[i]
				check(absf(tint.r-vertex.color[0]/255.0)<0.004 and absf(tint.a-vertex.color[3]/255.0)<0.004,"original ribbon color and alpha")
	var f=FileAccess.open(destination.path_join("manifest.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"core_blend_samples":core_blend_samples,"ordered_blend_samples":ordered_blend_samples,"window_restoration":window_restoration,"fixture":"Isolated presentation states and actual viewport drag events, forced result XP, synthetic native GPU blend texels; no earned rewards or original whole-game equivalence."},"\t"));f.close()
	print("PRESENTATION_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures}))
	finished=true;completed.emit(0 if failures.is_empty() else 1)

func normal_bits(v:Vector2) -> Array:return [splash_bits(v.x),splash_bits(v.y)]
func normal_f(word) -> float:
	var bytes=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,int(word));return bytes.decode_float(0)
func normal_vec(words:Array) -> Vector2:return Vector2(normal_f(words[0]),normal_f(words[1]))
func normal_integer(value:Variant) -> Variant:
	if value is float:return int(value)
	if value is Array:return value.map(normal_integer)
	if value is Dictionary:
		var result={}
		for key in value:result[key]=normal_integer(value[key])
		return result
	return value

func normal_qa_actor(input:Dictionary) -> Dictionary:
	app.start_mission("1",true,false,false);app.tutorial=null
	var config=Content.mission("8").duplicate(true);config.waves=[];config.settings={"tutorial":0,"build_around_base":1}
	config.sources=[{"x":int(input.source_cell[0]),"y":int(input.source_cell[1]),"neutrality":int(input.source_owner),"target":int(input.source_target)}];config.bases=[]
	for base in input.bases:config.bases.append({"x":int(base.cell[0]),"y":int(base.cell[1]),"hp":0 if base.inactive else 1000,"hpmax":1000,"type":1,"player":int(base.owner),"neutrality":int(base.owner)})
	var map=Content.maps["1"].duplicate(true)
	map.hex_width=16;map.hex_height=16;map.hex_base=44;map.hex_side=22;map.hex_h=64;map.hex_offset_x=0;map.hex_offset_y=0;map.cells=[];map.foreground=[]
	for i in 256:map.cells.append({"w":1,"l":1})
	var data=Content.catalog.duplicate(true);var def=data.tower_creeps[int(input.creep_number)]
	def.hp=100;def.speed=int(input.get("speed",1000));def.rof=1000000;def.base_distance=2;def.damage=0;def.price=0
	app.sim=preload("res://scripts/simulation.gd").new();app.sim.setup(data,map,config,Profile.fresh(),114,Content.animations)
	app.sim.live_updates=false;app.sim.spawn_hold=true;app.sim.tutorial_finished=false
	app.camera=Vector2(512,384);app.zoom=1;app.animation_delta_ms=0;app.animation_epoch+=1
	app.refresh_controls();app.map_underlay.prepare()
	var actor=app.sim.spawn_enemy(int(input.creep_number),0,"",9001,false)
	app.sim.CreepView.update(app.sim,actor)
	return actor

func normal_qa_step(actor:Dictionary,dt:float) -> void:
	app.sim.tick_ms=dt;app.sim.clock_ms+=int(dt)
	app.sim.update_living_enemy(actor);app.sim.advance_creep_hover(actor,dt);app.sim.CreepView.update(app.sim,actor)
	if actor.has("portal_pose"):app.sim.CreepPortal.advance(actor.portal_pose,dt,app.sim.creep_portal_base(actor),actor.draw_light,float(actor.def.traits.get("shadow_scale_factor",1)))

func normal_qa_fields(actor:Dictionary) -> Dictionary:
	var path=[]
	for cell in actor.path.slice(int(actor.path_at)+1):path.append([cell.x,cell.y])
	return {"state":int(actor.state),"cell":[actor.cell.x,actor.cell.y],"next_cell":[actor.next_cell.x,actor.next_cell.y],"aligned":int(actor.attacking),"base_index":int(actor.base),"position_bits":normal_bits(actor.visual_pos),"logical_bits":normal_bits(actor.pos),"offset_bits":normal_bits(actor.animator_offset),"phase_bits":splash_bits(actor.hover_phase),"progress_bits":splash_bits(actor.move_progress),"remaining_count":int(actor.path_remaining),"path":path,"primary":str(actor.primary_animation),"secondary":str(actor.secondary_animation)}

func normal_qa_render_record(actor:Dictionary) -> Dictionary:
	var authored=actor.def.traits.get("scale",[1,1]);var pose=app.creep_render_pose(actor);var health=app.creep_health_layout(actor)
	return {"actual":normal_qa_fields(actor),"body_bits":normal_bits(app.creep_animator_position(actor)),"health_bits":normal_bits(health.origin),"native_scale_bits":normal_bits(pose.native_scale),"authored_scale_bits":normal_bits(Vector2(authored[0],authored[1])),"layers":actor.visual_layers.map(func(layer):return {"name":layer.state,"alpha_bits":splash_bits(layer.alpha),"rotation_bits":splash_bits(layer.rotation)}),"rendered_frames":pose.body_clocks.map(func(clock):return {"name":clock.get("name",""),"frame":clock.get("frame",0),"stopped":clock.get("stopped",false)}),"map_scale":app.map_scale(),"viewport_body":[(app.map_origin()+app.creep_animator_position(actor)*app.map_scale()).x,(app.map_origin()+app.creep_animator_position(actor)*app.map_scale()).y]}

func verify_normal_poses() -> void:
	var prior_gallery=app.qa_gallery;app.qa_gallery=true
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://data/qa-normal-poses.json"))
	check(fixture.poses.size()==10,"native normal poses retain ten immutable-oracle inputs")
	for row in fixture.poses:
		var actor=normal_qa_actor(row.input)
		for dt in row.warmup_deltas:normal_qa_step(actor,float(dt))
		if row.change!=null:
			for cell in row.change.blocked:app.sim.map.cells[int(cell[1])*16+int(cell[0])].w=0
			for i in row.change.get("inactive_base_indices",[]):app.sim.bases[int(i)].hp=0
			app.sim.path_cache.clear();app.sim.route_cost_cache.clear();app.sim.update_source_paths();app.sim.set_enemy_path(actor)
		for dt in row.after_deltas:normal_qa_step(actor,float(dt))
		var actual=normal_qa_fields(actor)
		for key in actual:
			if key=="primary" and not row.primary_name_verified:continue
			check(actual[key]==normal_integer(row.expected[key]),"native normal "+row.name+" original "+key)
		# Supplied health input only makes the original raw health anchor visible.
		# It never supplies position/state/path/animation expected values.
		actor.hp=50
		var record=normal_qa_render_record(actor)
		check(record.body_bits==normal_bits(normal_vec(row.expected.position_bits)+normal_vec(row.expected.offset_bits)),"native normal "+row.name+" unscaled original body offset")
		check(record.health_bits==normal_bits(normal_vec(row.expected.position_bits)+Vector2(-16,16)),"native normal "+row.name+" raw health anchor")
		check(record.native_scale_bits==record.authored_scale_bits,"native normal "+row.name+" authored asset proportions")
		app.animation_epoch+=1;app.animation_delta_ms=0
		await snapshot("creep-normal-"+str(row.name))
		var stretch=get_viewport().get_stretch_transform();check(stretch.x.x==stretch.y.y,"native normal "+row.name+" equal-axis canvas")
		captures[-1].normal_pose=record;captures[-1].normal_pose.original_fixture=row.original_fixture;captures[-1].normal_pose.original_sha256=row.original_sha256;captures[-1].limit=fixture.limit
	# Functional actual-constructor/portal join. R178 remains the separate
	# immutable supplied-actor original initializer oracle, without claiming
	# it executed this exact constructor-plus-portal sequence.
	var actor=normal_qa_actor(fixture.poses[0].input);var exit_cell=Vector2i(6,4)
	for i in 20:
		if actor.move_progress>=0.5 and actor.move_progress<1:break
		normal_qa_step(actor,100)
	var entry:Vector2i=actor.next_cell
	app.sim.abilities.m_portal=1
	check(app.sim.use_ability("m_portal",app.sim.center(entry.x,entry.y))=="Choose the portal exit.","native actual constructor places portal entry through ability")
	check(app.sim.use_ability("m_portal",app.sim.center(exit_cell.x,exit_cell.y)).is_empty(),"native actual constructor connects portal through ability")
	var pair=app.sim.portals[0].presentation
	app.sim.check_portal_transfers(pair,entry,exit_cell)
	check(actor.has("portal_pose") and actor.portal_pose.state==1 and pair.queue.has(actor.id),"native actual constructor enters portal queue through real admission")
	actor.hp=50
	await snapshot("creep-normal-portal-enter")
	captures[-1].normal_pose=normal_qa_render_record(actor);captures[-1].limit=fixture.limit
	for i in 20:
		if actor.portal_pose.state==2:break
		normal_qa_step(actor,100);app.sim.check_portal_transfers(pair,entry,exit_cell)
	var exit_point=app.sim.center(exit_cell.x,exit_cell.y)
	check(actor.portal_pose.state==2 and actor.portal_pose.clock==0 and pair.queue.is_empty(),"native actual constructor portal transfers from queue into exit stage")
	check(actor.pos==exit_point and actor.move_progress==1,"native actual constructor portal initializes exit and stationary boundary")
	await snapshot("creep-normal-portal-exit")
	captures[-1].normal_pose=normal_qa_render_record(actor);captures[-1].limit=fixture.limit
	var boundary_target:Vector2i=actor.next_cell
	normal_qa_step(actor,0)
	check(actor.cell==boundary_target and actor.pos==exit_point,"native actual constructor portal consumes stationary boundary without a jump")
	await snapshot("creep-normal-portal-boundary")
	captures[-1].normal_pose=normal_qa_render_record(actor);captures[-1].limit=fixture.limit

	app.qa_gallery=prior_gallery

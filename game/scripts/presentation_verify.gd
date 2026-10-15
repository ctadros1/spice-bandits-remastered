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

func snapshot(name:String,settle_portrait:bool=true) -> void:
	if settle_portrait:app.portrait_view.advance(0.5)
	app.queue_redraw();app.battle_overlay.queue_redraw();app.bolt_renderer.prepare()
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
	if name.begins_with("electricity") or name=="active-defense":
		record.towers=app.sim.towers.map(func(t):return {"type":t.type,"level":t.level,"filename":t.def.filename,"position":[t.pos.x,t.pos.y]})
		record.bolts=app.effects.filter(func(e):return e.kind=="shot").map(func(e):return {"texture":e.texture,"source":[e.points[0].x,e.points[0].y],"target":[e.points[-1].x,e.points[-1].y],"ball_source":[e.ball_source.x,e.ball_source.y],"ball":e.ball,"scatter":e.scatter,"ribbon_alpha":e.get("ribbon_alpha",1),"clock":e.get("bolt_clock",{}).duplicate(true)})
		record.render_slots=app.bolt_renderer.slots.filter(func(s):return s.visible).map(func(s):return {"texture":s.effect.texture,"atlas_pixels":[s.product.size.x,s.product.size.y],"atlas_rect":[s.atlas_rect.position.x,s.atlas_rect.position.y,s.atlas_rect.size.x,s.atlas_rect.size.y],"rectangle":[s.screen_rect.position.x,s.screen_rect.position.y,s.screen_rect.size.x,s.screen_rect.size.y]})
	captures.append(record)

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
	Profile.data=preview_profile
	app.magic_placement="";app.sim=preview_sim;app.tutorial=preview_tutorial;app.tutorial_step=preview_step
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
	app.reset_reward_bursts()
	Profile.data.xp=8;app.battle_initial_xp=0;app.result_started=0;app.elapsed_ui=0
	# Explicit zero-delay arithmetic fixture retained for the historical poses.
	# The ordinary result lifecycle inherits the active room's closed timer.
	app.result_closed_delay=0;app.result_initial_delay=0
	app.notice_until=0;app.refresh_controls()
	var result_control_count=app.ui.get_child_count()
	for time in [0.5,2.0,4.0]:
		while app.elapsed_ui<time:app._process(minf(0.03,time-app.elapsed_ui))
		await snapshot("result-%03d"%int(time*100))
	check(app.ui.get_children().filter(func(n):return n.has_meta("result_spice")).all(func(n):return n.modulate.a==0),"spice reward waits for the original post-XP clock")
	var spice_rows=app.ui.get_children().filter(func(n):return n.has_meta("result_spice"))
	check(spice_rows.size()==1 and spice_rows[0].text==app.result_spice_text() and spice_rows[0].get_theme_font("font")==app.font and spice_rows[0].get_theme_font_size("font_size")==20,"spice reward uses one original regular20pt text object")
	while app.elapsed_ui<5.025:app._process(minf(0.03,5.025-app.elapsed_ui))
	await snapshot("result-spice-entering")
	while app.elapsed_ui<5.25:app._process(minf(0.03,5.25-app.elapsed_ui))
	check(spice_rows[0].modulate.a>0 and spice_rows[0].modulate.a<1 and spice_rows[0].scale.x>1 and spice_rows[0].position.x<app.results_origin().x+332,"native spice reveal enters enlarged and centered before settling")
	await snapshot("result-spice-growing")
	while app.elapsed_ui<5.55:app._process(minf(0.03,5.55-app.elapsed_ui))
	check(app.result_clock.spice_phase>=1 and app.ui.get_children().filter(func(n):return n.has_meta("result_spice")).all(func(n):return n.modulate.a==1),"spice reveal completes after its native500ms phase")
	check(app.ui.get_child_count()==result_control_count,"result UI does not accumulate tutorial labels each frame")
	check(app.reward_spice_burst and app.reward_burst_fx.systems.size()==7,"spice reveal emits seven original burst systems once")
	check(app.reward_burst_fx.systems.all(func(s):return s.definition.release_interval==5.0) and is_equal_approx(app.reward_burst_fx.clock_multiplier,1.6),"result bursts use the native release interval and particle clock")
	await snapshot("result-spice-555")
	app.battle_medals=[Content.catalog.tower_medals[0],Content.catalog.tower_medals[1]];app.refresh_controls()
	while app.elapsed_ui<7.75:app._process(minf(0.03,7.75-app.elapsed_ui))
	await snapshot("result-medal-growing")
	var growing=app.ui.get_children().filter(func(n):return n is TextureRect and n.has_meta("result_medal") and n.get_meta("result_medal")==0)[0]
	check(growing.size.x>43 and growing.size.x<60 and growing.modulate.a>0 and growing.modulate.a<1,"medal reveal shrinks from its native enlarged size")
	while app.elapsed_ui<8.0:app._process(minf(0.03,8.0-app.elapsed_ui))
	check(app.result_clock.medal_clock>0 and app.result_clock.medal_clock<1.5,"first medal's native slot opens before the second")
	await snapshot("result-medal-first")
	while app.elapsed_ui<10.0:app._process(minf(0.03,10.0-app.elapsed_ui))
	check(app.reward_medal_bursts.size()==2,"each revealed medal creates one original object burst")
	check(app.reward_burst_fx.systems.filter(func(s):return s.name=="WinSpiceBump").is_empty(),"spice burst has expired before the medal sequence finishes")
	check(app.ui.get_children().filter(func(n):return n.has_meta("result_medal")).all(func(n):return n.size==Vector2(43,43)),"completed medals use native truncated0.8 source size")
	await snapshot("result-medals")
	app.selected_medal=app.battle_medals[0].duplicate(true);app.refresh_controls();await snapshot("result-medal-description");app.selected_medal={};app.refresh_controls()
	var fractional_xp=Profile.data.xp;Profile.data.xp=9.5
	await snapshot("result-fractional-xp")
	check(SpiceNative.format_xp(app.displayed_xp(),false)=="10","result XP rounds fractional totals with the original libc format")
	Profile.data.xp=fractional_xp
	# Separate incremental sequence after an active room has already passed
	# the two-second delay, matching the recorded normal-length battle.
	app.elapsed_ui=0;app.result_started=-1;app.result_clock={};app.result_clock_age=0
	app.result_closed_delay=3;app.result_initial_delay=0;app.result_previous_xp=0
	app.reward_fx.reset();app.reward_bar_emitting=false;app.reset_reward_bursts()
	app.battle_medals.clear();app.battle_spice_reward=3;app.refresh_controls()
	for time in [0.5,0.72,0.9,1.5,2.4,3.0,3.6,4.2,4.8,5.4,6.0]:
		while app.elapsed_ui<time:app._process(minf(0.03,time-app.elapsed_ui))
		if time==0.5:check(app.result_clock.xp_phase==0,"ordinary result XP waits for the opening fade")
		if time==0.9:check(app.result_clock.xp_phase>0 and app.result_clock.spice_phase==0,"ordinary result XP starts after fade without a new two-second delay")
		if time==3.0:check(app.result_clock.xp_phase>1 and app.result_clock.spice_phase==0,"ordinary result completes XP before the separate spice phase")
		if time==4.8:check(app.result_clock.spice_phase>=1 and app.reward_spice_burst,"ordinary result spice text and once-only burst reveal at the inherited clock age")
		await snapshot("result-room-%03d"%roundi(time*100))
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

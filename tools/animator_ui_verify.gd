extends SceneTree
const Anim=preload("res://scripts/animator_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label)
func fixture(name:String):return JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-"+name+"-reference.json")))
func _initialize():
	create_timer(30).timeout.connect(func():push_error("Animator source unit exceeded its bound");quit(1))
	run.call_deferred()
func run():
	var clocks=fixture("animator-clock");var clock_frames=0
	for c in clocks.cases:
		var i=c.input;var state=Anim.initial(i.count,i.rate,i.loop,i.multiplier,i.divisor)
		for frame in c.frames:
			Anim.advance(state,frame.dt,0);clock_frames+=1
			check(state.phase==Anim.f32(frame.phase) and state.frame==int(frame.frame) and state.stopped==frame.finished,"full original ordinary clock/stop/loop-overflow arithmetic")
	var alpha=fixture("animator-alpha");var alpha_frames=0
	for c in alpha.cases:
		var i=c.input;var state=Anim.initial(0,i.rate,i.loop);state.alpha_from=Anim.f32(i.start);state.alpha_to=Anim.f32(i.end)
		for frame in c.frames:
			Anim.advance(state,0,int(frame.now),true);alpha_frames+=1
			check(state.alpha_start==int(frame.timer_start) and state.stopped==frame.finished,"original monotonic opacity timer/finish/reverse")
			check(state.alpha_from==Anim.f32(frame.from) and state.alpha_to==Anim.f32(frame.to),"original opacity endpoint direction")
			for channel in range(4):check(state.alpha_color[channel]==Anim.f32(frame.rgba[channel]),"original exact opacity RGBA")
	var rendering=fixture("animator-render");var render_frames=0
	for c in rendering.cases:
		var keys=[Vector4(64,64,0,0),Vector4(65 if c.geometry=="atlas_x" else 64,64,3 if c.geometry=="offset" else 0,0)]
		var recipe=Anim.render_frames(int(c.phase)%2,c.phase,keys,c.interpolation,c.alpha,Anim.f32(.3*c.alpha),Color(.3,.3,.3,1))
		var expected=c.calls.filter(func(call):return call.method=="frame")
		check(recipe.size()==expected.size(),"original interpolation predicate uses atlas coordinates and offsets")
		for index in range(mini(recipe.size(),expected.size())):
			check(recipe[index].frame==int((int(expected[index].frame)-0x11000)/0x100),"original current/next frame order and wrap")
			for channel in range(4):check(recipe[index].color[channel]==Anim.f32(expected[index].rgba[channel]),"original raw frame RGBA including animator opacity override")
			render_frames+=1
	var frames=fixture("animation-frame")
	for c in frames.cases:
		var i=c.input;var offset=Anim.offset(Vector2(i.group[0],i.group[1]),Vector2(i.offset[0],i.offset[1]),Vector2(i.size[0],i.size[1]))
		check(offset==Vector2(c.output.offset[0],c.output.offset[1]),"full original AddFrame group/individual offset and odd-size half-pixel correction")
	var stacks=fixture("animation-stack");var stack_frames=0
	for c in stacks.cases:
		var i=c.input;var x=int(i.x);var y=4;var expected=[]
		for index in range(3):
			if x+int(i.size[0])>=256:x=0;y+=int(i.size[1])
			expected.append(Vector2i(x,y));x+=int(i.size[0])
		if i.reverse:expected.reverse()
		for index in range(3):
			var frame=c.output[index];stack_frames+=1
			check(Vector2i(frame.atlas_bytes[0],frame.atlas_bytes[1])==expected[index],"original stack UV wrap/reverse order")
			check(Anim.offset(Vector2.ZERO,Vector2(i.offset[0],i.offset[1]),Vector2(i.size[0],i.size[1]))==Vector2(frame.offset[0],frame.offset[1]),"original stack uses supplied absolute offset and odd-size correction")
	var app=load("res://scripts/main.gd").new();app.sim=load("res://scripts/simulation.gd").new()
	app.animation_epoch=1;app.animation_delta_ms=30;var mine={}
	var mine_reference=clocks.cases.filter(func(c):return int(c.input.count)==8 and float(c.input.rate)==5)[0].frames
	var clock=app.owned_animation(mine,"lights","sfx/mine_lights","Builded")
	check(clock.phase==Anim.f32(mine_reference[0].phase),"mine lights start their own source clock only when first rendered")
	app.owned_animation(mine,"lights","sfx/mine_lights","Builded")
	check(clock.phase==Anim.f32(mine_reference[0].phase),"repeat native readback preserves the same process-frame animation")
	app.animation_epoch=2;app.sim.paused=true;app.animation_delta_ms=100
	app.owned_animation(mine,"lights","sfx/mine_lights","Builded")
	check(clock.phase==Anim.f32(mine_reference[0].phase),"paused owner retains animation phase")
	app.sim.paused=false;app.animation_epoch=3;app.animation_delta_ms=100
	app.owned_animation(mine,"lights","sfx/mine_lights","Builded")
	check(clock.phase==Anim.f32(mine_reference[3].phase),"live owner resumes its fractional frame clock")
	var gate={};var pending=app.owned_animation(gate,"portal","sfx/portals","Blue",false)
	check(pending.phase==0 and pending.stopped,"pending portal retains original stopped animation")
	app.animation_epoch=4;app.owned_animation(gate,"portal","sfx/portals","Blue",true)
	check(pending.phase==Anim.f32(.1) and not pending.stopped,"original same-name portal play resumes after connection growth begins")
	var content_for_portal=root.get_node("Content");var portal_mission=content_for_portal.mission("1");var portal_profile=root.get_node("Profile").fresh();portal_profile.abilities.m_portal=5
	app.sim.setup(content_for_portal.catalog,content_for_portal.maps[portal_mission.map],portal_mission,portal_profile,114,content_for_portal.animations);app.sim.spawn_hold=true
	check(app.sim.use_ability("m_portal",app.sim.center(7,4))=="Choose the portal exit.","real typed-array portal entry placement succeeds")
	var live_pair=app.sim.portals[0].presentation
	var submitted=app.battle_portal_objects()[0]
	app.animation_epoch+=1;app.animation_delta_ms=250
	app.owned_animation(submitted.gate,"portal","sfx/portals",submitted.state,false)
	check(live_pair.gates[0].has("render_animators") and live_pair.gates[0].render_animators.portal.stopped,"rendered portal retains the actual simulation gate identity")
	check(app.sim.use_ability("m_portal",app.sim.center(9,4)).is_empty(),"real typed-array portal exit placement succeeds")
	app.sim.advance_frame(250);app.animation_epoch+=1
	for portal in app.battle_portal_objects():app.owned_animation(portal.gate,"portal","sfx/portals",portal.state,portal.gate.animation_played)
	check(live_pair.gates.all(func(g):return g.render_animators.portal.phase==.25 and not g.render_animators.portal.stopped),"both actual live gate identities retain their original quarter-frame phase")
	app.free()
	var plays=fixture("animator-play")
	for c in plays.cases:
		var i=c.input;var state=Anim.initial(4,8,true)
		state.name=i.current;state.phase=Anim.f32(i.phase);state.frame=int(i.phase);state.stopped=i.stopped;state.reset_on_change=i.reset;state.alpha_start=33;state.alpha_now=44
		var definition={} if i.request=="missing" else {"frames":2 if i.request=="B" else 4,"speed":.5 if i.request=="B" else 8,"loop":i.request=="A","alpha_anim_from":1 if i.request=="B" else 0,"alpha_anim_to":0 if i.request=="B" else 1}
		Anim.play(state,i.request,definition)
		for key in ["name","frame","stopped","alpha_start","alpha_now"]:check(state[key]==c.output[key],"full original constructor/play restart/reset/missing-name "+key)
		for key in ["phase","alpha_from","alpha_to"]:check(state[key]==Anim.f32(c.output[key]),"full original play exact scalar "+key)
	var content=root.get_node("Content");var authored_frames=0;var combined_offset_frames=0
	for set_name in content.animations:
		for state_name in content.animations[set_name].states:
			var definition=content.animations[set_name].states[state_name]
			for index in range(definition.resolved_frames.size()):
				var declaration=definition.resolved_frames[index]
				var resource=content.animations[set_name].resources[str(int(declaration.get("res_id",definition.get("res_id",1))))]
				var size=Vector2(declaration.get("f_width",resource.frame_width),declaration.get("f_height",resource.frame_height))
				var group=Vector2(definition.get("offset_x",0),definition.get("offset_y",0)) if declaration.get("native_added",0)==1 else Vector2.ZERO
				var offset=Anim.offset(group,Vector2(declaration.get("offset_x",0),declaration.get("offset_y",0)),size)
				var actual=content.frame(set_name,state_name,index)
				check(actual.offset==offset,"all imported frame offsets follow original group/individual/stack/parity fields")
				check(actual.native_key==Vector4(declaration.get("x",0),declaration.get("y",0),offset.x,offset.y),"authored source frame key retains atlas coordinates rather than dimensions")
				check(actual.blend_flags==((1 if bool(definition.get("alpha_between_frame",false)) else 0)|(2 if bool(definition.get("alpha_anim",false)) else 0)),"prepared frame flags preserve original declaration")
				authored_frames+=1
				if group!=Vector2.ZERO:combined_offset_frames+=1
	var report={"checks":checks,"failures":failures,"clock_cases":clocks.cases.size(),"clock_frames":clock_frames,"alpha_cases":alpha.cases.size(),"alpha_frames":alpha_frames,"render_cases":rendering.cases.size(),"render_frames":render_frames,"frame_layout_cases":frames.cases.size(),"play_cases":plays.cases.size(),"authored_frames":authored_frames,"combined_offset_frames":combined_offset_frames,"stack_cases":stacks.cases.size(),"stack_frames":stack_frames,"scope":"Original supplied-record clock/RGBA/order/frame-offset arithmetic; loader/whole owner scheduling/GPU are separate."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/animator-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("ANIMATOR_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

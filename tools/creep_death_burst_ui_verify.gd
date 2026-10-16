extends SceneTree
var checks=0
var failures=[]
var skipped=[]
var content
func _initialize():
	create_timer(60).timeout.connect(func():quit(1));run.call_deferred()
func check(value:bool,label:String):
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func missing_textures(names:Array) -> Array:
	return names.filter(func(n):return content.tex(str(content.particles.systems[n].texture))==null)
func run():
	content=root.get_node("Content")
	# Runtime load after autoload registration; external --script compilation
	# cannot statically extend these singleton-dependent game classes.
	var fx_script=load("res://scripts/particle_fx.gd")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-death-effects-reference.json"))
	var creation_cases=0
	for c in fixture.cases:
		var expected=c.output.events.filter(func(e):return e.method=="emit")
		var missing=missing_textures(expected.map(func(e):return str(e.system)))
		if not missing.is_empty():skipped.append({"phase":"creation","resource":c.input.name,"missing_textures":missing});continue
		creation_cases+=1
		var fx=fx_script.new()
		var point=Vector2(c.input.aim[0],c.input.aim[1]);fx.emit_creep_death_burst(str(c.input.name),point)
		check(fx.systems.size()==expected.size(),"original SetDie alias count")
		for i in mini(fx.systems.size(),expected.size()):
			var s=fx.systems[i];var e=expected[i]
			check(s.name==e.system and s.pos==Vector2(e.point[0],e.point[1]),"original ordered alias/anchor packet")
			check(s.particles.size()==int(e.count) and not s.emitting and int(e.interval_bits)==1084227584,"actual initial count versus original5s-interval newborn burst")
		fx.free()
	var timeline=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-death-tail-reference.json"))
	var actual_cases=0
	for c in timeline.cases:
		var resource=str(c.resource);var names=c.frames[0].output.systems.map(func(s):return str(s.name))
		var missing=missing_textures(names)
		if not missing.is_empty():skipped.append({"phase":"tail","resource":resource,"dt_ms":c.dt_ms,"missing_textures":missing});continue
		actual_cases+=1
		var fx=fx_script.new();fx.emit_creep_death_burst(resource,Vector2(333.25,219.75))
		var parents=fx.systems.duplicate()
		var dt=Vector2(Vector2(float(c.dt_ms),0).x*Vector2(.001,0).x,0).x
		for row in c.frames:
			if int(row.frame)>0:
				fx.clock_seconds=Vector2(fx.clock_seconds+dt,0).x;fx.clock_ms=fx.clock_seconds*1000.0
				# The native tail oracle explicitly omits child particle pointers.
				SpiceNative.advance_systems(fx.systems,fx.clock_ms,func(_n,_p,_v):pass,fx.emit_batch,fx.random,dt)
			for original in row.output.systems:
				var matching=parents.filter(func(s):return s.name==original.name)
				check(matching.size()==1 and matching[0].particles.size()==int(original.active),"original full-tail active parent count "+resource+" frame"+str(row.frame))
			check(parents.all(func(s):return s.released==0.0),"original tail has no second initial-system emission")
		check(parents.all(func(s):return s.particles.is_empty()),"original newborn tails expire")
		fx.free()
		await process_frame
	# Actual Main kill branch: only in-memory QA sound setting changes, restored.
	var profile=root.get_node("Profile");var profile_before=profile.data.duplicate(true);profile.data.settings.sound=false
	var app=load("res://scripts/main.gd").new();app.test_session=true
	var fx=fx_script.new();app.particle_fx=fx
	var main_cases=0
	for key in range(content.catalog.tower_creeps.size()):
		var definition=content.catalog.tower_creeps[key];fx.reset()
		if not definition.has("filename"):continue
		# Use original fixture packets as expectation, rather than helper internals.
		var original=fixture.cases.filter(func(c):return c.input.name=="creeps/"+str(definition.filename))
		if original.is_empty():continue
		var expected=original[0].output.events.filter(func(e):return e.method=="emit")
		if not missing_textures(expected.map(func(e):return str(e.system))).is_empty():continue
		main_cases+=1;app.handle_event({"kind":"kill","id":9001,"type":int(key),"pos":Vector2(101,203),"ms":0,"reward":10})
		check(fx.systems.size()==expected.size() and fx.systems.all(func(s):return not s.emitting),"actual Main kill initial death systems")
	check(app.pending_xp.is_empty(),"QA Main kill cannot earn progression")
	fx.free();app.free()
	# Exercise the same live elapsed/clock selector used by ordinary Main.
	profile.data.settings.music=false
	var live=load("res://scripts/main.gd").new();live.set_meta("qa_fixture",true);root.add_child(live);live.set_process(false)
	live.start_mission("1",true,false,false);live.tutorial=null;live.sim.spawn_hold=true;live.sim.live_updates=true;live.qa_gallery=false
	var enemy=live.sim.spawn_enemy(1,0,"",995,false);enemy.pos=live.sim.center(8,6);enemy.visual_pos=enemy.pos;enemy.path=[]
	live.sim.damage(enemy,float(enemy.max_hp)*10);live._process(0)
	var live_parents=live.particle_fx.systems.filter(func(sys):return "explosion" in str(sys.get("creep_alias","")))
	var dormant=live.particle_fx.systems.filter(func(sys):return not "explosion" in str(sys.get("creep_alias","")))
	check(live_parents.size()==3 and dormant.size()==5 and dormant.all(func(sys):return sys.particles.is_empty()),"actual Main retains five empty constructor roots plus three SetDie bursts")
	var original_case=timeline.cases.filter(func(c):return c.resource=="creeps/creep1" and c.dt_ms==30)[0]
	for frame in range(46):
		if frame>0:live._process(.03)
		var original=original_case.frames[frame].output.systems
		check(PackedFloat32Array([live.particle_fx.clock_seconds]).to_byte_array().decode_u32(0)==int(original[0].clock_bits),"actual live Main clock exactly matches original frame"+str(frame))
		for i in range(original.size()):check(live_parents[i].particles.size()==int(original[i].active),"actual live Main parent count frame"+str(frame))
		if frame==20:
			var before_pause=var_to_bytes(live_parents);var before_clock=live.particle_fx.clock_seconds
			live.toggle_pause();live._process(.5)
			check(live.sim.paused and var_to_bytes(live_parents)==before_pause and live.particle_fx.clock_seconds==before_clock,"actual live Main pause holds parents/clock")
			live.toggle_pause();check(not live.sim.paused,"actual live Main resume")
	check(live.pending_xp.is_empty(),"live QA lethal flow cannot earn progression")
	live.free();profile.data=profile_before
	var report={"checks":checks,"failures":failures,"original_creation_cases":creation_cases,"actual_parent_timeline_cases":actual_cases,"actual_main_cases":main_cases,"actual_live_main_frames":46,"skipped":skipped,"scope":"Original fullSetDie ordered initial packets/counts and fullCreep.Update tail parent counts versus actual ParticleFX/native updates. The original supplied tail omits child pointers; its parent-count expectations are unchanged. The legacy global callback is unused by the new owned path, which additionally runs real children verified independently. Availability is checked; all100creation/50tail cases resolve existing textures through preserved aliases (creep7 uses Creep6ExplosionParts). Unused Creep7ExplosionParts definitions still have missing obsolete references; no textures are synthesized. Actual Main kill branch runs in QA with no audio/profile writes. Current caller anchor, trajectories/globalRNG, complete retained dying actors/later emissions/campaign timing remain separate; owned child fields have independent original fixtures. Duration0 is a bounded newborn one-burst adapter, not full original emitter lifetime."}
	var file=FileAccess.open("res://../builds/creep-death-burst-r130-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_DEATH_BURST ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

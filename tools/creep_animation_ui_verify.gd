extends SceneTree
const Freeze=preload("res://scripts/creep_freeze_view.gd")
const CreepAnim=preload("res://scripts/creep_animator_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func read_fixture(name:String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/"+name))
func _initialize() -> void:
	create_timer(30).timeout.connect(func():push_error("Creep animator source unit exceeded its bound");quit(1))
	call_deferred("run")
func run() -> void:
	var speed=read_fixture("native-creep-animation-speed-reference.json")
	for i in speed.cases.size():
		var c=speed.cases[i];var a=c.input
		var value=Freeze.speed(float(a.base),float(a.first),float(a.second),float(a.pending),int(a.held)!=0)
		var actual={"speed_bits":bits(value.current),"primary_divisor_bits":bits(value.divisor),"secondary_divisor_bits":bits(value.divisor),"primary_multiplier_bits":bits(value.multiplier),"secondary_multiplier_bits":bits(value.multiplier),"pending_bits":bits(value.pending),"consumed_slow":int(value.consumed_slow),"tracker_value":1 if value.consumed_slow and a.tracker else 17}
		for k in actual:check(actual[k]==int(c.output[k]),"speed %d %s"%[i,k])
	var freeze=read_fixture("native-creep-animation-freeze-reference.json")
	for i in freeze.cases.size():
		var c=freeze.cases[i];var a=c.input
		var actor={"state":int(a.state),"freeze_attached":bool(a.existing),"freeze_remaining":17,"freeze_auxiliary_present":bool(a.tracker),"freeze_auxiliary_value":17}
		var old_pointer=0x4000 if a.existing else 0
		Freeze.use_freeze(actor)
		var pointer=0x3000 if int(a.state) not in [2,3] else old_pointer
		check(pointer==int(c.output.attached_pointer),"freeze attachment %d"%i)
		check(actor.freeze_auxiliary_value==int(c.output.tracker_after_attach),"freeze tracker %d"%i)
		for j in c.output.frames.size():
			var row=c.output.frames[j];var v=Freeze.speed(1000,1,1,float(a.slow),actor.freeze_attached)
			actor.consumed_slow=v.consumed_slow
			if v.consumed_slow and actor.freeze_auxiliary_present:actor.freeze_auxiliary_value=1
			var before=pointer if actor.freeze_attached else 0
			Freeze.process_creep(actor,77 if pointer==0x4000 else int(row.counter))
			var actual={"pointer_before_freeze":before,"pointer_after_freeze":pointer if actor.freeze_attached else 0,"remaining":actor.freeze_remaining,"multiplier_bits":bits(v.multiplier),"tracker":actor.freeze_auxiliary_value,"consumed_slow":int(actor.consumed_slow)}
			for k in actual:check(actual[k]==int(row[k]),"freeze %d %d %s"%[i,j,k])
	var manager=read_fixture("native-creep-freeze-reference.json")
	for i in manager.timers.size():
		var c=manager.timers[i];var active=false;var sounds=[];var counts=[]
		for count in c.input.remaining:
			var state={"remaining":int(count),"room_active":true}
			if Freeze.advance_timer(state,float(c.input.dt)):sounds.append("freeze_deactivation-mono")
			active=active or state.room_active;counts.append(state.remaining)
		check(active==c.output.room_active,"room freeze flag %d"%i)
		check(counts==c.output.remaining.map(func(v):return int(v)),"room freeze counts %d"%i)
		check(sounds==c.output.sounds,"room freeze sounds %d"%i)
	for i in manager.attachments.size():
		var c=manager.attachments[i]
		for j in c.output.size():
			var actor={"owner":int(c.input.owners[j]),"state":int(c.input.states[j]),"freeze_attached":false,"freeze_auxiliary_present":true,"freeze_auxiliary_value":17}
			Freeze.apply(actor,int(c.input.player_owner))
			check(actor.freeze_attached==c.output[j].attached,"manager attachment %d %d"%[i,j])
			check(actor.freeze_auxiliary_value==int(c.output[j].tracker),"manager tracker %d %d"%[i,j])
	var render=read_fixture("native-creep-animation-render-reference.json")
	for i in render.cases.size():
		var c=render.cases[i];var a=c.input
		var definition={"frames":8,"speed":4,"loop":true}
		var states=[CreepAnim.initial("RunDown",definition),CreepAnim.initial("RunDown",definition)]
		for state in states:state.phase=0.75
		var v=Freeze.speed(float(a.base),1,1,float(a.slow),int(a.held)!=0)
		for j in c.frames.size():
			var row=c.frames[j];var updates=[];var frames=[]
			for draw in int(row.draws):
				for actor in [0,1] if a.secondary else [0]:
					CreepAnim.prepare(states[actor],"RunDown",definition,v.divisor,v.multiplier,false)
					CreepAnim.render_tick(states[actor],float(row.dt),bool(a.stopped))
					updates.append(76 if actor==0 else 192);frames.append(0x10200+actor*0x1000+int(states[actor].frame)*0x40)
			var actual={"primary_phase_bits":bits(states[0].phase),"secondary_phase_bits":bits(states[1].phase),"primary_frame":states[0].frame,"secondary_frame":states[1].frame}
			for k in actual:check(actual[k]==int(row[k]),"render %d %d %s"%[i,j,k])
			check(updates==row.updates.map(func(v):return int(v)),"render update routing %d %d"%[i,j])
			check(frames==row.frame_calls.map(func(f):return int(f.frame)),"render frame calls %d %d"%[i,j])
	var moving=CreepAnim.initial("RunDown",{"frames":8,"speed":4,"loop":true})
	CreepAnim.render_tick(moving,100)
	var phase=moving.phase
	CreepAnim.prepare(moving,"RunUp",{"frames":8,"speed":4,"loop":true},1,1,false)
	check(moving.phase==phase,"a walking direction change retains phase")
	CreepAnim.prepare(moving,"RunRight",{"frames":8,"speed":4,"loop":true},1,1,true)
	check(moving.phase==0 and moving.frame==0 and moving.stopped,"attack explicitly stops at frame0")
	CreepAnim.prepare(moving,"RunRight",{"frames":8,"speed":4,"loop":true},1,1,false)
	CreepAnim.render_tick(moving,100)
	check(not moving.stopped and moving.phase==phase,"same direction resumes after attack")
	var content=root.get_node("Content")
	var profile=root.get_node("Profile").fresh()
	var mission=content.mission("1")
	var sim=load("res://scripts/simulation.gd").new()
	sim.setup(content.catalog,content.maps[mission.map],mission,profile,118,content.animations)
	sim.spawn_hold=true;sim.abilities.m_freeze=5
	var enemy=sim.spawn_enemy(1,0,"");enemy.owner=0
	var friendly=sim.spawn_enemy(1,0,"");friendly.owner=1
	var dying=sim.spawn_enemy(1,0,"");dying.owner=0;dying.state=3
	check(sim.use_ability("m_freeze").is_empty(),"actual ability starts source countdown")
	var duration=int(sim.freeze_state.remaining)
	check(enemy.freeze_attached and not friendly.freeze_attached and not dying.freeze_attached,"actual manager bridge filters owner/dying states")
	sim.advance_frame(16.667)
	check(sim.freeze_state.remaining==maxi(0,int(Freeze.f32(duration-16.667))),"actual simulation countdown uses original float32 subtraction/truncation")
	check(enemy.animation_multiplier==0 and enemy.freeze_remaining==sim.freeze_state.remaining,"actual creep speed precedes freeze countdown read")
	var late=sim.spawn_enemy(1,0,"");late.owner=0
	check(not late.freeze_attached,"new supplied spawn has no old freeze pointer")
	sim.freeze_state.remaining=1
	sim.advance_frame(30)
	check(sim.freeze_state.remaining==0 and sim.freeze_state.room_active,"expiry frame retains original room freeze flag")
	check(enemy.animation_multiplier==0 and enemy.freeze_remaining==0 and not enemy.freeze_attached,"expiry frame stops animation before releasing pointer")
	sim.advance_frame(30)
	check(enemy.animation_multiplier==1 and not sim.freeze_state.room_active and sim.freeze_until==0,"following frame resumes animation and inactive deadline remains0")
	var app=load("res://scripts/main.gd").new();app.sim=sim
	var definition={"frames":8,"speed":4,"loop":true}
	var states={"RunDown":definition,"RunUp":definition}
	enemy.animation_divisor=1.0;enemy.animation_multiplier=1.0;enemy.attacking=false
	app.animation_epoch=1;app.animation_delta_ms=100
	var first=app.creep_owned_animation(enemy,0,{"state":"RunDown"},states)
	check(first.phase==phase,"actual primary bridge advances its owned clock")
	app.creep_owned_animation(enemy,0,{"state":"RunDown"},states)
	check(first.phase==phase,"repeated capture holds the same rendered epoch")
	app.animation_epoch=2
	app.creep_owned_animation(enemy,0,{"state":"RunUp"},states)
	check(first.phase==Freeze.f32(phase+phase),"actual walking turn retains progress")
	check(app.creep_animation_owners[enemy.id].clocks[1].is_empty(),"invisible secondary has no rendered ticks")
	var secondary=app.creep_owned_animation(enemy,1,{"state":"RunUp"},states)
	check(secondary.phase==phase,"secondary starts only when rendered")
	sim.paused=true;app.animation_epoch=3
	app.creep_owned_animation(enemy,0,{"state":"RunUp"},states)
	check(first.phase==Freeze.f32(phase+phase),"actual paused primary retains its phase")
	sim.paused=false;enemy.attacking=true;app.animation_epoch=4
	app.creep_owned_animation(enemy,0,{"state":"RunUp"},states)
	check(first.phase==0 and first.stopped,"actual attack bridge stops at original frame0")
	check(secondary.phase==0 and secondary.stopped,"actual attack also resets the cached hidden secondary")
	enemy.attacking=false;app.animation_epoch=5
	app.creep_owned_animation(enemy,0,{"state":"RunUp"},states)
	check(first.phase==phase and not first.stopped,"actual same-direction attack exit resumes")
	var reused=enemy.duplicate(true);app.animation_epoch=6
	var fresh=app.creep_owned_animation(reused,0,{"state":"RunUp"},states)
	check(fresh.phase==phase and not is_same(fresh,first),"reused ID with a different creature gets a fresh owned clock")
	check(not enemy.has("render_animators"),"creep render clocks stay outside simulation state")
	app.free()
	var sequence=read_fixture("native-creep-animation-sequence-reference.json")
	var real_definition={"frames":12,"speed":17,"loop":true}
	var trace_clocks=[CreepAnim.initial("RunDown",real_definition),CreepAnim.initial("RunDown",real_definition)]
	var direction="RunDown";var attacking=false
	for row in sequence.rows:
		var action=row.input
		direction=str(action.get("direction",direction))
		if action.get("attack",false):attacking=true
		if action.get("play",false):attacking=false
		var v=Freeze.speed(1000,1,1,float(action.get("slow",-1)),bool(action.get("held",false)))
		for index in row.clocks.size():
			CreepAnim.prepare(trace_clocks[index],direction,real_definition,v.divisor,v.multiplier,attacking)
			CreepAnim.render_tick(trace_clocks[index],float(action.dt),bool(action.get("paused",false)))
			check(bits(trace_clocks[index].phase)==int(row.clocks[index].phase_bits),"real marine owner sequence exact phase "+str(action.name))
			check(trace_clocks[index].frame==int(row.clocks[index].frame) and trace_clocks[index].stopped==row.clocks[index].stopped,"real marine owner sequence frame/stop "+str(action.name))
	var report={"checks":checks,"failures":failures,"speed_cases":speed.cases.size(),"freeze_cases":freeze.cases.size(),"manager_timer_cases":manager.timers.size(),"manager_attachment_cases":manager.attachments.size(),"render_cases":render.cases.size(),"scope":"Supplied original clock/freeze fields and callbacks. Complete room/loader/culling/attack caller/whole GPU remain separately bounded."}
	var f=FileAccess.open("res://../builds/creep-animation-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("CREEP_ANIMATION ",JSON.stringify({"checks":checks,"failures":failures.slice(0,8),"failure_count":failures.size()}));quit(1 if not failures.is_empty() else 0)

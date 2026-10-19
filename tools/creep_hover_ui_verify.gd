extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const State=preload("res://scripts/creep_state_view.gd")
const Freeze=preload("res://scripts/creep_freeze_view.gd")
var checks=0
var failure_count=0
var failures=[]
var sim=Sim.new()
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failure_count+=1
		if failures.size()<25:failures.append(label)
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func number(value:int) -> float:return PackedInt32Array([value]).to_byte_array().decode_float(0)
func point(values:Array) -> Vector2:return Vector2(number(int(values[0])),number(int(values[1])))
func fixture(name:String,digest:String) -> Dictionary:
	var path="res://../tests/fixtures/"+name+".json"
	check(FileAccess.get_sha256(path)==digest,"unchanged independently repeated original "+name)
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func actor_for(idle:int,moving:int,active:int=0,phase:float=0,y:float=0) -> Dictionary:
	return {"state":0,"hover_when_idle":idle,"hover_while_moving":moving,"hover_active":active,"hover_phase":phase,"animator_offset":Vector2(0,y),"def":{"traits":{"offset":[0,0]}}}
func advance(actor:Dictionary,dt:float) -> void:
	if sim.has_method("advance_creep_hover"):sim.call("advance_creep_hover",actor,dt)
func compare(actor:Dictionary,phase:int,y:int,label:String) -> void:
	check(bits(float(actor.get("hover_phase",0)))==phase,label+" phase bits")
	check(bits(actor.get("animator_offset",Vector2.ZERO).y)==y,label+" retained offset bits")
func make_sim():
	var content=root.get_node("Content");var result=Sim.new();var config=content.mission("8").duplicate(true);config.waves=[]
	result.setup(content.catalog.duplicate(true),content.maps[config.map],config,root.get_node("Profile").fresh(),114,content.animations)
	result.spawn_hold=true;result.tutorial_finished=false
	return result
func run() -> void:
	check(sim.has_method("advance_creep_hover"),"actual simulation exposes original hover phase")
	var tail=fixture("native-creep-hover-reference","a717c416d295486401ab53491769fa9290aafd42fa2f737b53a5635f1babdbd6")
	for row in tail.cases:
		var input=row.input;var actor=actor_for(int(input.hover348),int(input.hover349),int(input.hover34a),float(input.phase),float(input.offset_y))
		advance(actor,float(input.delta));compare(actor,int(row.after.phase_bits),int(row.after.offset_y_bits),"single original hover call")
		if float(input.phase)==0:
			# Fresh live actors use implicit phase zero and the authored offset
			# until the first actual hover call; include nonzero base offsets.
			actor.erase("hover_phase");actor.erase("animator_offset")
			actor.def.traits.offset=[2.25,float(input.offset_y)]
			advance(actor,float(input.delta))
			var offset:Vector2=actor.get("animator_offset",Vector2(2.25,float(input.offset_y)))
			check(bits(float(actor.get("hover_phase",0)))==int(row.after.phase_bits),"fresh implicit phase matches original zero phase")
			check(offset.x==2.25 and bits(offset.y)==int(row.after.offset_y_bits),"first hover retains authored offset including float32 accumulation")
	for sequence in tail.sequences:
		var actor=actor_for(int(sequence.hover348),int(sequence.hover349))
		for row in sequence.frames:
			State.change(actor,int(row.requested_state));advance(actor,float(sequence.delta))
			compare(actor,int(row.after.phase_bits),int(row.after.offset_y_bits),"joined original SetState/tail")
			check(int(actor.hover_active)==int(row.after.hover34a),"original state selector remains joined")
	var movement=fixture("native-creep-hover-movement-reference","fd97dac03a1f901de26cb552d305c8f48c7eaea3b9f71fb998b885bb1e5ae97e")
	for sequence in movement.sequences:
		var actor=actor_for(int(sequence.hover348),int(sequence.hover349))
		for row in sequence.frames:
			State.change(actor,int(row.requested_state));advance(actor,float(sequence.delta))
			compare(actor,int(row.after.phase_bits),int(row.after.animator_offset_bits[1]),"full original movement/position joined hover")
	var owner=fixture("native-creep-hover-owner-reference","1f04af2e776bfefd713757411d54838bf50aeee939cdf7646503aca1fcbd1208")
	for sequence in owner.cases:
		var input=sequence.input;var actual=make_sim();var actor=actual.spawn_enemy(1,0,"",9003,false)
		actor.path=[];actor.base=-1;actor.speed=float(input.speed);actor.hover_when_idle=int(input.hover348);actor.hover_while_moving=int(input.hover349)
		actor.animator_offset=Vector2.ZERO;State.select_hover(actor,0)
		if input.freeze:Freeze.use_freeze(actor)
		for row in sequence.frames:
			# Supply the pre-room integer so its real countdown produces the
			# same post-room count provided to the original owner fixture.
			actual.freeze_state.remaining=int(ceil(float(row.supplied_counter)+float(input.delta)))
			actual.advance_frame(float(input.delta))
			check(actual.freeze_state.remaining==int(row.supplied_counter),"supplied post-room counter matches original input")
			check(actual.outcome=="playing","actual simulation owner phase executed")
			compare(actor,int(row.phase_bits),int(row.offset_bits[1]),"actual owner advances hover independently of walking/Freeze")
			check(bits(float(actor.animation_multiplier))==int(row.primary_multiplier_bits),"actual Freeze expiry animation multiplier ordering")
			check(bool(actor.freeze_attached)==bool(row.freeze_attached) and int(actor.freeze_remaining)==int(row.freeze_remaining),"actual Freeze lifetime unchanged")
		var stopped=var_to_bytes([actor.get("hover_phase",0),actor.animator_offset])
		actual.paused=true;actual.advance_frame(100)
		check(var_to_bytes([actor.get("hover_phase",0),actor.animator_offset])==stopped,"actual pause retains hover phase and offset")
		actual.particle_state.destroy_creep(actor)
	var render=fixture("native-creep-hover-render-reference","937fd8636613d8a5dbe48e00e62afdbb7bbc88a5f0e136b078ed44eba8b2b88b")
	var app=load("res://scripts/main.gd").new();app.sim=Sim.new()
	var authored=fixture("native-creep-authored-hover-reference","a04db89611a085fe6f0108e590fef4ab47ede915607a5f3d31d53a22e632153a")
	for sequence in authored.sequences:
		var actor=actor_for(int(sequence.hover348),int(sequence.hover349))
		actor.erase("hover_phase");actor.erase("animator_offset")
		actor.def.traits=root.get_node("Content").catalog.resource_params[str(sequence.resource)]
		actor.pos=Vector2.ZERO;actor.float_until=0
		for row in sequence.frames:
			State.change(actor,int(row.requested_state));advance(actor,float(sequence.delta))
			var body=app.creep_animator_position(actor)
			check(bits(float(actor.get("hover_phase",0)))==int(row.after.phase_bits),"constructor-derived original hover phase")
			check(bits(body.y)==int(row.after.offset_y_bits),"actual renderer retains original authored offset through hover accumulation")
			check(bits(body.x)==int(sequence.initial_offset_bits[0]),"authored horizontal offset stays unscaled")
	for sequence in render.cases:
		var input=sequence.input;var scale=Vector2(input.scale[0],input.scale[1]);var frame=Vector2(input.frame_offset[0],input.frame_offset[1])
		for row in sequence.frames:
			var raw=point(row.render.actor_position_bits);var offset=point(row.render.actor_offset_bits)
			var actor={"pos":raw,"visual_pos":raw,"animator_offset":offset,"def":{"traits":{"offset":[123,456]}},"float_until":0,"hp":30.0,"max_hp":100,"grow_ms":400,"state":0}
			var actual=app.creep_animator_position(actor)+frame*scale
			check(bits(actual.x)==int(row.render.quad_request.x_bits) and bits(actual.y)==int(row.render.quad_request.y_bits),"actual body anchor adds unscaled retained offset before scaled frame offset")
			var health=app.creep_health_layout(actor)
			check(health.origin==raw+Vector2(-16,16),"hover body offset never moves raw health anchor")
	app.free()
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"failure_count":failure_count,"failures":failures,"single_calls":tail.cases.size(),"tail_sequences":tail.sequences.size(),"movement_sequences":movement.sequences.size(),"owner_cases":owner.cases.size(),"render_cases":render.cases.size(),"authored_sequences":authored.sequences.size(),"scope":"Original R164 tail/SetState and R166 full movement-position phase/offset bits; actual Sim owner step compares R167 Freeze/hover fields with supplied counters and no walking route; actual Main body anchor plus existing scaled frame offset compares R168 quad requests and raw HP separation. Additional R172 full-constructor-derived authored offsets cover all ten supplied resources/7200 frames through actual renderer anchors. Default Godot sine matches supplied float32 math.sin stub on these inputs, not original libm/GPU. Full pathfinding, Fly/portal/growth/status/audio ownership remain separate."}
	if not output.is_empty() and not FileAccess.file_exists(output):
		var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_HOVER ",JSON.stringify(report));quit(1 if failure_count else 0)

extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/creep_view.gd")
var checks=0
var failure_count=0
var failures=[]
var failures_by_field={}
var examples=[]
var example_keys={}
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String,field:String="fixture") -> void:
	checks+=1
	if not ok:
		failure_count+=1;failures_by_field[field]=int(failures_by_field.get(field,0))+1
		if failures.size()<25:failures.append(label+"/"+field)
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func vector_bits(value:Vector2) -> Array:return [bits(value.x),bits(value.y)]
func integer_record(value:Variant) -> Variant:
	# JSON numbers are doubles; Godot container equality distinguishes them
	# from integer bit words even when every numeric value is identical.
	if value is float:
		assert(value==floor(value))
		return int(value)
	if value is Array:
		return value.map(integer_record)
	if value is Dictionary:
		var result={}
		for key in value:result[key]=integer_record(value[key])
		return result
	return value
func check_displacement_geometry() -> void:
	var path="res://../tests/fixtures/native-creep-hex-reference.json"
	check(FileAccess.get_sha256(path)=="9deef1f845fd3c57ba2a11b164b9b008619d8230d0d884a203f601b3320322a1","unchanged independently repeated original slot fixture")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	for sequence in fixture.displacement_sequences:
		var input=sequence.input;var sim=Sim.new();var cell=Vector2i(input.cell[0],input.cell[1])
		sim.map={"hex_width":16,"hex_height":16,"hex_h":int(input.hex_distance)}
		sim.cell_positions.resize(256);sim.cell_positions[sim.cell_index(cell)]=Vector2(input.center[0],input.center[1])
		for frame in sequence.frames:
			var point=sim.displace_point(cell,Vector2(input.toward[0],input.toward[1]),int(frame.owner),Vector2(-9,-9))
			check(vector_bits(point)==integer_record(frame.point_bits),"exact original displacement point "+str(input)+"/"+str(frame.owner),"slot_geometry")
			var owners=[]
			for slot in frame.slots:owners.append(-1 if bool(slot.free) else int(slot.owner))
			check(sim.displacement_owners.get(cell,[])==owners,"exact original reservation order and exhausted fallback "+str(input)+"/"+str(frame.owner),"slot_owners")
	# The fifth original case is a null cell inside a sparse supplied native
	# map. Current imported maps are dense, so that producer is not claimed.
	for row in fixture.invalid_displacement_cases:
		var cell=Vector2i(row.cell[0],row.cell[1]);var sim=Sim.new();sim.map={"hex_width":16,"hex_height":16,"hex_h":64}
		if sim.within(cell):continue
		check(vector_bits(sim.displace_point(cell,Vector2(500,500),42,Vector2(-9,-9)))==integer_record(row.point_bits),"original out-of-bounds displacement fallback","slot_geometry")
func make_case(input:Dictionary) -> Array:
	var content=root.get_node("Content");var sim=Sim.new();var config=content.mission("8").duplicate(true);config.waves=[];config.settings={"tutorial":0,"build_around_base":1}
	config.sources=[{"x":4,"y":4,"neutrality":2,"target":1}];config.bases=[{"x":int(input.base_cell[0]),"y":int(input.base_cell[1]),"hp":1000,"neutrality":1}]
	var geometry=input.geometry
	var map={"hex_width":16,"hex_height":16,"hex_base":int(geometry.base),"hex_side":int(geometry.side),"hex_h":int(geometry.height),"hex_offset_x":int(geometry.offset_x),"hex_offset_y":int(geometry.offset_y),"cells":[]}
	for i in 256:map.cells.append({"w":1,"l":1})
	sim.setup(content.catalog.duplicate(true),map,config,root.get_node("Profile").fresh(),114,content.animations);sim.spawn_hold=true;sim.tutorial_finished=false
	var type=-1
	for i in sim.catalog.tower_creeps.size():
		if sim.catalog.tower_creeps[i].get("filename","")==str(input.resource).trim_prefix("creeps/"):type=i;break
	check(type>=0,"supplied normal resource has a populated catalog entry")
	var actor=sim.spawn_enemy(type,0,"",int(input.owner),false)
	# Joined.setup supplies zeroed bomber/laser/kamikaze raw flags; only
	# constructor-derived hover/smoke/offset fields are joined in this fixture.
	actor.def.traits.kamikaze=0;actor.def.traits.shoot_bomb=0;actor.def.traits.shoot_laser=0
	actor.def.rof=int(input.supplied_rof);actor.def.base_distance=int(input.base_distance)
	actor.base=0;actor.cell=Vector2i(4,4);actor.next_cell=Vector2i(4,5);actor.path=[actor.cell,actor.next_cell]
	for cell in input.remaining_route:actor.path.append(Vector2i(cell[0],cell[1]))
	actor.path_at=1;actor.move_progress=sim.f32(float(input.progress));actor.move_carry=sim.f32(float(input.get("carry",0)))
	actor.move_start=sim.center(4,4);actor.pos=actor.move_start.lerp(sim.center(4,5),float(input.progress));actor.visual_pos=actor.pos
	actor.move_target=sim.center(4,5)
	preload("res://scripts/creep_state_view.gd").change(actor,0)
	sim.displacement_owners.clear();sim.displacement_last_owners.clear()
	actor.dir=Vector2.DOWN;actor.attacking=false;actor.attack_reload_ms=0;actor.speed=float(input.speed);actor.grow_ms=400
	for key in ["corner","corner_key","semi","semi_key"]:actor.erase(key)
	return [sim,actor]
func run() -> void:
	check_displacement_geometry()
	var cases=[]
	for spec in [["native-creep-approach-reference.json","3336158da0e8596587a0a4684e92f351b3b735a02cdbdf511b01ecc50c708938"],["native-creep-approach-variable-reference.json","522859de1f89ec1e233785f26775171fae105749d9c0890f8ffb6a1313bf2d65"]]:
		var path="res://../tests/fixtures/"+str(spec[0])
		check(FileAccess.get_sha256(path)==spec[1],"unchanged independently repeated original joined movement fixture "+str(spec[0]))
		cases.append_array(JSON.parse_string(FileAccess.get_file_as_string(path)).cases)
	check(integer_record([1.0,4294967295.0])==[1,4294967295] and integer_record([1.0,4294967295.0])!=[1,4294967294],"exact JSON integer normalization distinguishes one-bit changes")
	for sequence in cases:
		var input=sequence.input;var setup=make_case(input);var sim=setup[0];var actor:Dictionary=setup[1]
		for row in sequence.frames:
			var dt=float(row.get("delta",input.get("delta",0)))
			sim.tick_ms=dt;sim.clock_ms+=int(dt)
			sim.update_living_enemy(actor);sim.advance_creep_hover(actor,dt);View.update(sim,actor)
			var authored=actor.def.traits.get("offset",[0,0]);var offset:Vector2=actor.get("animator_offset",Vector2(authored[0],authored[1]))
			var owners={}
			for cell in sim.displacement_owners:owners[str(cell.x)+","+str(cell.y)]=sim.displacement_owners[cell]
			var actual={"state":int(actor.state),"hover":int(actor.hover_active),"aligned":int(actor.attacking),"progress_bits":bits(float(actor.move_progress)),"alignment_bits":bits(float(actor.get("attack_alignment",0))),"logical_bits":vector_bits(actor.pos),"position_bits":vector_bits(actor.visual_pos),"offset_bits":vector_bits(offset),"phase_bits":bits(float(actor.get("hover_phase",0))),"cell":[actor.cell.x,actor.cell.y],"next_cell":[actor.next_cell.x,actor.next_cell.y],"working_interval_bits":bits(float(actor.smoke_work_interval)),"reload_bits":bits(float(actor.attack_reload_ms)),"displacement_owners":owners}
			for key in actual:
				var expected=integer_record(row.after[key])
				var sample_key=str(input.resource)+"/"+str(key)
				if actual[key]!=expected and not example_keys.has(sample_key):
					example_keys[sample_key]=true;examples.append({"input":input,"frame":row.frame,"field":key,"actual":actual[key],"expected":expected})
				check(actual[key]==expected,str(input.resource)+"/"+str(input.remaining_route.size())+"/"+str(input.base_cell)+"/"+str(dt)+"/"+str(row.frame),str(key))
		sim.particle_state.destroy_creep(actor)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report")
	var report={"checks":checks,"failure_count":failure_count,"failures":failures,"failures_by_field":failures_by_field,"examples":examples,"original_cases":cases.size(),"scope":"Actual Simulation living update plus existing hover/visual owner phases against full original normal movement joined to original route-head/map-slot/distance/position/state helpers on identical supplied map/path/base fields. Non-kamikaze/non-bomber/non-laser supplied raw flags, no shots, direction/animation names and external sinf/floorf remain explicit stubs; full path builder/target-loss/Fly/portal/audio/GPU remain separate. Variable-time extension covers selected speeds, carry, progress and two geometry heights."}
	if not output.is_empty() and not FileAccess.file_exists(output):
		var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_APPROACH ",JSON.stringify(report));quit(1 if failure_count else 0)

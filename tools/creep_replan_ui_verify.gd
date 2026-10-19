extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/creep_view.gd")
const State=preload("res://scripts/creep_state_view.gd")
var checks=0
var failures=0
var failures_by_field={}
var examples=[]
var sample_keys={}
var trace_this_case=false
var trace_rows=[]
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func f(word:Variant) -> float:
	var bytes=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,int(word));return bytes.decode_float(0)
func vec(words:Array) -> Vector2:return Vector2(f(words[0]),f(words[1]))
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func vector_bits(value:Vector2) -> Array:return [bits(value.x),bits(value.y)]
func integer_record(value:Variant) -> Variant:
	if value is float:
		assert(value==floor(value));return int(value)
	if value is Array:return value.map(integer_record)
	if value is Dictionary:
		var result={}
		for key in value:result[key]=integer_record(value[key])
		return result
	return value
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;failures_by_field[label]=int(failures_by_field.get(label,0))+1
func check_slot_lifetime() -> void:
	var path="res://../tests/fixtures/native-creep-slot-lifetime-reference.json"
	check(FileAccess.get_sha256(path)=="bc0069afda41d305385a7f7681902051b513bdc7d79c0c1c3f2f58bf9d7e611e","unchanged_original_slot_lifetime_fixture")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	for sequence in fixture.sequences:
		var input=sequence.input;var sim=Sim.new();var cell=Vector2i(input.cell[0],input.cell[1])
		sim.map={"hex_width":16,"hex_height":16,"hex_h":int(input.height)};sim.cell_positions.resize(256);sim.cell_positions[sim.cell_index(cell)]=Vector2(input.center[0],input.center[1])
		for row in sequence.frames:
			if str(row.action)=="reserve":
				var point=sim.displace_point(cell,Vector2(input.toward[0],input.toward[1]),int(row.owner),Vector2(-9,-9))
				check(vector_bits(point)==integer_record(row.point_bits),"slot_lifetime_point")
			else:sim.release_cell_displacement(cell,int(row.owner))
			check(sim.displacement_owners[cell]==integer_record(row.active_owners),"slot_lifetime_active")
			check(sim.displacement_last_owners[cell]==integer_record(row.retained_owners),"slot_lifetime_retained_owner_ids")
func setup_case(sequence:Dictionary) -> Array:
	var input=sequence.input;var before=sequence.before;var content=root.get_node("Content");var config=content.mission("8").duplicate(true)
	config.waves=[];config.settings={"tutorial":0,"build_around_base":1};config.sources=[{"x":4,"y":4,"neutrality":2,"target":1}];config.bases=[{"x":int(input.base_cell[0]),"y":int(input.base_cell[1]),"hp":1000,"neutrality":1}]
	var map={"hex_width":16,"hex_height":16,"hex_base":44,"hex_side":22,"hex_h":64,"hex_offset_x":0,"hex_offset_y":0,"cells":[]}
	for i in 256:map.cells.append({"w":1,"l":1})
	for cell in input.blocked:map.cells[int(cell[1])*16+int(cell[0])].w=0
	var sim=Sim.new();sim.setup(content.catalog.duplicate(true),map,config,root.get_node("Profile").fresh(),114,content.animations);sim.spawn_hold=true;sim.tutorial_finished=false
	var actor=sim.spawn_enemy(5,0,"",int(input.owner),false)
	# R177/R178 original supplied actors have raw owner0/target0 and a null
	# source pointer. The source config above only isolates construction.
	actor.owner=0;actor.target_owner=0;actor.source=-1
	actor.def.traits.kamikaze=0;actor.def.traits.shoot_bomb=0;actor.def.traits.shoot_laser=0
	# The basic supplied original actor has raw+0x38 zero. A separate full
	# constructor-direction join must establish resource5's physical flag1.
	actor.def.traits.dir_interpolation=int(input.get("direction_interpolation",0))
	actor.def.rof=int(input.supplied_rof);actor.def.base_distance=int(input.base_distance);actor.speed=float(input.speed);actor.base=0;actor.grow_ms=400
	actor.state=int(before.state);actor.hover_active=int(before.hover);actor.cell=Vector2i(before.cell[0],before.cell[1]);actor.next_cell=Vector2i(before.next_cell[0],before.next_cell[1])
	actor.move_progress=f(before.progress_bits);actor.move_carry=f(before.carry_bits);actor.move_start=vec(before.start_bits);actor.move_target=vec(before.target_bits);actor.pos=vec(before.logical_bits);actor.visual_pos=vec(before.position_bits)
	actor.attack_point=vec(before.attack_point_bits);actor.attacking=bool(before.aligned);actor.attack_alignment=f(before.alignment_bits);actor.attack_reload_ms=f(before.reload_bits)
	actor.animator_offset=vec(before.offset_bits);actor.hover_phase=f(before.phase_bits);actor.smoke_work_interval=f(before.working_interval_bits);actor.dir=Vector2.DOWN
	if before.has("walking_animator"):
		actor.primary_animation=str(before.walking_animator.primary);actor.secondary_animation=str(before.walking_animator.secondary)
	actor.path=[actor.cell,actor.next_cell];actor.path_at=1
	for cell in before.path:actor.path.append(Vector2i(cell[0],cell[1]))
	for key in ["corner","corner_key","semi","semi_key"]:actor.erase(key)
	sim.displacement_owners.clear();sim.displacement_last_owners.clear()
	for key in before.displacement_owners:
		var xy=str(key).split(",");sim.displacement_owners[Vector2i(int(xy[0]),int(xy[1]))]=integer_record(before.displacement_owners[key])
	return [sim,actor]
func compare(sim,actor:Dictionary,expected:Dictionary,label:String) -> void:
	var owners={}
	for cell in sim.displacement_owners:owners[str(cell.x)+","+str(cell.y)]=sim.displacement_owners[cell]
	var path=[]
	for cell in actor.path.slice(int(actor.path_at)+1):path.append([cell.x,cell.y])
	var actual={"state":int(actor.state),"hover":int(actor.hover_active),"aligned":int(actor.attacking),"progress_bits":bits(View.progress(sim,actor)),"alignment_bits":bits(float(actor.get("attack_alignment",0))),"carry_bits":bits(float(actor.get("move_carry",0))),"start_bits":vector_bits(actor.move_start),"target_bits":vector_bits(actor.get("move_target",sim.center(actor.next_cell.x,actor.next_cell.y))),"attack_point_bits":vector_bits(actor.attack_point),"position_bits":vector_bits(actor.visual_pos),"logical_bits":vector_bits(actor.pos),"offset_bits":vector_bits(actor.animator_offset),"phase_bits":bits(float(actor.hover_phase)),"cell":[actor.cell.x,actor.cell.y],"next_cell":[actor.next_cell.x,actor.next_cell.y],"working_interval_bits":bits(float(actor.smoke_work_interval)),"reload_bits":bits(float(actor.attack_reload_ms)),"path":path,"displacement_owners":owners}
	if expected.has("walking_animator") and int(expected.state)==0 and not bool(expected.aligned) and not label.ends_with("/replan"):
		var layers:Array=actor.visual_layers
		actual.walking_animator={"primary":layers[0].state,"secondary":layers[1].state,"rotation_bits":bits(float(layers[0].rotation)),"alpha_bits":bits(float(layers[0].alpha)),"secondary_rotation_bits":bits(float(layers[1].rotation)),"secondary_alpha_bits":bits(float(layers[1].alpha))}
	if trace_this_case:
		trace_rows.append({"label":label,"actual":actual.duplicate(true),"expected":expected,"corner":actor.get("corner",{}).duplicate(true),"semi":actor.get("semi",{}).duplicate(true),"normal_boundary":actor.get("normal_boundary",false)})
	for key in actual:
		var wanted=integer_record(expected[key]);var ok=actual[key]==wanted;check(ok,str(key))
		if not ok and not sample_keys.has(key):sample_keys[key]=true;examples.append({"label":label,"field":key,"actual":actual[key],"expected":wanted})
func run() -> void:
	check_slot_lifetime()
	var cases=[]
	for spec in [["native-creep-replan-reference.json","4ed4ef2bd03bed624c3d5ecc97a1e60dc14a0060bb287a78bcce4a746923b949"],["native-creep-replan-direction-reference.json","dbaae956c5506eebfe13c269d3a753f826b92f0017e47fd24cf560b4c2535b6a"],["native-creep-replan-long-reference.json","acba77c443be60db43da8e72beed8c06480e3de273bb6fe86b949439b44f35ce"]]:
		var path="res://../tests/fixtures/"+str(spec[0])
		check(FileAccess.get_sha256(path)==spec[1],"unchanged_independently_repeated_original_fixture")
		cases.append_array(JSON.parse_string(FileAccess.get_file_as_string(path)).cases)
	for sequence in cases:
		var input=sequence.input;var setup=setup_case(sequence);var sim=setup[0];var actor:Dictionary=setup[1];var label=str(input.pose)+"/"+str(input.base_cell)+"/"+str(input.blocked)
		trace_this_case="--trace-rows" in OS.get_cmdline_user_args() and str(input.pose)=="walking-early" and int(input.base_cell[0])==10 and input.blocked.is_empty() and sequence.frames.size()>100
		sim.set_enemy_path(actor);compare(sim,actor,sequence.after_replan,label+"/replan")
		for row in sequence.frames:
			var dt=float(row.delta);sim.tick_ms=dt;sim.clock_ms+=int(dt);sim.update_living_enemy(actor);sim.advance_creep_hover(actor,dt);View.update(sim,actor);compare(sim,actor,row.after,label+"/"+str(row.frame))
		sim.particle_state.destroy_creep(actor)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh_explicit_report")
	var result={"checks":checks,"failure_count":failures,"failures_by_field":failures_by_field,"examples":examples,"original_cases":cases.size(),"scope":"Actual Simulation set_enemy_path then living/hover/visual phases against full original normal UpdateShortestPath/FindPathToBase/A*/smoothing/base/walkability/state/displacement/movement. Identical supplied16x16graph, valid owner/base records and selected constructor fields; both basic raw direction0 and full direction-helper flag1 joins. Nonaligned walking compares animator names/rotation/alpha. Full graph/resource producers, external math/animation/audio/GPU and faction/target-loss/special cases remain separate."}
	if not trace_rows.is_empty():result.trace_rows=trace_rows
	if not output.is_empty() and not FileAccess.file_exists(output):var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	result.erase("trace_rows");print("CREEP_REPLAN ",JSON.stringify(result));quit(1 if failures else 0)

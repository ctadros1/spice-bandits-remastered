extends "res://../tools/creep_initial_path_ui_verify.gd"

func make_sim(input:Dictionary):
	var content=root.get_node("Content");var config=content.mission("8").duplicate(true)
	config.waves=[];config.settings={"tutorial":0,"build_around_base":1}
	config.sources=[{"x":int(input.source_cell[0]),"y":int(input.source_cell[1]),"neutrality":int(input.source_owner),"target":int(input.source_target)}];config.bases=[]
	for base in input.bases:config.bases.append({"x":int(base.cell[0]),"y":int(base.cell[1]),"hp":0 if base.inactive else 1000,"neutrality":int(base.owner)})
	var map={"hex_width":16,"hex_height":16,"hex_base":44,"hex_side":22,"hex_h":64,"hex_offset_x":0,"hex_offset_y":0,"cells":[]}
	for i in 256:map.cells.append({"w":1,"l":1})
	var blocked=input.get("blocked",[])
	if str(input.mask)=="source":blocked=[input.source_cell]
	if str(input.mask)=="wall":
		blocked=[]
		for x in 16:blocked.append([x,7])
	for cell in blocked:map.cells[int(cell[1])*16+int(cell[0])].w=0
	var data=content.catalog.duplicate(true);var def=data.tower_creeps[5];def.speed=1000;def.rof=1000000;def.base_distance=2;def.hp=100;def.damage=0;def.price=0
	var script=load("res://../builds/creep-spawn-path-r179-before-runtime/simulation-anonymous.gd") if "--preport" in OS.get_cmdline_user_args() else Sim
	var sim=script.new();sim.setup(data,map,config,root.get_node("Profile").fresh(),114,content.animations);sim.spawn_hold=true;sim.tutorial_finished=false;return sim

func run() -> void:
	var source_path="res://../tests/fixtures/native-source-path-reference.json"
	check(FileAccess.get_sha256(source_path)=="b41d2564456de96607831bcb8066e6777abf963807d733dcfb121f013ff35447","unchanged_original_source_fixture")
	var source_fixture=JSON.parse_string(FileAccess.get_file_as_string(source_path))
	for sequence in source_fixture.cases:
		var sim=make_sim(sequence.input)
		if sim.has_method("update_source_paths"):sim.update_source_paths()
		var cached:Dictionary=sim.sources[0].get("cached_paths",{})
		check(int(sim.sources[0].get("target",0))==int(sequence.after.target),"source_target")
		for kind in ["ground","air"]:
			var row:Dictionary=cached.get(kind,{"path":[],"base_index":-1});var path=[]
			for cell in row.path:path.append([cell.x,cell.y])
			check(path==integer_record(sequence.after.routes[kind].path),"source_"+kind+"_path")
			check(int(row.base_index)==int(sequence.after.routes[kind].base_index),"source_"+kind+"_base")
	var spawn_path="res://../tests/fixtures/native-creep-spawn-path-reference.json"
	check(FileAccess.get_sha256(spawn_path)=="623e65e9938a27b35c3ecbd25832bb07acf51df4a8e282eac232d29a1f96115d","unchanged_independently_repeated_original_spawn_fixture")
	var fixture={"cases":[]} if "--source-only" in OS.get_cmdline_user_args() else JSON.parse_string(FileAccess.get_file_as_string(spawn_path))
	for sequence in fixture.cases:
		var sim=make_sim(sequence.input);var actor:Dictionary=sim.spawn_enemy(5,0,"",9001,false);var label=str(sequence.input.source_cell)+"/"+str(sequence.input.bases)+"/"+str(sequence.input.mask)
		# Materialize the public view's defaults from actual game data, never
		# from the original expected actor. Production spawn must produce its
		# own path/state and all compared retained fields.
		var offset=actor.def.traits.get("offset",[0,0]);actor.animator_offset=actor.get("animator_offset",Vector2(offset[0],offset[1]));actor.hover_phase=actor.get("hover_phase",0.0)
		actor.move_start=actor.get("move_start",actor.pos);actor.visual_pos=actor.get("visual_pos",actor.pos)
		View.update(sim,actor);compare(sim,actor,sequence.after_constructor,label+"/construct");compare_extra(actor,sequence.after_constructor,label+"/construct");check(int(actor.base)==int(sequence.after_constructor.base_index),"spawn_base")
		for row in sequence.frames:
			var dt=float(row.delta);sim.tick_ms=dt;sim.clock_ms+=int(dt);sim.update_living_enemy(actor);sim.advance_creep_hover(actor,dt);View.update(sim,actor);compare(sim,actor,row.after,label+"/"+str(row.frame));compare_extra(actor,row.after,label+"/"+str(row.frame))
		sim.particle_state.destroy_creep(actor)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh_explicit_report")
	var result={"checks":checks,"failure_count":failures,"failures_by_field":failures_by_field,"examples":examples,"source_cases":source_fixture.cases.size(),"spawn_cases":fixture.cases.size(),"scope":"Actual Simulation source cache and fresh resource5 spawn/living/hover/view phases. Original full C2/SetInitPosition/source path/A* join on supplied graph/resources/records; explicit shooting/math/backend callbacks. Full resource/graph/room/manager/GPU and other creature/special types remain separate."}
	if not output.is_empty() and not FileAccess.file_exists(output):var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("CREEP_SPAWN_PATH ",JSON.stringify(result));quit(1 if failures else 0)

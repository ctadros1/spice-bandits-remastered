extends "res://../tools/creep_air_path_ui_verify.gd"

func compare_linked(sim,actor:Dictionary,expected:Dictionary,label:String) -> void:
	super.compare_linked(sim,actor,expected,label)
	# This new oracle executes the direction callback. All primary names,
	# including retention after shooting and rerouting, are now eligible.
	for key in ["primary","secondary"]:
		var actual=str(actor.get(key+"_animation","RunDownRight"));var wanted=str(expected[key]);var ok=actual==wanted;check(ok,"full_"+key)
		if not ok and not sample_keys.has("full_"+key):sample_keys["full_"+key]=true;examples.append({"label":label,"field":"full_"+key,"actual":actual,"expected":wanted})

func run() -> void:
	var path="res://../tests/fixtures/native-creep-shooting-reference.json"
	check(FileAccess.get_sha256(path)=="30790afa94ea428d648fba8e82d749b189d8a5cc8bb7e99edc8f3e4c9a13ae54","independently_reproduced_original_fixture")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(fixture.original_unchanged,"original_bodies_unchanged")
	var direct_sim=Sim.new()
	for name in fixture.authored_table_bits:check(vector_bits(Sim.AIM_ANIMATIONS[name])==integer_record(fixture.authored_table_bits[name]),"authored_vector")
	var direction_differences=[]
	var equal_distance_cases=0
	for row in fixture.directions:
		var actual=direct_sim.creep_animation({"attacking":true,"dir":vec(row.direction_bits)});var ok=actual==str(row.primary);check(ok,"direct_primary")
		var has_angles=direct_sim.has_method("creep_shooting_angle")
		var angle=direct_sim.creep_shooting_angle(vec(row.direction_bits)) if has_angles else INF;check(has_angles and bits(angle)==int(row.query_angle_bits),"direct_query_angle_bits")
		var minimum=10000.0;var tied=0
		for candidate in row.distances:
			var facing=float(direct_sim.creep_aim_angles[str(candidate.name)]) if has_angles else 0.0
			var distance=minf(absf(direct_sim.f32(angle-facing)),absf(direct_sim.f32(angle-direct_sim.f32(facing-360.0))))
			check(has_angles and bits(distance)==int(candidate.distance_bits),"direct_distance_bits")
			if distance<minimum:minimum=distance;tied=1
			elif distance==minimum:tied+=1
		if tied>1:equal_distance_cases+=1
		if not ok and direction_differences.size()<30:direction_differences.append({"direction_bits":row.direction_bits,"actual":actual,"expected":row.primary})
	check(equal_distance_cases==21,"native_equal_distance_cases")
	for sequence in fixture.cases:
		shooting_name_dependency=false;previous_original_offset=[0,0]
		var input:Dictionary=sequence.input;var sim=make_sim(input);var number=int(input.creep_number);var def=sim.catalog.tower_creeps[number];def.hp=100;def.speed=1000;def.rof=1000000;def.base_distance=2;def.damage=0;def.price=0
		var actor:Dictionary=sim.spawn_enemy(number,0,"",9001,false);var label=str(number)+"/"+str(input.pose)+"/"+str(sequence.change.kind)
		materialize_public_defaults(sim,actor);View.update(sim,actor);compare_linked(sim,actor,sequence.after_constructor,label+"/construct")
		for row in sequence.warmup_frames:advance_actor(sim,actor,row,label+"/warm")
		compare_source(sim,sequence.source_cache_before,label+"/source-before")
		for cell in sequence.change.blocked:sim.map.cells[int(cell[1])*16+int(cell[0])].w=0
		sim.path_cache.clear();sim.route_cost_cache.clear();sim.update_source_paths();compare_source(sim,sequence.source_cache_after,label+"/source-after")
		sim.set_enemy_path(actor);compare_linked(sim,actor,sequence.after_replan,label+"/replan")
		for row in sequence.frames:advance_actor(sim,actor,row,label+"/after")
		sim.particle_state.destroy_creep(actor)
	check(shooting_dependent_primary_names_unverified==0,"no_omitted_shooting_names")
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh_explicit_report")
	var result={"checks":checks,"failure_count":failures,"failures_by_field":failures_by_field,"examples":examples,"direction_differences":direction_differences,"direct_cases":fixture.directions.size(),"equal_minimum_distance_cases":equal_distance_cases,"actor_cases":fixture.cases.size(),"original_nonfinite_visual_fallbacks":original_nonfinite_visual_fallbacks,"omitted_primary_names":shooting_dependent_primary_names_unverified,"scope":"Actual Simulation facing and resource5/kind1 + resource4/kind2 constructor/living/hover/view/source rerouting. Original full shooting-direction/AngPos/AngleNormalize and C2/source/movement bodies; supplied stdmap lexical slots and float64 atan/backend callbacks. Other special/resource/Freeze/owner/backend/GPU identity remains open."}
	if not output.is_empty() and not FileAccess.file_exists(output):var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("CREEP_SHOOTING ",JSON.stringify(result));quit(1 if failures else 0)

extends "res://../tools/creep_replan_ui_verify.gd"

func compare_extra(actor:Dictionary,expected:Dictionary,label:String) -> void:
	var actual={"aim_bits":vector_bits(actor.get("visual_aim",Vector2.ZERO)),"remaining_count":int(actor.get("path_remaining",0)),"previous_progress_bits":bits(float(actor.get("previous_move_progress",0))),"segment_relation":int(actor.get("segment_relation",0))}
	for key in actual:
		var wanted=integer_record(expected[key]);var ok=actual[key]==wanted;check(ok,key)
		if not ok and not sample_keys.has(key):sample_keys[key]=true;examples.append({"label":label,"field":key,"actual":actual[key],"expected":wanted})

func run() -> void:
	var fixture="res://../tests/fixtures/native-creep-initial-path-reference.json"
	check(FileAccess.get_sha256(fixture)=="50e3d9c5216fc14033eac9e473bcee59b001c996844eb18c7e30296dcd38abdf","unchanged_independently_repeated_original_fixture")
	var cases=JSON.parse_string(FileAccess.get_file_as_string(fixture)).cases
	var compared=0
	for sequence in cases:
		var input=sequence.input
		var setup=setup_case(sequence);var sim=setup[0];var actor:Dictionary=setup[1]
		actor.body_jitter=Vector2(input.jitter[0],input.jitter[1]);actor.visual_aim=vec(sequence.before.aim_bits);actor.path_remaining=int(sequence.before.remaining_count)
		var label=str(input.operation)+"/"+str(input.pose)
		if input.operation=="teleport":
			actor.portal_pose={"state":3,"clock":171.0};var exit_cell=Vector2i(input.exit_cell[0],input.exit_cell[1]);label+="/"+str(exit_cell)
			sim.teleport_enemy(actor,exit_cell);compared+=1
		else:
			label+="/"+str(input.relation)+"/"+str(input.progress)
			sim.initialize_normal_creep_segment(actor,Vector2i(input.start[0],input.start[1]),Vector2i(input.end[0],input.end[1]),float(input.progress))
		compare(sim,actor,sequence.after_operation,label+"/replan");compare_extra(actor,sequence.after_operation,label+"/operation")
		for row in sequence.frames:
			var dt=float(row.delta);sim.tick_ms=dt;sim.clock_ms+=int(dt);sim.update_living_enemy(actor);sim.advance_creep_hover(actor,dt);View.update(sim,actor);compare(sim,actor,row.after,label+"/"+str(row.frame));compare_extra(actor,row.after,label+"/"+str(row.frame))
		sim.particle_state.destroy_creep(actor)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh_explicit_report")
	var result={"checks":checks,"failure_count":failures,"failures_by_field":failures_by_field,"examples":examples,"teleport_cases":compared,"initializer_cases":cases.size()-compared,"scope":"Actual Simulation segment initializer, teleport and living/hover/visual phases against full original TeleportCreep and segment initializer with real original A*. Supplied actor/base/16x16 graph, not the complete original fresh-spawn/room constructor or GPU."}
	if not output.is_empty() and not FileAccess.file_exists(output):var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("CREEP_INITIAL_PATH ",JSON.stringify(result));quit(1 if failures else 0)

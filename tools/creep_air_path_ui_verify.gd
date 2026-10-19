extends "res://../tools/creep_reward_ui_verify.gd"

func make_plane_sim(input:Dictionary):
	var sim=make_sim(input);var def=sim.catalog.tower_creeps[int(input.creep_number)]
	def.hp=100;def.speed=int(input.speed);def.rof=1000000;def.base_distance=2;def.damage=0;def.price=3
	sim.upgrades.up_interest=7
	return sim

func materialize_public_defaults(sim,actor:Dictionary) -> void:
	# Only defaults from actual public fields/data, never expected native data.
	# This permits the previous implementation's missing retained fields to
	# be compared as defaults instead of turning a mismatch into a script error.
	var offset=actor.def.traits.get("offset",[0,0]);actor.animator_offset=actor.get("animator_offset",Vector2(offset[0],offset[1]));actor.hover_phase=actor.get("hover_phase",0.0)
	actor.move_start=actor.get("move_start",actor.pos);actor.move_target=actor.get("move_target",sim.center(actor.next_cell.x,actor.next_cell.y));actor.move_progress=actor.get("move_progress",0.0)
	actor.visual_pos=actor.get("visual_pos",actor.pos);actor.visual_aim=actor.get("visual_aim",sim.enemy_visual_aim_point(actor));actor.path_remaining=actor.get("path_remaining",0)

func run() -> void:
	var path="res://../tests/fixtures/native-creep-air-path-reference.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="):path=arg.trim_prefix("--reference=")
	check(FileAccess.get_sha256(path)=="c1773610b3e72e1ffb4741a1a01e0352e2693c91fad344beeee612ca954004e4","unchanged_original_air_path_fixture")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	for sequence in fixture.cases:
		shooting_name_dependency=false;previous_original_offset=[0,0]
		var input:Dictionary=sequence.input;var sim=make_plane_sim(input);var actor:Dictionary=sim.spawn_enemy(int(input.creep_number),0,"",9001,false);var label=str(input.pose)+"/"+str(input.creep_number)+"/"+str(input.initial_label)+"/"+str(sequence.change.kind)
		materialize_public_defaults(sim,actor);View.update(sim,actor);compare_linked(sim,actor,sequence.after_constructor,label+"/construct")
		check(bool(actor.native_air),"native_air_resource_selector")
		for row in sequence.warmup_frames:advance_actor(sim,actor,row,label+"/warm")
		compare_source(sim,sequence.source_cache_before,label+"/source-before")
		for cell in sequence.change.blocked:sim.map.cells[int(cell[1])*16+int(cell[0])].w=0
		for i in sequence.change.inactive_base_indices:sim.bases[int(i)].hp=0
		sim.path_cache.clear();sim.route_cost_cache.clear();sim.update_source_paths();compare_source(sim,sequence.source_cache_after,label+"/source-after")
		sim.set_enemy_path(actor);compare_linked(sim,actor,sequence.after_replan,label+"/replan")
		for row in sequence.frames:advance_actor(sim,actor,row,label+"/after")
		var initial_money=float(input.initial_money);sim.money=initial_money
		sim.damage(actor,101,1,0);compare_damage(sim,actor,sequence.after_damage,initial_money,label+"/damage")
		sim.damage(actor,101,1,0);compare_damage(sim,actor,sequence.after_repeat,initial_money,label+"/repeat")
		sim.particle_state.destroy_creep(actor)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh_explicit_report")
	var result={"checks":checks,"failure_count":failures,"failures_by_field":failures_by_field,"examples":examples,"cases":fixture.cases.size(),"shooting_dependent_primary_names_unverified":shooting_dependent_primary_names_unverified,"original_nonfinite_visual_fallbacks":original_nonfinite_visual_fallbacks,"scope":"Actual Simulation ordinary plane constructor, normal movement/hover/view, source refresh/actor reroute, local kill reward and repeated damage. Original full resource4/kind2 C2/source paths/movement/reroute/DoDamage/SetDie on supplied graph/resources/room/player and explicit callbacks. Plane variants4/22/23/24 use supplied integer arguments and authored speeds in constructor cases. Omitted shooting primary-name dependencies and existing nonfinite visual fallbacks remain separately reported. Full resource/room/graph/player/owner/special/bomber/missile/particle/audio/GPU identity and complete native fidelity remain open."}
	if not output.is_empty() and not FileAccess.file_exists(output):var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("CREEP_AIR_PATH ",JSON.stringify(result));quit(1 if failures else 0)

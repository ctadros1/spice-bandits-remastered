extends "res://../tools/creep_source_replan_ui_verify.gd"

func compare_damage(sim,actor:Dictionary,expected:Dictionary,initial_money:float,label:String) -> void:
	var actual={"hp_bits":bits(float(actor.hp)),"state":int(actor.state),"previous_state":int(actor.death_previous_state),"score":int(sim.score),"player_kills":int(sim.kills),"room_kills":int(sim.kill_chain),"remaining_count":int(actor.path_remaining)}
	for key in actual:
		var wanted=int(expected[key]);var ok=actual[key]==wanted;check(ok,"damage_"+key)
		if not ok and not sample_keys.has("damage_"+key):sample_keys["damage_"+key]=true;examples.append({"label":label,"field":key,"actual":actual[key],"expected":wanted})
	check(bits(float(sim.score))==bits(float(expected.score)),"exact_score_float")
	check(bits(float(sim.money))==bits(initial_money+float(expected.score)),"exact_wallet_credit")
	var killed=sim.events.filter(func(event):return str(event.kind)=="kill")
	check(killed.size()==1,"one_kill_event")
	if killed.size()==1:
		var ok=int(killed[0].reward)==int(expected.score);check(ok,"kill_event_reward")
		if not ok and not sample_keys.has("event_reward"):sample_keys.event_reward=true;examples.append({"label":label,"field":"event_reward","actual":int(killed[0].reward),"expected":int(expected.score)})
	if expected.has("local_player_money"):check(bits(float(sim.money))==bits(float(expected.local_player_money)),"native_local_wallet_credit")
	compare_source(sim,expected.source_cache,label+"/source")

func check_local_wallet() -> int:
	var path="res://../tests/fixtures/native-creep-reward-wallet-reference.json"
	check(FileAccess.get_sha256(path)=="d359a2bafd70e69a8d91bda58f18b4c1cceef0a79d36f95f56639e247069e96c","unchanged_original_local_wallet_fixture")
	var cases=JSON.parse_string(FileAccess.get_file_as_string(path)).cases
	for sequence in cases:
		shooting_name_dependency=false
		var input:Dictionary=sequence.input;var sim=make_sim(input);sim.catalog.tower_creeps[5].price=int(input.price);sim.upgrades.up_interest=int(input.upgrade_level)
		var actor:Dictionary=sim.spawn_enemy(5,0,"",9001,false);View.update(sim,actor);sim.update_source_paths();sim.set_enemy_path(actor)
		var label="local-wallet/"+str(input.price)+"/"+str(input.upgrade_level)+"/"+str(input.initial_money)
		compare(sim,actor,sequence.before_damage,label+"/replan");compare_extra(actor,sequence.before_damage,label+"/replan")
		var initial=float(input.initial_money);sim.money=initial
		sim.damage(actor,101,1,0);compare_damage(sim,actor,sequence.after_damage,initial,label+"/damage")
		sim.damage(actor,101,1,0);compare_damage(sim,actor,sequence.after_repeat,initial,label+"/repeat")
		sim.particle_state.destroy_creep(actor)
	return cases.size()

func run() -> void:
	var local_wallet_cases=check_local_wallet()
	var path="res://../tests/fixtures/native-creep-reward-reference.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="):path=arg.trim_prefix("--reference=")
	check(FileAccess.get_sha256(path)=="886227ec3d84da8e9916455edcbcc4091d75ef3ef624e54a3267ce857e512030","unchanged_original_reward_fixture")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	for sequence in fixture.cases:
		shooting_name_dependency=false
		var input:Dictionary=sequence.input;var sim=make_sim(input);sim.catalog.tower_creeps[5].price=int(input.price);sim.upgrades.up_interest=int(input.upgrade_level)
		check(int(sim.catalog.tower_upgrades.up_interest.percent)==int(input.upgrade_percent),"preserved_interest_percent")
		var actor:Dictionary=sim.spawn_enemy(5,0,"",9001,false);var label=str(input.pose)+"/"+str(sequence.change.kind)+"/"+str(input.price)+"/"+str(input.upgrade_level)
		View.update(sim,actor);compare(sim,actor,sequence.after_constructor,label+"/construct");compare_extra(actor,sequence.after_constructor,label+"/construct")
		for i in int(input.warmup_count):
			var dt=float([0,30,100,16.667,133.333,30,100,100][i%8]);sim.tick_ms=dt;sim.clock_ms+=int(dt);sim.update_living_enemy(actor);sim.advance_creep_hover(actor,dt);View.update(sim,actor)
		compare(sim,actor,sequence.before_change,label+"/warm");compare_extra(actor,sequence.before_change,label+"/warm")
		for cell in sequence.change.blocked:sim.map.cells[int(cell[1])*16+int(cell[0])].w=0
		for i in sequence.change.inactive_base_indices:sim.bases[int(i)].hp=0
		sim.path_cache.clear();sim.route_cost_cache.clear();sim.update_source_paths();sim.set_enemy_path(actor)
		compare(sim,actor,sequence.before_damage,label+"/replan");compare_extra(actor,sequence.before_damage,label+"/replan")
		var initial_money=float(sim.money)
		sim.damage(actor,float(input.damage_amount),int(input.damage_owner),int(input.damage_kind));compare_damage(sim,actor,sequence.after_damage,initial_money,label+"/damage")
		sim.damage(actor,float(input.damage_amount),int(input.damage_owner),int(input.damage_kind));compare_damage(sim,actor,sequence.after_repeat,initial_money,label+"/repeat")
		sim.particle_state.destroy_creep(actor)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh_explicit_report")
	var result={"checks":checks,"failure_count":failures,"failures_by_field":failures_by_field,"examples":examples,"cases":fixture.cases.size(),"local_wallet_cases":local_wallet_cases,"scope":"Actual Simulation constructor/normal movement/source refresh/reroute then lethal damage and repeated damage. Full original C2/source/path/movement/DoDamage/SetDie on supplied graph/resource5/player1/normal-room records and explicit callbacks. Compared HP/state/previous state/cached remaining/source caches/local score-wallet credit/kill count and once-only event. Additional4cases execute nonnull local-player currency credit and compare that original field directly. Original resource/room/player producers, other attacker ownership/modes, death sprite/particle/backend/audio/GPU identity and full owner chronology remain separate."}
	if not output.is_empty() and not FileAccess.file_exists(output):var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("CREEP_REWARD ",JSON.stringify(result));quit(1 if failures else 0)

extends "res://../tools/creep_spawn_path_ui_verify.gd"
var previous_original_offset=[0,0]
var original_nonfinite_visual_fallbacks=[]
var shooting_name_dependency=false
var shooting_dependent_primary_names_unverified=0

func compare(sim,actor:Dictionary,expected:Dictionary,label:String) -> void:
	# The native shooting-direction callback is deliberately omitted by this
	# oracle. Its primary animation name cannot establish later retention.
	# Keep every other walking field asserted, including the untouched
	# secondary processor. Never replace the runtime name with the stub's name.
	for event in expected.events:
		if str(event.get("kind",""))=="recording-callback" and str(event.get("address",""))=="0x7dcac":shooting_name_dependency=true
	if shooting_name_dependency and expected.has("walking_animator") and int(expected.state)==0 and not bool(expected.aligned) and not label.ends_with("/replan"):
		var other=expected.duplicate(true);other.erase("walking_animator");super.compare(sim,actor,other,label)
		var layers:Array=actor.visual_layers
		var actual={"secondary":layers[1].state,"rotation_bits":bits(float(layers[0].rotation)),"alpha_bits":bits(float(layers[0].alpha)),"secondary_rotation_bits":bits(float(layers[1].rotation)),"secondary_alpha_bits":bits(float(layers[1].alpha))}
		for key in actual:
			var wanted=integer_record(expected.walking_animator[key]);var ok=actual[key]==wanted;check(ok,"walking_"+key)
			if not ok and not sample_keys.has("walking_"+key):sample_keys["walking_"+key]=true;examples.append({"label":label,"field":"walking_"+key,"actual":actual[key],"expected":wanted})
		shooting_dependent_primary_names_unverified+=1
	else:super.compare(sim,actor,expected,label)


func compare_source(sim,expected:Dictionary,label:String) -> void:
	var source:Dictionary=sim.sources[0]
	check(int(source.get("target",0))==int(expected.target),"source_target")
	for kind in ["ground","air"]:
		var actual:Dictionary=source.cached_paths[kind];var path=[]
		for cell in actual.path:path.append([cell.x,cell.y])
		for key in ["path","base_index"]:
			var value=path if key=="path" else int(actual.base_index);var wanted=integer_record(expected.routes[kind][key]);var ok=value==wanted
			check(ok,"source_"+kind+"_"+key)
			if not ok and not sample_keys.has(kind+key):sample_keys[kind+key]=true;examples.append({"label":label,"field":"source_"+kind+"_"+key,"actual":value,"expected":wanted})

func compare_linked(sim,actor:Dictionary,expected:Dictionary,label:String) -> void:
	var comparison=expected
	var nonfinite_position=expected.position_bits.any(func(word):return not is_finite(f(word)))
	var nonfinite_aim=expected.aim_bits.any(func(word):return not is_finite(f(word)))
	if nonfinite_position or nonfinite_aim:
		# Existing finite-position protection intentionally differs from the
		# original zero-length projection's NaNs. Assert that fallback against
		# original logical position and pre-hover offset, and report the gap.
		comparison=expected.duplicate(true)
		if nonfinite_position:comparison.position_bits=expected.logical_bits
		if nonfinite_aim:comparison.aim_bits=vector_bits(vec(expected.logical_bits)+vec(previous_original_offset))
		original_nonfinite_visual_fallbacks.append({"label":label,"position":nonfinite_position,"aim":nonfinite_aim})
	compare(sim,actor,comparison,label);compare_extra(actor,comparison,label)
	previous_original_offset=expected.offset_bits
	var actual={"base_index":int(actor.base),"previous_state":int(actor.get("path_previous_state",0)),"target_owner":int(actor.target_owner)}
	for key in actual:
		var ok=actual[key]==int(expected[key]);check(ok,key)
		if not ok and not sample_keys.has(key):sample_keys[key]=true;examples.append({"label":label,"field":key,"actual":actual[key],"expected":int(expected[key])})

func advance_actor(sim,actor:Dictionary,row:Dictionary,label:String) -> void:
	var dt=float(row.delta);sim.tick_ms=dt;sim.clock_ms+=int(dt);sim.update_living_enemy(actor);sim.advance_creep_hover(actor,dt);View.update(sim,actor);compare_linked(sim,actor,row.after,label+"/"+str(row.frame))

func run() -> void:
	var path="res://../tests/fixtures/native-creep-source-replan-reference.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="):path=arg.trim_prefix("--reference=")
	check(FileAccess.get_sha256(path)=="0270e2ea85362820760a5d2c79063902c2ab672d5505f18a350cf85e35f14c61","unchanged_original_source_replan_fixture")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	for sequence in fixture.cases:
		shooting_name_dependency=false
		var sim=make_sim(sequence.input);var actor:Dictionary=sim.spawn_enemy(5,0,"",9001,false);var label=str(sequence.input.pose)+"/"+str(sequence.change.kind)
		trace_this_case="--trace-rows" in OS.get_cmdline_user_args()
		View.update(sim,actor);compare_linked(sim,actor,sequence.after_constructor,label+"/construct")
		for row in sequence.warmup_frames:advance_actor(sim,actor,row,label+"/warm")
		compare_source(sim,sequence.source_cache_before,label+"/source-before")
		for cell in sequence.change.blocked:sim.map.cells[int(cell[1])*16+int(cell[0])].w=0
		for i in sequence.change.inactive_base_indices:sim.bases[int(i)].hp=0
		sim.path_cache.clear();sim.route_cost_cache.clear();sim.update_source_paths();compare_source(sim,sequence.source_cache_after,label+"/source-after")
		sim.set_enemy_path(actor);compare_linked(sim,actor,sequence.after_replan,label+"/replan")
		for row in sequence.frames:advance_actor(sim,actor,row,label+"/after")
		sim.particle_state.destroy_creep(actor)
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh_explicit_report")
	var result={"checks":checks,"original_nonfinite_visual_fallbacks":original_nonfinite_visual_fallbacks,"shooting_dependent_primary_names_unverified":shooting_dependent_primary_names_unverified,"failure_count":failures,"failures_by_field":failures_by_field,"examples":examples,"cases":fixture.cases.size(),"scope":"Actual constructor/warmup/source refresh/actor reroute and normal movement phases against unchanged original source-linked actor execution on supplied graph/resources/records. Selected map/base-active/target-loss changes; backend/math callbacks remain explicit. Primary animation names after omitted shooting-direction calls are explicitly unverified; secondary names and rotation/alpha remain asserted. Original zero-length projection NaNs use separately reported existing finite logical-position/previous-offset fallback; no original visual identity is claimed for those fields. Full original production, other resources, animation clocks/audio/GPU and reward consumers remain separate."}
	if not trace_rows.is_empty():result.trace_rows=trace_rows
	if not output.is_empty() and not FileAccess.file_exists(output):var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	result.erase("trace_rows");print("CREEP_SOURCE_REPLAN ",JSON.stringify(result));quit(1 if failures else 0)

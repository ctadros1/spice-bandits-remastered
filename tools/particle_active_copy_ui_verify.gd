extends "res://../tools/particle_child_binding_ui_verify.gd"
var copy_active=false
func advance(state,roots:Array,dt:float,deferred:bool,trace:Trace=null) -> bool:
	var particle:Callable=state.make_owned_particle if trace==null else trace.particle
	var child:Callable=state.make_owned_child if trace==null else trace.child
	# Both branches advance every root; false selects the preserved eager
	# callback binding and true skips only demonstrably unused bindings.
	var previous=[]
	for sys in roots:
		if not sys.get("retain_for_owner",false) or not sys.has("owned_tree"):continue
		previous.append({"sys":sys,"tree":sys.owned_tree,"active":sys.owned_tree.particles,"items":sys.owned_tree.particles.duplicate(),"pool":sys.owned_tree.pool,"delay":sys.owned_tree.delay_seconds})
	var accepted=SpiceNative.advance_creep_particles(roots,state.clock_ms,dt,particle,child,state.owned_prepared,deferred,copy_active)
	if accepted:
		for old in previous:
			check(is_same(old.tree,old.sys.owned_tree) and is_same(old.pool,old.tree.pool),"tree and pool aliases unchanged")
			if not old.items.is_empty() and old.delay<=0:
				check(not is_same(old.active,old.tree.particles),"nonempty advancing root creates fresh active array")
			if not old.items.is_empty():check(old.active.size()==old.items.size(),"previous nonempty active-array structure unchanged")
			for i in old.items.size():
				var p=old.items[i]
				check(is_same(p,old.active[i]),"previous active-array particle dictionary alias unchanged")
				check(old.tree.particles.any(func(v):return is_same(v,p)) or old.tree.pool.any(func(v):return is_same(v,p)),"previous particle dictionary survives active or pooled")
	return accepted
func boundary(typed_input:bool,readonly:bool,shape:int,copied:bool) -> Dictionary:
	copy_active=copied
	var sim=make_sim();var actor=sim.spawn_enemy(1,0,"",9901,false);var state=sim.particle_state
	var sys=actor.particle_roots.filter(func(v):return str(v.creep_alias)=="smoke")[0]
	var tree:Dictionary=sys.owned_tree
	tree.particles=[];tree.pool=[]
	var trace=Trace.new();trace.state=state
	SpiceNative.owned_particle_emit(tree,4,trace.particle,trace.child.bind(sys.texture,str(sys.variation)))
	check(tree.particles.size()==4,"four supplied actual smoke particles")
	tree.rate=0;tree.release_seconds=1000000.0;tree.clock_seconds=.25;tree.delay_seconds=0.0
	for i in tree.particles.size():
		var expired=shape==1 or (shape==2 and i%2==0) or (shape==3 and i<2) or (shape==4 and i>=2)
		tree.particles[i].born_seconds=-100.0 if expired else .25
		tree.particles[i].child={}
	if typed_input:
		var typed:Array[Dictionary]=[];typed.assign(tree.particles);tree.particles=typed
	if readonly:tree.particles.make_read_only()
	sys.particles=tree.particles;trace.events=[]
	check(advance(state,[sys],30,true,trace),"array-boundary root accepted")
	check(not tree.particles.is_typed() and not tree.particles.is_read_only(),"retained untyped mutable fresh output semantics")
	var value={"state":state_hash(state,actor),"requests":trace.events.duplicate(true)}
	state.destroy_creep(actor)
	return value
func run() -> void:
	var snapshots=[]
	for copied in [false,true]:
		copy_active=copied
		var rows=[]
		for prepared in [false,true]:
			for number in range(1,11):
				var eager=sequence(number,prepared,false);var deferred=sequence(number,prepared,true)
				check(eager.size()==deferred.size(),"same trace length")
				for i in eager.size():
					check(eager[i].state_sha256==deferred[i].state_sha256 and eager[i].requests_sha256==deferred[i].requests_sha256,"full state and callback order exact")
				rows.append_array(eager);rows.append_array(deferred)
		var baseline_path="res://../tests/reference/particle-child-binding-r169.json"
		var provenance=JSON.parse_string(FileAccess.get_file_as_string(baseline_path.get_basename()+"-provenance.json"))
		check(FileAccess.get_sha256(baseline_path)==str(provenance.baseline_sha256),"immutable independently repeated R169 baseline")
		var baseline=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		check(rows.size()==baseline.rows.size(),"same complete historical row count")
		for i in mini(rows.size(),baseline.rows.size()):
			for key in rows[i]:check(rows[i][key]==baseline.rows[i][key],"exact historical state/request row "+str(i)+"/"+str(key))
		check(child_updates_without_parent_emission>0,"active children emit while parent rate is zero")
		check(pool_reuses>0,"retained pools are reused")
		# Additional synthetic boundaries do not change any immutable historical row.
		for prepared in [false,true]:
			for rate in [0,-3]:
				check(pooled_boundary(rate,prepared,false)==pooled_boundary(rate,prepared,true),"complete eager/deferred pooled-child boundary state exact")
		snapshots.append(rows)
	check(var_to_bytes(snapshots[0])==var_to_bytes(snapshots[1]),"all full rows and callback order byte exact across allocation branches")
	var rows=snapshots[1]
	var boundary_cases=0
	for typed_input in [false,true]:
		for readonly in [false,true]:
			for shape in 5:
				check(var_to_bytes(boundary(typed_input,readonly,shape,false))==var_to_bytes(boundary(typed_input,readonly,shape,true)),"typed/read-only/survivor compaction full state/callback equality")
				boundary_cases+=1
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"boundary_cases":boundary_cases,"checks":checks,"failures":failures,"rows":rows,"child_births_without_parent_emission":child_updates_without_parent_emission,"pool_reuses":pool_reuses,"scope":"R189 copied versus retained active-array allocation, additional fresh-array/pool/particle alias checks. R169 behavior preservation: normalized complete actor/system/key/numeric state, ordered callback requests, RNG/serials/aliases. Ten supplied resources including unused creep7, both prepared paths, variable delta, delay/freeze/slow/Disco/health/death/child tails/pool reuse. Eager/deferred bindings compared. Additional zero/negative-count empty roots retain actual pooled parents and children, advance clocks/release timestamps, and preserve aliases without factory calls. Independent immutable R169 rows remain unchanged; original full game/GPU remains separate."}
	if not output.is_empty() and not FileAccess.file_exists(output):
		var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PARTICLE_ACTIVE_COPY ",JSON.stringify({"boundary_cases":boundary_cases,"checks":checks,"failures":failures,"rows":rows.size(),"child_births_without_parent_emission":child_updates_without_parent_emission,"pool_reuses":pool_reuses}));quit(1 if not failures.is_empty() else 0)

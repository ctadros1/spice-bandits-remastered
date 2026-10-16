extends SceneTree
const View=preload("res://scripts/particle_child_view.gd")
var next_particle=0
var children=[]
var factory_calls=0
var child_real_alpha=0
var diagnostics=[]
var checks=0
var failures=[]
var failure_count=0
func _initialize():
	create_timer(40).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:
		failure_count+=1
		if failures.size()<25:failures.append(label)
func same(a:Variant,b:Variant) -> bool:
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):if not same(a[i],b[i]):return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for k in a:if not b.has(k) or not same(a[k],b[k]):return false
		return true
	return a==b
func make_particle(system:Dictionary,_i:int,fresh:bool,old:Dictionary) -> Dictionary:
	var identity=8388608+0x6000+next_particle*0x100 if fresh else int(old.id)
	if fresh:next_particle+=1
	return {"id":identity,"pos":system.pos,"velocity":Vector2(10,-70),"rotation":0.0,"rot_speed":0.0,"alpha":1.0}
func make_child(_name:String) -> Dictionary:
	factory_calls+=1
	var sys=View.initialize({"max_particles":10,"num_release":1,"release_interval":.05,"life_cycle":.12,"color":[1,1,1,1],"gravity":[0,0],"wind":[0,0],"real_alpha":bool(child_real_alpha)},false,true,false)
	sys.id=8388608+0x2000+children.size()*0x200;sys.pos=Vector2.ZERO;sys.wind_enabled=false
	children.append(sys);return sys
func chain(particles:Array) -> Array:
	var result=[]
	for p in particles:result.append({"pointer":p.id,"child":p.child.id if not p.child.is_empty() else 0,"born_bits":View.bits(p.born_seconds),"position_bits":[View.bits(p.pos.x),View.bits(p.pos.y)]})
	return result
func owner_state(system:Dictionary,label:String) -> Dictionary:
	var result={"label":label,"parent_clock_bits":View.bits(system.clock_seconds),"parent_active":system.particles.size(),"active":chain(system.particles),"pool":chain(system.pool),"factory_calls":factory_calls,"heap_allocations":next_particle,"child_updates":children.reduce(func(total,c):return total+int(c.advance_calls),0),"children":[]}
	for child in children:result.children.append({"pointer":child.id,"clock_bits":View.bits(child.clock_seconds),"active_chain":chain(child.particles),"pool_chain":chain(child.pool)})
	return result
func check_owner(system:Dictionary,original:Dictionary):
	var actual=owner_state(system,str(original.label))
	for key in ["parent_clock_bits","parent_active","active","pool","factory_calls","heap_allocations","child_updates"]:check(same(actual[key],original[key]),"original ownership "+str(original.label)+" "+str(key))
	for i in range(actual.children.size()):
		for key in ["pointer","clock_bits","active_chain","pool_chain"]:check(same(actual.children[i][key],original.children[i][key]),"original child "+str(original.label)+" "+str(key))
func particle_fields(system:Dictionary,result:Dictionary):
	for key in ["particles","pool"]:
		for p in system[key]:
			result[int(p.id)]={"id":p.id,"velocity_bits":[View.bits(p.velocity.x),View.bits(p.velocity.y)],"rotation_bits":View.bits(p.rotation),"opacity_bits":View.bits(p.alpha),"rgba_bits":p.rgba.map(func(v):return View.bits(float(v)))}
			if not p.child.is_empty():particle_fields(p.child,result)
func check_motion(system:Dictionary,original:Dictionary):
	check_owner(system,original)
	check(View.bits(system.delay_seconds)==int(original.parent_delay_bits),"original delay entry/crossing bits")
	check(View.bits(system.release_seconds)==int(original.parent_release_bits),"original parent release bits")
	check(View.bits(float(system.get("phase",0)))==int(original.parent_phase_bits),"original per-particle sine phase bits")
	check(int(system.rate)==int(original.parent_rate) and int(system.first_release)==int(original.parent_first_release),"original disable-after/first emission flags")
	for i in range(children.size()):
		check(View.bits(children[i].release_seconds)==int(original.children[i].release_bits),"original strict float32 child release clock")
		check(int(children[i].rate)==int(original.children[i].rate) and int(children[i].first_release)==int(original.children[i].first_release),"original child rate/first flags")
	var fields={};particle_fields(system,fields)
	check(fields.size()==original.particle_fields.size(),"all allocated active/pooled particle fields covered")
	for row in original.particle_fields:
		var ok=fields.has(int(row.id)) and same(fields[int(row.id)],row)
		if not ok and diagnostics.size()<8:diagnostics.append({"expected":row,"actual":fields.get(int(row.id),{}),"parent_clock":original.parent_clock_bits})
		check(ok,"original full particle color/opacity/velocity/rotation bits")
func run():
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-particle-child-render-reference.json"))
	for c in fixture.cases:
		var root:Dictionary=c.input.duplicate(true)
		for expected in c.outputs:
			var actual=View.render(root,bool(c.homogeneous))
			check(actual.count==int(expected.count),"original recursive strip count "+str(c.pose))
			for i in mini(actual.vertices.size(),expected.vertices.size()):check(same(actual.vertices[i],expected.vertices[i]),"original vertex/UV/RGBA8 "+str(c.pose)+" "+str(i)+" render"+str(expected.render))
			for i in range(2):
				var rgba=root.particles[0].child.particles[i].rgba
				check(same(rgba.map(func(v):return View.bits(float(v))),expected.child_rgba_bits[i]),"original child color mutation "+str(c.pose))
	var factory=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-particle-factory-reference.json"))
	for c in factory.cases:
		var sys=View.initialize({"num_release":6},c.input.texture,c.input.homogeneous,c.input.uv_list,8417280 if c.input.info else 0,bool(c.input.found))
		if not c.input.found:
			check(sys.is_empty() and c.output.returned==0 and c.output.allocations==0,"missing original resource does not allocate");continue
		check(sys.particles.size()==int(c.output.active) and sys.pool.is_empty() and c.output.active_head==0 and c.output.pool_head==0,"original factory empty lists/count")
		check(View.bits(sys.clock_seconds)==int(c.output.clock_bits) and View.bits(sys.release_seconds)==int(c.output.release_bits) and View.bits(sys.delay_seconds)==int(c.output.delay_bits),"original factory zero clocks")
		check(sys.backup_rate==int(c.output.backup_rate) and int(sys.wind_enabled)==int(c.output.wind_flag) and int(sys.first_release)==int(c.output.first_release_flag),"original factory rate/wind/first flags")
		check(int(sys.homogeneous)==int(c.output.homogeneous_flag) and sys.info==int(c.output.info),"original factory texture/opaque info flags")
	var owner=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-particle-child-owner-reference.json"))
	var system=View.initialize({"max_particles":3,"num_release":2,"release_interval":5,"life_cycle":.3,"child_system":"Creep1DebrisSmoke","color":[1,1,1,1],"gravity":[0,0],"wind":[0,0]},false,true,false)
	system.id=8388608;system.pos=Vector2(101.25,203.5);system.wind_enabled=false
	View.emit(system,2,make_particle,make_child);check_owner(system,owner.states[0])
	for frame in range(1,13):View.advance(system,.03,make_particle,make_child);check_owner(system,owner.states[frame])
	View.advance(system,.1,make_particle,make_child);check_owner(system,owner.states[13])
	View.emit(system,1,make_particle,make_child);check_owner(system,owner.states[14])
	View.advance(system,.03,make_particle,make_child);check_owner(system,owner.states[15])
	View.restart(system);check_owner(system,owner.states[16])
	var deleted=[];View.destroy(system,deleted)
	check(same(deleted,owner.deleted),"original recursive destructor delete order")
	check(system.particles.is_empty() and system.pool.is_empty() and children.all(func(c):return c.particles.is_empty() and c.pool.is_empty()),"original destructor clears all chains; stale dead counts not modeled")
	var opacity=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-particle-opacity-reference.json"))
	var math=load("res://scripts/particle_math.gd")
	for row in opacity.cases:
		var definition={"life_cycle":row.life,"blend_delay":row.blend,"fade_in_time":row.fade,"gravity":[0,0],"wind":[0,0],"wind_enabled":false}
		var age=Vector2(float(row.age),0).x
		check(View.bits(math.opacity(age,definition))==int(row.output.opacity_bits),"original scalar opacity floor/boundary")
		var p={"pos":Vector2.ZERO,"velocity":Vector2.ZERO,"rotation":0.0,"rot_speed":0.0}
		SpiceNative.update_particle(p,definition,0,age)
		check(View.bits(p.alpha)==int(row.output.opacity_bits),"original native opacity floor/boundary")
		if View.bits(p.alpha)!=int(row.output.opacity_bits):print("OPACITY_MISMATCH ",JSON.stringify({"row":row,"native_bits":View.bits(p.alpha),"script_bits":View.bits(math.opacity(age,definition))}))
	var motion=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-particle-child-motion-reference.json"))
	for c in motion.cases:
		next_particle=0;children=[];factory_calls=0;child_real_alpha=int(c.input.real_alpha)
		var definition={"max_particles":3,"num_release":2,"release_interval":5,"life_cycle":.3,"child_system":"Creep1DebrisSmoke","color":[1,1,1,1],"gravity":[0,0],"wind":[0,0],"real_alpha":bool(c.input.real_alpha),"amplifyX_withSin_by":float(c.input.amplitude),"amplification_speed":10,"disable_after":float(c.input.disable_seconds)*1000}
		var state=View.initialize(definition,false,true,false);state.pos=Vector2(101.25,203.5);state.wind_enabled=false
		state.motion_limited=bool(c.input.motion_limited);state.motion_seconds=Vector2(float(c.input.motion_seconds),0).x;state.delay_seconds=Vector2(float(c.input.delay),0).x
		View.emit(state,2,make_particle,make_child);check_motion(state,c.frames[0])
		for frame in range(1,c.frames.size()):View.advance(state,float(c.input.dt),make_particle,make_child);check_motion(state,c.frames[frame])
	var report={"checks":checks,"failure_count":failure_count,"diagnostics":diagnostics,"failures":failures,"render_cases":fixture.cases.size(),"motion_cases":motion.cases.size(),"opacity_cases":opacity.cases.size(),"owner_states":owner.states.size(),"factory_cases":factory.cases.size(),"scope":"Independent original factory/C2, recursive render/packing, ownership/reuse/destruction, motion/delay/phase/first-release and opacity field comparisons. Child component remains disconnected; opacity floor and fade-window cap are connected in existing particle math/native coefficients. Supplied short-life zero-variance/no-wind records, sin/cos stubs and AngPos0 remain explicit; no GPU/atlas/whole owner-room/original parser acceptance."}
	var f=FileAccess.open("res://../builds/particle-child-r137-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("PARTICLE_CHILD_FIELDS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

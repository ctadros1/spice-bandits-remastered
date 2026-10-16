extends RefCounted
## Particle state shared by owner simulation and presentation.
const Math=preload("res://scripts/particle_math.gd")
const Owned=preload("res://scripts/particle_owned_view.gd")
const OwnedReference=preload("res://scripts/particle_child_view.gd")
var app
var content
var owners:Dictionary={}
var systems:Array[Dictionary]=[]
var clock_ms=0.0
var clock_seconds=0.0
var random=RandomNumberGenerator.new()
var serial=0
var owned_serial=0
var owned_prepared=true
var reference_emission=false

func _init() -> void:
	var tree=Engine.get_main_loop()
	if tree is SceneTree:content=tree.root.get_node_or_null("Content")

func reset() -> void:
	for sys in systems:
		if sys.has("owned_tree"):Owned.destroy(sys.owned_tree,[])
	for e in owners.values():e.particle_roots=[]
	owners.clear()
	owned_serial=0;systems.clear();clock_ms=0.0;clock_seconds=0.0;serial=0;random.seed=114

func emit_system(name: String, point: Vector2, variation: String = "", owner: String = "", duration_ms: int = 0, direction: Vector2 = Vector2.ZERO, object_owner: int = -1) -> void:
	var started=Time.get_ticks_usec()
	var definition=content.particles.systems.get(name,{})
	if definition.is_empty() or str(definition.texture).is_empty():return
	var texture=content.tex(definition.variations.get(variation,definition.texture))
	if texture==null:return
	emit_definition(name,definition,texture,point,variation,owner,duration_ms,direction,object_owner)
	if is_instance_valid(app):app.record_qa_time("particle_emit_system",started)

func emit_creep_death_burst(resource:String,point:Vector2,variation:String="") -> void:
	# SetDie emits each matching alias once; its5s interval exceeds every
	# supplied newborn death tail. Keep definitions/native cache unchanged.
	# Complete retained-owner/existing smoke/child lifetime remains separate.
	var bindings:Dictionary=content.particles.bindings.get(resource,{})
	var aliases=bindings.keys();aliases.sort()
	for alias in aliases:
		if not "explosion" in str(alias):continue
		var previous_serial=serial
		emit_system(str(bindings[alias].filename),point,variation,"",0)
		if serial==previous_serial:continue
		# Original CParticleSystem starts its own float32 clock at zero.
		# Subtracting a late room birth from the global clock loses precision.
		var sys=systems[-1]
		if sys.has("owned_tree"):
			sys.owned_tree.death_burst=true;sys.owned_tree.interval_seconds=Math.f32(5)
		sys.local_clock_seconds=0.0;sys.view_clock_ms=0.0
		sys.born=0.0;sys.released=0.0;sys.until=0.0
		for p in sys.particles:p.born=0.0;p.child_released=0.0

func emit_definition(name:String,definition:Dictionary,texture:Texture2D,point:Vector2,variation:String="",owner:String="",duration_ms:int=-1,direction:Vector2=Vector2.ZERO,object_owner:int=-1,force_owned:bool=false,initial_emit:bool=true) -> void:
	serial+=1
	var sys={"id":serial,"name":name,"definition":definition,"native_coefficients":SpiceNative.compile_particle(definition),"texture":texture,"pos":point,"direction":direction,"owner":owner,"object_owner":object_owner,"particles":[],"variation":variation,"born":clock_ms,"released":clock_ms,"until":clock_ms+duration_ms if duration_ms>=0 else -1,"emitting":duration_ms!=0,"phase":0.0}
	var child_name=str(definition.get("child_system",""))
	if force_owned or (not child_name.is_empty() and content.particles.systems.has(child_name)):
		sys.owned_tree=create_owned_tree(name,definition,texture,point,variation)
		sys.particles=sys.owned_tree.particles
	systems.append(sys)
	if initial_emit:emit_batch(sys)

func emit_batch(sys: Dictionary) -> void:
	var started=Time.get_ticks_usec()
	if sys.has("owned_tree"):
		var executor=OwnedReference if reference_emission else Owned
		executor.emit(sys.owned_tree,int(sys.owned_tree.rate),make_owned_particle,make_owned_child.bind(sys.texture,str(sys.variation)))
		sys.particles=sys.owned_tree.particles
	elif reference_emission:reference_emit_batch(sys)
	else:SpiceNative.emit_batch(sys,clock_ms,random)
	if is_instance_valid(app):app.record_qa_time("particle_emit_batch",started)

func reference_emit_batch(sys: Dictionary) -> void:
	var definition=sys.definition
	var number=int(definition.get("num_release",1))
	for i in range(number):
		if sys.particles.size()>=int(definition.get("max_particles",100)):break
		var rectangles=definition.texture_list
		var rect=rectangles[random.randi_range(0,rectangles.size()-1)] if not rectangles.is_empty() else {"x":definition.get("tx",0),"y":definition.get("ty",0),"w":definition.get("tw",sys.texture.get_width()),"h":definition.get("th",sys.texture.get_height())}
		var region=Rect2(float(rect.x),float(rect.y),float(rect.w),float(rect.h))
		var velocity_values=definition.get("velocity",[0,0])
		var velocity=Vector2(float(velocity_values[0]),float(velocity_values[1]))
		var point:Vector2=sys.pos
		if int(definition.get("circled_emission",0)):
			var angle=TAU*i/maxi(1,number)+deg_to_rad(random.randf_range(-float(definition.get("circle_angle_var",0)),float(definition.get("circle_angle_var",0))))
			var heading=Vector2(cos(angle),sin(angle))
			point+=heading*float(definition.get("circle_radius",0))
			velocity=heading*(float(definition.get("circle_vel_amount",0))+random.randf_range(0,float(definition.get("velocity_var",1))))
		else:velocity+=Vector2.from_angle(random.randf()*TAU)*float(definition.get("velocity_var",1))
		var rot_speed=float(definition.get("rot_speed",1.0))
		if random.randi_range(0,99)<int(definition.get("rot_dir_rand",0)):rot_speed*=1 if random.randi()%2 else -1
		var rotation=float(definition.get("rot_angle",0))
		var rot_variation=float(definition.get("rot_angle_var",0))
		rotation+=random.randf_range(-rot_variation/2,rot_variation/2)
		var size_offset=random.randf_range(-float(definition.get("size_init_var",0)),float(definition.get("size_init_var",0)))
		var p={"pos":point,"velocity":velocity,"rotation":rotation,"rot_speed":rot_speed,"alpha":0.0 if float(definition.get("fade_in_time",0))>0 else 1.0,"born":clock_ms,"region":region,"size_offset":size_offset,"child_released":clock_ms}
		sys.particles.push_front(p)
	sys.released=clock_ms

func reference_spawn_particle(sys:Dictionary,i:int) -> Dictionary:
	var definition=sys.definition
	var number=int(definition.get("num_release",1))
	var rectangles=definition.texture_list
	var rect=rectangles[random.randi_range(0,rectangles.size()-1)] if not rectangles.is_empty() else {"x":definition.get("tx",0),"y":definition.get("ty",0),"w":definition.get("tw",sys.texture.get_width()),"h":definition.get("th",sys.texture.get_height())}
	var region=Rect2(float(rect.x),float(rect.y),float(rect.w),float(rect.h))
	var velocity_values=definition.get("velocity",[0,0])
	var velocity=Vector2(float(velocity_values[0]),float(velocity_values[1]))
	var point:Vector2=sys.pos
	if int(definition.get("circled_emission",0)):
		var angle=TAU*i/maxi(1,number)+deg_to_rad(random.randf_range(-float(definition.get("circle_angle_var",0)),float(definition.get("circle_angle_var",0))))
		var heading=Vector2(cos(angle),sin(angle))
		point+=heading*float(definition.get("circle_radius",0))
		velocity=heading*(float(definition.get("circle_vel_amount",0))+random.randf_range(0,float(definition.get("velocity_var",1))))
	else:velocity+=Vector2.from_angle(random.randf()*TAU)*float(definition.get("velocity_var",1))
	var rot_speed=float(definition.get("rot_speed",1.0))
	if random.randi_range(0,99)<int(definition.get("rot_dir_rand",0)):rot_speed*=1 if random.randi()%2 else -1
	var rotation=float(definition.get("rot_angle",0))
	var rot_variation=float(definition.get("rot_angle_var",0))
	rotation+=random.randf_range(-rot_variation/2,rot_variation/2)
	var size_offset=random.randf_range(-float(definition.get("size_init_var",0)),float(definition.get("size_init_var",0)))
	var p={"pos":point,"velocity":velocity,"rotation":rotation,"rot_speed":rot_speed,"alpha":0.0 if float(definition.get("fade_in_time",0))>0 else 1.0,"born":clock_ms,"region":region,"size_offset":size_offset,"child_released":clock_ms}
	return p

func create_owned_tree(name:String,definition:Dictionary,texture:Texture2D,point:Vector2,variation:String) -> Dictionary:
	var tree=Owned.initialize(definition,true,false,not definition.texture_list.is_empty())
	tree.name=name;tree.texture=texture;tree.pos=point;tree.variation=variation
	if definition.has("source_sha256") and not str(definition.get("name","")).is_empty():tree.native_coefficients=SpiceNative.compile_particle(definition)
	owned_serial+=1;tree.id=owned_serial
	return tree

func make_owned_child(name:String,texture:Texture2D,variation:String) -> Dictionary:
	var definition:Dictionary=content.particles.systems.get(name,{})
	if definition.is_empty():return {}
	return create_owned_tree(name,definition,texture,Vector2.ZERO,variation)

func make_owned_particle(tree:Dictionary,index:int,fresh:bool,old:Dictionary) -> Dictionary:
	# Existing isolated Godot RNG is an adaptation, not recovered global RNG.
	var p:Dictionary=reference_spawn_particle(tree,index) if reference_emission else SpiceNative.particle_spawn_fields(tree,index,random)
	if fresh:owned_serial+=1
	p.id=owned_serial if fresh else int(old.id)
	p.born=float(tree.clock_seconds)*1000.0;p.child_released=p.born
	var region:Rect2=p.region;var extent=Vector2(tree.texture.get_width(),tree.texture.get_height())
	p.texture={"width":region.size.x,"height":region.size.y,"uv":[Math.f32(region.position.x/extent.x),Math.f32(region.end.x/extent.x),Math.f32(region.position.y/extent.y),Math.f32(region.end.y/extent.y)]}
	return p

func advance_owned_system(sys:Dictionary,dt:float,reference:bool=false) -> bool:
	var tree:Dictionary=sys.owned_tree;tree.pos=sys.pos
	if not tree.get("death_burst",false) and float(sys.until)>=0 and clock_ms>=float(sys.until):
		sys.emitting=false;tree.rate=0
	var executor=OwnedReference if reference else Owned
	if reference:executor.advance(tree,dt,make_owned_particle,make_owned_child.bind(sys.texture,str(sys.variation)))
	else:SpiceNative.owned_particle_advance(tree,dt,make_owned_particle,make_owned_child.bind(sys.texture,str(sys.variation)),1.0,owned_prepared)
	sys.particles=tree.particles;sys.phase=float(tree.get("phase",0))
	var seconds=float(tree.clock_seconds);sys.view_clock_ms=seconds*1000.0
	if sys.has("local_clock_seconds"):sys.local_clock_seconds=seconds
	if int(tree.rate)==0:sys.emitting=false
	if not sys.get("retain_for_owner",false) and not sys.emitting and sys.particles.is_empty():
		executor.destroy(tree,[]);return true
	return false


# Roots owned by a creep remain allocated (including empty pools) until its
# manager destroys that creep. The renderer and headless simulation share them.
func creep_root(e:Dictionary,alias:String,point:Vector2,initial_emit:bool=true,raw_map_field8:Variant=null) -> Dictionary:
	var roots:Array=e.get("particle_roots",[])
	for sys in roots:
		if str(sys.creep_alias)==alias:return sys
	var resource="creeps/"+str(e.def.filename)
	var binding:Dictionary=content.particles.bindings.get(resource,{}).get(alias,{})
	var name=str(binding.get("filename",""));var d:Dictionary=content.particles.systems.get(name,{})
	if d.is_empty():return {}
	# Creep.C2 changes its private system header, never the resource template.
	if not initial_emit:
		d=d.duplicate(true)
		d.native_header_variant=resource+":"+str(raw_map_field8)
		var params:Dictionary=e.def.get("traits",{})
		if alias=="smoke":
			for pair in [["size","smoke_scale"],["release_interval","smoke_emition_multiplier"],["velocity_var","smoke_vel_rand_multiplier"],["rot_speed","smoke_rot_multiplier"]]:
				if params.has(pair[1]):d[pair[0]]=Math.f32(Math.f32(float(d.get(pair[0],0)))*Math.f32(float(params[pair[1]])))
			if params.has("smoke_lifecycle"):d.life_cycle=Math.f32(Math.f32(float(params.smoke_lifecycle))*Math.f32(.7))
			if params.has("smoke_alpha_multiplier"):d.color[3]=Math.f32(Math.f32(float(d.color[3]))*Math.f32(float(params.smoke_alpha_multiplier)))
			# The constructor's later interval assignment overrides the earlier
			# smoke_max_dmg_emittion_rate parameter in the original body.
			e.smoke_base_interval=Math.f32(float(d.release_interval));e.smoke_work_interval=e.smoke_base_interval
			e.smoke_max_multiplier=Math.f32(float(params.get("smoke_max_dmg_emittion_rate_multiplier",1)))
			e.smoke_rate=int(d.get("num_release",1));e.smoke_color_flag=bool(params.get("smoke_color_from_damage",false))
			e.smoke_idle_multiplier=Math.f32(float(params.get("smoke_emittion_mult_on_idle",1)))
		elif alias in ["hover_flow","hover_flow2"] and raw_map_field8!=null and int(raw_map_field8)==1:
			for k in 3:d.color[k]=1.0
	var variation=str(e.def.get("color","")) if bool(binding.get("have_variation",false)) else ""
	var texture=content.tex(d.variations.get(variation,d.texture))
	if texture==null:return {}
	emit_definition(name,d,texture,point,variation,"enemy:%d:%s" % [e.id,alias],-1,e.dir,-1,true,initial_emit)
	var sys=systems[-1]
	owners[int(e.id)]=e
	sys.creep_owner=int(e.id);sys.creep_alias=alias;sys.retain_for_owner=true
	sys.creep_binding=binding
	if not initial_emit and alias in ["smoke","poison","radiation","lsd","freeze"]:
		sys.owned_tree.rate=0;sys.emitting=false
	roots.append(sys);roots.sort_custom(func(a,b):return str(a.creep_alias)<str(b.creep_alias));e.particle_roots=roots
	return sys

func initialize_creep(e:Dictionary,raw_map_field8:Variant=null) -> void:
	# All non-explosion roots are born empty. Only SetDie explicitly Emits.
	# Raw map+8 can be supplied by original-field tests; its live producer is
	# unresolved, so live hover color retains the authored resource RGB.
	var aliases=content.particles.bindings.get("creeps/"+str(e.def.filename),{}).keys();aliases.sort()
	for alias in aliases:
		if not "explosion" in str(alias):creep_root(e,str(alias),e.pos,false,raw_map_field8)
	e.freeze_auxiliary_present=e.get("particle_roots",[]).any(func(sys):return str(sys.creep_alias)=="freeze")
	e.freeze_auxiliary_value=0

func stop_creep(e:Dictionary) -> void:
	for sys in e.get("particle_roots",[]):
		sys.emitting=false;sys.owned_tree.rate=0

func begin_creep_death(e:Dictionary,point:Vector2) -> void:
	stop_creep(e)
	var aliases=content.particles.bindings.get("creeps/"+str(e.def.filename),{}).keys();aliases.sort()
	for alias in aliases:
		if not "explosion" in str(alias):continue
		var sys=creep_root(e,str(alias),point)
		if sys.is_empty():continue
		# SetDie's authored initial Emit is already performed by construction.
		# Its five-second interval is retained, not replaced by a guessed tail.
		sys.owned_tree.death_burst=true;sys.owned_tree.interval_seconds=Math.f32(5)
		sys.local_clock_seconds=0.0;sys.view_clock_ms=0.0
		sys.born=0.0;sys.released=0.0;sys.until=0.0;sys.emitting=false
		for p in sys.particles:p.born=0.0;p.child_released=0.0

func refresh_creep(sim,e:Dictionary) -> void:
	# Freeze's real constructor alias is driven by ProcessSpeed/ProcessFreeze.
	# LSD/poison/radiation retain the existing caller bridge pending recovery.
	var aliases=[]
	if sim.clock_ms<e.disco_until:aliases.append("lsd")
	if float(e.get("poison_count",0))>0:
		var radiation=sim.zones.any(func(z):return int(z.type)==5 and not z.has("bubble") and e.pos.distance_to(z.pos)<float(z.def.get("poison_range",0))*float(sim.map.hex_h)/1000.0)
		aliases.append("radiation" if radiation else "poison")
	for sys in e.get("particle_roots",[]):
		var alias=str(sys.creep_alias)
		if alias=="freeze":sys.owned_tree.rate=int(e.get("freeze_auxiliary_value",0))
		elif alias in ["lsd","poison","radiation"]:sys.owned_tree.rate=int(sys.owned_tree.backup_rate) if alias in aliases else 0
		sys.owner_hidden=e.has("portal_pose") and not e.portal_pose.particles_visible

func stop_creep_smoke(e:Dictionary) -> void:
	for sys in e.get("particle_roots",[]):
		if str(sys.creep_alias)=="smoke":sys.owned_tree.rate=0;sys.emitting=false

func update_creep_fields(e:Dictionary,aim:Vector2,direction:Vector2,heavy:bool=false) -> void:
	# Full original UpdateParticles: its smoke pointer aliases a mapped root.
	# It is never a separately advanced emitter. Preserve float32 operation order.
	for sys in e.get("particle_roots",[]):
		var tree:Dictionary=sys.owned_tree
		if str(sys.creep_alias)=="smoke":
			var maximum=Math.f32(float(int(e.max_hp)))
			if float(e.hp)<Math.f32(maximum*Math.f32(.6000000238418579)):
				if e.get("smoke_color_flag",false) and int(e.state) not in [2,3]:
					var factor=Math.f32(Math.f32(maxf(0,Math.f32(float(e.hp)))/maximum)/Math.f32(.6000000238418579))
					var base=Math.f32(float(e.smoke_base_interval))
					var interval=Math.f32(base+Math.f32(Math.f32(Math.f32(base*Math.f32(float(e.smoke_max_multiplier)))-base)*Math.f32(1.0-factor)))
					e.smoke_work_interval=maxf(Math.f32(.03),interval);tree.interval_seconds=e.smoke_work_interval
					for k in 3:tree.definition.color[k]=factor
					tree.rate=int(e.smoke_rate)
			else:tree.rate=0
		var binding:Dictionary=sys.get("creep_binding",{})
		var x=Math.f32(float(binding.get("offsetX",0)));var y=Math.f32(float(binding.get("offsetY",0)))
		var distance=Math.f32(sqrt(Math.f32(Math.f32(x*x)+Math.f32(y*y))))
		sys.pos=Vector2(Math.f32(aim.x+Math.f32(-Math.f32(direction.x*distance))),Math.f32(aim.y+Math.f32(-Math.f32(direction.y*distance))))
		if bool(binding.get("emitt_on_walking",false)):
			tree.rate=0 if int(e.state) in [1,2,3,4,5,6] or heavy else int(tree.backup_rate)
		sys.emitting=int(tree.rate)!=0

func advance_creep(e:Dictionary,dt_ms:float) -> void:
	var dt=Math.f32(Math.f32(dt_ms)*Math.f32(.001))
	for sys in e.get("particle_roots",[]):advance_owned_system(sys,dt,reference_emission)

func destroy_creep(e:Dictionary) -> void:
	for sys in e.get("particle_roots",[]):Owned.destroy(sys.owned_tree,[])
	var id=int(e.id)
	owners.erase(id)
	systems=systems.filter(func(sys):return int(sys.get("creep_owner",-1))!=id)
	e.particle_roots=[]

func advance_unowned(dt:float) -> void:
	# Owner roots are stepped at their creep's actual phase, even headless.
	# The remaining existing effects keep their separate presentation adapter.
	var active:Array[Dictionary]=[]
	for sys in systems:
		if not sys.has("creep_owner"):active.append(sys)
	var before_serial=serial
	SpiceNative.advance_systems(active,clock_ms,emit_system,emit_batch,random,dt)
	var live={}
	for sys in active:live[int(sys.id)]=true
	systems=systems.filter(func(sys):return sys.has("creep_owner") or live.has(int(sys.id)) or int(sys.id)>before_serial)

func replace_systems(value:Array[Dictionary]) -> void:
	# QA held-render restoration replaces full mutable trees. Rebind owners to
	# those restored dictionaries so the next live step cannot update ghosts.
	systems=value
	for e in owners.values():e.particle_roots=[]
	for sys in systems:
		var id=int(sys.get("creep_owner",-1))
		if owners.has(id):owners[id].particle_roots.append(sys)
	for e in owners.values():e.particle_roots.sort_custom(func(a,b):return str(a.creep_alias)<str(b.creep_alias))

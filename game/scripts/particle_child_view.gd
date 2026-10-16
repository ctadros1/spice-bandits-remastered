extends RefCounted
## Original particle-system initialization and recursive render fields.
## Integration with live ParticleFX remains separate until ownership is verified.
const Math=preload("res://scripts/particle_math.gd")

static func initialize(definition:Dictionary,texture_present:bool,texture_homogeneous:bool,texture_list_nonempty:bool,info:Variant=null,found:bool=true) -> Dictionary:
	if not found:return {}
	return {"definition":definition,"particles":[],"pool":[],"clock_seconds":0.0,"release_seconds":0.0,"delay_seconds":0.0,"rate":int(definition.get("num_release",1)),"backup_rate":int(definition.get("num_release",1)),"wind_enabled":true,"first_release":true,"homogeneous":not texture_list_nonempty and (not texture_present or texture_homogeneous),"info":info,"advance_calls":0}

static func bits(value:float) -> int:
	return PackedFloat32Array([value]).to_byte_array().decode_u32(0)

static func packed_channel(value:float) -> int:
	# The original VCVT.S32 followed by a byte store is not RGBA8 clamping.
	var scaled=Math.f32(Math.f32(value)*255.0)
	if scaled<=-2147483648.0:return 0
	if scaled>=2147483647.0:return 255
	return int(scaled)&255

static func quad(root:Dictionary,system:Dictionary,p:Dictionary) -> Array:
	var d:Dictionary=system.definition
	var size=Math.f32(float(d.get("size",1)))
	var half=Math.f32(size+Math.f32(float(p.get("size_offset",0)))) if float(d.get("size_init_var",0))!=0 else size
	var factor=1.0
	if d.get("scalable",false):
		var age=Math.f32(Math.f32(float(system.clock_seconds))-Math.f32(float(p.get("born_seconds",0))))
		var progress=Math.f32(age/Math.f32(float(d.get("life_cycle",1))))
		var scale=Math.f32(float(d.get("scale",0)))
		factor=Math.f32(1.0-Math.f32(Math.f32(1.0-scale)*progress)) if scale<=1 else Math.f32(1.0+Math.f32(scale*progress))
		half=Math.f32(half*factor)
	var width=half;var height=half
	if d.get("use_real_size",false):
		width=Math.f32(Math.f32(float(p.texture.width)*0.5)*size)
		height=Math.f32(Math.f32(float(p.texture.height)*0.5)*size)
		if d.get("scalable",false):width=Math.f32(width*factor);height=Math.f32(height*factor)
	var x=Math.f32(float(p.pos[0]));var y=Math.f32(float(p.pos[1]))
	if not d.get("rotational",false) and not d.get("orient_to_velocity",false):
		return [Vector2(Math.f32(x-width),Math.f32(y-height)),Vector2(Math.f32(x+width),Math.f32(y-height)),Vector2(Math.f32(x-width),Math.f32(y+height)),Vector2(Math.f32(x+width),Math.f32(y+height))]
	# The original uses the root system's angle flag, including for children.
	# direction_angle is a supplied AngPos result; its caller is not ported here.
	var angle=Math.f32(float(p.get("rotation",0))) if root.definition.get("rotational",false) else Math.f32(float(p.get("direction_angle",0)))
	angle=Math.f32(angle+Math.f32(PI/2))
	var c=Math.f32(cos(angle));var s=Math.f32(sin(angle))
	var wc=Math.f32(width*c);var hs=Math.f32(height*s);var hc=Math.f32(height*c);var ws=Math.f32(width*s)
	return [Vector2(Math.f32(Math.f32(-wc-(-hs))+x),Math.f32(Math.f32(-hc+(-ws))+y)),Vector2(Math.f32(Math.f32(wc-(-hs))+x),Math.f32(Math.f32(-hc+ws)+y)),Vector2(Math.f32(Math.f32(-wc-hs)+x),Math.f32(Math.f32(hc+(-ws))+y)),Vector2(Math.f32(Math.f32(wc-hs)+x),Math.f32(Math.f32(hc+ws)+y))]

static func append_particle(root:Dictionary,system:Dictionary,p:Dictionary,homogeneous:bool,vertices:Array) -> void:
	var points=quad(root,system,p)
	var rgba=[]
	for value in p.rgba:rgba.append(packed_channel(float(value)))
	var uv:Array=p.texture.uv
	var uvs=[Vector2(uv[0],uv[2]),Vector2(uv[1],uv[2]),Vector2(uv[0],uv[3]),Vector2(uv[1],uv[3])]
	var order=[0,1,2,3,3] if vertices.is_empty() else [0,0,1,2,3,3]
	for index in order:
		var point:Vector2=points[index];var tex:Vector2=uvs[index]
		vertices.append({"position_bits":[bits(point.x),bits(point.y)],"uv_bits":null if homogeneous else [bits(tex.x),bits(tex.y)],"rgba8":rgba.duplicate()})
	var child:Dictionary=p.get("child",{})
	if child.is_empty():return
	for particle in child.particles:
		# Render mutates stored color, not the particle's own opacity field.
		if child.definition.get("real_alpha",false):
			for i in range(3):particle.rgba[i]=Math.f32(float(particle.rgba[i])*float(p.alpha))
		particle.rgba[3]=Math.f32(float(particle.rgba[3])*float(p.alpha))
		append_particle(root,child,particle,homogeneous,vertices)

static func render(root:Dictionary,homogeneous:bool) -> Dictionary:
	var vertices=[]
	for p in root.particles:append_particle(root,root,p,homogeneous,vertices)
	return {"count":vertices.size(),"vertices":vertices}

static func emit(system:Dictionary,count:int,make_particle:Callable,make_child:Callable) -> void:
	system.release_seconds=system.clock_seconds
	for i in range(count):
		if system.particles.size()>=int(system.definition.get("max_particles",100)):continue
		var fresh=system.pool.is_empty()
		var p:Dictionary={} if fresh else system.pool.pop_front()
		var old_child:Dictionary=p.get("child",{})
		var values:Dictionary=make_particle.call(system,i,fresh,p)
		p.merge(values,true)
		if fresh:
			var child_name=str(system.definition.get("child_system",""))
			p.child=make_child.call(child_name) if not child_name.is_empty() else {}
		else:p.child=old_child
		p.born_seconds=system.clock_seconds
		p.alpha=0.0 if float(system.definition.get("fade_in_time",0))>0 else 1.0
		var color:Array=system.definition.get("color",[1,1,1,1]);p.rgba=[]
		for channel in range(4):
			var value=Math.f32(float(color[channel]))
			p.rgba.append(Math.f32(value*p.alpha) if channel==3 or system.definition.get("real_alpha",false) else value)
		system.particles.push_front(p);system.first_release=false

static func advance(system:Dictionary,dt:float,make_particle:Callable,make_child:Callable,interval_scale:float=1.0) -> void:
	dt=Math.f32(dt)
	system.advance_calls=int(system.get("advance_calls",0))+1
	if system.delay_seconds>0:
		system.delay_seconds=Math.f32(float(system.delay_seconds)-dt);return
	var d:Dictionary=system.definition
	system.clock_seconds=Math.f32(float(system.clock_seconds)+Math.f32(Math.f32(float(d.get("time_scale",1)))*dt))
	var disable=Math.f32(float(d.get("disable_after",0))/1000.0)
	if disable>0 and disable<=float(system.clock_seconds) and not system.first_release:system.rate=0
	var live=[]
	var physics=d.duplicate();physics.wind_enabled=system.wind_enabled
	var life=Math.f32(float(d.get("life_cycle",1)))
	for p in system.particles:
		var age=Math.f32(float(system.clock_seconds)-float(p.born_seconds))
		var active=age<life
		var moving=not system.get("motion_limited",false) or age<float(system.get("motion_seconds",0))
		if active and moving:Math.update_particle(p,physics,dt,age)
		else:
			p.rotation=Math.f32(float(p.rotation)+Math.f32(float(p.rot_speed)*dt))
			p.alpha=Math.opacity(age,d)
		var color:Array=d.get("color",[1,1,1,1])
		if d.get("real_alpha",false):
			for i in range(3):p.rgba[i]=Math.f32(Math.f32(float(color[i]))*float(p.alpha))
		p.rgba[3]=Math.f32(Math.f32(float(color[3]))*float(p.alpha))
		if active:
			live.append(p)
			var child:Dictionary=p.get("child",{})
			if moving and not child.is_empty():
				child.pos=p.pos;advance(child,dt,make_particle,make_child,interval_scale)
		else:system.pool.push_front(p)
		var amplitude=Math.f32(float(d.get("amplifyX_withSin_by",0)))
		if amplitude!=0:
			var old=float(system.get("phase",0));var phase=Math.f32(old+Math.f32(float(d.get("amplification_speed",0))*dt));system.phase=phase
			p.pos.x=Math.f32(p.pos.x+Math.f32(Math.f32(sin(phase)-sin(old))*amplitude))
	system.particles=live
	var interval=Math.f32(Math.f32(float(d.get("release_interval",1)))*Math.f32(interval_scale))
	if interval<Math.f32(float(system.clock_seconds)-float(system.release_seconds)) and dt<life:
		emit(system,int(system.rate),make_particle,make_child)

static func restart(system:Dictionary) -> void:
	for p in system.particles:system.pool.push_front(p)
	system.particles=[]

static func destroy(system:Dictionary,deleted:Array) -> void:
	for key in ["particles","pool"]:
		for p in system[key]:
			var child:Dictionary=p.get("child",{})
			if not child.is_empty():destroy(child,deleted);deleted.append(child.id)
			deleted.append(p.id)
		system[key]=[]

extends RefCounted

static func f32(v: float) -> float: return Vector2(v,0.0).x

static func opacity(age: float, definition: Dictionary) -> float:
	var life=f32(float(definition.get("life_cycle",1)))
	var fade=f32(float(definition.get("fade_in_time",0)))
	var blend=f32(float(definition.get("blend_delay",0)))
	var value=1.0
	if blend>0 and age>f32(life/blend):value=f32(1.0-f32(f32(age-f32(life/blend))/f32(life/blend)))
	elif fade>0:
		if age<=fade:value=f32(age/fade)
		else:value=f32(1.0-f32(f32(age-fade)/f32(life-fade)))
	elif blend==0:value=f32(1.0-f32(age/life))
	return minf(1,value)

static func update_particle(p: Dictionary, definition: Dictionary, dt: float, age: float) -> void:
	SpiceNative.update_particle(p,definition,dt,age)

static func advance_particles(particles: Array, definition: Dictionary, dt: float, clock: float) -> void:
	SpiceNative.update_particles(particles,definition,dt,clock)

static func reference_update_particle(p: Dictionary, definition: Dictionary, dt: float, age: float) -> void:
	# CParticleSystem::Update0x111088: gravity, wind drag, position and
	# rotation are explicit f32 operations. Their seconds clock is independent
	# of wall-clock time, so effects share battle pause and speed behavior.
	var gravity=definition.get("gravity",[0,0])
	var wind=definition.get("wind",[0,0])
	var v: Vector2=p.velocity
	v+=Vector2(f32(float(gravity[0])*dt),f32(float(gravity[1])*dt))
	if bool(definition.get("wind_enabled",true)):
		v+=Vector2(f32(float(wind[0])-v.x),f32(float(wind[1])-v.y))*dt
	p.velocity=v
	p.pos+=v*dt
	p.rotation=f32(float(p.rotation)+f32(float(p.rot_speed)*dt))
	p.alpha=opacity(age,definition)

static func age(clock: float, born: float) -> float:
	return f32(f32(clock/1000.0)-f32(born/1000.0))

static func size_factor(age: float, definition: Dictionary) -> float:
	if int(definition.get("scalable",0))==0:return 1.0
	var scale=f32(float(definition.get("scale",0)))
	var progress=f32(age/float(definition.get("life_cycle",1)))
	return f32(1.0-f32(f32(1.0-scale)*progress)) if scale<=1 else f32(1.0+f32(scale*progress))

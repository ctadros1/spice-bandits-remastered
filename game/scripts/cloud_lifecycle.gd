extends RefCounted
# Selected CPoison caller port. Particle factory/physics, random sources, parent
# production, decals and sound are explicit adapters; no synthetic tail model.
# Simulation integration follows separate verification of real retained systems.
const Poison=preload("res://scripts/creep_poison.gd")
static func f32(v:float) -> float:return Vector2(v,0).x

# The resource tier is the original one-based word at +8. Radiation is the
# original constructor flag, independent of the resource's slowdown flag.
static func construct(resource:Dictionary,pos:Vector2,owner:int,bonus:float,radiation:bool,tier:int,slow:bool) -> Dictionary:
	return {"def":resource,"pos":pos,"initial_pos":pos,"owner":owner,"damage_bonus":f32(bonus),"type":5 if radiation else 7,"radiation":radiation,"tier":tier,"slow":slow,"active":true,"deleted":false,"age_ms":0.0,"emit_age_ms":1000.0,"parent30":{},"parent40":{},"ready":true,"roots":[],"creeps_in_range":[]}

static func emit_system(zone:Dictionary,height:float,adapters:Dictionary) -> void:
	var radiation:bool=zone.radiation
	var name="RadiationDebris" if radiation else "GooCloud" if zone.slow else "PoisonCloud"
	var system:Dictionary=adapters.factory.call(name)
	if not radiation:
		if int(zone.tier)==1:system.interval=f32(float(system.interval)+float(system.interval))
	else:
		var alpha_random:int=adapters.random.call()
		system.alpha=f32(f32(f32(alpha_random%10)*f32(.4))+f32(-.3))
		system.pos=Vector2(system.pos.x,f32(float(system.pos.y)+f32(-500.0)))
	var vector:Vector2=adapters.vector.call()
	var radius=f32(float(zone.def.get("poison_range",0))/1000.0)
	if radius!=0:
		if not radiation:
			var extent=int(f32(f32(radius/f32(1.5))*f32(height)))
			var value:int=adapters.rand.call()
			var remainder:int=adapters.modulo.call(value,extent)
			var spread=f32(f32(remainder)+f32(f32(extent)*f32(.25)))
			if spread>f32(extent):spread=f32(extent)
			system.pos=Vector2(f32(float(zone.pos.x)+f32(float(vector.x)*spread)),f32(float(zone.pos.y)+f32(float(vector.y)*spread)))
		else:
			# Two rand calls precede both modulo calls. Y uses the first
			# remainder; X uses their sum, substituting 1 only for that sum.
			var first:int=adapters.rand.call()
			var extent=int(f32(f32(radius*f32(.5))*f32(height)))
			var second:int=adapters.rand.call()
			var left:int=adapters.modulo.call(first,extent)
			var right:int=adapters.modulo.call(second,extent)
			var spread=f32(f32(left)+f32(right))
			if spread==0:spread=1.0
			var x=f32(float(zone.pos.x)+f32(f32(float(vector.x)*spread)*f32(1.4)))
			var y=f32(f32(float(zone.pos.y)+f32(float(vector.y)*f32(left)))+f32(-100.0))
			system.pos=Vector2(x,y)
	system.disable_after_seconds=f32(f32(float(zone.def.poison_duration))*f32(.001))
	if not radiation:
		for i in 25:adapters.advance.call(system,f32(.05))
	zone.roots.append(system)

static func update_particles(zone:Dictionary,dt_ms:float,adapters:Dictionary) -> void:
	var seconds=f32(f32(dt_ms)*f32(.001))
	var i=0
	while i<zone.roots.size():
		var system:Dictionary=zone.roots[i]
		if int(system.active_count)>0 or bool(system.first_release) or float(system.disable_after_seconds)==0:
			adapters.advance.call(system,seconds)
			i+=1
		else:
			adapters.destroy.call(system)
			zone.roots.remove_at(i)

static func update(zone:Dictionary,actors:Array,height:float,dt_ms:float,adapters:Dictionary,argument_b:bool=false,trace:Callable=Callable()) -> void:
	var released=false
	if not zone.parent40.is_empty():
		zone.ready=int(zone.parent40.word4)!=0
		if zone.ready:zone.parent40={};released=true
	elif not zone.parent30.is_empty():
		zone.ready=(int(zone.parent30.byte44)&1)==0
		if zone.ready:zone.parent30={};released=true
	else:zone.ready=true
	if released:
		adapters.decals.call(zone)
		if not zone.radiation:adapters.sound.call("acid_splash_and_burn-mono",zone.pos,1)
	if zone.ready:
		zone.age_ms=f32(float(zone.age_ms)+f32(dt_ms))
		if float(zone.age_ms)>=f32(float(zone.def.poison_duration)):zone.deleted=true
		if not zone.deleted:
			zone.emit_age_ms=f32(float(zone.emit_age_ms)+f32(dt_ms))
			if float(zone.emit_age_ms)>=(60.0 if zone.radiation else 80.0):
				zone.emit_age_ms=0.0
				emit_system(zone,height,adapters)
			if zone.slow:Poison.apply_slow(actors,zone,height,trace)
			else:Poison.apply_damage(actors,zone,height,dt_ms,adapters.damage,argument_b,trace)
	update_particles(zone,dt_ms,adapters)
	if zone.deleted and zone.roots.is_empty():
		zone.active=false
		for actor in actors:Poison.stop(actor,1 if zone.radiation else 2,trace)

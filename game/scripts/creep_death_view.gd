extends RefCounted
# Disconnected R124 death-field/splash port. Complete existing-owner/particle
# birth chronology and render/lifetime integration remain separate.
static func f32(v:float) -> float:return Vector2(v,0).x
static func sprite(life:float,position:Vector2,initial_scale:float,divisor:float) -> Dictionary:
	var d=f32(int(f32(divisor)))
	return {"life":f32(life),"initial_life":f32(life),"position":position,"start":position,"end":position,"initial_scale":Vector2.ONE*f32(initial_scale),"scale":Vector2.ONE if d==0 else Vector2.ZERO,"divisor":d,"alpha":1.0}
static func update_sprite(s:Dictionary,dt:float) -> void:
	s.life=maxf(0,f32(float(s.life)-f32(dt)))
	var progress=maxf(0,f32(1.0-f32(float(s.life)/float(s.initial_life))))
	s.alpha=f32(1.0-progress)
	var t=f32(progress*.5);var inverse=f32(1.0-t)
	s.position=Vector2(f32(f32(s.start.x*inverse)+f32(s.end.x*t)),f32(f32(s.start.y*inverse)+f32(s.end.y*t)))
	if float(s.divisor)!=0:
		var factor=f32(f32(1.0-float(s.alpha))/float(s.divisor))
		s.scale=Vector2(f32(f32(s.initial_scale.x*factor)+s.initial_scale.x),f32(f32(s.initial_scale.y*factor)+s.initial_scale.y))
static func tail(state:int,emitter_count,counts:Array,sprites:Array,dt:float) -> Dictionary:
	var updated=[];var deleted=[];var next=[];var state_calls=[]
	if state!=3:return {"state":state,"emitter_rate":37 if emitter_count!=null else null,"sprites":sprites,"updated":updated,"deleted":deleted,"state_calls":state_calls}
	var finished=emitter_count==null or int(emitter_count)<1
	for count in counts:finished=finished and int(count)<1
	for s in sprites:
		if float(s.life)<=0:deleted.append(int(s.index))
		else:
			update_sprite(s,dt);next.append(s);updated.append(int(s.index));finished=false
	if finished:state=2;state_calls.append(2)
	return {"state":state,"emitter_rate":0 if emitter_count!=null else null,"sprites":next,"updated":updated,"deleted":deleted,"state_calls":state_calls}
static func creation(resource:Dictionary,bindings:Dictionary,systems:Dictionary,kind:int,already:bool,logical:Vector2,offset:Vector2,aim:Vector2,animator:Vector2,sound_index:int=0,crater_index:int=0) -> Dictionary:
	var params:Dictionary=resource.params;var textures:Dictionary=resource.textures
	var result={"state":3,"crater_created":true,"particles":[],"sprites":[],"sound":{},"crater":{}}
	var cues:Array=params.get("explosion_sound_list",[])
	if not cues.is_empty():result.sound={"cue":cues[posmod(sound_index,cues.size())],"position":animator}
	var aliases=bindings.keys();aliases.sort()
	for alias in aliases:
		if not "explosion" in str(alias):continue
		var name=str(bindings[alias].filename)
		result.particles.append({"name":name,"count":int(systems[name].num_release),"position":aim,"interval":5.0})
	if kind!=2 and textures.has("ExplosionSplash"):
		# All supplied creep resources have exp_scale_div. Missing-field
		# original compiler/register behavior is outside this bounded port.
		var s=sprite(float(params.get("exp_lifetime",300)),logical+offset,float(params.get("exp_init_scale",f32(.7))),float(params.exp_scale_div))
		s.texture="ExplosionSplash";result.sprites.append(s)
	var craters:Array=params.get("crater_list",[])
	if not already and not craters.is_empty():
		var name=str(craters[posmod(crater_index,craters.size())])
		if textures.has(name):result.crater={"name":name,"position":logical,"scale":f32(float(params.get("crater_scale_factor",1))),"life":4000.0,"fade":4000.0,"fade_in":0.0}
	return result
# Newborn death bursts only: supplied original lifetimes, no existing smoke,
# child effects, rendering or whole original particle system equivalence.
static func burst_clocks(bindings:Dictionary,definitions:Dictionary) -> Array:
	var result=[];var aliases=bindings.keys();aliases.sort()
	for alias in aliases:
		if not "explosion" in str(alias):continue
		var name=str(bindings[alias].filename);var definition:Dictionary=definitions[name]
		result.append({"name":name,"life":f32(float(definition.life_cycle)),"clock":0.0,"active":int(definition.num_release)})
	return result
static func advance_newborn_tail(state:int,systems:Array,sprites:Array,dt:float) -> Dictionary:
	var result=tail(state,null,systems.map(func(s):return s.active),sprites,dt)
	var seconds=f32(f32(dt)*f32(.001))
	for system in systems:
		system.clock=f32(float(system.clock)+seconds)
		if float(system.clock)>=float(system.life):system.active=0
	return result

extends RefCounted
# Pure selected CPoisonBubble controller. All particle/texture/draw operations
# are adapters. Real owned-particle and Simulation joins are separate.
static func f32(value:float) -> float:return Vector2(value,0).x
static func interpolate(start:float,target:float,progress:float) -> float:
	var value=f32(f32(f32(target-start)*progress)+start)
	return minf(value,target) if start<target else maxf(value,target)
static func vector_interpolate(start:Vector2,target:Vector2,progress:float) -> Vector2:
	if progress<0:return start
	if progress>1:return target
	var inverse=f32(1.0-progress)
	return Vector2(f32(f32(float(start.x)*inverse)+f32(float(target.x)*progress)),f32(f32(float(start.y)*inverse)+f32(float(target.y)*progress)))
static func construct(resource:Dictionary,start:Vector2,target_id:int,follow_target:int,slow:bool,adapters:Dictionary,initial_target:Vector2=Vector2.ZERO) -> Dictionary:
	var height=adapters.parameter.call("tower_height")
	var launch=Vector2(start.x,f32(float(start.y)-f32(0 if height==null else int(height))))
	var target=adapters.lookup.call(target_id)
	var family="goo" if slow else "poison"
	var main:Dictionary=adapters.texture.call("sfx/"+family+"_bubble.png",Vector2i.ZERO,Vector2i(64,64),0x4c)
	var shadow:Dictionary=adapters.texture.call("sfx/"+family+"_bubble.png",Vector2i(66,27),Vector2i(20,16),0x50)
	main.size=Vector2i(16,16)
	var bubble={"def":resource,"pos":start,"launch":launch,"lift_target":Vector2(launch.x,f32(float(launch.y)-60.0)),"target":initial_target if target==null else target,"shadow":start,"shadow_origin":start,"age":0.0,"progress":0.0,"alpha":f32(.4),"active":1,"lifted":0,"follow_particles":1,"follow_target":follow_target,"target_id":target_id,"slow":slow,"main":main,"shadow_texture":shadow,"roots":[]}
	var prefix="GooBubble" if slow else "PoisonBubble"
	for suffix in ["Trail","Stars"]:
		var system:Dictionary=adapters.factory.call(prefix+suffix)
		if not system.is_empty():bubble.roots.append(system)
	return bubble
static func update(bubble:Dictionary,dt_ms:float,adapters:Dictionary,_argument_b:bool=false) -> void:
	var dt=f32(dt_ms)
	if int(bubble.active)&1:
		if int(bubble.follow_target)&1:
			var target=adapters.lookup.call(int(bubble.target_id))
			if target!=null:bubble.target=target
		if (int(bubble.lifted)&1)==0:
			bubble.age=f32(float(bubble.age)+f32(dt/500.0))
			bubble.progress=f32(float(bubble.progress)+f32(dt/f32(500.0+float(bubble.age))))
			bubble.pos=Vector2(bubble.pos.x,interpolate(float(bubble.launch.y),float(bubble.lift_target.y),float(bubble.progress)))
			var size=int(f32(16.0+f32(48.0*float(bubble.progress))))
			bubble.main.size=Vector2i(size,size)
			bubble.alpha=minf(1.0,f32(float(bubble.alpha)+float(bubble.progress)))
			if float(bubble.pos.y)<=float(bubble.lift_target.y):
				bubble.pos.y=bubble.lift_target.y;bubble.age=0.0;bubble.progress=0.0;bubble.lifted=1;bubble.main.size=Vector2i(64,64)
				bubble.shadow.y=f32(float(bubble.shadow_origin.y)+f32(f32(float(bubble.launch.y)-float(bubble.pos.y))*.5))
		else:
			bubble.progress=f32(float(bubble.progress)+f32(dt/600.0))
			bubble.pos=vector_interpolate(bubble.pos,bubble.target,float(bubble.progress))
			bubble.shadow=vector_interpolate(bubble.shadow,bubble.target,float(bubble.progress))
			var delta:Vector2=bubble.target-bubble.pos
			var distance=f32(sqrt(f32(f32(float(delta.x)*float(delta.x))+f32(float(delta.y)*float(delta.y)))))
			if absf(distance)<5.0 or float(bubble.progress)>=1.0:
				bubble.active=0
				for system in bubble.roots:system.rate=0
				var prefix="GooBubble" if bubble.slow else "PoisonBubble"
				var explosion:Dictionary=adapters.factory.call(prefix+"Explode")
				if not explosion.is_empty():
					for i in 6:adapters.advance.call(explosion,f32(.05))
					explosion.pos=Vector2(bubble.pos.x,f32(float(bubble.pos.y)-15.0));bubble.follow_particles=0;bubble.roots.append(explosion)
				var spray:Dictionary=adapters.factory.call(prefix+"ExplodeSpray")
				if not spray.is_empty():
					spray.pos=Vector2(bubble.pos.x,f32(float(bubble.pos.y)-5.0))
					for i in 6:adapters.advance.call(spray,f32(.05))
					bubble.roots.append(spray)
	var seconds=f32(dt*f32(.001))
	var i=0
	while i<bubble.roots.size():
		var system:Dictionary=bubble.roots[i]
		if int(system.active_count)>0 or int(system.first_release)&1 or float(system.disable_after_seconds)==0:
			if int(bubble.follow_particles)&1:system.pos=bubble.pos
			adapters.advance.call(system,seconds);i+=1
		else:
			adapters.destroy.call(system);bubble.roots.remove_at(i)
static func render(bubble:Dictionary,adapters:Dictionary) -> void:
	if int(bubble.active)&1:
		adapters.blend.call(1,0x303);adapters.color.call(float(bubble.alpha))
		var size:Vector2i=bubble.main.size
		adapters.quad.call(bubble.main,bubble.pos-Vector2(int(float(size.x)/2),int(float(size.y)/2)))
		var shadow:Vector2=bubble.shadow
		if (int(bubble.lifted)&1)==0:shadow=Vector2(bubble.shadow_origin.x,f32(float(bubble.shadow_origin.y)+f32(f32(float(bubble.launch.y)-float(bubble.pos.y))*.5)))
		size=bubble.shadow_texture.size
		adapters.quad.call(bubble.shadow_texture,shadow-Vector2(int(float(size.x)/2),int(float(size.y)/2)))
	for system in bubble.roots:adapters.particle_render.call(system)
static func destroy(bubble:Dictionary,adapters:Dictionary) -> void:
	for system in bubble.roots:adapters.destroy.call(system)
	bubble.roots.clear()
	for field in ["main","shadow_texture"]:
		if not bubble[field].is_empty():adapters.texture_destroy.call(bubble[field]);bubble[field]={}

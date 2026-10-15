extends RefCounted

# Original ProcessPortal0x7ee94; this helper alone does not implement the
# gate queue/path bridge. The visibility flag controls owned particles.
static func f32(value:float) -> float:return Vector2(value,0).x

static func create(base:Vector2,light:float=1,shadow_scale:float=1) -> Dictionary:
	return {"clock":0.0,"state":0,"particles_visible":true,"scale":base,"secondary_scale":base,"health_alpha":1.0,"shadow_scale":f32(shadow_scale),"anim_alpha":1.0,"anim_color":f32(light)}

static func can_enter(resource_type:int,creep_state:int,portal_state:int,target_matches:bool,progress:float,gate_type:int=0) -> bool:
	return gate_type==0 and resource_type==1 and creep_state not in [2,3,5] and portal_state==0 and target_matches and f32(progress)>=0.5 and f32(progress)<1

static func interpolate_ease(start:float,target:float,amount:float) -> float:
	if amount<=0:return start
	if amount>=1:return target
	var polynomial=f32(f32(amount*6)-15)
	polynomial=f32(f32(polynomial*amount)+10)
	polynomial=f32(f32(f32(polynomial*amount)*amount)*amount)
	var value=f32(start+f32(f32(target-start)*polynomial))
	return minf(value,target) if start<target else maxf(value,target)

static func advance(pose:Dictionary,elapsed_ms:float,base:Vector2,light:float,shadow_base:float) -> void:
	if pose.state==3:return
	if pose.state not in [1,2]:pose.health_alpha=1.0;return
	var entering=pose.state==1
	if not entering:pose.particles_visible=true
	pose.clock=f32(float(pose.clock)+f32(elapsed_ms))
	var fraction=f32(float(pose.clock)/300.0)
	var from=base if entering else Vector2.ZERO
	var to=Vector2.ZERO if entering else base
	pose.scale=Vector2(interpolate_ease(from.x,to.x,fraction),interpolate_ease(from.y,to.y,fraction))
	if entering and fraction>=0.5:pose.particles_visible=false
	if fraction>=1:
		pose.scale=to;fraction=1.0;pose.state=3 if entering else 0
	var alpha=f32(1-fraction) if entering else fraction
	pose.secondary_scale=pose.scale
	pose.health_alpha=alpha
	pose.shadow_scale=f32(f32(shadow_base)*alpha)
	pose.anim_alpha=alpha
	pose.anim_color=f32(f32(light)*alpha)

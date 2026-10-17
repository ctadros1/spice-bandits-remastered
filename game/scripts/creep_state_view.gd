extends RefCounted
## Full original SetState / SetHoverStateFromCreepState selected fields.
## Hover motion and the sound object's producer/backend are separate evidence.
static func f32(value:float) -> float:return Vector2(value,0).x
static func select_hover(actor:Dictionary,value:int) -> void:
	var idle=int(actor.get("hover_when_idle",0))!=0
	var moving=int(actor.get("hover_while_moving",0))!=0
	# Both configuration bytes clear leaves the existing active byte untouched.
	if not idle and not moving:return
	actor.hover_active=int((moving and value==0) or (idle and value in [1,4]))
static func initialize(actor:Dictionary) -> void:
	var params:Dictionary=actor.def.get("traits",{})
	actor.hover_when_idle=int(params.get("shouldHoverWhenIdle",0))
	actor.hover_while_moving=int(params.get("shouldHoverWhileMoving",0))
	actor.hover_active=0
	select_hover(actor,int(actor.get("state",0)))
static func change(actor:Dictionary,value:int,stop_sound:Callable=Callable()) -> void:
	var previous=int(actor.get("state",0))
	if previous!=value:
		if previous in [0,7] and value in [1,2,3,4,5,6]:
			var multiplier=f32(float(actor.get("smoke_idle_multiplier",0)))
			if multiplier>0 and actor.get("particle_roots",[]).any(func(sys):return str(sys.creep_alias)=="smoke"):
				actor.smoke_work_interval=f32(f32(float(actor.smoke_work_interval))*multiplier)
		if previous==4:
			# Supplied raw sound +0x16 flag. No live sound ownership is invented.
			var flags:Variant=actor.get("state_sound_flags")
			if flags!=null and (int(flags)&1)!=0 and stop_sound.is_valid():stop_sound.call()
		actor.state=value
	# Original tail-call executes even when the state byte did not change.
	select_hover(actor,value)

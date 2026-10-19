extends RefCounted
## Full original SetState / SetHoverStateFromCreepState selected fields.
## Hover tail matches supplied original movement/owner traces. Sound ownership
## and the complete Fly/portal/growth movement joins remain separate evidence.
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
static func advance_hover(actor:Dictionary,dt_ms:float) -> void:
	# Original movement tail: configuration bits, retained phase and primary
	# animator offset. It runs independently of walking/animation Freeze.
	if (int(actor.get("hover_when_idle",0))&1)==0 and (int(actor.get("hover_while_moving",0))&1)==0:return
	var previous=f32(float(actor.get("hover_phase",0)))
	if (int(actor.get("hover_active",0))&1)==0 and previous<=0:return
	var phase=f32(previous+f32(f32(dt_ms)/550.0))
	# The original wraps once, not with fmod, and retains a positive phase
	# after hover selection clears. Do not invent an immediate offset reset.
	if phase>=6.2831854820251465:phase=maxf(0,f32(phase-6.2831854820251465))
	var offset:Vector2
	if actor.has("animator_offset"):offset=actor.animator_offset
	else:
		var authored=actor.def.traits.get("offset",[0,0])
		offset=Vector2(authored[0],authored[1])
	var difference=f32(f32(sin(phase))-f32(sin(previous)))
	offset.y=f32(offset.y+f32(difference+difference))
	actor.hover_phase=phase;actor.animator_offset=offset
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

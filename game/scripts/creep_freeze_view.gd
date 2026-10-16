extends RefCounted
# Supplied-record original ProcessPlayers/FreezeCreeps/UseFreeze/ProcessFreeze.
# The remaining integer is the player's shared countdown, not an end timestamp.
static func f32(value:float) -> float:return Vector2(value,0).x
static func initial() -> Dictionary:return {"remaining":0,"room_active":false}
static func advance_timer(state:Dictionary,dt_ms:float) -> bool:
	state.room_active=int(state.remaining)>0
	if not state.room_active:return false
	state.remaining=maxi(0,int(f32(f32(float(state.remaining))-f32(dt_ms))))
	return int(state.remaining)==0
static func use_freeze(creep:Dictionary) -> void:
	if int(creep.get("state",0)) in [2,3]:return
	creep.freeze_attached=true
	if creep.get("freeze_auxiliary_present",false):creep.freeze_auxiliary_value=1
static func apply(creep:Dictionary,player:int) -> void:
	if int(creep.get("owner",0))!=player:use_freeze(creep)
static func process_creep(creep:Dictionary,remaining:int) -> void:
	if creep.get("freeze_attached",false):
		creep.freeze_remaining=remaining
		if remaining>0:return
		creep.freeze_attached=false
	else:creep.freeze_remaining=0
	if creep.get("freeze_auxiliary_present",false) and not creep.get("consumed_slow",false):creep.freeze_auxiliary_value=0
static func speed(base:float,first:float,second:float,pending:float,attached:bool) -> Dictionary:
	var current=f32(f32(f32(base)*f32(first))*f32(second))
	var slow=pending>0
	if slow:current=f32(current*f32(pending))
	return {"current":current,"divisor":f32(1000.0/current) if current!=0 else INF,"multiplier":0.0 if attached else 1.0,"pending":-1.0 if slow else pending,"consumed_slow":slow}

# Existing Simulation pre-movement fields, with exact script reference/fallback.
# Does not port additional original callers or change float/disco/hit ordering.
static func advance_fields(creep:Dictionary,dt_ms:float,remaining:int) -> void:
	if SpiceNative.advance_creep_fields(creep,dt_ms,remaining):return
	reference_fields(creep,dt_ms,remaining)
static func reference_fields(creep:Dictionary,dt_ms:float,remaining:int) -> void:
	creep.grow_ms=minf(400,f32(float(creep.grow_ms)+dt_ms))
	creep.slow=creep.slow_pending if creep.slow_pending>0 else 1.0
	creep.consumed_slow=creep.slow_pending>0
	if creep.consumed_slow and creep.get("freeze_auxiliary_present",false):creep.freeze_auxiliary_value=1
	creep.slow_pending=-1.0
	var current_speed=f32(float(creep.speed)*float(creep.slow))
	creep.animation_divisor=f32(1000.0/current_speed) if current_speed!=0 else INF
	creep.animation_multiplier=0.0 if creep.get("freeze_attached",false) else 1.0
	process_creep(creep,remaining)
	creep.poison_count=0
	creep.slow_count=0

extends RefCounted
static func f32(value:float) -> float:return Vector2(value,0).x
static func initial(delay:float=0,mode:int=0) -> Dictionary:
	return {"state":mode,"alpha":0.0,"open_phase":0.0,"delay":delay,"xp_phase":0.0,"medal_clock":0.0,"spice_phase":0.0}
static func advance(clock:Dictionary,dt_ms:float,win:bool=true) -> void:
	var dt=f32(dt_ms)
	if clock.state==0 or clock.state==2:
		clock.open_phase=f32(float(clock.open_phase)+f32(dt/700.0))
		clock.alpha=minf(clock.open_phase,1.0) if clock.state==0 else maxf(f32(1.0-clock.open_phase),0.0)
		if clock.state==0 and clock.alpha>=1.0:clock.state=1
		elif clock.state==2 and clock.alpha<=0.0:clock.state=3
	clock.delay=f32(float(clock.delay)+f32(dt*f32(0.001)))
	# The original ARM comparison is2 seconds. Decompiled NEON output
	# incorrectly describes this as a comparison with0; the probe executes it.
	if clock.state==1 and win and clock.delay>=2.0:
		clock.xp_phase=f32(float(clock.xp_phase)+f32(dt*f32(0.0005)))
		if clock.xp_phase>=1.5:
			clock.spice_phase=f32(float(clock.spice_phase)+f32(dt*f32(0.002)))
			if clock.spice_phase>=5.0:clock.medal_clock=f32(float(clock.medal_clock)+f32(dt*f32(0.001)))

extends RefCounted
static func f32(value:float) -> float:return Vector2(value,0).x
static func initial(count:int,speed:float,loop:bool=true,multiplier:float=1,divisor:float=1) -> Dictionary:
	return {"count":count,"speed":speed,"loop":loop,"multiplier":multiplier,"divisor":divisor,"frame":0,"phase":0.0,"stopped":false}
static func advance(state:Dictionary,dt_ms:float) -> void:
	if state.count<2:state.frame=0;state.stopped=true;return
	if state.stopped:return
	var rate=f32(f32(float(state.speed)/float(state.divisor))*float(state.multiplier))
	state.phase=f32(float(state.phase)+f32(f32(f32(dt_ms)/1000.0)*rate))
	state.frame=int(state.phase)
	if state.frame>=state.count:
		state.frame=0 if state.loop else state.count-1
		state.stopped=not state.loop;state.phase=0.0
static func tint(valid:bool) -> Color:
	return Color(1,1,1,0.5) if valid else Color(1,0.3,0.3,0.6)

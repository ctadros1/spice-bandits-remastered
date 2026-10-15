extends RefCounted
var states=[]
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]
static func initial() -> Dictionary:
	return {"phase":0.0,"index":0,"from":0,"to":1,"stopped":false,"initialized":false}
static func linear(a:float,b:float,t:float) -> float:
	var value=f32(f32(f32(b-a)*t)+a)
	if a<b and value>b:return b
	if b<a and value<b:return b
	return value
static func ease_interpolate(a:float,b:float,t:float) -> float:
	var x=f32(f32(t*6)-15)
	x=f32(f32(x*t)+10)
	x=f32(x*t);x=f32(x*t);x=f32(x*t)
	return linear(a,b,x)
static func advance(state:Dictionary,definition:Dictionary,dt_ms:float) -> Dictionary:
	var position=Vector2(int(definition.x),int(definition.y));var angle=0.0
	var frames=definition.frames
	if state.stopped or frames.size()<2:return {"position":position,"angle":angle}
	if not state.initialized:
		state.from=0;state.to=1;state.index=1;state.initialized=true
	state.phase=f32(state.phase+f32(clampf(f32(float(definition.get("anim_speed",0))),0,5)*f32(dt_ms)))
	var a=frames[int(state.from)];var b=frames[int(state.to)]
	var smooth=bool(definition.get("anim_ease",0))
	var x=ease_interpolate(f32(a.pos[0]),f32(b.pos[0]),state.phase) if smooth else linear(f32(a.pos[0]),f32(b.pos[0]),state.phase)
	var y=ease_interpolate(f32(a.pos[1]),f32(b.pos[1]),state.phase) if smooth else linear(f32(a.pos[1]),f32(b.pos[1]),state.phase)
	angle=ease_interpolate(f32(a.angle),f32(b.angle),state.phase) if smooth else linear(f32(a.angle),f32(b.angle),state.phase)
	position=Vector2(f32(position.x+x),f32(position.y+y))
	if state.phase>=1:
		var next=int(state.index)+1
		if next<frames.size():state.from=state.index;state.to=next;state.index=next;state.phase=0.0
		elif not bool(definition.get("anim_loop",0)):state.stopped=true
		else:state.from=frames.size()-1;state.to=0;state.index=0;state.phase=0.0
	return {"position":position,"angle":angle}
func reset() -> void:states.clear()
func poses(definitions:Array,dt_ms:float) -> Array:
	while states.size()<definitions.size():states.append(initial())
	var result=[]
	for i in range(definitions.size()):result.append(advance(states[i],definitions[i],dt_ms))
	return result

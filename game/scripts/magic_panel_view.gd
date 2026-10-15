extends RefCounted

static func f32(value:float) -> float:return Vector2(value,0).x
static func body_height(count:int) -> int:
	# UpdateItems0x97628 deduplicates refill offers by tag, then uses
	# ceil(items/2)*65+65+5. The constructor's335 is replaced on Open.
	return int(ceil(count/2.0))*65+70
static func initial(height:float=768,panel_height:int=265) -> Dictionary:
	return {"y":height-61,"height":panel_height,"phase":0.0,"visible":false,"opening":false,"closing":false,"opened":false,"hidden":true}
static func open(state:Dictionary) -> void:
	state.opening=true;state.visible=true;state.closing=false
static func close(state:Dictionary) -> void:
	state.closing=true;state.opened=false
static func slide_ease(a:float,b:float,t:float) -> float:
	var value=f32(f32(t*6)-15)
	value=f32(f32(value*t)+10)
	for i in range(3):value=f32(value*t)
	value=f32(a+f32(f32(b-a)*value))
	return minf(value,b) if a<b else maxf(value,b)
static func advance(state:Dictionary,dt_ms:float,height:float=768) -> void:
	var bottom=height-61;var top=bottom-int(state.height)
	if state.opening and state.hidden:
		state.phase=f32(float(state.phase)+f32(f32(dt_ms)/500))
		state.y=slide_ease(bottom,top,state.phase)
		if state.y<=top:
			state.merge({"phase":0.0,"y":top,"hidden":false,"opening":false,"opened":true},true)
	if state.closing and not state.hidden:
		state.phase=f32(float(state.phase)+f32(f32(dt_ms)/500))
		state.y=slide_ease(top,bottom,state.phase)
		if state.y>=bottom:
			state.merge({"phase":0.0,"y":bottom,"hidden":true,"closing":false,"visible":false},true)

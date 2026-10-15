extends RefCounted
const FrameClock=preload("res://scripts/tower_preview_view.gd")
static func f32(value:float) -> float:return Vector2(value,0).x
static func initial(count:int=0,speed:float=1,loop:bool=false,multiplier:float=1,divisor:float=1) -> Dictionary:
	var value=FrameClock.initial(count,speed,loop,multiplier,divisor)
	value.merge({"name":"","alpha_from":0.0,"alpha_to":1.0,"alpha_start":0,"alpha_now":0,"alpha_color":Color.WHITE,"reset_on_change":false})
	return value
static func play(state:Dictionary,name:String,definition:Dictionary) -> void:
	if name==state.name and not name.is_empty():state.stopped=false;return
	if definition.is_empty():return
	state.name=name;state.alpha_start=0;state.alpha_now=0;state.stopped=false
	var frames=definition.get("resolved_frames",definition.get("added_frames",[]))
	state.count=maxi(1,frames.size() if not frames.is_empty() else int(definition.get("frames",1)))
	state.speed=f32(float(definition.get("speed",1)));state.loop=bool(definition.get("loop",false))
	if state.reset_on_change:state.frame=0;state.phase=0.0
	state.alpha_from=f32(float(definition.get("alpha_anim_from",0)));state.alpha_to=f32(float(definition.get("alpha_anim_to",1)))
static func advance(state:Dictionary,dt_ms:float,now_ms:int,alpha_animation:bool=false,stop_all:bool=false) -> void:
	if stop_all:return
	if not alpha_animation:FrameClock.advance(state,dt_ms);return
	if state.alpha_start==0:state.alpha_start=now_ms
	state.alpha_now=now_ms
	var elapsed=f32(float(now_ms-int(state.alpha_start)))
	var amount=f32(elapsed/f32(1000.0/float(state.speed)))
	var a=float(state.alpha_from);var b=float(state.alpha_to)
	var value=f32(a+f32(f32(b-a)*amount))
	if a<b and value>b:value=b
	if b<a and value<b:value=b
	if a<b and value>=1:
		if not state.loop:state.stopped=true;value=1.0
		else:state.alpha_start=0;state.alpha_from=1.0;state.alpha_to=0.0;value=1.0
	elif b<a and value<=0:
		if not state.loop:state.stopped=true;value=0.0
		else:state.alpha_start=0;state.alpha_from=0.0;state.alpha_to=1.0;value=0.0
	state.alpha_color=Color(value,value,value,value)
static func offset(group:Vector2,frame:Vector2,size:Vector2) -> Vector2:
	return Vector2(f32(f32(group.x+frame.x)+(0.5 if int(size.x)%2!=0 else 0.0)),f32(f32(group.y+frame.y)+(0.5 if int(size.y)%2!=0 else 0.0)))
static func render_frames(frame:int,phase:float,keys:Array,interpolate:bool,alpha:float=1,color:float=1,caller:Color=Color.WHITE) -> Array:
	if keys.is_empty() or frame<0 or frame>=keys.size():return []
	if not interpolate:return [{"frame":frame,"color":caller if alpha==1 else Color(color,color,color,alpha)}]
	var next=frame+1
	if next>=keys.size():next=0
	if keys[frame]==keys[next]:return [{"frame":frame,"color":Color.WHITE}]
	var fraction=f32(f32(phase)-float(frame))
	var doubled=0.0 if fraction>1 else f32(fraction+fraction)
	var a=f32(1-clampf(f32(doubled-1),0,1));var b=minf(1,doubled)
	return [{"frame":frame,"color":Color(a,a,a,a)},{"frame":next,"color":Color(b,b,b,b)}]
static func straight(color:Color) -> Color:
	# Original fixed-function GL clamps color arguments before modulating
	# premultiplied textures. Godot imports their straight RGBA counterparts.
	var alpha=clampf(color.a,0,1)
	return Color(clampf(color.r,0,1)/alpha,clampf(color.g,0,1)/alpha,clampf(color.b,0,1)/alpha,alpha) if alpha>0 else Color(1,1,1,0)

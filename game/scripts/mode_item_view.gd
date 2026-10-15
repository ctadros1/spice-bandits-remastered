extends RefCounted
const TITLE_SIZE=28
const PLAYER_COUNT_SIZE=14
const CAPTION_SIZE=16
const SHADOW_BLUR=7
const SHADOW_INTENSITY=7
static func title_ink(mode:int,alpha:float) -> Color:
	if mode==1:return Color(1,1,1,f32(alpha*f32(.7)))
	if mode==3:return Color(0,0.4156000018119812,0.6116999983787537,alpha)
	return Color(f32(f32(.9330000281333923)*alpha),f32(f32(.5058000087738037)*alpha),0,alpha)
static func shadow_ink(mode:int,alpha:float) -> Color:
	return Color(0,0,0,f32(alpha*f32(.7))) if mode==1 else Color(alpha,alpha,alpha,alpha)
static func caption_ink(alpha:float) -> Color:return Color(0.5839999914169312,0.7019000053405762,0.7490000128746033,alpha)
static func f32(value:float) -> float:return Vector2(value,0).x
static func count_pose(point:Vector2,mode:int,star:bool,title_width:float) -> Dictionary:
	var x=f32(f32(point.x+55)+f32(title_width+5))
	var y=f32(point.y-11)
	var text_x=f32(x+(24 if mode==3 and star else 0))
	# Completed stars shift count ink; the original count underlay retains
	# its earlier x coordinate. Keep that asymmetry in the bounded port.
	return {"players":Vector2(text_x,y),"online":Vector2(text_x,f32(y+12)),"players_shadow":Vector2(x,y),"online_shadow":Vector2(x,f32(y+12))}
static func native_ease(t:float) -> float:
	var value=f32(f32(t*6)-15);value=f32(f32(value*t)+10)
	for i in range(3):value=f32(value*t)
	return value
static func initial(opened:bool=true) -> Dictionary:
	return {"phase":0.0,"geometry_alpha":0.0,"pulse_alpha":0.0,"flash_ms":0.0,"text_phase":0.0,"text_alpha":0.0,"opened":opened,"x":0.0,"y":0.0}
static func advance(state:Dictionary,dt_ms:float,origin:Vector2,offset:Vector2) -> void:
	var dt=f32(dt_ms);var amount=f32(dt/300.0)
	state.phase=f32(float(state.phase)+amount)
	if state.phase>=1.0:state.phase=1.0;state.flash_ms=f32(float(state.flash_ms)+dt)
	elif state.phase<0.0:state.phase=0.0
	var blend=native_ease(state.phase)
	state.geometry_alpha=blend if state.opened else f32(1.0-blend)
	var a=origin if state.opened else origin+offset;var b=origin+offset if state.opened else origin
	state.x=f32(a.x+f32(f32(b.x-a.x)*blend));state.y=f32(a.y+f32(f32(b.y-a.y)*blend))
	if not state.opened or state.phase==1.0:
		state.text_phase=minf(f32(float(state.text_phase)+amount),1.0)
		state.text_alpha=native_ease(state.text_phase) if state.opened else maxf(f32(1.0-native_ease(state.text_phase)),0.0)
	var pulse=1.0
	if state.phase==1.0:
		var angle=f32(f32(f32(float(state.flash_ms)/1000.0)*20.0)*PI*2.0)
		pulse=f32(f32(sin(angle))+1.0)
	state.pulse_alpha=clampf(f32(float(state.text_alpha)+f32(pulse/-40.0)),0.0,1.0)

static func render_pose(state:Dictionary,point:Vector2,mode:int,star:bool=false) -> Dictionary:
	# CLevelItem::Render0x8621c. Each atlas entry keeps its native bounds;
	# the plate's width expansion is an authored animation, with full UVs.
	return {"plate_rect":Rect2(point-Vector2(35,35),Vector2(f32(364.0*float(state.text_alpha)),98)),
		"plate_visible":state.phase>=1.0 or not state.opened,"plate_alpha":state.pulse_alpha,
		"plate_region":Rect2(0,0 if mode==1 else 196 if mode==2 else 98,364,98),
		"circle_rect":Rect2(point-Vector2(20,20),Vector2(71,71)),"circle_alpha":state.geometry_alpha,
		"circle_region":Rect2(364,0 if mode==1 else 71 if mode==2 else 142,71,71),
		"icon_rect":Rect2(point-Vector2(14,14),Vector2(58,58)),"icon_alpha":f32(float(state.geometry_alpha)*(.5 if mode==1 else 1.0)),
		"title_point":point+Vector2(55+(24 if star and mode==3 else 0),-11),
		"subtitle_point":point+Vector2(55,12),"star_rect":Rect2(point+Vector2(49,-16),Vector2(32,32)),
		"title_alpha":f32(float(state.text_alpha)*f32(.7)) if mode==1 else state.text_alpha,
		"subtitle_alpha":state.text_alpha}

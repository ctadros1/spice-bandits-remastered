extends RefCounted

# CLevelUpScreen::Update0xa55bc/Close0xa5760, tablet branch. Opening stays
# flagged after reaching1; Close resets phase and the next frame fades from1.
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]
static func initial() -> Dictionary:
	return {"visible":false,"can_close":true,"opening":true,"closing":false,"finished":false,"alpha":0.0,"phase":0.0}
static func close(state:Dictionary) -> bool:
	if state.closing or not state.can_close:return false
	state.closing=true;state.can_close=false;state.opening=false;state.phase=0.0
	return true
static func advance(state:Dictionary,dt_ms:float) -> void:
	var dt=f32(dt_ms)
	if state.opening:
		state.visible=true
		state.phase=f32(state.phase+f32(dt/700.0))
		state.alpha=minf(state.phase,1.0)
	if state.closing:
		state.phase=f32(state.phase+f32(dt/700.0))
		state.alpha=maxf(f32(1.0-state.phase),0.0)
		if state.alpha<=0.0:state.visible=false;state.finished=true
static func origin(size:Vector2) -> Vector2:
	return Vector2(int(size.x)/2-323,int(size.y)/2-264).floor()
static func positions(size:Vector2,title_width:float) -> Dictionary:
	var point=origin(size)
	return {"frame1":point,"frame2":point+Vector2(512,0),"frame3":point+Vector2(640,0),
		"shadow1":point+Vector2(0,512),"shadow2":point+Vector2(512,512),
		"title":Vector2(int(f32(f32(int(size.x)/2)-f32(title_width*0.5))),point.y+197),
		"description":point+Vector2(90,246),"spice":point+Vector2(105,278),
		"upgrade_label":point+Vector2(105,305),"new_stuff":point+Vector2(90,337)}
static func rank_rect() -> Rect2:
	# Open0xa57a0 declares128x128 at425,187 relative to the frame origin.
	return Rect2(425,187,128,128)
static func observed_rank(level:int) -> String:
	# The first promotion badge is visible in the main recording. Later
	# server rank_short payloads are missing; do not invent their thresholds.
	return "assets/cdt.png" if level==1 else "assets/2lt.png" if level==2 else ""
static func rank_name(level:int) -> String:
	return "Cadet" if level==1 else "2nd Lieutenant" if level==2 else "Level %d"%level

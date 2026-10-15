extends RefCounted
static func f32(value:float) -> float:return Vector2(value,0).x
static func initial() -> Dictionary:return {"alpha":0.0,"previous_ms":0.0,"opaque":false}
static func advance_in(state:Dictionary,dt_ms:float) -> void:
	# CTutorialPage::Update0xb30e8 intentionally uses the previous frame.
	if not state.opaque:
		state.alpha=f32(float(state.alpha)+f32(float(state.previous_ms)/400.0))
		if state.alpha>=1.0:state.alpha=1.0;state.opaque=true
	state.previous_ms=f32(dt_ms)
static func advance_out(state:Dictionary) -> bool:
	# CTutorialInterface::Update0xb7c98 uses the just-stored elapsed time.
	state.opaque=true
	state.alpha=maxf(f32(float(state.alpha)+f32(float(state.previous_ms)/-400.0)),0.0)
	return state.alpha<=0.0

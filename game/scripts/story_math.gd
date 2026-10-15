extends RefCounted

static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

static func interpolate(a:float,b:float,factor:float) -> float:
	var value=f32(a+f32(f32(b-a)*factor))
	return minf(value,b) if a<b else maxf(value,b) if b<a else value

static func position(start:Vector2,end:Vector2,factor:float) -> Vector2:
	if factor<0:return start
	if factor>1:return end
	var inverse=f32(1-factor)
	return Vector2(f32(f32(start.x*inverse)+f32(end.x*factor)),f32(f32(start.y*inverse)+f32(end.y*factor)))

static func advance(node:Dictionary,dt_ms:float) -> void:
	# CStoryScreen::Node::Render0xb1964, including the immediate change
	# to the fading-out half when the fading-in alpha reaches one.
	node.phase=f32(float(node.phase)+f32(f32(dt_ms)*0.0020000000949949026))
	if node.fade_in:
		node.alpha=interpolate(float(node.initial_alpha),1,float(node.phase))
		node.position=position(node.start,node.end,f32(float(node.phase)*0.5))
		if node.alpha<1:return
		node.alpha=1.0;node.fade_in=false;node.phase=0.0;node.initial_alpha=1.0
	node.alpha=interpolate(float(node.initial_alpha),0,float(node.phase))
	node.position=position(node.start,node.end,f32(f32(float(node.phase)*0.5)+0.5))
	if node.alpha<=0:
		node.alpha=0.0;node.phase=0.0;node.initial_alpha=0.0;node.finished=true

extends RefCounted

# CCreep::Render0x7f5c8, independently executed in the health fixture.
# RGBA is premultiplied in the original; Godot's decoded straight-alpha
# textures use white RGB and the same opacity at submission.
static func f32(value:float) -> float:return Vector2(value,0).x

static func layout(point:Vector2,hp:float,maximum:int,alpha:float,state:int=0,dimensions:Vector2=Vector2(32,16),uv:Vector4=Vector4(0,1,0,1)) -> Dictionary:
	if not f32(hp)<f32(maximum) or state==2 or state==3:return {}
	var ratio=maxf(0,f32(f32(hp)/f32(maximum))) if maximum!=0 else 0.0
	var origin=point+Vector2(-16,16)
	var width=f32(dimensions.x*ratio)
	var right=f32(f32(uv.x*f32(1-ratio))+f32(uv.y*ratio))
	alpha=f32(alpha)
	return {"origin":origin,"ratio":ratio,"fill":Rect2(origin,Vector2(width,dimensions.y)),"source":Rect2(0,0,width,dimensions.y),"uv":Vector4(uv.x,uv.z,right,uv.w),"premultiplied":Color(alpha,alpha,alpha,alpha),"color":Color(1,1,1,alpha)}

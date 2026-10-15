extends RefCounted
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]
static func advance(alpha:float,dt:float,closing:bool=false) -> float:
	var change=f32(f32(dt)*3.5)
	return clampf(f32(f32(alpha)-change if closing else f32(alpha)+change),0,1)
static func button_enabled(alpha:float) -> bool:return f32(alpha)>f32(0.2)
static func background(size:Vector2) -> Rect2:
	return Rect2(Vector2(int((size.x-512)/2),int((size.y-512)/2)),Vector2(512,512))
static func text_position(size:Vector2,width:float,title:bool=false) -> Vector2:
	return Vector2(int(f32(f32(size.x-width)*0.5)),int(f32(f32((size.y-512)*0.5)+(205 if title else 240))))
static func button(size:Vector2,index:int) -> Dictionary:
	var center=size/2+Vector2(-85 if index==0 else 85,100)
	var sprite=Rect2(center-Vector2(128,64),Vector2(256,128))
	return {"sprite":sprite,"hit":Rect2(sprite.position+Vector2(50,40),Vector2(156,48)),"text_y":center.y-8,"center_x":center.x}

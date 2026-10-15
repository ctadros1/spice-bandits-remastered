extends RefCounted
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]
# CLobby::LoadMap0x8dcbc passes tablet CMap(minZoom0.25,maxZoom1,500).
# CMap::BoundOffset0x1081d8, for the full4096x3072 lobby with zero offsets.
static func bound_origin(origin:Vector2,zoom:float,size:Vector2) -> Vector2:
	var width=int(f32(4096*f32(zoom)));var height=int(f32(3072*f32(zoom)))
	var point=origin
	point.x=maxf(minf(point.x,0),size.x-width)
	point.y=maxf(minf(point.y,0),size.y-height)
	if width<size.x:point.x=float(int((size.x-width)/2))
	if height<size.y:point.y=float(int((size.y-height)/2))
	return point

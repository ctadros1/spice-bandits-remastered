extends RefCounted

static func sample(current:Variant,target:Variant,progress:float,previous:float=1) -> float:
	# Original GetCell null handling; a valid CHexCell defaults its light to1.
	if current==null:return Vector2(previous,0).x
	var a=Vector2(float(current.get("l",1)),0).x
	if target==null:return a
	return SpiceNative.creep_light(a,float(target.get("l",1)),progress)

static func cell(map:Dictionary,point:Vector2i) -> Variant:
	if point.x<0 or point.y<0 or point.x>=int(map.hex_width) or point.y>=int(map.hex_height):return null
	var index=point.y*int(map.hex_width)+point.x
	return map.cells[index] if index<map.cells.size() else null

static func from_map(map:Dictionary,current:Vector2i,target:Vector2i,progress:float,previous:float=1) -> float:
	return sample(cell(map,current),cell(map,target),progress,previous)

static func body_color(native_air:bool,light:float,alpha:float=1) -> Color:
	var value=1.0 if native_air else Vector2(light,0).x
	return Color(value,value,value,alpha)

extends RefCounted
static func tablet(index:int) -> Dictionary:
	var mirrored=index%5>2
	return {"position":Vector2((index%5)*150,int(index/5)*137),"mirrored":mirrored,"panel_x":5-321 if mirrored else 5,"name_x":171-455 if mirrored else 171,"cost_x":400-455 if mirrored else 400,"description_x":171-455 if mirrored else 171}

static func selection_scroll(row:float,offset:float,height:float) -> float:
	if row<offset:offset=row
	var span=height-210.0-187.0
	if offset+span<row:offset=row-span
	return offset

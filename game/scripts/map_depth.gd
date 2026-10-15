extends RefCounted

static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

static func tower_height(resource:Dictionary) -> float:
	var states=resource.get("states",{})
	var state=states.get("Rot",states.get("Idle",{}))
	var source=resource.get("resources",{}).get(str(int(state.get("res_id",1))),{})
	# CAnimFrames0x10e424 keeps the resource's untrimmed frame height at
	# +0x48. CTower0xe2e3c copies it once; a supplied integer depth_pos wins.
	return f32(int(resource.params.depth_pos)) if resource.get("params",{}).has("depth_pos") else f32(float(source.get("frame_height",0)))

static func top(center_y:float,height:float,offset:float=-7.0) -> int:
	# SetPosition0xe4228 truncates toward zero after separate float32 steps.
	return int(f32(f32(f32(center_y)+f32(offset))+f32(f32(height)*-0.5)))

static func key(depth_top:int,height:float) -> float:
	# CMap::objectSorting0x103650 compares these float32 sums strictly.
	return f32(f32(depth_top)+f32(height))

static func tower(center_y:float,resource:Dictionary) -> float:
	var height=tower_height(resource)
	return key(top(center_y,height),height)

static func base_height(resource:Dictionary) -> float:
	# CBase0x7595e retains Idle-100's untrimmed height before depth_pos.
	var state=resource.get("states",{}).get("Idle-100",{})
	var source=resource.get("resources",{}).get(str(int(state.get("res_id",1))),{})
	return f32(int(resource.params.depth_pos)) if resource.get("params",{}).has("depth_pos") else f32(float(source.get("frame_height",0)))

static func base(center_y:float,resource:Dictionary) -> float:
	var height=base_height(resource)
	# SetInitPosition0x75fe0 leaves the visible animator at the cell center.
	return key(top(center_y,height,0),height)

static func creep_height(resource:Dictionary) -> float:
	# CCreep ctor plays RunDownRight before retaining its untrimmed height.
	var state=resource.get("states",{}).get("RunDownRight",{})
	var source=resource.get("resources",{}).get(str(int(state.get("res_id",1))),{})
	return f32(int(resource.params.depth_pos)) if resource.get("params",{}).has("depth_pos") else f32(float(source.get("frame_height",0)))

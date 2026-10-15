extends RefCounted
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]
# MenuBottomView::updateUserInfo0x512a8 rounds all three service values
# separately. Its disassembly applies a minimum5% bar width above level1.
static func footer(xp:float,remaining:float,lower:float,level:int,width:float) -> Dictionary:
	var current=int(roundf(f32(xp)));var to_next=int(roundf(f32(remaining)));var previous=int(roundf(f32(lower)))
	var upper=current+to_next
	var denominator=f32(float(upper-previous))
	if denominator==0:denominator=1.0
	var fraction=maxf(0,f32(float(current-previous)/denominator))
	if fraction>denominator:fraction=denominator
	var fill=f32(f32(width)*fraction)
	if level>1:fill=maxf(fill,f32(f32(width)*f32(0.05)))
	return {"current":current,"upper":upper,"width":minf(f32(width),fill),"promotion_hidden":to_next>0}

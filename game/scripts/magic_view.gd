extends RefCounted

static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

# Native premultiplied OpenGL modulation converted for decoded straight-alpha
# textures. Keep RGB/alpha separate: portal previews use(1,1,1,0.5).
static func straight(color:Color) -> Color:
	if color.a<=0:return Color.TRANSPARENT
	return Color(color.r/color.a,color.g/color.a,color.b/color.a,color.a)

static func mine(position:Vector2,active:bool,state:int,remaining:int,sleep:int,light:float) -> Dictionary:
	var sprites=[];var bars=[]
	if state==1:return {"sprites":sprites,"bars":bars}
	var gain=f32(light)
	var alpha=1.0
	if not active or remaining>0:gain=f32(gain*0.5);alpha=0.5
	var color=Color(gain,gain,gain,alpha)
	sprites.append({"key":"body","color":color})
	if active:
		if state==2:sprites.append({"key":"lights","color":color})
		if remaining>0:
			var point=position+Vector2(-26,20)
			bars.append({"rect":Rect2(point,Vector2(52,3)),"color":Color(0,0,0,f32(0.4))})
			var width=f32(f32(1-f32(float(remaining)/float(sleep)))*52)
			bars.append({"rect":Rect2(point,Vector2(width,3)),"color":Color(0,0,0,f32(0.6))})
	return {"sprites":sprites,"bars":bars}

static func portal(active:bool,state:int) -> Array:
	return [] if state==3 else [{"key":"body","color":Color(1,1,1,1 if active else 0.5)}]

# CMap::CanMineBeBuildableInPlace0x103b80. Runtime ownership and map-object
# identity reconstruction are separate from these explicit cell flags.
static func mine_allowed(within:bool,buildable:bool,walkable:bool,owner:int=0,player:int=1) -> bool:
	return within and (owner==0 or owner==player) and buildable and walkable

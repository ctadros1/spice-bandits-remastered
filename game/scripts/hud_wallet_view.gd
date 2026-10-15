extends RefCounted

const MONEY_SIZE=25
const SPICE_SIZE=15
const XP_SIZE=12
const MONEY_SHADOW_OFFSET=Vector2(0,-1)
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

static func money_position(width:float,money_width:float,spice_width:float,phone:bool=false) -> Vector2:
	var x=f32(width-(130.0 if phone else 160.0))
	x=f32(x-spice_width);x=f32(x-(5.0 if phone else 6.0));x=f32(x-money_width)
	return Vector2(x,1.0 if phone else 3.0)

static func plate_position(width:float,money_width:float,spice_width:float) -> Vector2:
	var minimum=57.0 if money_width<=57.0 else float(int(money_width))
	var offset=int(f32(minimum-money_width))
	var x=int(f32(f32(money_position(width,money_width,spice_width).x-30.0)-offset))
	return Vector2(maxi(x,int(width)-400),0)

static func flash_initial() -> Dictionary:return {"active":false,"age_ms":0.0}
static func flash_request(state:Dictionary) -> void:state.active=true
static func flash_advance(state:Dictionary,dt_ms:float) -> void:
	if state.active:
		state.age_ms=f32(float(state.age_ms)+f32(dt_ms))
		if state.age_ms>=2000.0:state.active=false;state.age_ms=0.0
static func flash_color(state:Dictionary) -> Color:
	var factor=1.0
	if state.active:factor=f32(f32(f32(cos(f32(float(state.age_ms)/f32(67.04660034179688))))+1.0)*.5)
	return Color(1,factor,factor,f32(.8))

static func spice_text(value:int) -> String:
	var amount=f32(value)
	if amount<1000:return "%dsp"%int(amount)
	var thousands=f32(amount/1000.0)
	return "%4.1fk sp"%thousands if amount<10000 else "%dk sp"%int(thousands)

static func xp_pose(width:float,xp:float,remaining:float,lower:int,level:int,text_width:float,phone:bool=false) -> Dictionary:
	var total=f32(f32(xp+remaining)-lower)
	if total==0:total=1.0
	var phase=clampf(f32(f32(xp-lower)/total),0,1)
	if level>1:phase=maxf(phase,f32(0.05))
	return {"frame":Rect2(width-(116 if phone else 147),0,80,17),"fill":Rect2(width-(111 if phone else 140),4 if phone else 5,f32(66*phase),7),"text":Vector2(int(width)-int(f32(text_width*0.5))-(81 if phone else 106),11 if phone else 15)}

static func pose(width:float,font:Font,money:int,spice:int) -> Dictionary:
	var cash="$%d"%money
	var balance=spice_text(spice)
	var money_width=f32(font.get_string_size(cash,HORIZONTAL_ALIGNMENT_LEFT,-1,MONEY_SIZE).x)
	var spice_width=f32(font.get_string_size(balance,HORIZONTAL_ALIGNMENT_LEFT,-1,SPICE_SIZE).x)
	return {"money":cash,"spice":balance,"money_position":money_position(width,money_width,spice_width),"spice_position":Vector2(f32(f32(width-160)-spice_width),2),"plate_position":plate_position(width,money_width,spice_width)}

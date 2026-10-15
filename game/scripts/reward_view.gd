extends RefCounted
static func f32(value:float) -> float:return Vector2(value,0).x
static func spice(content:Vector2,quad:Vector2,phase:float,origin:Vector2,color_alpha:float=1,screen_alpha:float=1) -> Dictionary:
	var point=origin+Vector2(332,295)
	var shape=quad
	var alpha=f32(color_alpha*screen_alpha)
	if phase<1:
		var amount=minf(f32(phase),1)
		var remaining=f32(1-amount)
		var growth=Vector2(f32(f32(quad.x*remaining)*f32(0.2)),f32(f32(quad.y*remaining)*f32(0.2)))
		shape=Vector2(f32(quad.x+growth.x),f32(quad.y+growth.y))
		point=Vector2(f32(f32(point.x-f32(growth.x*0.5))+f32(f32(f32(quad.x*0.5)-f32(content.x*0.5))*f32(growth.x/quad.x))),f32(f32(point.y-f32(growth.y*0.5))+f32(f32(f32(quad.y*0.5)-f32(content.y*0.5))*f32(growth.y/quad.y))))
		# This entering branch uses the text color alpha alone. The completed
		# branch multiplies by the screen alpha in the original instructions.
		alpha=f32(color_alpha*amount)
	return {"point":point,"quad":shape,"scale":shape/quad,"alpha":alpha}

static func text_quad(content:Vector2) -> Vector2:
	# Texture2D(Text) rounds the UIKit content to power-of-two backing sizes.
	# The current font renderer supplies content metrics; its raster differs.
	var quad=Vector2.ONE
	while quad.x<content.x:quad.x*=2
	while quad.y<content.y:quad.y*=2
	return quad

static func burst_radius(value:int) -> float:return f32(f32(f32(float(value))*f32(0.0000000004656612873077392578125))*7)

static func spice_burst_point(content:Vector2,index:int,origin:Vector2,vector:Vector2,radius:float) -> Vector2:
	var offset=Vector2(f32(vector.x*radius),f32(vector.y*radius))
	return Vector2(f32(f32(f32(origin.x+332)+f32(f32(content.x/6)*float(index)))+offset.x),f32(f32(f32(origin.y+295)+f32(content.y*0.5))+offset.y))

static func medal(source:Vector2,index:int,slot:int,fraction:float,origin:Vector2,alpha:float=1) -> Dictionary:
	var point=origin+Vector2(295+39*index,378)
	var extra=Vector2.ZERO
	var opacity=alpha
	if index==slot:
		extra=Vector2(int(f32(f32(source.x*f32(1-fraction))*f32(0.3))),int(f32(f32(source.y*f32(1-fraction))*f32(0.3))))
		point-=extra*0.5;opacity=f32(alpha*fraction)
	var shape=Vector2(int(f32(f32(source.x*f32(0.8))+extra.x)),int(f32(f32(source.y*f32(0.8))+extra.y)))
	return {"rect":Rect2(point,shape),"alpha":opacity if index<=slot else 0.0,"burst":index<slot or (index==slot and fraction>=1),"burst_point":Vector2(f32(point.x+f32(source.x*f32(0.4))),f32(point.y+f32(source.y*f32(0.4))))}
static func medal_clock(clock:float) -> Dictionary:
	var slot=int(f32(clock/1.5))
	return {"slot":slot,"fraction":minf(1,f32(f32(clock-f32(float(slot)*1.5))*2))}
static func burst_definition(original:Dictionary,speed:float=1) -> Dictionary:
	var definition=original.duplicate(true)
	# compile_particle caches integration coefficients by name/hash. These
	# immutable release overrides need a distinct runtime coefficient key;
	# varying birth velocity is read directly by Emit, never from that cache.
	definition.name=str(original.name)+"::WinLoseRender"
	definition.release_interval=5.0
	definition.velocity=[f32(float(original.velocity[0])*speed),f32(float(original.velocity[1])*speed)]
	definition.circle_vel_amount=f32(float(original.circle_vel_amount)*speed)
	return definition

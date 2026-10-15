extends RefCounted
const GENERATORS=[
	{"position":[304,2466],"radius":200,"color_gain":1.0},
	{"position":[550,2731],"radius":200,"color_gain":1.0},
	{"position":[1783,2803],"radius":200,"color_gain":1.0},
	{"position":[2319,2923],"radius":200,"color_gain":1.0},
	{"position":[3563,2881],"radius":200,"color_gain":1.0},
	{"position":[3091,2807],"radius":200,"color_gain":1.0},
	{"position":[2358,193],"radius":200,"color_gain":0.5},
	{"position":[400,400],"radius":240,"color_gain":1.0},
	{"position":[3842,236],"radius":240,"color_gain":0.5}]
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

static func setup_record(source:Dictionary) -> Dictionary:
	var record=source.duplicate(true)
	record.position=[float(source.position[0]),float(source.position[1])]
	record.lifetime_ms=4000.0;record.rate=0.5;record.capacity=50
	record.color_override=float(record.color_gain)!=1.0
	return record

static func produce(source:Dictionary,direction:Vector2,radial_random:int,ratio:float,initial:bool) -> Dictionary:
	var radius=f32(source.radius)
	var radial=minf(radius,f32(float(radial_random%int(radius))+f32(radius*0.25)))
	var point=Vector2(f32(float(source.position[0])+f32(direction.x*radial)),f32(float(source.position[1])+f32(direction.y*radial)))
	var gain=float(source.color_gain) if source.color_override else 1.0
	var channel=f32(f32(0.5)*f32(gain))
	return {"position":point,"color":[channel,channel,channel,channel],"emission_seconds":f32(f32(source.lifetime_ms)*f32(0.001)),"clock_ratio":f32(ratio),"initial_emits":1 if initial else 0,"generator_spawn_timer":0.0}

static func intersects(source:Dictionary,zoom:float,origin:Vector2,viewport:Vector2) -> bool:
	var x=f32(f32(float(source.position[0])*f32(zoom))+origin.x)
	var y=f32(f32(float(source.position[1])*f32(zoom))+origin.y)
	var radius=f32(f32(float(source.radius)+50)*f32(zoom))
	return f32(x+radius)>0 and f32(x-radius)<viewport.x and f32(y+radius)>0 and f32(y-radius)<viewport.y

static func spawn_step(timer:float,count:int,capacity:int,dt_ms:float) -> Dictionary:
	var elapsed=f32(timer+f32(dt_ms))
	var spawn=elapsed>=80.0 and count<capacity
	return {"spawn":spawn,"timer":0.0 if spawn else elapsed}

static func particle_step(rate:float,dt_ms:float) -> float:
	return f32(f32(f32(rate)*f32(0.001))*f32(dt_ms))


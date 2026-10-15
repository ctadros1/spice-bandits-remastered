extends RefCounted

const CAPACITY=150
const INTERVAL=0.05999999865889549
const OPACITY=[0.0,1.0,1.0,0.0]
const MenuAnimation=preload("res://scripts/main_menu_view.gd")
var source_rects:Array=[]
var bounds=Rect2()
var age=0.0
var until_emit=INTERVAL
var next_slot=0
var pool:Array=[]
var rng=RandomNumberGenerator.new()

static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

static func creation(width:float,height:float,rx:int,ry:int,offset:Vector2) -> Dictionary:
	var local=Vector2(f32(width*f32(float(rx%100)/100.0)),f32(height*f32(float(ry%100)/100.0)))
	var point=Vector2(f32(local.x+offset.x),f32(local.y+offset.y))
	return {"local":local,"point":point,"speed":60.0,"distance":clampf(f32(point.y-10.0),0,100)}

static func declaration(point:Vector2,speed:float,distance:float) -> Dictionary:
	return {"from":point,"to":Vector2(point.x,f32(point.y-distance)),"duration":f32(distance/speed),"opacity":OPACITY,"timing":"easeIn"}

static func emission_plan(chance:int,target:int,count:int,source_count:int) -> Dictionary:
	var burst=chance%50==10
	return {"ordinary":4,"target":target%source_count if source_count>0 else 0,"extra":count%20+10 if burst else 0}

func reset(rects:Array,frame:Rect2,seed_value:int=-1) -> void:
	source_rects=rects.duplicate();bounds=frame;age=0.0;until_emit=INTERVAL;next_slot=0;pool.clear();pool.resize(CAPACITY)
	if seed_value<0:rng.randomize()
	else:rng.seed=seed_value

func random_int() -> int:return rng.randi()&0x7fffffff

func emit_from(index:int) -> void:
	if source_rects.is_empty():return
	var rect:Rect2=source_rects[index]
	var pose=creation(rect.size.x,rect.size.y,random_int(),random_int(),rect.position-bounds.position)
	pool[next_slot]={"born":age,"pose":declaration(pose.point,pose.speed,pose.distance)}
	next_slot=(next_slot+1)%CAPACITY

func advance(seconds:float) -> void:
	var remaining=maxf(seconds,0)
	while remaining>=until_emit:
		age+=until_emit;remaining-=until_emit;until_emit=INTERVAL
		if source_rects.is_empty():continue
		for _i in range(4):emit_from(random_int()%source_rects.size())
		if random_int()%50==10:
			var plan=emission_plan(10,random_int(),random_int(),source_rects.size())
			for _i in range(plan.extra):emit_from(plan.target)
	age+=remaining;until_emit-=remaining

func draw(canvas:CanvasItem) -> void:
	for record in pool:
		if record==null:continue
		var pose:Dictionary=record.pose
		var elapsed=age-float(record.born)
		if pose.duration<=0 or elapsed>=float(pose.duration):continue
		var phase=MenuAnimation.curve(elapsed/float(pose.duration),pose.timing)
		var point=bounds.position+pose.from.lerp(pose.to,phase)
		var alpha=MenuAnimation.keyframe(OPACITY,[0.0,1.0/3.0,2.0/3.0,1.0],phase)
		canvas.draw_rect(Rect2(point-Vector2(0.5,0.5),Vector2.ONE),Color(1,1,1,alpha))

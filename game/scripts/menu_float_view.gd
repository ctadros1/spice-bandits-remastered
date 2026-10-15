extends RefCounted

const MenuMotion=preload("res://scripts/main_menu_view.gd")
const POSITION_DURATION=20.0
const DAMPING=-0.8999999761581421
const LAMP_VALUES=[0.0,1.0,0.0]
const LAMP_TIMES=[0.0,0.05000000074505806,0.30000001192092896,0.6000000238418579,1.0]
const LAMP_DURATION=3.5
var age=0.0
var items={}
var rng=RandomNumberGenerator.new()

static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

static func declaration(height:float,position:Vector2,random_values:Array) -> Dictionary:
	var dx=f32(float((int(random_values[1])%100)*2)/100.0)
	var dy=f32(2.0+f32(float((int(random_values[0])%int(f32(height/10.0)))*6)/100.0))
	var path=[position]
	while true:
		path.append(Vector2(f32(position.x+dx),f32(position.y+dy)))
		dx=f32(dx*DAMPING);dy=f32(dy*DAMPING)
		if absi(int(dx))<1 and absi(int(dy))<1:break
	path.append(position)
	return {"path":path,"duration":POSITION_DURATION,"angles":[0.0,f32(0.01+f32(float(int(random_values[2])%40)/1000.0)),0.0,f32(-0.01-f32(float(int(random_values[3])%40)/1000.0))],"rotation_duration":f32(4.0+f32(float(int(random_values[4])%100)/100.0))}

static func lamp_begin(tag:int,media_time:float=0.0) -> float:
	var index=tag-100
	return f32(f32(media_time)+f32(float(index%10)/10.0))+float(100+index)*0.08

static func lamp_alpha(tag:int,seconds:float) -> float:
	var elapsed=seconds-lamp_begin(tag)
	if elapsed<0:return 0.0
	return MenuMotion.keyframe(LAMP_VALUES,LAMP_TIMES,MenuMotion.curve(fposmod(elapsed,LAMP_DURATION)/LAMP_DURATION,"easeInEaseOut"))

func reset(entries:Array,height:float,seed_value:int=-1) -> void:
	age=0.0;items.clear()
	if seed_value<0:rng.randomize()
	else:rng.seed=seed_value
	for entry in entries:
		var values=[]
		for _i in range(5):values.append(rng.randi()&0x7fffffff)
		items[int(entry.id)]=declaration(height,entry.rect.get_center(),values)

func advance(seconds:float) -> void:age+=maxf(seconds,0)

func pose(id:int) -> Dictionary:
	if not items.has(id):return {"translation":Vector2.ZERO,"rotation":0.0}
	var spec=items[id]
	var phase=fposmod(age/POSITION_DURATION,2.0)
	if phase>1:phase=2-phase
	var at=phase*(spec.path.size()-1)
	var left=mini(int(at),spec.path.size()-2)
	var position:Vector2=spec.path[left].lerp(spec.path[left+1],at-left)
	var spin=fposmod(age/spec.rotation_duration,2.0)
	if spin>1:spin=2-spin
	var angle=MenuMotion.keyframe(spec.angles,[],MenuMotion.curve(spin,"easeInEaseOut"))
	return {"translation":position-spec.path[0],"rotation":angle}

func transform_for(id:int,rect:Rect2) -> Transform2D:
	var state=pose(id)
	return Transform2D(state.rotation,rect.get_center()+state.translation)*Transform2D(0,-rect.get_center())

extends RefCounted

const MenuAnimation=preload("res://scripts/main_menu_view.gd")
const NOTE_ALPHA=[0.0,1.0,0.699999988079071,1.0,0.800000011920929,1.0,0.0]
const FLY_DURATION=2.0
const NOTE_DURATION=4.0
var age=0.0
var until_note=MenuAnimation.NOTE_INTERVAL
var flies={}
var notes:Array=[]
var note_entries:Array=[]
var note_frame=Rect2()
var next_note=0
var rng=RandomNumberGenerator.new()

static func f32(value:float) -> float:return PackedFloat32Array([value])[0]
static func ratio(value:int) -> float:return f32(float(value%100)/100.0)

static func fly_declaration(width:float,height:float,values:Array,device:int=0) -> Dictionary:
	var start=Vector2(f32(width*ratio(int(values[0]))),f32(height*ratio(int(values[1]))))
	var distance=16.0 if device==1 else 40.0
	var count=int(values[2])%6+4
	var curves=[];var at=3
	for i in range(count+1):
		var curve=[]
		for _j in range(2):
			curve.append(Vector2(f32(start.x+f32(distance*ratio(int(values[at])))),f32(start.y+f32(distance*ratio(int(values[at+1]))))));at+=2
		if i<count:
			curve.append(Vector2(f32(start.x+f32(distance*ratio(int(values[at])))),f32(start.y+f32(distance*ratio(int(values[at+1]))))));at+=2
		else:curve.append(start)
		curves.append(curve)
	return {"start":start,"curves":curves,"duration":FLY_DURATION}

static func note_spawn(width:float,height:float,rx:int,ry:int) -> Dictionary:
	var x=f32(f32(width*0.5)+f32(f32(width*0.20000000298023224)+f32(f32(width*-0.4000000059604645)*ratio(rx))))
	var y=f32(height+f32(f32(height*-0.10000000149011612)*ratio(ry)))
	return {"point":Vector2(x,y),"duration":NOTE_DURATION,"distance":y}

static func note_declaration(point:Vector2,duration:float,distance:float,value:int,device:int=0) -> Dictionary:
	var amplitude=f32((3.0 if device==1 else 6.0)*ratio(value))
	var path=[point]
	for i in range(1,5):
		var fraction=[0.0,0.20000000298023224,0.4000000059604645,0.6000000238418579,0.800000011920929][i]
		path.append(Vector2(f32(point.x+(amplitude if i%2==1 else -amplitude)),f32(point.y-f32(distance*fraction))))
	path.append(Vector2(point.x,f32(point.y-distance)))
	return {"path":path,"duration":duration,"alpha_duration":duration*0.7,"alpha":NOTE_ALPHA}

func reset(fly_entries:Array,fly_frame:Rect2,entries:Array,frame:Rect2,seed_value:int=-1) -> void:
	age=0.0;until_note=MenuAnimation.NOTE_INTERVAL;flies.clear();notes.clear();notes.resize(entries.size());note_entries=entries.duplicate();note_frame=frame;next_note=0
	if seed_value<0:rng.randomize()
	else:rng.seed=seed_value
	for entry in fly_entries:
		var values=[]
		for _i in range(80):values.append(rng.randi()&0x7fffffff)
		var declaration=fly_declaration(fly_frame.size.x,fly_frame.size.y,values)
		flies[int(entry.id)]={"frame":fly_frame,"pose":declaration}

func random_int() -> int:return rng.randi()&0x7fffffff

func advance(seconds:float,music:bool) -> void:
	var remaining=maxf(seconds,0)
	while remaining>=until_note:
		age+=until_note;remaining-=until_note;until_note=MenuAnimation.NOTE_INTERVAL
		if not music or notes.is_empty():continue
		var spawn=note_spawn(note_frame.size.x,note_frame.size.y,random_int(),random_int())
		notes[next_note]={"born":age,"pose":note_declaration(spawn.point,spawn.duration,spawn.distance,random_int())}
		next_note=(next_note+1)%notes.size()
	age+=remaining;until_note-=remaining

func fly_position(id:int) -> Vector2:
	var record=flies[id]
	var spec=record.pose
	var at=fposmod(age,FLY_DURATION)/FLY_DURATION*spec.curves.size()
	var index=mini(int(at),spec.curves.size()-1)
	var start:Vector2=spec.start if index==0 else spec.curves[index-1][2]
	var curve=spec.curves[index]
	# The original cubic control points are retained. Core Animation's path
	# flattening and parameterization are not executed by this renderer.
	return record.frame.position+start.bezier_interpolate(curve[0],curve[1],curve[2],at-index)

func draw_notes(canvas:CanvasItem,content:Node) -> void:
	for i in range(notes.size()):
		if notes[i]==null:continue
		var record=notes[i]
		var spec=record.pose
		var elapsed=age-float(record.born)
		if elapsed>=spec.alpha_duration:continue
		var alpha=MenuAnimation.keyframe(NOTE_ALPHA,[],elapsed/spec.alpha_duration)
		var at=clampf(elapsed/spec.duration,0,1)*(spec.path.size()-1)
		var left=mini(int(at),spec.path.size()-2)
		var point=note_frame.position+spec.path[left].lerp(spec.path[left+1],at-left)
		var entry=note_entries[i]
		var size=Vector2(entry.rect[2],entry.rect[3])
		canvas.draw_texture_rect(content.tex(entry.image),Rect2(point-size/2,size),false,Color(1,1,1,alpha))

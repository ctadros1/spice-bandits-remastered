extends RefCounted
# CMapArray admission + CDecal/manager clocks. Texture choice/submission
# comes from the death caller; original RNG/loader/GPU remain separate.
var width=0
var height=0
var serial=0
var items:Array=[]
var cells:Dictionary={}
static func f32(v:float) -> float:return Vector2(v,0).x
static func header(w:int,h:int) -> Array:return [w,h,int(w/100.0),int(h/100.0),100,5,30,30,20,3]
static func distance(a:Vector2,b:Vector2) -> float:
	var dx=f32(a.x-b.x);var dy=f32(a.y-b.y)
	return f32(sqrt(f32(f32(dx*dx)+f32(dy*dy))))
static func initial(point:Vector2,scale:float,life:float,fade:float,fade_in:float=0.0) -> Dictionary:
	return {"position":point,"scale":f32(scale),"life":f32(life),"fade":f32(fade),"fade_in":f32(fade_in),"clock":0.0,"alpha":0.0 if fade_in>0 else 1.0,"deleted":false,"fading":false}
func setup(w:int,h:int) -> void:
	width=w;height=h;serial=0;items.clear();cells.clear()
func cell_at(point:Vector2) -> Vector2i:
	return Vector2i(int(f32(point.x/100.0)),int(f32(point.y/100.0)))
func add(point:Vector2,texture:String,scale:float,life:float=4000.0,fade:float=4000.0,fade_in:float=0.0,kind:int=1,with_array:bool=true) -> Dictionary:
	var cell=Vector2i(-1,-1)
	if kind==1 and with_array:
		if point.x<0 or point.y<0 or point.x>width or point.y>height:return {}
		var candidate=cell_at(point)
		# Inclusive world edges and partial100px cells still create an
		# unregistered decal; only fully outside world bounds reject it.
		if candidate.x>=0 and candidate.y>=0 and candidate.x<int(width/100.0) and candidate.y<int(height/100.0):
			cell=candidate
			if not cells.has(cell):cells[cell]=[]
			var members:Array=cells[cell]
			if members.size()>=20:return {}
			var close=0
			for old in members:
				if distance(point,old.position)<30.0:
					if close>=3:
						old.deleted=true;members.erase(old);break
					close+=1
	serial+=1
	var item=initial(point,scale,life,fade,fade_in)
	item.merge({"id":serial,"texture":texture,"cell":cell})
	items.append(item)
	if cell!=Vector2i(-1,-1):cells[cell].push_front(item)
	return item
static func update_item(item:Dictionary,dt_ms:float) -> void:
	if item.deleted:return
	var dt=f32(dt_ms)
	if float(item.fade_in)>0 and float(item.clock)<float(item.fade_in):item.alpha=f32(float(item.clock)/float(item.fade_in))
	if not item.fading:
		item.clock=f32(float(item.clock)+dt)
		if float(item.clock)>=float(item.life):item.fading=true;item.clock=0.0
	if item.fading:
		# The switch frame consumes the complete delta in fade and discards
		# hold overflow, just as original CDecal.Update does.
		item.clock=f32(float(item.clock)+dt)
		var fraction=f32(float(item.clock)/float(item.fade)) if float(item.fade)!=0 else INF
		item.alpha=0.0 if fraction>1 else 1.0 if fraction<0 else f32(1.0-fraction)
		if float(item.alpha)<=0:item.alpha=0.0;item.deleted=true
func advance(dt_ms:float) -> void:
	var live=0
	for index in items.size():
		var item:Dictionary=items[index]
		if item.deleted:
			if cells.has(item.cell):cells[item.cell].erase(item)
			continue
		update_item(item,dt_ms)
		if live!=index:items[live]=item
		live+=1
	items.resize(live)

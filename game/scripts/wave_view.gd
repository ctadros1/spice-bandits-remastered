extends RefCounted

# CRoom::LoadCreepsResource0xd02dc, original float32 color constants.
const COLORS={
	1:Color(0.0,0.0,1.0,1.0),
	2:Color(1.0,0.0,0.0,1.0),
	3:Color(1.0,0.0,0.0,1.0),
	4:Color(0.878000020980835,0.6744999885559082,0.0,1.0),
	5:Color(0.0,0.5842999815940857,0.125,1.0),
	6:Color(0.0,0.5842999815940857,0.125,1.0),
	7:Color(0.0,0.5842999815940857,0.125,1.0),
	8:Color(0.0,0.6430000066757202,0.7019000053405762,1.0),
	9:Color(0.7372000217437744,0.49410000443458557,0.8740000128746033,1.0),
	10:Color(0.49410000443458557,0.26269999146461487,0.6230000257492065,1.0),
	11:Color(1.0,1.0,0.0,1.0),
	12:Color(0.7372000217437744,0.49410000443458557,0.8740000128746033,1.0),
	13:Color(0.7372000217437744,0.49410000443458557,0.8740000128746033,1.0),
	14:Color(0.7372000217437744,0.49410000443458557,0.8740000128746033,1.0),
	15:Color(0.0,0.0,1.0,1.0),
	16:Color(0.0,0.0,1.0,1.0),
	17:Color(1.0,0.0,0.0,1.0),
	18:Color(1.0,0.0,0.0,1.0),
	19:Color(1.0,0.0,0.0,1.0),
	20:Color(1.0,0.0,0.0,1.0),
	21:Color(1.0,0.0,0.0,1.0),
	22:Color(0.878000020980835,0.6744999885559082,0.0,1.0),
	23:Color(0.878000020980835,0.6744999885559082,0.0,1.0),
	24:Color(0.878000020980835,0.6744999885559082,0.0,1.0),
	25:Color(0.0,0.0,1.0,1.0),
	26:Color(0.0,0.0,1.0,1.0),
	27:Color(0.0,0.0,1.0,1.0),
	28:Color(0.0,0.0,1.0,1.0),
	29:Color(0.0,0.0,1.0,1.0),
	30:Color(0.0,0.0,1.0,1.0),
}

static func f32(value:float) -> float:return Vector2(value,0).x
static var indicator_cache:Dictionary={}

static func rows(current:int,elapsed:int,delay:int,total:int,particle_age:Variant=null,particle_life:float=60,collapse:Dictionary={}) -> Array:
	# RenderWaves0xd811c, including its two separate integer truncations
	# during early collapse. Multiplayer/phone layout remains separate.
	var result=[]
	var ratio=f32(float(elapsed)/delay)
	var offset=f32(f32(float(60*(current-1))+f32(60*ratio))-34)
	var retain_previous=particle_age!=null and float(particle_age)<f32(particle_life*0.5)
	for i in range(total):
		if i+1<=current and not retain_previous:continue
		var x=int(f32(float(i*60)-offset))
		if not collapse.is_empty():
			if result.is_empty():
				x=int(f32(float(x)-float(collapse.distance)));collapse.first=x
				if x<35:collapse.active=true
			elif collapse.active and float(collapse.duration)>0:
				var amount=clampf(f32(float(collapse.distance)/float(collapse.duration)),0,1)
				x=int(f32(float(x)-f32(float(collapse.extra)*amount)))
		result.append({"number":i+1,"x":x,"text_y":6})
	return result

static func battle_rows(sim,collapse:Dictionary={}) -> Array:
	var delay=int(sim.config.wavedelay)
	var elapsed=clampi(sim.clock_ms-sim.next_wave_ms+delay,0,delay)
	return rows(sim.wave_index,elapsed,delay,sim.config.waves.size(),null,60,collapse)

static func initial_collapse(current:int) -> Dictionary:
	return {"current":current,"distance":0.0,"duration":0.0,"extra":0.0,"active":true,"first":94}

static func advance_collapse(collapse:Dictionary,dt_ms:float,current:int,elapsed:int,delay:int,total:int) -> void:
	collapse.distance=f32(float(collapse.distance)+f32(f32(dt_ms)/5.0))
	var future=rows(current,elapsed,delay,total)
	if not future.is_empty():
		collapse.duration=f32(float(future[0].x+40))
		collapse.extra=f32(float(future[0].x-34))
	rows(current,elapsed,delay,total,null,60,collapse)

static func indicators(creeps:Array,width:float=60) -> Array:
	var key=JSON.stringify(creeps)+":"+str(width)
	if indicator_cache.has(key):return indicator_cache[key]
	var result=[]
	var total=creeps.filter(func(value):return int(value)!=-1).size()
	if total==0:return result
	for id in range(32):
		var count=creeps.filter(func(value):return int(value)==id).size()
		if count==0:continue
		result.append({"width":f32(f32(width)*f32(float(count)/total)),"color":COLORS.get(id,Color.BLACK)})
	indicator_cache[key]=result
	return result

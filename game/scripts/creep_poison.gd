extends RefCounted
# Selected original Emit/Stop, cloud apply and reserved in-range list methods.
# Full cloud constructor/Update/particle-tail and damage callback remain separate.
static func f32(v:float) -> float:return Vector2(v,0).x
static func particle_root(creep:Dictionary,alias:String) -> Dictionary:
	for sys in creep.get("particle_roots",[]):
		if str(sys.get("creep_alias",""))==alias:return sys.owned_tree
	return {}
static func emit(creep:Dictionary,type:int,trace:Callable=Callable()) -> void:
	if trace.is_valid():trace.call("emit",creep,type)
	var alias="radiation" if type==1 else "poison" if type==2 else "freeze" if type==3 else ""
	if alias.is_empty() or (type==3 and creep.get("consumed_slow",false)):return
	var tree=particle_root(creep,alias)
	if not tree.is_empty():tree.rate=1
static func stop(creep:Dictionary,type:int,trace:Callable=Callable()) -> void:
	if trace.is_valid():trace.call("stop",creep,type)
	var alias="radiation" if type==1 else "poison" if type==2 else ""
	if alias.is_empty():return
	var tree=particle_root(creep,alias)
	if not tree.is_empty():tree.rate=0
static func erase(zone:Dictionary,creep:Dictionary) -> void:
	var tracked:Array=zone.get("creeps_in_range",[])
	for i in tracked.size():
		if int(tracked[i].id)==int(creep.id):tracked.remove_at(i);return
static func clear(zone:Dictionary,trace:Callable=Callable()) -> void:
	var type=1 if int(zone.get("type",0))==5 else 2
	var tracked:Array=zone.get("creeps_in_range",[])
	for creep in tracked:stop(creep,type,trace)
	tracked.clear()
static func distance(creep:Dictionary,zone:Dictionary,height:float) -> float:
	var dx=f32(float(creep.pos.x)-float(zone.pos.x));var dy=f32(float(creep.pos.y)-float(zone.pos.y))
	return f32(f32(sqrt(f32(f32(dx*dx)+f32(dy*dy))))/f32(height))
# The raw kind is supplied in ARM fixtures. The live catalog retains its
# existing ground/air bridge; full resource producer recovery is separate.
static func eligible(creep:Dictionary) -> bool:
	return int(creep.state) not in [2,3] and int(creep.get("resource_kind",2 if creep.get("air",false) else 1))==1
static func apply_damage(actors:Array,zone:Dictionary,height:float,dt_ms:float,damage:Callable,argument_b:bool=false,trace:Callable=Callable()) -> void:
	if not zone.has("creeps_in_range"):zone.creeps_in_range=[]
	var tracked:Array=zone.creeps_in_range
	var type=1 if int(zone.get("type",0))==5 else 2
	var radius=f32(float(zone.def.get("poison_range",0))/1000.0)
	var seconds=f32(f32(dt_ms)*f32(.001))
	for creep in actors:
		if not eligible(creep):stop(creep,type,trace);erase(zone,creep);continue
		var dist=distance(creep,zone,height)
		if not dist<radius:stop(creep,type,trace);erase(zone,creep);continue
		var nominal=f32(f32(float(zone.def.get("poison_damage",0)))+f32(float(zone.get("damage_bonus",0))))
		var falloff=f32(1.0-f32(dist/nominal)) if dist>0 else 1.0
		var previous=int(creep.poison_count);creep.poison_count=previous+1
		var amount=f32(f32(f32(nominal*falloff)*seconds)/f32(pow(2.0,previous)))
		damage.call(creep,int(zone.owner),amount,not argument_b,3)
		emit(creep,type,trace)
		if not tracked.any(func(v):return int(v.id)==int(creep.id)):tracked.append(creep)
static func apply_slow(actors:Array,zone:Dictionary,height:float,trace:Callable=Callable()) -> void:
	var radius=f32(float(zone.def.get("poison_range",0))/1000.0)
	for creep in actors:
		if not eligible(creep) or not distance(creep,zone,height)<radius:continue
		var previous=int(creep.slow_count);creep.slow_count=previous+1
		emit(creep,3,trace)
		var factor=f32(f32(f32(float(zone.def.get("slowdown",0)))/f32(pow(2.0,previous)))/f32(-100.0))
		factor=f32(factor+1.0)
		creep.slow_pending=f32(f32(float(creep.slow_pending))*factor) if float(creep.slow_pending)>0 else factor

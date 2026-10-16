extends RefCounted
# Port of original DoDamage/Update hit fields, connected to Simulation
# and the ordered per-owner additive renderer in R123.
static func f32(value:float) -> float:return Vector2(value,0).x
static func initial() -> Dictionary:
	return {"hit_elapsed":0.0,"hit_active":false,"hit_running":false,"hit_last_kind":0}
static func after_damage(actor:Dictionary,kind:int) -> void:
	# HP is supplied after damage; reward/death ownership stays in Simulation.
	if int(actor.get("state",0)) in [2,3]:return
	if float(actor.hp)>0:
		if kind==3 and int(actor.hit_last_kind)==3:return
		if not actor.hit_running:actor.hit_active=true;actor.hit_running=true
		actor.hit_last_kind=kind
	else:
		actor.hit_active=false;actor.hit_running=false
static func advance(actor:Dictionary,dt_ms:float) -> void:
	if not actor.hit_running:return
	actor.hit_elapsed=f32(f32(float(actor.hit_elapsed))+f32(dt_ms))
	if actor.hit_elapsed>60.0:
		actor.hit_elapsed=0.0;actor.hit_running=false;actor.hit_active=false
static func frames(state:int,hit:bool,layers:Array) -> Array:
	if state in [2,3] or not hit or layers.is_empty():return []
	var result=[{"index":0,"rgba":Color(.2,.2,.2,.2),"source":1,"destination":1}]
	if layers.size()>1 and float(layers[1].alpha)!=0:result.append({"index":1,"rgba":Color(.2,.2,.2,.2),"source":1,"destination":1})
	return result

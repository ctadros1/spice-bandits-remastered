extends RefCounted
# Original GetLsdDuration/ProcessPlayers selected fields. Admission, actor
# state restoration and the pathfinder have separate caller evidence.
static func f32(value:float) -> float:return Vector2(value,0).x
static func initial() -> Dictionary:return {"remaining":0,"stop_sound":true,"reset_admission":true}
static func duration(base:int,pharm:int,wizard:int,pharm_percent:int=5,wizard_percent:int=5) -> int:
	var specific=f32(1.0+f32(f32(float(pharm*pharm_percent))*f32(0.01)))
	var general=f32(1.0+f32(f32(float(wizard*wizard_percent))*f32(0.01)))
	return int(f32(f32(f32(float(base))*specific)*general))
static func advance_timer(state:Dictionary,dt_ms:float) -> void:
	var active=int(state.remaining)>0
	state.remaining=maxi(0,int(f32(f32(float(state.remaining))-f32(dt_ms)))) if active else 0
	state.stop_sound=int(state.remaining)<=0
	# Full ProcessPlayers only resets admission when no counter was positive
	# at entry; the expiration frame itself defers that reset one call.
	state.reset_admission=not active

# Full UseLsd/ProcessLsd selected fields. A root is the original constructor
# alias, not a new effect. Optional raw fields retain offsets whose complete
# gameplay producers are still under investigation.
static func set_rate(actor:Dictionary,value:int) -> void:
	var root:Dictionary=actor.get("disco_root",{})
	if not root.is_empty():root.rate=value
static func change_state(actor:Dictionary,value:int,transition:Callable) -> void:
	if transition.is_valid():transition.call(value)
	else:actor.state=value
static func use(actor:Dictionary,player:int,counter:Dictionary,cell_affiliation:Variant,release:Callable=Callable(),path:Callable=Callable(),transition:Callable=Callable()) -> bool:
	var state=int(actor.get("state",0))
	if state in [1,2,3,5] or cell_affiliation==null:return false
	if int(cell_affiliation)!=0 and int(cell_affiliation)!=player:return false
	actor.disco_managed=true
	if (int(actor.get("disco_blocked",0))&1)==0:
		if state!=7:
			actor.disco_previous=state
			if state==4 and release.is_valid():release.call()
			set_rate(actor,1)
			if actor.has("disco_flag_25f"):actor.disco_flag_25f=0
		change_state(actor,7,transition)
		actor.disco_player=player
		if actor.get("disco_timer")==null and path.is_valid():path.call()
	actor.disco_timer=counter
	actor.disco_attached=true
	return true
static func process(actor:Dictionary,path:Callable=Callable(),transition:Callable=Callable()) -> void:
	var counter:Variant=actor.get("disco_timer")
	if counter!=null:
		if int(counter.remaining)>0:return
		set_rate(actor,0)
		if actor.has("disco_field_40"):actor.disco_field_44=actor.disco_field_40
		var previous=int(actor.get("disco_previous",0))
		if previous==4:
			previous=0;actor.disco_previous=0
			if actor.has("disco_flag_236"):actor.disco_flag_236=0
		change_state(actor,previous,transition)
		actor.disco_timer=null;actor.disco_attached=false;actor.disco_until=0
		if path.is_valid():path.call()
	else:set_rate(actor,0)

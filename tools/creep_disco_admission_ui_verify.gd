extends SceneTree
const Disco=preload("res://scripts/creep_disco_view.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failure_count=0
var failures=[]
class Requests extends RefCounted:
	var actor:Dictionary
	var events=[]
	var path_without_timer=[]
	func release() -> void:events.append({"call":"FreeDisplace-stub","x":6,"y":7,"slot":17})
	func state(value:int) -> void:
		events.append({"call":"SetState-full","actor":0,"state":value});events.append({"call":"Hover-stub","actor":0});actor.state=value
	func path() -> void:
		path_without_timer.append(actor.get("disco_timer")==null);events.append({"call":"UpdateShortestPath-stub","actor":0,"argument":1})
func _initialize() -> void:
	create_timer(60).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failure_count+=1
		if failures.size()<30:failures.append(label)
# JSON parses the original register integers as floats. Compare every
# requested field exactly as an integer, retaining array/callback order.
func same_requests(actual:Array,expected:Array) -> bool:
	if actual.size()!=expected.size():return false
	for i in actual.size():
		if actual[i].size()!=expected[i].size():return false
		for key in expected[i]:
			if not actual[i].has(key):return false
			var value=expected[i][key];var got=actual[i][key]
			if value is float:
				if value!=floor(value) or not got is int or got!=int(value):return false
			elif got!=value:return false
	return true
func actor_fields(a:Dictionary,b:Dictionary,timer:Variant) -> void:
	a.state=int(b.state);a.disco_previous=int(b.previous);a.disco_field_40=int(b.field40);a.disco_field_44=int(b.field44)
	a.disco_player=int(b.field174);a.disco_timer=timer;a.disco_attached=timer!=null;a.disco_blocked=int(b.flag214)
	a.disco_flag_236=int(b.flag236);a.disco_flag_25f=int(b.flag25f)
func snapshot(a:Dictionary,counter:Dictionary,old:Dictionary) -> Dictionary:
	var timer:Variant=a.get("disco_timer")
	return {"state":int(a.state),"previous":int(a.disco_previous),"field40":int(a.disco_field_40),"field44":int(a.disco_field_44),"field174":int(a.disco_player),"timer_pointer":"0x0" if timer==null else ("player+0x38" if is_same(timer,counter) else ("old" if is_same(timer,old) else "unknown")),"flag214":int(a.disco_blocked),"flag236":int(a.disco_flag_236),"flag25f":int(a.disco_flag_25f),"rate":a.disco_root.get("rate")}
func compare(a:Dictionary,expected:Dictionary,counter:Dictionary,old:Dictionary,label:String) -> void:
	var actual=snapshot(a,counter,old)
	for key in expected:check(actual[key]==expected[key],label+" "+key)
func make_sim():
	var c=root.get_node("Content");var s=Sim.new();var config=c.mission("8").duplicate(true);config.waves=[]
	s.setup(c.catalog.duplicate(true),c.maps[config.map].duplicate(true),config,root.get_node("Profile").fresh(),114,c.animations);s.spawn_hold=true;s.clock_ms=1000
	return s
func run() -> void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-lsd-reference.json"))
	for c in fixture.cases:
		var counter={"remaining":100};var old={"remaining":50};var a={"disco_root":{} if c.input.slot==false else {"rate":int(c.before.rate)}}
		actor_fields(a,c.before,old if c.input.existing else null)
		var trace=Requests.new();trace.actor=a;trace.events=[{"call":"UseLsd-full","actor":0},{"call":"GetCell-stub","x":6,"y":7}]
		Disco.use(a,int(c.input.player),counter,c.input.cell,trace.release,trace.path,trace.state)
		compare(a,c.after_use,counter,old,"original UseLsd "+str(c.input))
		check(same_requests(trace.events,c.use_calls),"ordered original UseLsd requests")
		check(trace.path_without_timer.all(func(v):return v),"new-path request precedes timer attachment")
		for f in c.frames:
			counter.remaining=int(f.supplied_player_counter);trace.events=[];trace.path_without_timer=[]
			Disco.process(a,trace.path,trace.state)
			compare(a,f.after,counter,old,"original ProcessLsd "+str(c.input)+"/"+str(f.supplied_player_counter))
			check(same_requests(trace.events,f.calls),"ordered original ProcessLsd requests")
			check(trace.path_without_timer.all(func(v):return v),"expiry detaches timer before path request")
	for c in fixture.manager_sequences:
		var s=make_sim();s.disco_state.remaining=100;var actors=[]
		for i in c.rows.size():
			var row=c.rows[i];var e=s.spawn_enemy(1,0,"",9001,false)
			# Undo this separate spawn caller before posing the supplied manager.
			e.disco_managed=false;e.disco_until=0
			actor_fields(e,{"state":row.state,"previous":row.previous,"field40":23,"field44":47,"field174":13,"flag214":0,"flag236":1,"flag25f":1},null)
			e.owner=int(row.owner);e.disco_root.rate=17
			if row.cell==null:e.cell=Vector2i(-1,-1)
			else:s.map.cells[s.cell_index(e.cell)].p=int(row.cell)
			actors.append(e)
		for e in actors:s.use_disco_on(e,int(c.player),true)
		for i in actors.size():compare(actors[i],c.after_use[i],s.disco_state,{},"actual manager owner/admission "+str(c.player))
		for e in actors:e.disco_blocked=1
		s.reset_disco_admission()
		for i in actors.size():compare(actors[i],c.after_reset[i],s.disco_state,{},"actual manager reset")
		s.particle_state.reset()
	var s=make_sim();s.disco_state.remaining=100;s.sources[0]=s.sources[0].duplicate(true);s.sources[0].neutrality=1
	var born=s.spawn_enemy(1,0,"",9001,false)
	check(born.owner==1 and born.state==7 and born.disco_attached,"actual direct new-spawn caller admits same owner")
	check(is_same(born.disco_timer,s.disco_state) and int(born.disco_root.rate)==1,"new spawn shares timer and existing constructor root")
	var original=born.disco_root;var restored=s.particle_state.systems.duplicate(true);s.particle_state.replace_systems(restored)
	var root=born.particle_roots.filter(func(sys):return str(sys.creep_alias)=="lsd")[0].owned_tree
	check(is_same(root,born.disco_root) and not is_same(original,born.disco_root),"held renderer restoration rebinds constructor alias")
	born.disco_root.rate=3;check(int(root.rate)==3 and int(original.rate)==1,"restored alias mutates only restored tree")
	s.particle_state.destroy_creep(born);check(born.disco_root.is_empty() and born.particle_roots.is_empty(),"final owner destruction drops alias")
	var other=s.spawn_enemy(1,0,"",9002,false);s.particle_state.reset();check(other.disco_root.is_empty(),"particle reset drops alias")
	var report={"checks":checks,"failure_count":failure_count,"failures":failures,"cases":fixture.cases.size(),"manager_sequences":fixture.manager_sequences.size(),"scope":"Original selected admission/expiry fields and ordered requests with explicit callbacks; actual simulation manager/new-spawn/root-rebind/destruction integration. Full state/hover/audio/pathfinder/other callers/GPU remain separate."}
	var f=FileAccess.open("res://../builds/creep-disco-admission-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("CREEP_DISCO_ADMISSION ",JSON.stringify(report));quit(1 if failure_count else 0)

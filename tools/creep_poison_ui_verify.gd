extends SceneTree
const Poison=preload("res://scripts/creep_poison.gd")
var checks=0
var failures=[]
class Recorder extends RefCounted:
	var actors=[]
	var events=[]
	var kill_label=-1
	func label(creep:Dictionary) -> int:
		for i in actors.size():
			if is_same(actors[i],creep):return i
		return -1
	func effect(kind:String,creep:Dictionary,type:int) -> void:events.append({"kind":kind,"actor":label(creep),"type":type})
	func damage(creep:Dictionary,owner:int,amount:float,argument:bool,type:int) -> void:
		var at=label(creep)
		events.append({"kind":"damage_stub","actor":at,"owner":owner,"damage_bits":PackedFloat32Array([amount]).to_byte_array().decode_u32(0),"argument_b":int(argument),"damage_type":type})
		if at==kill_label:creep.state=3
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func make_roots(presence:int,initial:int) -> Dictionary:
	var roots=[];var trees=[]
	for i in 3:
		var tree={"rate":initial+i,"backup_rate":9+i};trees.append(tree)
		if presence&(1<<i):roots.append({"creep_alias":["poison","radiation","freeze"][i],"owned_tree":tree})
	return {"roots":roots,"trees":trees}
func direct(row:Dictionary) -> void:
	var inp=row.input;var roots=make_roots(int(inp.presence),int(inp.initial))
	var actor={"state":int(inp.state),"consumed_slow":bool(int(inp.flag)&1),"particle_roots":roots.roots}
	var expected=actor.duplicate(true)
	for sys in expected.particle_roots:sys.owned_tree.rate=int(row.rates[["poison","radiation","freeze"].find(sys.creep_alias)])
	if inp.method=="emit":Poison.emit(actor,int(inp.tag))
	else:Poison.stop(actor,int(inp.tag))
	for i in 3:check(int(roots.trees[i].rate)==int(row.rates[i]),"direct pointer/rate "+str(inp)+"/"+str(i))
	check(var_to_bytes(actor)==var_to_bytes(expected),"direct complete supplied actor/root/key state exact")
func snapshot(actors:Array,trees:Array,zones:Array,record:Recorder) -> Dictionary:
	var rows=[]
	for i in actors.size():
		var a=actors[i];rows.append({"state":a.state,"poison_count":a.poison_count,"slow_count":a.slow_count,"pending_bits":PackedFloat32Array([a.slow_pending]).to_byte_array().decode_u32(0),"rates":trees[i].map(func(v):return v.rate)})
	var tracked=[]
	for z in zones:tracked.append(z.creeps_in_range.map(func(v):return record.label(v)))
	return {"actors":rows,"tracked":tracked,"events":record.events.duplicate(true)}
func sequence(row:Dictionary,index:int) -> void:
	var inp=row.input;var actors=[];var trees=[];var zones=[]
	for i in inp.actors.size():
		var a:Dictionary=inp.actors[i];var r=make_roots(int(a.get("presence",7)),int(a.get("initial_rate",7)));trees.append(r.trees)
		actors.append({"id":int(a.get("id",100+i)),"state":int(a.get("state",0)),"resource_kind":int(a.get("resource_kind",1)),"consumed_slow":bool(int(a.get("flag",0))&1),"pos":Vector2(a.pos[0],a.pos[1]),"poison_count":int(a.get("poison_count",0)),"slow_count":int(a.get("slow_count",0)),"slow_pending":float(a.get("pending",-1)),"particle_roots":r.roots})
	for c in inp.clouds:
		var tracked=[]
		for at in c.get("tracked",[]):tracked.append(actors[int(at)])
		zones.append({"pos":Vector2(c.pos[0],c.pos[1]),"def":{"poison_range":float(c.get("range",2))*1000.0,"poison_damage":float(c.get("damage",10)),"slowdown":float(c.get("slowdown",50))},"type":5 if int(c.get("radiation",0))&1 else 7,"owner":int(c.get("owner",43)),"damage_bonus":float(c.get("bonus",2.5)),"creeps_in_range":tracked})
	var record=Recorder.new();record.actors=actors;record.kill_label=int(inp.damage_stub_sets_state3_for) if inp.damage_stub_sets_state3_for!=null else -1
	for i in inp.actions.size():
		var action=inp.actions[i];var z=zones[int(action.get("cloud",0))];record.events=[]
		if action.kind=="move":actors[int(action.actor)].pos=Vector2(action.pos[0],action.pos[1])
		elif action.kind=="state":actors[int(action.actor)].state=int(action.state)
		elif action.kind=="clear":Poison.clear(z,record.effect)
		elif action.kind=="slow":Poison.apply_slow(actors,z,float(inp.get("height",32.0)),record.effect)
		else:Poison.apply_damage(actors,z,float(inp.get("height",32.0)),float(action.get("dt_ms",30)),record.damage,bool(action.get("argument_b",0)),record.effect)
		var actual=snapshot(actors,trees,zones,record);var expected=integer_frame(row.frames[i])
		check(var_to_bytes(actual)==var_to_bytes(expected),"complete normalized original frame integer words/order/callback bytes exact "+str(index)+"/"+str(i))
		for j in actual.actors.size():
			for key in actual.actors[j]:check(actual.actors[j][key]==expected.actors[j][key],"original caller "+str(index)+"/"+str(i)+"/"+str(j)+"/"+key+" actual "+str(actual.actors[j][key])+" expected "+str(expected.actors[j][key]))
		check(actual.tracked==expected.tracked,"in-range list order/ID deduplication exact "+str(index)+"/"+str(i))
		check(actual.events==expected.events,"damage/Emit/Stop callback order and raw bits exact "+str(index)+"/"+str(i)+" actual "+str(actual.events)+" expected "+str(expected.events))
func integer_frame(value):
	if value is Dictionary:
		var out={}
		for key in value:out[key]=integer_frame(value[key])
		return out
	if value is Array:
		var out=[]
		for item in value:out.append(integer_frame(item))
		return out
	if value is float:
		check(value==floor(value),"schema-defined original frame word is exactly integral")
		return int(value)
	return value
func integration() -> void:
	var content=root.get_node("Content");var profile=root.get_node("Profile");profile.read_only=true
	var Sim=load("res://scripts/simulation.gd")
	for types in [[7],[5],[8,7],[7,5]]:
		var config=content.mission("8").duplicate(true);config.waves=[]
		var sim=Sim.new();sim.setup(content.catalog,content.maps[config.map],config,profile.fresh(),114,content.animations);sim.spawn_hold=true
		var actor=sim.spawn_enemy(1,0,"",9901,false);actor.speed=0;actor.hp=1000000;actor.max_hp=1000000
		for type in types:sim.zones.append({"pos":actor.pos,"def":sim.tower_data(type,1),"until":5000,"owner":type,"type":type})
		sim.advance(30)
		var expected_poison=1 if 7 in types else 0;var expected_radiation=1 if 5 in types else 0
		check(int(Poison.particle_root(actor,"poison").rate)==expected_poison,"actual ordered chemical emitter starts")
		check(int(Poison.particle_root(actor,"radiation").rate)==expected_radiation,"actual independent radiation emitter starts")
		check(int(actor.poison_count)==types.count(7)+types.count(5),"actual Goo does not increment poison exposure")
		check(int(actor.slow_count)==types.count(8),"actual slow counter remains separate")
		if 8 in types:check(float(actor.slow_pending)==0.5,"actual authored50percent first slowdown exact")
		for z in sim.zones:
			if int(z.type)==8:continue
			check(z.creeps_in_range.size()==1 and is_same(z.creeps_in_range[0],actor),"cloud tracks the actual actor dictionary")
		for frame in 20:sim.advance(30)
		for pair in [["poison",expected_poison],["radiation",expected_radiation]]:
			if pair[1]==1:
				var sys=actor.particle_roots.filter(func(v):return str(v.creep_alias)==pair[0])[0]
				check(int(sys.owned_tree.rate)==1 and not sys.particles.is_empty(),"actual owned "+pair[0]+" particles survive exposure counter resets")
		for z in sim.zones:Poison.clear(z)
		sim.zones.clear();sim.advance(60)
		check(Poison.particle_root(actor,"poison").rate==0 and Poison.particle_root(actor,"radiation").rate==0,"original cleanup methods stop both aliases in current lifetime adapter")
		sim.particle_state.reset();sim.enemies.clear()
	for order in [[0,1],[1,0]]:
		var config=content.mission("8").duplicate(true);config.waves=[]
		var sim=Sim.new();sim.setup(content.catalog,content.maps[config.map],config,profile.fresh(),114,content.animations);sim.spawn_hold=true
		var actor=sim.spawn_enemy(1,0,"",9901,false);actor.speed=0;actor.hp=1000000;actor.max_hp=1000000
		var supplied=[]
		for pos in [actor.pos,actor.pos+Vector2(10000,0)]:supplied.append({"pos":pos,"def":sim.tower_data(7,1),"until":5000,"owner":7,"type":7})
		for index in order:sim.zones.append(supplied[index])
		sim.advance(30)
		check(int(Poison.particle_root(actor,"poison").rate)==(1 if order[-1]==0 else 0),"actual last same-type cloud determines emitter rate")
		var inside=supplied[0];check(inside.creeps_in_range.size()==1,"actual in-range tracking populated")
		sim.destroy_enemy_owner(actor);sim.enemies.erase(actor)
		check(inside.creeps_in_range.is_empty(),"actual owner destruction clears cloud references")
		sim.particle_state.reset()
func run() -> void:
	var path="res://../tests/fixtures/native-creep-poison-callers-reference.json"
	check(FileAccess.get_sha256(path)=="315cf5fa2e3b87903ec8247d358b36ea87b9d6e5fa844cf879f1b6822826bae6","independently reproduced original fixture binding")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	for row in data.direct:direct(row)
	for i in data.sequences.size():sequence(data.sequences[i],i)
	var distance_path="res://../tests/fixtures/native-creep-poison-distance-reference.json"
	check(FileAccess.get_sha256(distance_path)=="719b9b87abd98bc61cf54c0fd0ae47f4c8a257fd33a9370f2b836d302de1beec","independently reproduced diagonal/range/damage-bit fixture")
	var distance_data=JSON.parse_string(FileAccess.get_file_as_string(distance_path))
	for i in distance_data.sequences.size():sequence(distance_data.sequences[i],data.sequences.size()+i)
	integration()
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit report path")
	var report={"checks":checks,"failures":failures,"direct_cases":data.direct.size(),"sequences":data.sequences.size(),"distance_cases":distance_data.sequences.size(),"scope":"Selected original Emit/Stop and ordered cloud apply/list/counter/callback raw values, plus complete direct supplied actor/root dictionary bytes. Actual Simulation constructed chemical/radiation/Goo mixtures, owned emission through resets, independent aliases, ordered overlapping clouds and owner cleanup also checked. Full original cloud constructor/Update/lifetime and real damage/GPU/audio remain separate."}
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)

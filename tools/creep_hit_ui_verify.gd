extends SceneTree
const Hit=preload("res://scripts/creep_hit_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func actor(input:Dictionary) -> Dictionary:
	var value=Hit.initial()
	value.hit_elapsed=float(input.get("age",0));value.hit_active=bool(input.get("hit",false));value.hit_running=bool(input.get("running",false));value.hit_last_kind=int(input.get("last_type",0));value.hp=float(input.get("hp",100));value.state=int(input.get("state",0))
	return value
func compare(value:Dictionary,expected:Dictionary,label:String) -> void:
	check(bits(value.hit_elapsed)==int(expected.age_bits),label+" exact elapsed bits")
	check(value.hit_active==expected.hit,label+" active flag")
	check(value.hit_running==expected.running,label+" running flag")
	check(value.hit_last_kind==int(expected.last_type),label+" prior damage kind")
func damage(value:Dictionary,amount:float,kind:int) -> void:
	if value.state in [2,3]:return
	value.hp=Hit.f32(Hit.f32(value.hp)-Hit.f32(amount))
	Hit.after_damage(value,kind)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-hit-reference.json"))
	for i in fixture.damage.size():
		var c=fixture.damage[i];var value=actor(c.input)
		damage(value,float(c.input.amount),int(c.input.kind))
		compare(value,c.output,"full original damage "+str(i))
	for i in fixture.updates.size():
		var c=fixture.updates[i];var value=actor(c.input)
		Hit.advance(value,float(c.input.dt));compare(value,c.output,"full original update "+str(i))
	var value=actor({})
	for i in fixture.sequence.size():
		var c=fixture.sequence[i]
		if c.input.has("damage"):
			damage(value,float(c.input.damage),int(c.input.kind))
			if value.hp<=0:value.state=3 # explicit SetDie stub used by the reference
		else:Hit.advance(value,float(c.input.dt))
		compare(value,c.output,"full original interleaved sequence "+str(i))
	for i in fixture.render.size():
		var c=fixture.render[i];var a=c.input
		var layers=[{"alpha":float(a.alpha)},{"alpha":float(a.secondary)}]
		var plan=Hit.frames(int(a.state),bool(a.add),layers)
		var expected=c.calls.filter(func(row):return row.method=="frame" and row.blend==[1.0,1.0])
		check(plan.size()==expected.size(),"full original additive frame count "+str(i))
		for j in mini(plan.size(),expected.size()):
			check(plan[j].index==(0 if int(expected[j].actor_offset)==76 else 1),"full original current frame routing "+str(i))
			for k in range(4):check(bits(plan[j].rgba[k])==bits(float(expected[j].rgba[k])),"full original raw constant RGBA "+str([i,j,k]))
		var seen_add=false;var seen_screen=false
		for call in c.calls:
			if call.method!="frame":continue
			if call.blend==[1.0,1.0]:seen_add=true;check(not seen_screen,"hit must precede status "+str(i))
			elif call.blend==[1.0,769.0]:seen_screen=true
			else:check(not seen_add,"normal frames must precede hit "+str(i))
	var content=root.get_node("Content");var profile=root.get_node("Profile").fresh()
	var mission=content.mission("1");var sim=load("res://scripts/simulation.gd").new()
	sim.setup(content.catalog,content.maps[mission.map],mission,profile,121,content.animations);sim.spawn_hold=true
	var creep=sim.spawn_enemy(1,0,"");creep.hp=1000;creep.max_hp=1000
	sim.damage(creep,1,0,3)
	check(creep.hit_active and creep.hit_running and creep.hit_last_kind==3,"actual damage bridge starts poison hit")
	sim.advance_frame(30);sim.damage(creep,1,0,3)
	check(creep.hit_elapsed==30.0 and creep.hit_active,"actual consecutive poison does not restart clock")
	sim.advance_frame(30)
	check(creep.hit_elapsed==60.0 and creep.hit_active,"actual source flash remains at exact60ms")
	sim.paused=true;sim.advance_frame(30)
	check(creep.hit_elapsed==60.0 and creep.hit_active,"actual pause holds flash state")
	sim.paused=false;sim.advance_frame(.001)
	check(creep.hit_elapsed==0 and not creep.hit_active,"actual expiry clears strictly after60ms")
	sim.damage(creep,1,0,3)
	check(not creep.hit_active,"actual consecutive poison suppression survives expiry")
	sim.damage(creep,1,0,2)
	check(creep.hit_active and creep.hit_last_kind==2,"actual direct missile kind reactivates flash")
	creep.state=2;var hp=creep.hp;sim.damage(creep,1)
	check(creep.hp==hp,"actual damage ignores original state2")
	creep.state=0;sim.damage(creep,2000)
	check(not creep.hit_active and not creep.hit_running,"actual lethal damage clears flash flags")
	var report={"checks":checks,"failures":failures,"full_original_damage_cases":fixture.damage.size(),"full_original_update_cases":fixture.updates.size(),"full_original_render_cases":fixture.render.size(),"sequence_rows":fixture.sequence.size(),"scope":"Original hit fields/direct-frame plan and actual Simulation damage/timer/pause bridge. Native ordered additive rendering verified separately. Full callers/death/original GPU remain bounded."}
	var out=FileAccess.open("res://../builds/creep-hit-verification.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("CREEP_HIT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

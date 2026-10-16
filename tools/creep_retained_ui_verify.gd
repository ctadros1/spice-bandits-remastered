extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
var content
var profile
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(1));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<35:failures.append(label)
func bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)
func make_sim(victory:bool=false):
	var s=Sim.new();var c=content.mission("8").duplicate(true);c.waves=[]
	s.setup(content.catalog,content.maps[c.map],c,profile.fresh(),114,content.animations)
	s.spawn_hold=true;s.tutorial_finished=victory;s.clock_ms=1000
	return s
func actor(s,resource:String,splash:bool):
	var type=-1
	for i in content.catalog.tower_creeps.size():
		if str(content.catalog.tower_creeps[i].get("filename",""))==resource.trim_prefix("creeps/"):type=i;break
	check(content.animations.has(resource) and content.particles.bindings.has(resource),"preserved resource "+resource)
	var supplied_only=type<0
	if supplied_only:type=1
	var e=s.spawn_enemy(type,0,"",9001,false)
	if supplied_only:
		# Resource7 is preserved but absent from the populated offline catalog.
		# Exercise the same supplied-resource scope as the original probe.
		e.def=e.def.duplicate(true);e.def.filename=resource.trim_prefix("creeps/")
	e.owner=0;e.target_owner=1;e.speed=0;e.path=[]
	e.pos=Vector2(320.25,230.75);e.visual_pos=Vector2(330.5,220.5)
	s.damage(e,float(e.max_hp)*10,0,0 if splash else 2)
	return e
func compare(s,e,parents:Array,out:Dictionary,label:String) -> void:
	check(int(e.state)==int(out.state),label+" state")
	check(s.enemies.has(e)==bool(out.retained),label+" retained")
	check(s.is_any_creep_targeted(1)==bool(out.targeted),label+" original target query")
	check(e.get("death_sprites",[]).size()==int(out.sprites),label+" sprites")
	for expected in out.systems:
		var matching=parents.filter(func(sys):return str(sys.name)==str(expected.name))
		check(matching.size()==1,label+" original root "+str(expected.name))
		if matching.size()==1:
			check(matching[0].particles.size()==int(expected.active),label+" exact active parent count")
			check(bits(matching[0].owned_tree.clock_seconds)==int(expected.clock_bits),label+" exact local clock bits")
func compare_splash(e:Dictionary,resource:String,expected:Dictionary,label:String) -> void:
	check(int(e.state)==int(expected.state),label+" original owner state")
	check(e.death_sprites.size()==expected.sprites.size(),label+" original splash count")
	var definition=content.animations[resource]
	var texture=content.tex(str(definition.textures.ExplosionSplash.texture))
	for j in mini(e.death_sprites.size(),expected.sprites.size()):
		var a=e.death_sprites[j];var x=expected.sprites[j];var draw=expected.draws[j]
		check(bits(a.life)==int(x.life_bits),label+" original life")
		var size=texture.get_size()*a.scale
		for k in 2:
			check(bits(a.scale[k])==int(x.scale_bits[k]),label+" original scale")
			check(bits(size[k])==int(draw.size_bits[k]),label+" original full texture quad size")
		for k in 4:check(bits(1 if k<3 else a.alpha)==int(x.rgba_bits[k]),label+" original RGBA")
func run() -> void:
	content=root.get_node("Content");profile=root.get_node("Profile")
	var query_fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-death-target-reference.json"))
	var query_sim=make_sim();query_sim.bases.clear()
	for row in query_fixture.cases:
		query_sim.enemies.assign([{"owner":row.owner,"target_owner":row.target,"state":row.state}])
		check(query_sim.is_any_creep_targeted(int(row.player))==bool(row.result),"full original target-query state/owner/target fields")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-death-room-reference.json"))
	for c in fixture.cases:
		var s=make_sim();var e=actor(s,str(c.resource),bool(c.splash));var parents:Array=e.particle_roots.duplicate()
		var money=s.money;var kills=s.kills;var score=s.score
		for i in c.frames.size():
			var row=c.frames[i];var label=str(c.resource)+" "+str(c.dt_ms)+"/"+str(i)
			compare(s,e,parents,row.before,label+" before")
			s.paused=bool(row.pause_opened);s.advance_frame(float(row.dt_ms))
			compare(s,e,parents,row.after,label+" after")
			s.damage(e,100,0,0)
			check(s.money==money and s.kills==kills and s.score==score,label+" once-only rewards")
		check(s.particle_state.systems.is_empty(),"actual final destruction clears roots/pools")
	fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-death-victory-reference.json"))
	for c in fixture.cases:
		var s=make_sim(true);var e=actor(s,str(c.resource),bool(c.splash))
		for i in c.frames.size():
			var row=c.frames[i];s.paused=bool(row.pause_opened);s.advance_frame(float(row.dt_ms))
			check((s.outcome=="victory")==("game-end-stub:2" in row.calls),"full original conditional victory admission "+str(c.resource)+"/"+str(i))
	fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-splash-mid-reference.json"))
	for c in fixture.cases:
		var splash_sim=make_sim();var splash_owner=actor(splash_sim,str(c.resource),true)
		compare_splash(splash_owner,str(c.resource),c.birth,"actual birth "+str(c.resource))
		splash_sim.advance_frame(0)
		compare_splash(splash_owner,str(c.resource),c.zero_delta,"actual zero-delta "+str(c.resource))
		for step in 5:splash_sim.advance_frame(30)
		compare_splash(splash_owner,str(c.resource),c.mid_150ms,"actual mid-flash "+str(c.resource))
	# Actual tower phase creates the tail after its owner's update, so the
	# newborn clock must still be zero when that gameplay step finishes.
	var s=make_sim();s.config=content.mission("8").duplicate(true);s.tutorial_finished=false
	s.money=1000;s.build(Vector2i(10,9),1)
	var t=s.towers[0];var e=s.spawn_enemy(1,0,"",9002,false)
	e.pos=t.pos+Vector2(0,-60);e.visual_pos=e.pos;e.speed=0;e.path=[];e.hp=1
	t.tracking={"id":e.id,"acquisition":1.0,"turn":1.0,"locked":true,"start":0.0,"first_ms":2000,"first_done":true};t.reload_ms=100000
	s.advance_frame(30)
	check(int(e.state)==3 and s.kills==1,"actual tower phase killed owner")
	check(e.get("particle_roots",[]).filter(func(sys):return "explosion" in str(sys.creep_alias)).all(func(sys):return bits(sys.owned_tree.clock_seconds)==bits(0)),"actual tower birth is not aged retroactively")
	var first_roots=e.particle_roots.filter(func(sys):return "explosion" in str(sys.creep_alias));s.advance_frame(30)
	check(first_roots.all(func(sys):return bits(sys.owned_tree.clock_seconds)==bits(Vector2(Vector2(30,0).x*Vector2(.001,0).x,0).x)),"actual next owner phase advances newly born roots once")
	var restored=make_sim();var retained=actor(restored,"creeps/creep1",true)
	var before_roots=retained.particle_roots.duplicate();var copied:Array[Dictionary]=[];copied.assign(restored.particle_state.systems.duplicate(true))
	var fx=load("res://scripts/particle_fx.gd").new();fx.use_state(restored.particle_state);fx.systems=copied
	check(retained.particle_roots.all(func(sys):return is_same(sys,copied.filter(func(record):return record.id==sys.id)[0])),"held-render restore rebinds owners to restored dictionaries")
	restored.advance_frame(30)
	check(retained.particle_roots.all(func(sys):return bits(sys.owned_tree.clock_seconds)==bits(Vector2(Vector2(30,0).x*Vector2(.001,0).x,0).x)),"resumed manager advances restored live roots")
	check(before_roots.all(func(sys):return bits(sys.owned_tree.clock_seconds)==bits(0)),"resumed manager never advances detached ghost roots")
	fx.free()
	var report={"checks":checks,"failures":failures,"original_room_sequences":100,"original_victory_sequences":20,"original_mid_splash_resources":10,"scope":"Live simulation-owned real particle counts/float32 clocks/sprites/retention/query/removal and conditional victory versus combined original R143/R144 traces, once-only rewards and real tower-after-owner birth phase. Original trajectory/child fields have separate fixtures; full original construction/attached smoke/render/GPU/global RNG remain open."}
	var f=FileAccess.open("res://../builds/creep-retained-r146-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

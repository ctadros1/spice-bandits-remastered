extends SceneTree
const Death=preload("res://scripts/creep_death_view.gd")
var checks=0
var failures=[]
var base=""
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label)
# JSON numbers parse as floats; compare numerical values recursively so
# integer bit-pattern/label arrays retain exact equality without type artifacts.
func same(a,b) -> bool:
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same(a[i],b[i]):return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]):return false
		return true
	return a==b
func bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)
func vector_bits(v:Vector2) -> Array:return [bits(v.x),bits(v.y)]
func data(name:String):return JSON.parse_string(FileAccess.get_file_as_string(base.path_join(name)))
func tail_out(value:Dictionary) -> Dictionary:
	return {"state":value.state,"emitter_rate":value.emitter_rate,"sprites":value.sprites.map(func(s):return {"index":s.index,"age_bits":bits(s.life)}),"updated":value.updated,"deleted":value.deleted,"state_calls":value.state_calls}
func compare_tail(actual:Dictionary,expected:Dictionary,label:String):
	var v=tail_out(actual)
	for key in expected:check(same(v[key],expected[key]),label+" "+key)
func _initialize():
	base=ProjectSettings.globalize_path("res://../tests/fixtures")
	create_timer(30).timeout.connect(func():quit(1))
	run.call_deferred()
func run():
	var fixture=data("native-creep-death-reference.json")
	for i in fixture.cases.size():
		var c=fixture.cases[i];var input=c.input;var sprites=[]
		for j in input.sprite_lifetimes.size():
			var s=Death.sprite(100,Vector2.ZERO,1,0);s.life=input.sprite_lifetimes[j];s.index=j;sprites.append(s)
		compare_tail(Death.tail(int(input.state),input.emitter,input.particle_counts,sprites,float(input.dt)),c.output,"tail "+str(i))
	for i in fixture.sequences.size():
		var c=fixture.sequences[i];var sprites=[];var state=3
		for j in c.input.sprite_lifetimes.size():
			var s=Death.sprite(100,Vector2.ZERO,1,0);s.life=c.input.sprite_lifetimes[j];s.index=j;sprites.append(s)
		for row in c.frames:
			var result=Death.tail(state,c.input.emitter,c.input.particle_counts,sprites,float(row.dt));compare_tail(result,row.output,"sequence "+str(i));state=result.state;sprites=result.sprites
	var animations=JSON.parse_string(FileAccess.get_file_as_string("res://data/animations.json"));var particles=JSON.parse_string(FileAccess.get_file_as_string("res://data/particles.json"))
	fixture=data("native-creep-death-effects-reference.json")
	for i in fixture.cases.size():
		var c=fixture.cases[i];var input=c.input;var resource=animations[input.name]
		var actual=Death.creation(resource,particles.bindings[input.name],particles.systems,int(input.kind),input.already,Vector2(input.logical[0],input.logical[1]),Vector2(input.offset[0],input.offset[1]),Vector2(input.aim[0],input.aim[1]),Vector2(input.animator[0],input.animator[1]))
		var expected=c.output
		check(actual.state==expected.state and actual.crater_created==bool(expected.crater_created),"creation flags "+str(i))
		var emissions=expected.events.filter(func(e):return e.method=="emit")
		check(actual.particles.size()==emissions.size(),"creation emission count "+str(i))
		for j in emissions.size():
			var a=actual.particles[j];var e=emissions[j]
			check(a.name==e.system and a.count==e.count and bits(a.interval)==e.interval_bits and [a.position.x,a.position.y]==e.point,"creation original emission "+str(i)+"/"+str(j))
		check(actual.sprites.size()==expected.sprites.size(),"creation splash count "+str(i))
		for j in actual.sprites.size():
			var a=actual.sprites[j];var e=expected.sprites[j]
			check(bits(a.life)==e.life_bits and bits(a.divisor)==e.scale_div_bits and [a.position.x,a.position.y]==e.position and [a.initial_scale.x,a.initial_scale.y]==e.initial_scale,"creation splash fields "+str(i))
		var sounds=expected.events.filter(func(e):return e.method=="sound-load")
		check(actual.sound.cue==sounds[0].cue,"creation cue "+str(i))
		var decals=expected.events.filter(func(e):return e.method=="decal")
		check(actual.crater.is_empty()==decals.is_empty(),"creation crater count "+str(i))
		if not decals.is_empty():
			var e=decals[0];var a=actual.crater
			check(a.name==e.texture and [a.position.x,a.position.y]==e.position and [a.scale,a.life,a.fade,a.fade_in]==e.stack_floats,"creation crater submission "+str(i))
	fixture=data("native-creep-death-sprite-reference.json")
	for c in fixture.cases:
		var resource=animations[c.resource];var definition=resource.params;var sprite=Death.sprite(definition.exp_lifetime,Vector2(323.75,223.5),definition.exp_init_scale,definition.exp_scale_div);sprite.index=0
		var state=3;var sprites=[sprite];var texture=load("res://"+resource.textures.ExplosionSplash.texture)
		for row in c.frames:
			if row.dt_ms!=null:
				var r=Death.tail(state,null,[],sprites,float(row.dt_ms));state=r.state;sprites=r.sprites
			var expected=row.output
			check(state==expected.state and sprites.size()==expected.sprites.size(),"sprite sequence state "+c.resource)
			if sprites.is_empty():continue
			var s=sprites[0];var e=expected.sprites[0];var draw=expected.draws[0]
			check(bits(s.life)==e.life_bits,"sprite exact life "+c.resource)
			check(same(vector_bits(s.position),e.position_bits),"sprite exact position "+c.resource)
			check(same(vector_bits(s.scale),e.scale_bits),"sprite exact scale "+c.resource)
			check(same([bits(1),bits(1),bits(1),bits(s.alpha)],e.rgba_bits),"sprite exact RGBA "+c.resource)
			check(same(vector_bits(texture.get_size()*s.scale),draw.size_bits),"sprite native full texture size "+c.resource)
	fixture=data("native-creep-death-tail-reference.json")
	for c in fixture.cases:
		var systems=Death.burst_clocks(particles.bindings[c.resource],particles.systems)
		var s=Death.sprite(300,Vector2.ZERO,.5,5);s.index=0
		var sprites=[s];var state=3
		for row in c.frames:
			if int(row.frame)>0:
				var r=Death.advance_newborn_tail(state,systems,sprites,float(c.dt_ms));state=r.state;sprites=r.sprites
			var actual={"state":state,"systems":systems.map(func(system):return {"name":system.name,"active":system.active,"clock_bits":bits(system.clock)}),"sprites":sprites.size(),"emission_calls":0}
			for key in actual:check(same(actual[key],row.output[key]),"full original tail clock "+c.resource+"/"+str(c.dt_ms)+"/"+str(row.frame)+" "+key)
	var report={"checks":checks,"failures":failures,"scope":"Disconnected isolated R124 helper,3000 full original DoOnDying supplied cases,5 sequences,100 SetDie resource cases and100 native sprite frames plus50 full Creep.Update/tail/particle supplied sequences1,992frames. Exact float bits. No Main/Simulation integration, full particle/owner/room/GPU or final fidelity claim."}
	var out=FileAccess.open("res://../builds/creep-death-verification.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close();print("CREEP_DEATH_PORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

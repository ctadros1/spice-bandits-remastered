extends SceneTree
const Reference=preload("res://scripts/particle_child_view.gd")
var checks=0
var failures=[]
func _initialize() -> void:
	create_timer(45).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<25:failures.append(label)
func normalize(value):
	if value is Dictionary:
		var result={};var names=[]
		for key in value:names.append(str(key))
		names.sort()
		for name in names:result[name]=normalize(value[name])
		return result
	if value is Array:
		var result=[]
		for item in value:result.append(normalize(item))
		return result
	return value
func particle(_system:Dictionary,index:int,fresh:bool,old:Dictionary) -> Dictionary:
	return {"id":index+100 if fresh else old.id,"pos":Vector2(10.25,20.5),"velocity":Vector2.ZERO,"rotation":0.0,"rot_speed":0.0,"texture":{"width":16.0,"height":16.0,"uv":[0.0,1.0,0.0,1.0]}}
func child(_name:String) -> Dictionary:return {}
func equal_state(a:Dictionary,b:Dictionary,label:String) -> void:
	check(var_to_bytes(normalize(a))==var_to_bytes(normalize(b)),label)
func run() -> void:
	for real_alpha in [false,true]:
		for explicit_color in [false,true]:
			for absent_child in [false,true]:
				var d={"max_particles":4,"num_release":0,"life_cycle":1.0,"release_interval":0.5,"size":2.0,"real_alpha":real_alpha}
				if explicit_color:d.color=[0.2,0.4,0.6,0.8]
				var source=var_to_bytes(d)
				var actual=Reference.initialize(d.duplicate(true),true,false,false)
				var expected=Reference.initialize(d.duplicate(true),true,false,false)
				SpiceNative.owned_particle_emit(actual,1,particle,child);Reference.emit(expected,1,particle,child)
				equal_state(actual,expected,"explicit/default emit RGBA")
				if not explicit_color:check(actual.particles[0].rgba==[1.0,1.0,1.0,1.0],"missing color emits white")
				actual.particles[0].rgba=[.125,.25,.5,.25];expected.particles[0].rgba=[.125,.25,.5,.25]
				if absent_child:actual.particles[0].erase("child");expected.particles[0].erase("child")
				for dt in [.25,.5,.5]:
					SpiceNative.owned_particle_advance(actual,dt,particle,child);Reference.advance(expected,dt,particle,child)
					equal_state(actual,expected,"complete default update/release/pool fields")
					for held in 2:
						var a=SpiceNative.owned_particle_render(actual,false);var b=Reference.render(expected,false)
						check(var_to_bytes(a)==var_to_bytes(b),"held default/missing-child literal original geometry")
						equal_state(actual,expected,"held render leaves exact state")
					if absent_child:check(actual.particles.all(func(p):return not p.has("child")),"missing child read never inserts a dictionary")
				check(actual.particles.is_empty() and actual.pool.size()==1,"expired particle retained in pool")
				var fresh=Reference.initialize({"num_release":0},true,false,false)
				SpiceNative.owned_particle_emit(fresh,1,particle,child)
				check(fresh.particles[0].rgba==[1.0,1.0,1.0,1.0],"mutated particle colors never alias shared white default")
				check(var_to_bytes(d)==source and not fresh.definition.has("color"),"fallback reads never mutate definitions")
				var a_deleted=[];var b_deleted=[]
				SpiceNative.owned_particle_destroy(actual,a_deleted);Reference.destroy(expected,b_deleted)
				equal_state(actual,expected,"default root final destruction")
				check(a_deleted==b_deleted,"default root exact deletion order")
	var report={"checks":checks,"failures":failures,"cases":8,"scope":"Default-white alias isolation and missing-child reads through emit/update/Emit0/repeated render/pool/destruction. Literal native/scalar render bytes; numeric state comparison normalizes only dictionary key spelling/order. Independent original and immutable native baselines remain separate mandatory gates."}
	var f=FileAccess.open("res://../builds/particle-defaults-r154-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

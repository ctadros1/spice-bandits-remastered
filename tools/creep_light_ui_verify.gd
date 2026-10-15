extends SceneTree
const Light=preload("res://scripts/creep_light_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-light-reference.json")))
	var body=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-body-reference.json")))
	for case in reference.cases:
		var current=null if case.current==null else {"l":case.current}
		var target=null if case.next==null else {"l":case.next}
		var value=Light.sample(current,target,float(case.movement.progress),float(case.initial_light))
		check(value==Vector2(case.light,0).x,"original GetCell null/default/f32 interpolation p"+str(case.p)+" speed"+str(case.speed))
	check(Light.sample({},null,0)==reference.hex_constructor_default_light,"omitted l retains complete original cell-constructor default")
	check(Light.from_map({"hex_width":1,"hex_height":1,"cells":[{}]},Vector2i(-1,0),Vector2i.ZERO,0.5,0.4)==Vector2(0.4,0).x,"outside source cell preserves prior actor light")
	var app=load("res://scripts/main.gd").new();app.sim=load("res://scripts/simulation.gd").new()
	var primary_draws=0;var flagged_draws=0
	for case in body.cases:
		var primary=case.calls.filter(func(call):return call.method=="anim-render" and call.actor_offset==76)
		if not primary.is_empty():
			var e={"native_air":int(case.resource_type)==2,"draw_light":float(case.light)}
			var actual=app.creep_body_tint(e)
			var rgba=primary[0].rgba
			for i in range(4):check(actual[i]==Vector2(rgba[i],0).x,"original normal primary-body GL color type"+str(case.resource_type))
			primary_draws+=1
		flagged_draws+=case.calls.filter(func(call):return call.method=="missile").size()
	check(primary_draws==96,"all96 supplied normal-body primary color branches consumed")
	check(flagged_draws>0 and body.disabled_calls.is_empty(),"complete body reference retains flagged missiles and global disabled guard; routing is separate work")
	var content=root.get_node("Content")
	var authored=0;var defaults=0
	for map in content.maps.values():
		if not map.has("cells"):continue
		for cell in map.cells:
			if cell.has("l"):authored+=1
			else:defaults+=1
			check(Light.sample(cell,cell,0.5)==Vector2(float(cell.get("l",1)),0).x,"authored/default light survives import")
	check(authored==2350 and defaults>20000,"all2350 authored light cells and omitted-light cells covered")
	# Exercise the real simulation bridge with a stationary enemy. The
	# original prefix reads light even at speed0, independent of sprite Y.
	var mission=content.mission("1");var map=content.maps[mission.map].duplicate(true)
	var a=Vector2i(4,4);var b=Vector2i(4,5)
	map.cells[a.y*int(map.hex_width)+a.x].l=0.3;map.cells[b.y*int(map.hex_width)+b.x].l=1.0
	app.sim.setup(content.catalog,map,mission,{},114,content.animations);app.sim.spawn_hold=true
	var enemy=app.sim.spawn_enemy(1,0,"",1001,false)
	check(enemy.draw_light==1,"new enemy starts with the source constructor's light")
	enemy.cell=a;enemy.next_cell=b;enemy.path=[a,b];enemy.path_at=1;enemy.move_progress=0.5;enemy.speed=0
	app.sim.advance(30)
	check(enemy.draw_light==Vector2(0.6499999761581421,0).x,"stationary simulation retains actual source halfway light")
	enemy.air=true
	check(app.creep_body_tint(enemy).r==enemy.draw_light,"temporary levitation cannot turn a ground resource's body white")
	app.free()
	var report={"checks":checks,"failures":failures,"original_light_cases":reference.cases.size(),"original_body_cases":body.cases.size(),"primary_body_draws":primary_draws,"authored_light_cells":authored,"default_light_cells":defaults,"limit":"Normal primary body tint and light interpolation only. Existing freeze approximation, additive/screen status overlays, full animator/GPU, other owner passes and health bars remain open."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-light-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_LIGHT_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

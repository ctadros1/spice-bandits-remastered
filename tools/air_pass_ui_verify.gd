extends SceneTree
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-air-pass-reference.json")))
	var app=load("res://scripts/main.gd").new()
	app.sim=load("res://scripts/simulation.gd").new()
	app.sim.map={"foreground":[]}
	var callbacks=0
	for case in reference.cases:
		app.sim.enemies.clear()
		for i in range(case.types.size()):
			# Types0/3 exercise the original air guard only. The game resource
			# catalog contains ground1/air2, and never spawns these placeholders.
			app.sim.enemies.append({"id":i,"pos":Vector2(0,100-i*10),"native_air":int(case.types[i])==2})
		var expected=[]
		for call in case.output:
			callbacks+=1
			if call["pass"]=="body":expected.append(int(call.label))
		check(app.battle_air_objects().map(func(e):return e.id)==expected,"air body vector matches original routing "+str(case.types))
		check(app.battle_objects().all(func(o):return not app.uses_air_pass(o.enemy)),"air bodies are absent from sorted ground list")
	check(callbacks==37 and reference.cases.size()==8,"all eight original cases/37 callbacks consumed; only body routing is reconstructed here")
	check(not app.uses_air_pass({"native_air":false,"air":true,"def":{"class":"air"}}),"temporary levitation does not reclassify ground resource")
	check(app.uses_air_pass({"native_air":true,"air":false,"def":{"class":"ground"}}),"temporary targeting state cannot demote an air resource")
	check(app.uses_air_pass({"def":{"class":"air"}}) and not app.uses_air_pass({}),"legacy fixtures fall back to declared resource class")
	var content=root.get_node("Content")
	var mission=content.mission("1")
	app.sim=load("res://scripts/simulation.gd").new()
	app.sim.setup(content.catalog,content.maps[mission.map],mission,{},114,content.animations)
	var populated=0
	for type in range(content.catalog.tower_creeps.size()):
		var definition=content.catalog.tower_creeps[type]
		if not definition.has("filename"):continue
		var e=app.sim.spawn_enemy(type,0,"",1000+type,false)
		check(not e.is_empty(),"spawn populated resource "+str(type))
		if e.is_empty():continue
		var native_air=definition.get("class","ground")=="air"
		check(app.uses_air_pass(e)==native_air,"spawned resource has original ground/air class "+str(type))
		e.air=not native_air
		check(app.uses_air_pass(e)==native_air,"targeting state leaves resource drawing pass unchanged "+str(type))
		populated+=1
	check(populated==29,"all29 populated enemy resources covered")
	var airborne=app.sim.enemies.filter(func(e):return e.native_air)
	check(app.battle_air_objects().map(func(e):return e.id)==airborne.map(func(e):return e.id),"spawned aircraft retain manager insertion order regardless of Y")
	check(app.battle_objects().filter(func(o):return o.has("enemy")).size()+airborne.size()==29,"each spawned body appears in exactly one ground/air pass")
	app.free()
	var report={"checks":checks,"failures":failures,"populated_resources":populated,"original_cases":reference.cases.size(),"original_callbacks":callbacks,"method":reference.method,"limit":"Body partition/vector order only. Preview, selection, before/after callbacks, mutable ground registry and original pixels remain separate work."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/air-pass-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("AIR_PASS_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

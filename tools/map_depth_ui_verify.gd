extends SceneTree
const Depth=preload("res://scripts/map_depth.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-map-depth-reference.json")))
	for case in reference.dimensions:
		check(case.output==[case.width,case.height],"original animation constructor retains untrimmed resource dimensions")
	for case in reference.declarations:
		var resource={"states":{"Idle":{"res_id":1}},"resources":{"1":{"frame_height":case.height}},"params":{}}
		if not case.animation:resource.resources.clear()
		if case.override!=null and case.resource:resource.params.depth_pos=case.override
		check(Depth.tower_height(resource)==case.output,"original tower constructor retains animation height unless integer override supplied")
	for case in reference.positions:
		check(Depth.top(case.center[1],case.height)==int(case.output.depth_top),"original tower depth truncation including fractional/negative/large positions")
		check(Vector2(case.output.animator[0],case.output.animator[1])==Vector2(case.center[0],Depth.f32(Depth.f32(case.center[1])-7)),"depth sorting leaves original visual centerY minus seven unchanged")
		check(case.output.light==(1.0 if case.light==null else case.light),"original placement retains default or supplied cell lighting")
	for case in reference.comparisons:
		check((Depth.key(int(case.a[0]),case.a[1])<Depth.key(int(case.b[0]),case.b[1]))==case.output,"original strict float32 comparator including ties")
	for case in reference.upgrades:
		check(case.output.height==case.old_height and case.output.current_animation==0,"original upgrade Init clears animation before height-copy guard and retains construction height")
	var content=root.get_node("Content")
	var forms=0
	for type in range(1,19):
		for level in range(1,4):
			var definition=content.tower(type,level)
			var resource=content.animations["towers/"+str(definition.filename)]
			var resource_heights=[]
			for source in resource.resources.values():resource_heights.append(float(source.frame_height))
			check(resource_heights.size()==1,"all54 current tower forms have one unambiguous source frame height")
			check(Depth.tower_height(resource)==resource_heights[0],"all54 tower forms use the untrimmed authored height")
			forms+=1
	check(forms==54,"all54 tower forms covered")
	var app=load("res://scripts/main.gd").new()
	app.sim=load("res://scripts/simulation.gd").new()
	app.sim.map={"foreground":[]}
	app.sim.towers.assign([{"id":1,"def":content.tower(1,1),"pos":Vector2(200,200)},{"id":2,"def":content.tower(5,1),"pos":Vector2(220,200)}])
	app.sim.enemies.assign([{"id":3,"pos":Vector2(210,230)}])
	var objects=app.battle_objects()
	check(objects.size()==3 and objects[0].get("tower",{}).get("id")==2 and objects[1].has("enemy") and objects[2].get("tower",{}).get("id")==1,"actual battle draw list uses different authored heights around a crossing enemy")
	check(objects[0].y==205 and objects[2].y==243,"actual battle list no longer sorts both towers at their common200px cell center")
	app.sim.towers[0].pos.y=250
	check(app.tower_depth(app.sim.towers[0])==293,"cached tower depth invalidates when the position changes")
	app.sim.towers[0].def=content.tower(5,1)
	check(app.tower_depth(app.sim.towers[0])==255,"cached fixture depth invalidates when its construction resource changes")
	app.sim=load("res://scripts/simulation.gd").new()
	var mission=content.mission("1")
	var unlocked=[]
	for kind in content.catalog.tower_towers:
		for level in kind.get("levels",[]):
			if level.has("unlock"):unlocked.append(str(level.unlock))
	app.sim.setup(content.catalog,content.maps[mission.map],mission,{"unlocks":unlocked},114,content.animations)
	app.sim.money=100000
	var built_error=app.sim.build(Vector2i(7,4),7)
	check(built_error.is_empty(),"source fixture builds original root ShockGun: "+built_error)
	if not app.sim.towers.is_empty():
		var built=app.sim.towers[0]
		var initial_depth=Depth.tower(built.pos.y,content.animations["towers/tower7_1"])
		for target in [[7,2],[7,3],[8,1]]:
			check(app.sim.upgrade_tower(built.id,target[0],target[1]).is_empty(),"source fixture follows legal electrical upgrade branch")
			check(built.depth_filename=="tower7_1","upgrading retains the construction depth resource despite changed art heights")
			check(app.battle_objects().filter(func(o):return o.has("tower"))[0].y==initial_depth,"actual upgraded tower keeps original62px construction height")
	app.free()
	var report={"checks":checks,"failures":failures,"forms":forms,"method":reference.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/map-depth-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAP_DEPTH_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

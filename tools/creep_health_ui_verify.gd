extends SceneTree
const Health=preload("res://scripts/creep_health_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-health-reference.json")))
	var drawn=0
	for case in reference.cases:
		var health=Health.layout(Vector2(case.animator_point[0],case.animator_point[1]),case.hp,int(case.max_hp),case.alpha,int(case.state),Vector2(32,16),Vector4(case.uv[0],case.uv[1],case.uv[2],case.uv[3]))
		var background=case.calls.filter(func(c):return c.method=="health-background")
		var fill=case.calls.filter(func(c):return c.method=="health-fill")
		check(health.is_empty()==background.is_empty(),"original HP/state guard")
		if health.is_empty():continue
		drawn+=1
		check(background.size()==1 and fill.size()==1,"original background then fill draws")
		check(health.origin==Vector2(background[0].point[0],background[0].point[1]),"original animator anchor")
		var values=fill[0].geometry_uv
		var actual=[health.fill.position.x,health.fill.position.y,health.fill.size.x,health.fill.size.y,health.uv.x,health.uv.y,health.uv.z,health.uv.w]
		for i in range(8):check(actual[i]==Vector2(values[i],0).x,"original float32 width/quad/UV"+str(i))
		for i in range(4):check(health.premultiplied[i]==Vector2(fill[0].rgba[i],0).x,"original premultiplied RGBA"+str(i))
	check(drawn==180,"all180 original damaged visible branches consumed")
	var content=root.get_node("Content")
	for color in ["red","green"]:check(content.tex("assets/creeps/life_bar_"+color+".png").get_size()==Vector2(32,16),"preserved health texture dimensions")
	var app=load("res://scripts/main.gd").new();app.sim=load("res://scripts/simulation.gd").new()
	var enemy={"pos":Vector2(200,200),"visual_pos":Vector2(210,230),"def":{"traits":{"offset":[3,-4]}},"float_until":1000,"hp":25,"max_hp":100,"grow_ms":200,"state":0}
	var result=app.creep_health_layout(enemy)
	check(result.origin==Vector2(197,212),"actual renderer uses drawn position, resource offset and levitation lift")
	check(result.fill.size==Vector2(8,16),"actual renderer crops eight pixels without scaling the texture height")
	check(result.color==Color(1,1,1,0.5),"actual renderer uses existing original linear growth alpha")
	app.sim.clock_ms=1000;enemy.grow_ms=400
	check(app.creep_health_layout(enemy).origin==Vector2(197,242),"bar follows restored animator after lift expiry")
	enemy.hp=100;check(app.creep_health_layout(enemy).is_empty(),"full health draws no bar")
	app.free()
	var report={"checks":checks,"failures":failures,"original_cases":reference.cases.size(),"drawn_cases":drawn,"limit":"Original full Render condition/geometry/RGBA/UV with supplied records. Existing growth and lift bridge verified; complete portal/state lifetime, texture loader and original GPU remain open."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-health-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_HEALTH_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
const Depth=preload("res://scripts/map_depth.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-magic-depth-reference.json")))
	for c in reference.declarations:
		var state="Idle" if c.kind=="mine" else "Blue"
		var resource={"states":{state:{"res_id":1}},"resources":{"1":{"frame_height":c.height}},"params":{"depth_pos":17}}
		if not c.animation:resource.resources.clear()
		check(Depth.effect_height(resource,state)==c.output.height,"full original constructor retains effect height without draw scale/depth_pos")
		check(c.output.registered.size()==1 and c.output.registered[0].actor==0 and c.output.registered[0].height==c.output.height,"full original constructor registers retained height")
	for c in reference.positions:
		var h=float(c.output.declaration.height)
		check(Depth.top(c.center[1],h,0)==int(c.output.top),"original full cell/mouse position float32 top")
		check(c.output.point==c.output.animator,"original cell and mouse methods write identical animator position")
		check(Depth.key(int(c.output.top),h)==SpiceNative.creep_depth(c.output.point[1],h),"shared native depth arithmetic matches original mine/portal key")
		check(c.output.light==1 if c.kind=="portal" or c.cell_light==null else c.output.light==c.cell_light,"original mine samples cell light; portal preserves its constructor light")
	var content=root.get_node("Content")
	check(Depth.effect_height(content.animations["sfx/mine"],"Idle")==34,"preserved Mine initial untrimmed height")
	check(Depth.effect_height(content.animations["sfx/portals"],"Blue")==82,"preserved Portal initial untrimmed height independent preview scale")
	var routing=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-magic-route-reference.json")))
	var app=load("res://scripts/main.gd").new()
	for c in routing.cases:
		app.sim=load("res://scripts/simulation.gd").new();app.sim.map={"foreground":[]}
		var points=[]
		for i in range(c.actors.size()):
			var a=c.actors[i];var point=Vector2(200,float(a.top)+float(a.height)*0.5);points.append(point)
			if a.kind=="mine":app.sim.mines.append({"id":i,"pos":point})
			elif a.kind=="portal":app.sim.portals.append({"pos":point})
			elif a.kind=="ground":app.sim.enemies.append({"id":i,"pos":point,"native_air":false,"def":content.catalog.tower_creeps[1]})
		var expected=[];var portals=[]
		for call in c.output.calls:
			if call.get("method")=="mine-body" or call.get("pass")=="body" and c.actors[int(call.label)].kind=="ground":expected.append(int(call.label))
			if call.get("method")=="portal-before":portals.append(points[int(call.label)])
		var actual=app.battle_objects().filter(func(o):return o.has("mine") or o.has("enemy")).map(func(o):return int(o.get("mine",o.get("enemy",{})).id))
		check(actual==expected,"actual mine/ground body ordering matches original preserved vtables")
		check(app.battle_portal_objects().map(func(p):return p.pos)==portals,"portal art follows original registered-before depth order")
	app.free()
	var report={"checks":checks,"failures":failures,"original_constructors":reference.declarations.size(),"original_positions":reference.positions.size(),"original_route_cases":routing.cases.size(),"limit":"Full supplied original constructors/positions/routing with explicit effect/hex/drawing stubs. Runtime depth/partition bridge only; original texture loading, mutable equal-depth registration, full portal growth/expiry/particle lifetime and GPU remain open."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/magic-depth-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAGIC_DEPTH_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
const Depth=preload("res://scripts/map_depth.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-depth-reference.json")))
	for case in reference.declarations:
		var resource={"states":{"RunDownRight":{"res_id":1}},"resources":{"1":{"frame_height":case.height}},"params":{}}
		if not case.animation:resource.resources.clear()
		if case.override!=null and case.resource:resource.params.depth_pos=case.override
		check(Depth.creep_height(resource)==case.output,"original creep constructor retains RunDownRight height or integer override")
	for case in reference.positions+reference.attacks:
		var output=case.output
		check(Depth.top(output.animator[1],case.height,0)==int(output.depth_top),"original full position/corner or attack-copy depth truncates drawn Y minus half height")
		check(SpiceNative.creep_depth(output.animator[1],case.height)==Depth.key(int(output.depth_top),case.height),"native drawing hot path matches original top and strict float32 map key")
		check(output.blending_animator==output.animator,"original main/blending animators share their depth position")
	var content=root.get_node("Content")
	var populated=0
	for definition in content.catalog.tower_creeps:
		if not definition.has("filename"):continue
		var resource=content.animations["creeps/"+str(definition.filename)]
		var initial=resource.states.get("RunDownRight",{})
		check(not initial.is_empty(),"every populated creep has its original constructor animation")
		var source=resource.resources[str(int(initial.res_id))]
		check(Depth.creep_height(resource)==float(resource.params.get("depth_pos",source.frame_height)),"all29 current creep declarations use original untrimmed height independently of draw scale")
		populated+=1
	check(populated==29,"all29 populated resources covered")
	var app=load("res://scripts/main.gd").new()
	app.sim=load("res://scripts/simulation.gd").new();app.sim.map={"foreground":[]}
	var marine={"id":1,"def":content.catalog.tower_creeps[1],"pos":Vector2(200,200),"visual_pos":Vector2(210,230),"native_air":false,"air":false}
	app.sim.enemies.assign([marine])
	app.sim.towers.assign([{"id":2,"def":content.tower(1,1),"pos":Vector2(200,200)}])
	check(app.creep_depth(marine)==249,"actual Marine38px depth uses drawn230px Y rather than logical200px Y")
	var ordered=app.battle_objects()
	check(ordered.size()==2 and ordered[0].has("tower") and ordered[1].has("enemy"),"actual ground list includes creep height around a crossing Minigun")
	marine.visual_pos.y=230.875
	check(app.creep_depth(marine)==249,"fractional creep depth keeps original truncation")
	marine.visual_pos.y=231
	check(app.creep_depth(marine)==250,"cached height still recomputes moving depth every draw")
	marine.def=content.catalog.tower_creeps[5]
	check(app.creep_depth(marine)==281,"different resource switches to its100px height")
	marine.air=true;marine.float_until=1000
	check(app.creep_depth(marine)==281 and app.battle_air_objects().is_empty(),"levitation lift and targeting class leave original ground depth unchanged")
	app.free()
	var report={"checks":checks,"failures":failures,"declarations":reference.declarations.size(),"positions":reference.positions.size(),"attacks":reference.attacks.size(),"populated_resources":populated,"method":reference.method,"limit":"Height/top/key and supplied original position records. Complete birth/update order, global jitter RNG, all animator/rendering and mutable map registry remain open."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-depth-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_DEPTH_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var content=root.get_node("Content");var app=load("res://scripts/main.gd").new()
	var mission=content.mission("8");app.sim=load("res://scripts/simulation.gd").new();app.sim.setup(content.catalog,content.maps[mission.map],mission,root.get_node("Profile").fresh(),185,content.animations)
	for progress in [0.55,0.7,0.8,0.05,0.2]:
		for e in app.sim.enemies:app.sim.particle_state.destroy_creep(e)
		app.sim.enemies.clear()
		for i in range(5):
			var e=app.qa_turn_actor(i,progress);var label=str([progress,e.type])
			check(e.state==0 and not e.attacking and e.normal_position_written and not e.normal_boundary,"supplied walking context "+label)
			check(e.move_progress==progress,"supplied progress "+label)
			check(e.move_target==app.sim.center(e.next_cell.x,e.next_cell.y),"supplied target "+label)
			check(e.visual_layers[0].state==("RunDown" if progress==0.55 else "RunDownRight" if progress==0.2 else "TurnDownRight"),"actual primary name "+label)
			if progress in [0.55,0.05]:check(float(e.visual_layers[1].alpha)>0,"actual blend "+label)
			if progress in [0.8,0.05,0.2]:check(not e.visual_pos.is_equal_approx(e.pos),"actual corner projection "+label)
			app.probe_creep_layers=true;app.creep_layer_usage={"cached":0,"reference":0};app.creep_layer_actor_ids={"cached":{},"reference":{}}
			app.reference_creep_layers=false;app.creep_layers(e,{})
			app.reference_creep_layers=true;app.creep_layers(e,{"RunDown":{},"RunDownRight":{},"TurnDownRight":{}})
			check(app.creep_layer_usage=={"cached":1,"reference":1},"both selectors exercised "+label)
			check(app.creep_layer_actor_ids.cached.keys()==[int(e.id)] and app.creep_layer_actor_ids.reference.keys()==[int(e.id)],"actual actor identity "+label)
	for e in app.sim.enemies:app.sim.particle_state.destroy_creep(e)
	app.sim.enemies.clear();app.free()
	var result={"checks":checks,"failures":failures,"actors":25,"scope":"Actual Main synthetic mid-corner input setup and cached/reference actor-ID instrumentation; no GPU draw or original-device equivalence."}
	var f=FileAccess.open("res://../builds/turn-pose-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();print("TURN_POSE ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

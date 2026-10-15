extends SceneTree
const Hex=preload("res://scripts/build_hex_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-selection-reference.json")))
	var app=load("res://scripts/main.gd").new()
	app.sim=load("res://scripts/simulation.gd").new()
	app.sim.map={"hex_h":62}
	var ovals=0
	for case in reference.cases:
		app.sim.towers.assign([{"id":1,"pos":Vector2(120,170),"def":{"range":2000}}])
		app.selected_tower=1
		if not case.flags.get("panel",true) or not case.flags.get("visible",true):app.selected_tower=-1
		if not case.flags.get("tower",true):app.sim.towers.clear()
		if not case.flags.get("resource",true):app.sim.towers[0].def={}
		app.tower_panel_close_at=0;app.elapsed_ui=(1.0-case.alpha)*0.4
		var selected=case.output.filter(func(call):return int(call.label)==0)
		var pose=app.selected_range_pose()
		check(pose.is_empty()==selected.is_empty(),"selected display follows recovered panel/tower/resource guards")
		if not pose.is_empty():
			check(pose.position==Vector2(120,170),"selected oval uses logical cell center rather than animatorY minus7")
			check(pose.draws.size()==selected[0].ovals.size(),"actual selected range submits original fill and three outlines")
			for i in range(pose.draws.size()):
				var expected=selected[0].ovals[i];var actual=pose.draws[i]
				check(actual.filled==expected.filled and actual.axes.distance_to(Vector2(expected.axes[0],expected.axes[1]))<0.00001,"actual selected oval retains original order and dimensions")
				check(actual.color.is_equal_approx(Color(expected.color[0],expected.color[1],expected.color[2],expected.color[3])),"actual selected fill/outline colors follow original panel alpha")
		# Inactive guard/caller routing is source evidence only here. Its
		# nonzero supply bonus also independently checks shared oval math.
		for call in case.output:
			var label=int(call.label)
			var draws=Hex.oval(call.alpha,Hex.f32(0.062),2000+label*500,label*125,label!=3)
			check(draws.size()==call.ovals.size(),"original selected/inactive caller oval counts")
			for i in range(draws.size()):
				var expected=call.ovals[i];var actual=draws[i]
				check(actual.axes.distance_to(Vector2(expected.axes[0],expected.axes[1]))<0.00001,"original selected/inactive range plus supplied bonus dimensions")
				check(actual.color.is_equal_approx(Color(expected.color[0],expected.color[1],expected.color[2],expected.color[3])),"original selected/inactive shared color and fade")
				ovals+=1
	check(reference.cases.size()==40 and ovals==112,"all40 original routing cases/112 oval submissions covered")
	app.free()
	var report={"checks":checks,"failures":failures,"original_cases":reference.cases.size(),"ovals":ovals,"method":reference.method,"limit":"Selected range shape/alpha/guards and shared oval arithmetic. Supply bonus integration, complete panel clocks, original raster and other owner passes remain open."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/selection-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SELECTION_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

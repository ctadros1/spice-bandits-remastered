extends SceneTree
var app
var checks=0
var failures=[]
var observed=[]
func check(value:bool,name:String):
	checks+=1
	if not value:failures.append(name);push_error(name)
func wait_for_screen(target:String) -> void:
	var limit=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<limit:
		var value=app.screen+":"+str(app.transition.phase)+":"+app.loading_kind
		if observed.is_empty() or observed.back()!=value:observed.append(value)
		if app.screen==target and app.transition.phase==3:return
		await process_frame
	check(false,"scene flow completed within15 seconds: "+target)
func _initialize():run.call_deferred()
func run():
	await process_frame
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app)
	var profile=root.get_node("Profile");profile.data=profile.fresh();profile.data.settings.music=false;profile.data.settings.sound=false
	check(app.test_session and profile.path!="user://profile.json","scene flow uses an isolated profile")
	check(app.original_transitions_enabled(),"scene flow exercises production transitions")
	app.start_mission("1",true,false)
	await wait_for_screen("game")
	check(app.tutorial!=null and app.tutorial.page==0 and app.sim.towers.is_empty() and app.sim.money==200,"arrival opens the untouched tutorial after revealing the map")
	check(observed.has("loading:2:arrival") and observed.has("loading:3:arrival"),"arrival is both revealed and held")
	app.navigate("world")
	await wait_for_screen("world")
	check(observed.has("loading:2:departure") and observed.has("loading:3:departure"),"departure is both revealed and held")
	check(app.screen=="world" and app.transition.phase==3,"departure returns to an interactive world map")
	var data={"checks":checks,"failures":failures,"observed":observed,"fixture":"Real asynchronous scene changes and original transitions with isolated QA data; no original device parity."}
	var file=FileAccess.open("res://../builds/scene-flow-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	print("SCENE_FLOW_VERIFICATION ",JSON.stringify(data));quit(0 if failures.is_empty() else 1)

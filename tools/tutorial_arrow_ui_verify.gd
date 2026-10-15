extends SceneTree
var checks=0
var failures=[]
func check(value:bool,name:String):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():run.call_deferred()
func run():
	var reference=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-tutorial-arrow-reference.json"))
	var profile=root.get_node("Profile");profile.data=profile.fresh();profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	app.start_mission("1",true,false);app.tutorial.pose(3)
	for c in reference.cases:
		if int(c.device)!=2 or not c.landscape:continue # Selected fixed iPad canvas.
		app.sim.towers.clear()
		for i in range(4):
			if int(c.built_mask)&(1<<i):app.sim.towers.append({"cell":Vector2i(reference.cells[i][0],reference.cells[i][1])})
		var layout=app.TutorialView.layout(app)
		var objects=c.result.objects
		var arrows=layout.images.filter(func(image):return "line_pointer_" in image.path)
		check(arrows.size()==int(objects.drag_arrow_landscape.image_visible),"original tablet shows one landscape arrow only before any tower exists")
		check(not arrows.any(func(image):return image.path.ends_with("line_pointer_0.png")),"portrait orientation arrow stays hidden on the fixed iPad canvas")
		var anchor=app.ClassicUI.dock_origin(app)
		var pirate=layout.images.filter(func(image):return image.path.ends_with("SPCBRD1.png"))[0]
		var bubble=layout.images.filter(func(image):return image.path.ends_with("bubble1.png"))[0]
		check(pirate.rect.position-anchor==Vector2(objects.a_pirate.image_position[0],objects.a_pirate.image_position[1]),"original tablet pirate dock anchor")
		check(bubble.rect.position-anchor==Vector2(objects.a_pirate_bubble.image_position[0],objects.a_pirate_bubble.image_position[1]),"original tablet build bubble dock anchor")
		check(layout.labels[0].rect.position-anchor==Vector2(objects.a_pirate_txt.text_position[0],objects.a_pirate_txt.text_position[1]),"original tablet instruction text dock anchor")
		check(app.tutorial.markers(app.sim).size()==4-app.sim.towers.size(),"only unbuilt requested hexes retain their marker")
	app.sim.towers.clear();app.queue_free();await process_frame
	print("TUTORIAL_ARROW_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures,"limit":"16 native tablet landscape tower-presence states; original texture construction and renderer are stubbed."}))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
var checks=0
var failures=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-tutorial-layout-reference.json")))
	if reference==null:push_error("Original tutorial layout fixture is missing.");quit(1);return
	var profile=root.get_node("Profile");profile.data=profile.fresh();profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	app.start_mission("1",true,false);app.sim.towers.clear()
	app.sim.bases[0].pos=Vector2(500,400);app.sim.sources[0].pos=Vector2(100,200)
	var cash_width=app.font.get_string_size("$200",HORIZONTAL_ALIGNMENT_LEFT,-1,25).x
	var spice_width=app.font.get_string_size("0sp",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	var anchors={"base":Vector2(500,400),"source":Vector2(100,200),"dock":Vector2(321,702),"wallet":Vector2(1024-160-spice_width-6-cash_width,3)}
	for sample in reference.cases:
		if int(sample.device)!=2:continue
		check(sample.camera_requests.is_empty(),"original tablet page has no phone-only camera request")
		for scale in [0.75,1.0,1.25]:
			app.zoom=scale;app.camera=Vector2(800,600);app.tutorial.pose(int(sample.page));app.tutorial.hint_visible=false
			var layout=app.TutorialView.layout(app)
			var expected=sample.objects.values().filter(func(item):return item.visible)
			check(layout.gl_items.size()==expected.size(),"original page's initial visible GL item count")
			for key in sample.objects:
				var original=sample.objects[key]
				if not original.visible:continue
				var items=layout.gl_items.filter(func(item):return item.id==key)
				check(items.size()==1,"original object identity "+key)
				if items.is_empty():continue
				var item=items[0]
				var position:Vector2=anchors[original.anchor] if original.anchor!=null else Vector2(original.absolute[0],original.absolute[1])
				position+=Vector2(original.offset[0],original.offset[1])
				check(item.native_rect.position.distance_to(position)<0.0001,"original attached/absolute object offset "+key)
				var projection=app.map_origin()+position*app.map_scale() if original.world else position
				check(item.rect.position.distance_to(projection)<0.0001,"original world or screen projection "+key)
				check(item.phase==("terrain" if original.world and original.below_objects else "before_hud" if original.world else "screen"),"original three render passes "+key)
				if original.kind=="image":
					check(item.path=="assets/"+original.path and item.native_rect.size==Vector2(original.size[0],original.size[1]),"original image and dimensions "+key)
					check(item.rect.size==item.native_rect.size*(app.map_scale() if original.world else 1.0),"world projection scales complete pointer/marker art "+key)
					check(item.flip_h==original.flip_h and item.flip_v==original.flip_v,"original UV mirroring request "+key)
					var geometry=app.TutorialView.image_geometry(item.native_rect,item.flip_h,item.flip_v)
					var corner_a:Vector2=geometry.transform*geometry.rect.position
					var corner_b:Vector2=geometry.transform*geometry.rect.end
					check(Vector2(minf(corner_a.x,corner_b.x),minf(corner_a.y,corner_b.y))==item.native_rect.position and Vector2(maxf(corner_a.x,corner_b.x),maxf(corner_a.y,corner_b.y))==item.native_rect.end,"mirrored image keeps original bounds without an extra width/height translation "+key)
				else:
					check(item.value==original.text and item.size==original.font_size,"original localized text and point size "+key)
					check(item.native_rect.size==Vector2(original.bounds[0],original.bounds[1]),"original constructor text bounds "+key)
	for sample in reference.uv_cases:check(sample.mirrored==(int(sample.argument)==0),"original SetFlip(false) reverses UV endpoints; true restores normal orientation")
	app.zoom=1.0;app.tutorial.pose(6);app.tutorial.hint_visible=false
	check(app.TutorialView.layout(app).images.filter(func(item):return item.path.ends_with("build_here.png")).size()==3,"original first-upgrade page retains all three authored markers")
	for page in [7,9,10,11]:
		app.tutorial.pose(page);app.tutorial.hint_visible=false
		check(not app.TutorialView.layout(app).images.any(func(item):return item.path.ends_with("build_here.png")),"selected upgrade/sale pages have no invented build marker")
	app.tutorial.pose(3);app.refresh_controls()
	check(app.ui.get_children().all(func(node):return not node.has_meta("tutorial_gl")),"GL text is no longer rendered as UIKit-style labels over every layer")
	var before=app.get_children().filter(func(node):return node.get_script()!=null and node.get_script().resource_path=="res://scripts/tutorial_gl_layer.gd")
	check(before.size()==1 and before[0].get_index()<app.hud_layer.get_index(),"world callouts render below the original HUD/tray")
	check(app.map_underlay.get_children().any(func(node):return node.get_script()!=null and node.get_script().resource_path=="res://scripts/tutorial_gl_layer.gd"),"native below-object markers have an underlay renderer")
	app.queue_free();await process_frame
	var report={"checks":checks,"failures":failures,"method":reference.method+" Runtime projection/pass/bounds/visibility comparisons cover all18 tablet pages at three zooms. Font raster, wallet text measurement and original whole-app pixels remain separate limits."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/tutorial-layout-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TUTORIAL_LAYOUT_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

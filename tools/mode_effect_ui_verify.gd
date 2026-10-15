extends SceneTree
const ModeItem=preload("res://scripts/mode_item_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var constructor=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-mode-text-reference.json")))
	for case in constructor.cases:
		for i in range(case.texts.size()):
			var text=case.texts[i]
			if i<12:check(text.font=="KautivaPro-Bold" and text.size==(ModeItem.TITLE_SIZE if i<4 else ModeItem.PLAYER_COUNT_SIZE),"original title/player-count declarations")
			elif int(case.device_type)==2:
				check(text.size==ModeItem.CAPTION_SIZE,"original tablet description/points size16")
				if text.target==case.roles.description:
					var ink=ModeItem.caption_ink(0.8)
					for j in range(4):check(absf(ink[j]-text.color[j])<0.000001,"original description color")
		for shadow in case.shadows:
			check(shadow.written.enabled and shadow.written.blur==ModeItem.SHADOW_BLUR and shadow.written.intensity==ModeItem.SHADOW_INTENSITY,"original repeated blurred-shadow setter")
			check(shadow.written.colors.all(func(v):return v==1.0),"original white shadow/text underlay")
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-mode-effect-reference.json")))
	for case in reference.updates:
		var state=ModeItem.initial(case.opened)
		for frame in case.frames:
			ModeItem.advance(state,frame.dt_ms,Vector2(360,369),Vector2(51,-224))
			for key in frame.state:check(absf(state[key]-float(frame.state[key]))<0.000001,"original mode update "+key)
			var title=frame.colors.filter(func(c):return int(c.target)==8)
			check(title.size()==1 and absf(float(title[0].alpha)-float(ModeItem.render_pose(state,Vector2.ZERO,int(case.mode)).title_alpha))<0.000001,"locked title keeps native0.7 alpha")
			var ink=ModeItem.title_ink(int(case.mode),state.text_alpha)
			var actual_title=frame.colors.filter(func(c):return int(c.target)==(8 if int(case.mode)==1 else 20 if int(case.mode)==2 else 16))[0]
			var actual_shadow=frame.colors.filter(func(c):return int(c.target)==12)[0]
			var actual_caption=frame.colors.filter(func(c):return int(c.target)==64)[0]
			for i in range(4):
				check(absf(ink[i]-float(actual_title.rgba[i]))<0.000001,"original complete title ink")
				check(absf(ModeItem.shadow_ink(int(case.mode),state.text_alpha)[i]-float(actual_shadow.rgba[i]))<0.000001,"original black/white shadow ink")
				check(absf(ModeItem.caption_ink(state.text_alpha)[i]-float(actual_caption.rgba[i]))<0.000001,"original description ink")
	for case in reference.renders:
		var state=ModeItem.initial(case.opened)
		for key in ["phase","geometry_alpha","text_alpha","pulse_alpha"]:state[key]=case[key]
		var pose=ModeItem.render_pose(state,Vector2(411,145),int(case.mode),case.star)
		var plates=case.draws.filter(func(d):return d.kind=="plate")
		check(pose.plate_visible==not plates.is_empty(),"plate waits for completed outward move")
		if not plates.is_empty():
			var draw=plates[0]
			for i in range(4):check(absf(float(draw.values[i])-float([pose.plate_rect.position.x,pose.plate_rect.position.y,pose.plate_rect.size.x,pose.plate_rect.size.y][i]))<0.000001,"plate geometry")
			check(absf(draw.color[0]-pose.plate_alpha)<0.000001,"plate pulse")
			check(int(draw.texture_id)=={1:100,2:102,3:101}[int(case.mode)],"native black/orange/blue plate selection")
		var images=case.draws.filter(func(d):return d.kind=="image")
		check(Vector2(images[0].point[0],images[0].point[1])==pose.circle_rect.position,"circle origin")
		check(absf(images[0].color[0]-pose.circle_alpha)<0.000001,"circle opacity")
		check(Vector2(images[1].point[0],images[1].point[1])==pose.icon_rect.position,"icon origin")
		check(absf(images[1].color[0]-pose.icon_alpha)<0.000001,"half opacity locked icon")
		var title_target=20488 if int(case.mode)==1 else 20500 if int(case.mode)==2 else 20496
		var title=case.draws.filter(func(d):return d.kind=="text" and int(d.target)==title_target)[0]
		var subtitle=case.draws.filter(func(d):return d.kind=="text" and int(d.target)==20544)[0]
		check(Vector2(title.point[0],title.point[1])==pose.title_point,"native title point/star advance")
		check(Vector2(subtitle.point[0],subtitle.point[1])==pose.subtitle_point,"native subtitle point")
		if case.get("multiplayer",false):
			var counts=ModeItem.count_pose(Vector2(411,145),int(case.mode),case.star,float(case.title_width))
			var player_target=20504 if int(case.mode)==1 else 20516 if int(case.mode)==2 else 20512
			var online_target=20520 if int(case.mode)==1 else 20532 if int(case.mode)==2 else 20528
			for key in ["players","online","players_shadow","online_shadow"]:
				var target=player_target if key=="players" else online_target if key=="online" else 20508 if key=="players_shadow" else 20524
				var submitted=case.draws.filter(func(d):return d.kind=="text" and int(d.target)==target)[0]
				var expected:Vector2=counts[key]-(Vector2.ONE*4 if key.ends_with("shadow") else Vector2.ZERO)
				check(Vector2(submitted.point[0],submitted.point[1])==expected,"original count ink/shadow origin and completed-star asymmetry")
		if case.star:check(images.size()==3 and Vector2(images[2].point[0],images[2].point[1])==pose.star_rect.position,"native32px star before title")
	var profile=root.get_node("Profile");profile.data=profile.fresh();profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	await process_frame
	app.navigate("world",false);app.selected_location="2";app.fan_opened=-1;app.refresh_controls()
	var rows=app.ClassicUI.mode_rows(app)
	check(rows.map(func(r):return r.icon)==["norm","sd","air","cmp","coo","mp"],"six original icon families")
	for row in rows:check(row.rect.size==Vector2(364,98),"native hit area98px tall")
	var groups=app.ui.get_children().filter(func(n):return n.has_meta("fan_offset"))
	for group in groups:
		var mode=int(group.get_meta("fan_mode"));var children=group.get_children()
		var title=children.filter(func(n):return str(n.get_meta("mode_part",""))=="title")[0]
		var state=app.mode_states[group.get_meta("fan_index")];var pose=ModeItem.render_pose(state,group.get_meta("fan_point"),mode,group.get_meta("fan_star"))
		check(title.position==pose.title_point,"actual title control uses native point")
		var subtitle=children.filter(func(n):return str(n.get_meta("mode_part",""))=="subtitle")[0]
		check(subtitle.get_theme_font_size("font_size")==ModeItem.CAPTION_SIZE,"actual tablet caption uses native16pt")
		var row=rows.filter(func(r):return r.index==group.get_meta("fan_index"))[0]
		var counts=children.filter(func(n):return str(n.get_meta("mode_part",""))=="player_count")
		check(counts.size()==int(row.player_count>1),"static player-count control exists only for preserved multiplayer metadata")
		if row.player_count>1:
			check(counts[0].text=="2 players" and counts[0].get_theme_font_size("font_size")==14,"Desert retains original2-player metadata and14pt font")
			var width=app.bold.get_string_size(row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,ModeItem.TITLE_SIZE).x
			check(counts[0].position==ModeItem.count_pose(row.point,mode,row.star,width).players,"actual player count follows title width plus5")
			check(subtitle.text==root.get_node("Content").interface_tutorials.mode_texts.offline and not row.enabled,"original offline caption accompanies disabled multiplayer")
			check(not children.any(func(n):return str(n.get_meta("mode_part",""))=="online_count"),"offline mode clears online count rather than fabricating live service state")
		var shadow=children.filter(func(n):return str(n.get_meta("mode_part",""))=="title_shadow")[0]
		check(shadow.texture!=null and shadow.modulate.a==title.modulate.a,"preserved-font title underlay shares original title alpha")
		if mode==1:
			var icon=children.filter(func(n):return str(n.get_meta("mode_part",""))=="icon")[0]
			check(icon.texture!=null and icon.texture.resource_path.contains("derived/gray50"),"locked icon uses derived original50percent grayscale")
	app.queue_free();await process_frame
	var report={"checks":checks,"failures":failures,"method":"Original skipped-service animation/color blocks and Render GL submissions with explicit textures/metrics; actual runtime control placement. Original text raster, glow blur and whole service state remain outside scope."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/mode-effect-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MODE_EFFECT_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

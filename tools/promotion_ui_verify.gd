extends SceneTree
const View=preload("res://scripts/promotion_view.gd")
var checks=0
var failures=[]
func check(value:bool,name:String) -> void:
	checks+=1
	if not value:failures.append(name)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-promotion-reference.json")))
	for case in original.sequences:
		var state=View.initial()
		var requests=0
		for index in range(case.frames.size()):
			if case.close_at!=null and index==int(case.close_at) and View.close(state):requests+=1
			View.advance(state,case.frames[index].dt_ms)
			if case.click and not case.item_pressed and View.close(state):requests+=1
			for field in state:
				var expected=case.frames[index].state[field]
				check(state[field]==(expected if expected is bool else View.f32(expected)),"original promotion clock/flags "+field)
			check(requests==case.frames[index].menu_requests.size(),"original close request is emitted once")
	for case in original.renders:
		var size=Vector2(case.viewport[0],case.viewport[1])
		var positions=View.positions(size,case.title_width)
		check(View.origin(size)==Vector2(case.origin[0],case.origin[1]),"original tablet integer origin")
		for draw in case.draws:
			if draw.kind=="dim":
				check(absf(View.f32(case.alpha/3.0)-draw.rgba[3])<0.0000001,"original promotion dim alpha")
			elif draw.name!="rank":
				check(positions[draw.name]==Vector2(draw.point[0],draw.point[1]),"original promotion frame/text position "+draw.name)
				check(case.alpha==draw.alpha,"original promotion shared frame/text alpha")
	var profile=root.get_node("Profile")
	profile.path="user://verification/promotion-ui-profile.json";profile.data=profile.fresh();profile.read_only=false
	profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	app.navigate("world",false);app.guidance_type=0
	app.promotions.assign([{"kind":"promotion","level":2,"spice":5,"points":3}]);app.open_promotion()
	check(app.promotion_open and app.promotion_alpha()==0,"opening earned-notice control begins at zero alpha")
	app.advance_promotion(175);app.refresh_controls()
	check(app.promotion_alpha()==0.25,"actual controller advances the shared native clock")
	var panels=app.ui.get_children().filter(func(n):return n.has_meta("promotion_panel"))
	check(panels.size()==1 and panels[0].modulate.a==0.25,"actual promotion frame applies opening alpha")
	var ranks=panels[0].get_children().filter(func(n):return n.has_meta("promotion_rank"))
	check(ranks.size()==1 and ranks[0].position==Vector2(425,187) and ranks[0].size==Vector2(128,128) and ranks[0].texture.resource_path=="res://assets/2lt.png","first observed rank badge uses natural128px art and original anchor")
	check(View.observed_rank(3).is_empty(),"missing later server rank thresholds are not invented")
	check(View.rank_name(1)=="Cadet" and View.observed_rank(1)=="assets/cdt.png","initial observed rank uses preserved Cadet art")
	check(View.rank_name(2)=="2nd Lieutenant" and View.rank_name(3)=="Level 3","known first rank and explicit later numeric fallback")
	app.advance_promotion(525);app.refresh_controls()
	profile.read_only=true
	check(not app.dismiss_promotion(false) and app.promotion_open and not app.promotion_state.closing and app.promotions.size()==1,"failed acknowledgement preserves the dialog and does not start closing")
	profile.read_only=false
	check(app.dismiss_promotion(false) and app.promotion_open and app.promotion_state.closing and app.promotions.size()==1,"successful acknowledgement retains the closing frame")
	var acknowledged=profile.data.settings.promotion_seen
	app.open_promotion();app.dismiss_promotion(false)
	check(app.promotion_state.closing and app.promotion_state.phase==0 and profile.data.settings.promotion_seen==acknowledged,"repeated close/open cannot restart a closing notice or acknowledge twice")
	check(app.ui.get_children().any(func(n):return n is BaseButton and n.text=="Continue" and n.disabled),"closing overlay blocks repeated background activation")
	app.advance_promotion(350);app.refresh_controls()
	check(app.promotion_open and app.promotion_alpha()==0.5 and app.promotions.size()==1,"half-closed frame remains visible and queued")
	app.advance_promotion(350)
	check(not app.promotion_open and app.promotions.is_empty(),"700ms close releases the notice only after fade completion")
	app.queue_free();await process_frame
	var report={"checks":checks,"failures":failures,"method":original.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/promotion-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PROMOTION_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
const Portrait=preload("res://scripts/portrait_view.gd")
var checks=0
var failures=[]
func check(value:bool,name:String):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():run.call_deferred()
func run():
	var file=FileAccess.open("res://../tests/fixtures/native-portrait-fade-reference.json",FileAccess.READ)
	var reference=JSON.parse_string(file.get_as_text())
	for c in reference.cases:
		var r=c.result
		check(Portrait.DURATION==r.show.request.duration and Portrait.DURATION==r.remove.request.duration,"original show/remove duration")
		check(r.show.request.delay==0 and r.remove.request.delay==0 and r.show.request.options==0 and r.remove.request.options==0,"original immediate default UIKit requests")
		check(absf(Portrait.curve(0)-r.show.initial_alphas[0])<0.000001,"original initial alpha0")
		check(absf(Portrait.curve(1)-r.show.target_alpha)<0.000001,"original show target alpha1")
		check(absf(1-Portrait.curve(1)-r.remove.target_alpha)<0.000001,"original remove target alpha0")
	var touches=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-portrait-touch-reference.json"))
	for c in touches.cases:
		check(Portrait.tap_allowed(Vector2(c.start[0],c.start[1]),Vector2(c.end[0],c.end[1]),c.contains)==c.result.remove,"original float32 strict20-point dismissal")
	var closes=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-portrait-close-reference.json"))
	for c in closes.cases:
		var menus=c.result.events.filter(func(e):return e.has("menu"))
		check(Portrait.after_close_menu(int(c.kind))==(int(menus[0].menu) if not menus.is_empty() else 0),"original portrait completion destination")
	var profile=root.get_node("Profile");profile.data=profile.fresh();profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	var composition=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/ipad-portrait-composition-reference.json"))
	for case in composition.cases:
		var text=load("res://scripts/tutorial.gd").PROMPTS[int(case.page)] if int(case.page)<18 else "Great job cadet!\n\nPress \"To the map\" to return to the world map."
		var layout=app.TutorialView.portrait(app,text,case.top);var caption=layout.labels[0]
		check(caption.value=="\n".join(PackedStringArray(case.lines)),"observed iPad portrait line breaks page"+str(case.page))
		check(caption.rect.size==Vector2(case.column,composition.hint_height) and caption.size==composition.font_size,"observed composition keeps font size/height and selected column")
		check(caption.line_spacing==composition.line_spacing,"observed portrait leading")
		check(caption.rect.position.y==(50 if case.top else 458)+composition.y_offset,"observed portrait vertical placement")
		check(layout.images.filter(func(n):return n.path.ends_with("spicebeard_tutor_pirate.png"))[0].rect.size==Vector2(135,261),"portrait art keeps natural dimensions")
	app.start_mission("1",true,false)
	var guide=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/ipad-welcome-reference.json"))
	var welcome=app.desired_portrait.layout.labels[0]
	var expected="\n".join(PackedStringArray(guide.paragraph_lines))+"\n\n"+"\n".join(PackedStringArray(guide.continuation_lines))
	check(welcome.value==expected,"observed iPad Welcome line breaks without stretching font glyphs")
	check(welcome.rect.size==Vector2(guide.chosen_unstretched_column,guide.hint_height) and welcome.size==guide.font_size,"observed Welcome column retains authored height and font size")
	check(app.desired_portrait.layout.images.filter(func(n):return n.path.ends_with("spicebeard_tutor_pirate.png"))[0].rect.size==Vector2(135,261),"Welcome correction preserves portrait asset dimensions")
	check(app.portrait_view.layers.size()==1,"opening tutorial creates one portrait view")
	check(app.desired_portrait.layout.hit_rect.position.y==433+composition.y_offset and app.desired_portrait.layout.hit_rect.size.y==265,"portrait retains local hintView y-5 through260 at the observed panel origin")
	var layer=app.portrait_view.layers[0];var id=layer.id;var count=app.ui.get_child_count()
	check(layer.controls.filter(func(n):return n.has_meta("portrait_text")).all(func(n):return n.get_theme_constant("line_spacing")==composition.line_spacing),"actual portrait text renders the selected interline spacing")
	check(layer.controls.all(func(n):return n.modulate.a<0.000001),"portrait art and text start together at alpha0")
	check(layer.controls.filter(func(n):return n is Button).all(func(n):return n.disabled),"default UIKit opening disables its view's dismissal")
	app.portrait_view.advance(0.25)
	check(absf(app.portrait_view.alpha(layer)-0.5)<0.000001,"half-duration portrait pose")
	app.refresh_controls()
	check(app.portrait_view.layers.size()==1 and app.portrait_view.layers[0].id==id and app.portrait_view.layers[0].age==0.25,"HUD refresh preserves the existing portrait and its clock")
	check(app.ui.get_child_count()==count,"HUD refresh does not accumulate portrait labels or buttons")
	app.portrait_view.advance(0.25)
	check(layer.controls.filter(func(n):return n is Button).all(func(n):return not n.disabled),"completed portrait opening enables dismissal")
	app.acknowledge_tutorial()
	check(app.tutorial.page==1 and app.tutorial.display_page==0 and layer.closing and layer.age==0,"logical dismissal starts portrait removal before GL page swap")
	check(layer.controls.filter(func(n):return n is Button).all(func(n):return n.disabled),"closing portrait cannot be dismissed twice")
	app.portrait_view.advance(0.25)
	check(absf(app.portrait_view.alpha(layer)-0.5)<0.000001,"closing art and text retain the view until its completion")
	app.refresh_controls()
	check(app.portrait_view.layers.size()==1 and app.portrait_view.layers[0].closing,"pending GL page does not recreate the dismissed portrait")
	app.portrait_view.advance(0.25)
	check(app.portrait_view.layers.is_empty() and not app.ui.get_children().any(func(n):return n.has_meta("uikit_portrait")),"500ms removal releases its controls")
	app.tutorial.pose(6);app.tutorial.hint_visible=true;app.refresh_controls();app.portrait_view.advance(0.5)
	id=app.portrait_view.layers[0].id
	app.tutorial.pose(7);app.refresh_controls()
	check(app.portrait_view.layers.size()==1 and app.portrait_view.layers[0].id==id,"upgrade pointer page retains its preceding portrait")
	app.navigate("career",false);app.guidance_type=0;app.refresh_controls();app.portrait_view.advance(0.5)
	app.offer_guidance(5,true);app.refresh_controls();app.portrait_view.advance(0.5)
	app.dismiss_guidance()
	check(app.screen=="career" and app.guidance_type==0,"promotion guidance notifies dismissal before its menu routing")
	app.portrait_view.advance(0.499)
	check(app.screen=="career","closing promotion portrait delays navigation through499ms")
	app.portrait_view.advance(0.0011)
	check(app.screen=="shop" and app.menu_navigation_request.current==103,"500ms completion routes to original Tech Shop destination")
	var serial=app.portrait_view.serial
	app.portrait_view.advance(1)
	check(app.screen=="shop" and app.portrait_view.serial==serial,"completed portrait callback runs once")
	app.navigate("career",false);app.offer_guidance(6,true);app.refresh_controls();app.portrait_view.advance(0.5)
	app.dismiss_guidance();app.portrait_view.advance(0.25)
	check(app.screen=="career" and app.portrait_view.layers.any(func(l):return l.key=="guidance/6" and l.closing),"second promotion portrait closes before routing")
	app.portrait_view.advance(0.25)
	check(app.screen=="upgrades" and app.menu_navigation_request.current==104,"second promotion completion routes to original Upgrades Yard")
	app.portrait_view.clear();app.queue_free();await process_frame
	print("PORTRAIT_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures,"limit":"Native UIKit requests/endpoints plus reconstructed lifecycle; compositor and default easing are not original runtime comparisons."}))
	quit(0 if failures.is_empty() else 1)

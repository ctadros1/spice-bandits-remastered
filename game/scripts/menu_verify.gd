extends Node

signal completed(status: int)
var app
var finished = false
var checks = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var capture_root = ""
const TutorialDriver = preload("res://scripts/tutorial_verify.gd")
var input = TutorialDriver.new()

func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name);push_error(name)

func snapshot(name: String,settle_portrait:bool=true) -> void:
	# Menu galleries pose the independent UIKit-style view clock; they do
	# not advance a battle or claim equivalent recorded input timing.
	if settle_portrait:app.portrait_view.advance(0.5)
	if settle_portrait and app.screen=="upgrades":app.advance_upgrade_presentation(0.3)
	if capture_root.is_empty(): return
	app.queue_redraw()
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var path=capture_root.path_join(name+".png")
	var error=get_tree().root.get_texture().get_image().save_png(path)
	var record={"name":name,"error":error,"path":path.get_file()}
	if name.begins_with("level-up"):
		record["promotion_state"]=app.promotion_state.duplicate(true)
		record["screen"]=app.screen
		record["pending_promotions"]=app.promotions.size()
	if name=="world-observed-level2":record["profile_pose"]={"level":2,"xp":31,"spice":8,"points":3,"method":"temporary unsaved reference pose, not earned campaign progress"}
	if name.begins_with("main-menu-"):record["presentation_age"]=app.main_menu_view.age;record["eye_index"]=app.main_menu_view.eye_index;record["eye_amount"]=app.main_menu_view.eye_amount()
	if name.begins_with("main-menu-"):
		record["lamp_alpha"]=[]
		for tag in range(100,109):record.lamp_alpha.append(app.MenuFloatView.lamp_alpha(tag,app.menu_floats.age))
		record["play_rotation"]=app.menu_floats.pose(391).rotation
		record["next_note"]=app.menu_motion.next_note
		record["note_records"]=app.menu_motion.notes.filter(func(n):return n!=null).size()
	captures.append(record)
	check(error==OK,"packaged menu capture "+name)

func run() -> void:
	await get_tree().process_frame
	var profile=get_tree().root.get_node("Profile")
	profile.path="user://verification/menu-profile.json"
	profile.data=profile.fresh()
	profile.data.settings.music=false
	profile.data.settings.sound=false
	profile.read_only=false
	if app==null:
		app=load("res://scenes/main.tscn").instantiate()
		app.set_meta("qa_fixture",true)
		get_tree().root.add_child(app)
	app.set_process(false)
	app.qa_real_seconds=0.0
	input.app=app
	input.root=get_tree().root
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-menu-capture-root="):capture_root=arg.trim_prefix("--qa-menu-capture-root=")
	if not capture_root.is_empty():DirAccess.make_dir_recursive_absolute(capture_root)
	app.navigate("shop")
	check(app.ui.find_children("*","Label",true,false).any(func(n):return n.text=="Guns") and app.ui.find_children("*","Label",true,false).any(func(n):return n.text=="Missiles") and app.ui.find_children("*","Label",true,false).any(func(n):return n.text=="Chemical"),"Shop uses native level0 family names rather than level1 weapon names")
	check(app.ui.get_children().filter(func(n):return n.has_meta("original_tab")).size()==5,"original five navigation tabs appear in the shop")
	check(input.press("Map") and app.screen=="world","original Map tab opens the campaign")
	check(input.press("Career") and app.screen=="career","original Career tab opens saved progression")
	check(input.press("Upgrades yard") and app.screen=="upgrades","original Upgrades yard tab opens point allocation")
	check(input.press("Spice") and app.screen=="spicery","original Spice tab opens the offline service replacement")
	check(input.press("Tech shop") and app.screen=="shop","original Tech shop tab returns to its technology branches")
	app.offer_guidance(7,true);app.refresh_controls()
	check(app.guidance_type==7,"first shop invitation uses preserved executable text")
	await snapshot("shop-fresh")
	check(input.press("Dismiss guidance") and app.guidance_type==8,"shop introduction leads to the missile instruction")
	app.portrait_view.advance(0.5)
	check(input.press("Dismiss guidance") and app.guidance_type==0,"missile instruction can be dismissed without purchasing")
	check(app.shop_item_alpha("T2L1")==0.85 and absf(app.shop_item_alpha("T2L3")-0.55)<0.0001,"locked shop branches fade by the native0.15 step")
	check(input.press("Minigun mk3 level 3"),"original shop branch strip selects basic level3 technology")
	check(not input.press("Unlock Minigun mk3"),"fresh level1 cannot buy level3 technology")
	profile.data.level=3
	profile.data.spice=7
	app.refresh_controls()
	profile.read_only=true
	check(input.press("Unlock Minigun mk3"),"enabled technology unlock button receives a click")
	check(profile.data.spice==7 and not profile.unlocked("T1L3"),"failed shop save retains spice and locked technology")
	profile.read_only=false
	check(input.press("Unlock Minigun mk3"),"shop purchase succeeds when storage is available")
	check(profile.data.spice==0 and profile.unlocked("T1L3"),"original7-spice technology price and unlock are applied once")
	check(app.notice.is_empty() and app.notice_until==0,"successful recovery clears the failed-save message without an invented purchase banner")
	profile.load_profile()
	check(profile.unlocked("T1L3") and profile.data.spice==0,"purchased technology survives relaunch")
	await snapshot("shop-selected-owned")
	app.menu_scroll=1200
	app.refresh_controls()
	await snapshot("shop-support-branches")
	profile.data.level=3
	profile.data.specpoints=3
	app.navigate("spicery");app.guidance_type=0;app.refresh_controls()
	check(app.ui.get_children().any(func(n):return n is Label and n.text=="You must be online to use the Spice Shop"),"Spice Shop uses its original anonymous warning")
	check(not app.ui.get_children().any(func(n):return n.has_meta("spicery_source") and int(n.get_meta("spicery_source"))==129),"offline Spice Shop hides StoreKit product art")
	check(app.ui.get_children().filter(func(n):return n is Button and n.has_meta("spicery_source")).all(func(n):return n.disabled),"Spice Shop external actions remain unavailable offline")
	await snapshot("spicery-offline")
	app.spicery_catalog_fixture=true;app.refresh_controls()
	check(app.ui.get_children().any(func(n):return n is Label and n.text=="1800sp") and app.ui.get_children().any(func(n):return n.has_meta("spicery_source") and int(n.get_meta("spicery_source"))==129),"catalog fixture uses original four offers and200px source art")
	check(not app.ui.get_children().any(func(n):return n is Label and n.text.begins_with("$")),"unavailable localized store prices do not use NIB sample dollars")
	check(app.ui.get_children().filter(func(n):return n is Button and n.has_meta("spicery_source") and n.text=="Get it!").all(func(n):return n.get_theme_font_size("font_size")==18),"Spice Shop purchase captions retain their original18-point size")
	check(app.ui.get_children().any(func(n):return n is TextureRect and n.has_meta("lobby_footer_source") and n.texture.resource_path.ends_with("shop_info_panel_2.png")),"Spice Shop uses its original gold wallet skin")
	app.offer_guidance(24,true);app.refresh_controls()
	var guide=app.TutorialView.portrait(app,app.get_node("/root/Content").interface_tutorials.texts["24"],false)
	check(guide.labels.all(func(h):return app.font.get_multiline_string_size(h.value,HORIZONTAL_ALIGNMENT_LEFT,-1,h.size).y<=h.rect.size.y),"long original guidance stays inside its portrait text area")
	var portrait_labels=app.ui.get_children().filter(func(n):return n is Label and n.has_meta("portrait_text"))
	check(not portrait_labels.is_empty() and portrait_labels.all(func(n):return n.autowrap_mode==TextServer.AUTOWRAP_OFF and n.get_minimum_size().y<=guide.labels[0].rect.size.y),"rendered portrait labels keep the measured lines without a second wrapping pass")
	await snapshot("spicery-catalog")
	app.spicery_catalog_fixture=false
	app.navigate("upgrades")
	check(input.press("Range"),"original upgrade icon opens selection controls")
	check(input.press("+ Range"),"original plus button allocates a point")
	check(profile.data.specpoints==2 and profile.data.upgrades.up_range==1,"range allocation uses its native first-level cost")
	await snapshot("upgrades-selected")
	check(input.press("Refund Range"),"native minus button returns allocated points")
	check(profile.data.specpoints==3 and profile.data.upgrades.up_range==0,"minus returns the complete original point cost")
	check(not input.press("Refund Range"),"zero-level upgrade hides its minus button")
	var grid=app.ui.find_children("*","Control",true,false).filter(func(n):return n.has_meta("original_upgrade_grid"))[0]
	check(grid.get_parent().custom_minimum_size==Vector2(768,548)*app.menu_scale() and grid.get_parent().get_parent().position.y==164*app.menu_scale(),"upgrade grid uses the original164px top and four137px rows without added scroll padding")
	check(grid.get_children().size()==20 and grid.get_children().all(func(n):return n.position==app.UpgradeView.tablet(int(n.get_meta("upgrade_index"))).position*app.menu_scale()),"all20 upgrade items retain original five-column native positions")
	var native_labels=app.ui.find_children("*","Label",true,false).filter(func(n):return n.has_meta("upgrade_outlet"))
	check(native_labels.filter(func(n):return n.get_meta("upgrade_outlet")=="itemNameLabel").all(func(n):return n.get_theme_font_size("font_size")==21),"upgrade names retain original21pt single-line labels")
	check(native_labels.filter(func(n):return n.get_meta("upgrade_outlet")=="itemCountLabel").all(func(n):return n.get_theme_font_size("font_size")==13 and n.text=="Level 0/10"),"upgrade counts retain original13pt localized format")
	check(native_labels.any(func(n):return n.get_meta("upgrade_outlet")=="itemPanelDescriptionLabel" and n.text=="+2% range of all towers per level"),"upgrade description keeps the original integer percent without invented cost copy")
	await get_tree().process_frame
	check(input.click_button("Close Range description") and app.selected_upgrade.is_empty(),"actual description click dismisses the selected Range instead of reaching the covered Damage tile")
	app.advance_upgrade_presentation(0.15)
	check(app.selected_upgrade.is_empty() and app.upgrade_view_states.has("up_range") and app.upgrade_view_states.up_range.alpha>0 and app.upgrade_view_states.up_range.alpha<1,"deselection retains the outgoing detail during its300ms fade")
	await snapshot("upgrades-deselect-mid",false)
	app.advance_upgrade_presentation(0.15)
	check(app.upgrade_view_states.is_empty(),"upgrade detail leaves the tree at the end of its fade")
	await snapshot("upgrades-grid")
	profile.data.level=30;app.refresh_controls()
	check(input.press("Wizard"),"rightmost upgrade selects its left-facing detail")
	app.advance_upgrade_presentation(0.15)
	await snapshot("upgrades-mirror-mid",false)
	app.advance_upgrade_presentation(0.15)
	var wizard=app.ui.find_children("*","Control",true,false).filter(func(n):return n.has_meta("upgrade_key") and n.get_meta("upgrade_key")=="up_wizard")[0]
	var panel=wizard.get_children().filter(func(n):return n is TextureRect and n.has_meta("upgrade_detail"))[0]
	check(panel.flip_h and panel.position==Vector2(-316,23)*app.menu_scale() and panel.size==Vector2(478,146)*app.menu_scale(),"right-column upgrade mirrors the complete478x146 authored panel at native-316px")
	await snapshot("upgrades-mirrored")
	profile.data.upgrades.up_range=10;app.select_upgrade("up_range");app.advance_upgrade_presentation(0.3)
	check(not input.press("+ Range") and input.press("Refund Range"),"maximum upgrade hides plus while refund remains available")
	app.select_upgrade("up_friends");app.advance_upgrade_presentation(0.3)
	check(not input.press("+ Friend Power") and not input.press("Refund Friend Power"),"original friend-derived upgrade exposes neither allocation button")
	check(input.press("First class"),"last-row upgrade can be selected above the footer")
	app.advance_upgrade_presentation(0.3)
	check(app.upgrade_scroll_y==40*app.menu_scale(),"original selection scroll lifts the187px last-row item by40px above the footer")
	await snapshot("upgrades-last-row")
	check(input.press("Range"),"first-row selection returns from the lifted last row")
	app.advance_upgrade_presentation(0.3)
	check(app.upgrade_scroll_y==0,"original top-row selection restores the zero content offset")
	profile.data.level=3;profile.data.upgrades.up_range=0;profile.data.specpoints=3
	app.navigate("medals")
	await snapshot("medals-all")
	check(input.press("Kills in a row"),"original medal grid opens a battle-medal description")
	await snapshot("medal-description")
	app.navigate("dress")
	check(app.get_node("/root/Content").catalog.tower_medals.all(func(m):return m.has("key") and m.has("image")),"closing a medal popup preserves all source catalog entries")
	check(app.ui.get_children().filter(func(n):return n.has_meta("original_tab")).size()==5,"fitting room retains the Career navigation")
	check(app.ui.get_children().any(func(n):return n is Button and n.text=="Apply outfit") and app.ui.get_children().any(func(n):return n is Button and n.text=="Cancel outfit"),"fitting controls are visible before a costume is changed")
	var thumbnails=app.ui.find_children("*","TextureRect",true,false).filter(func(n):return n.texture!=null and str(n.texture.resource_path).begins_with("res://assets/cosmetics/previews/"))
	check(not thumbnails.is_empty() and thumbnails.all(func(n):return n.size.distance_to(Vector2(130,110)*app.menu_scale())<0.001 and n.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED),"fitting thumbnails use the authored130x110 aspect-fit view rather than their source pixel size")
	app.offer_guidance(23,true);app.refresh_controls()
	await snapshot("fitting-body")
	check(input.press("Hats"),"original fitting-room category changes to hats")
	await snapshot("fitting-hats")
	var hats=app.get_node("/root/Content").catalog.tower_dress.filter(func(d):return int(d.group)==1 and not profile.unlocked(str(d.needsunlock)))
	check(not hats.is_empty(),"preserved unowned hats are available to preview")
	if not hats.is_empty():
		var before=profile.data.dress.duplicate(true)
		check(input.press("Try "+str(hats[0].title)),"unowned costume can be tried without purchase")
		check(profile.data.dress==before and not app.dress_preview.is_empty(),"trying changes the avatar preview without spending or saving a costume")
	await snapshot("fitting-preview")
	if not hats.is_empty():
		var before=profile.data.duplicate(true)
		profile.read_only=true
		check(input.press("Apply outfit") and profile.data==before and not app.dress_preview.is_empty(),"failed outfit save rolls back the whole costume cart and retains preview")
		profile.read_only=false
		check(input.press("Cancel outfit") and app.dress_preview.is_empty() and profile.data==before,"cancel discards a fitting preview without purchase")
		check(input.press("Try "+str(hats[0].title)) and input.press("Apply outfit"),"original Apply control commits an affordable selected costume")
		var slot="s"+str(hats[0].slot)
		profile.load_profile()
		check(profile.unlocked(str(hats[0].needsunlock)) and int(profile.data.dress.get(slot,-1))==int(hats[0].id),"purchased and worn costume survives relaunch")
		await snapshot("outfit-applied")
		app.navigate("dress")
		check(input.press("Pull off "+str(hats[0].title)) and profile.data.dress.has(slot),"pull-off previews removal until Apply")
		check(input.press("Apply outfit"),"Apply commits an optional costume removal")
		profile.load_profile()
		check(not profile.data.dress.has(slot) and profile.data.dress.has("s1") and profile.data.dress.has("s2"),"removed costume stays off after relaunch while required body and eye remain")
		await snapshot("outfit-removed")
	app.navigate("credits")
	await snapshot("credits-top")
	app.menu_scroll=1800
	app.refresh_controls()
	await snapshot("credits-team")
	profile.data.level=16
	profile.data.spice=0
	profile.data.unlocks.append("mo6_sp")
	app.navigate("world")
	app.selected_location="1000"
	app.refresh_controls()
	await snapshot("africa-pass")
	profile.read_only=true
	check(input.press("Free pass"),"original level16 Africa free-pass offer is selectable")
	check(not profile.unlocked("pass7_af"),"failed Africa pass save does not grant continent access")
	profile.read_only=false
	app.selected_location="1000"
	app.refresh_controls()
	check(input.press("Free pass") and profile.unlocked("pass7_af"),"original free Africa pass unlocks locally at level16")
	check(profile.available(app.get_node("/root/Content").mission("65")),"Africa pass and Buenos Aires token open Barricade")
	await snapshot("africa-unlocked")
	app.start_mission("8",true,false)
	var creep=app.sim.spawn_enemy(1,0,"",700,false)
	creep.pos=app.sim.center(15,8)
	creep.visual_pos=creep.pos
	creep.hp=creep.max_hp*0.2
	creep.poison_count=1
	creep.disco_until=10000
	app.sim.freeze_until=10000
	app.particle_fx.emit_system("Creep1ExplosionParts",creep.pos,"blue")
	for i in range(14):app.sim.advance_frame(30);app.particle_fx.advance(app.sim)
	check(app.particle_fx.systems.size()>=4,"preserved debris and enemy status particle systems activate")
	check(app.particle_fx.systems.any(func(sys):return not sys.particles.is_empty()),"particle integration retains visible authored particles")
	await snapshot("particles")
	app.sim.paused=true
	app.refresh_controls()
	await snapshot("pause")
	check(input.press("Restart") and app.pending_abandon=="restart","restart opens the native abandon-game question")
	app.update_question_presentation(0.1)
	check(app.question_alpha>0.349 and app.question_alpha<0.351,"original message fades at3.5 per second")
	check(app.question_root.get_children().filter(func(n):return n is Button).all(func(n):return not n.disabled),"original message buttons activate above0.2 alpha")
	await snapshot("abandon-opening")
	app.update_question_presentation(0.2)
	await snapshot("abandon")
	check(input.press("No") and app.question_closing and app.sim.paused,"declining restart begins the native closing fade")
	app.toggle_pause();check(app.sim.paused,"the question blocks pause toggles until it closes")
	app.update_question_presentation(0.3)
	check(app.pending_abandon.is_empty() and app.sim.paused,"declining restart releases its controls after the closing fade")
	check(input.press("Resume") and not app.sim.paused,"original back button resumes combat")
	app.sim.outcome="defeat"
	app.refresh_controls()
	await snapshot("defeat")
	app.sim.outcome="victory"
	app.refresh_controls()
	await snapshot("victory")
	# Leave the forced-result fixture before enabling earned XP writes. The
	# promotion now runs over the world, as in the main reference recording.
	check(input.press("To the map!"),"original results control returns to campaign")
	check(app.screen=="world","results navigation reaches the world")
	check(not app.particle_fx.visible,"leaving combat hides its particle layer even while the fixture pauses updates")
	profile.data=profile.fresh()
	profile.data.settings.music=false
	profile.data.settings.sound=false
	app.qa_persist_progress=true
	app.pending_xp.clear()
	app.pending_xp.append({"reward":100.0,"type":1})
	profile.read_only=true
	check(not app.flush_pending_xp() and app.promotions.is_empty(),"failed live XP save cannot display an unearned promotion")
	profile.read_only=false
	check(app.flush_pending_xp() and app.promotions.size()==1,"successful live XP credit queues one earned promotion")
	check(profile.data.level==2 and profile.data.spice==5 and profile.data.specpoints==3,"first promotion applies its recorded five-spice/three-point rule")
	app.promotions.clear()
	profile.load_profile()
	app.collect_promotions(0)
	check(app.promotions.size()==1 and profile.data.spice==5,"earned promotion notice survives profile relaunch without another reward")
	check(input.press("Level up!"),"native level-up indicator opens the original promotion frame")
	app.advance_promotion(175);app.refresh_controls()
	check(app.promotion_alpha()==0.25,"promotion quarter-open frame shares native alpha")
	await snapshot("level-up-opening-175",false)
	app.advance_promotion(175);app.refresh_controls()
	check(app.promotion_alpha()==0.5,"promotion half-open frame shares native alpha")
	await snapshot("level-up-opening-350",false)
	app.advance_promotion(350);app.refresh_controls()
	check(app.promotion_alpha()==1.0,"promotion reaches full visibility at its native700ms fade duration")
	check(app.ui.find_children("*","TextureRect",true,false).any(func(n):return n.has_meta("promotion_rank") and n.size==Vector2(128,128)),"promotion retains the first observed rank badge at natural scale")
	await snapshot("level-up-settled",false)
	app.offer_guidance(5,true);app.refresh_controls()
	await snapshot("level-up")
	app.guidance_type=0;app.refresh_controls()
	app.portrait_view.advance(0.5)
	profile.read_only=true
	check(input.press("Continue") and app.promotions.size()==1 and app.promotion_open,"failed notice save retains its pending dialog and rewards")
	await snapshot("level-up-acknowledgement-failed",false)
	profile.read_only=false
	check(input.press("Continue") and app.promotions.size()==1 and app.promotion_state.closing,"dismissing the promotion starts its original fade without collecting a reward again")
	app.notice_until=0;app.refresh_controls()
	app.advance_promotion(175);app.refresh_controls()
	check(app.promotion_alpha()==0.75,"promotion quarter-close retains the shared frame/item fade")
	await snapshot("level-up-closing-175",false)
	app.advance_promotion(175);app.refresh_controls()
	check(app.promotion_alpha()==0.5,"promotion half-close remains visible")
	await snapshot("level-up-closing-350",false)
	app.advance_promotion(350)
	check(not app.promotion_open and app.promotions.is_empty(),"completed700ms closing frame releases the acknowledged promotion")
	check(app.ui.find_children("*","Label",true,false).any(func(n):return n.text=="rank: 2nd lieutenant" and n.get_line_count()==1 and n.get_minimum_size().y<=21),"known first promotion stays in the original single-line footer rank frame")
	app.navigate("career",false)
	check(app.ui.find_children("*","Label",true,false).any(func(n):return n.text=="2nd Lieutenant"),"known first promotion updates Career rank")
	await snapshot("career-first-promotion",false)
	app.navigate("world",false)
	var earned_notice_profile=profile.data.duplicate(true)
	# Display-only pose from two supplied video frames. Never save this state
	# or conflate it with the actual10XP notification account used above.
	profile.data.xp=31.0;profile.data.spice=8;profile.data.specpoints=3
	app.refresh_controls()
	check(app.ui.find_children("*","Label",true,false).any(func(n):return n.text=="xp: 31 / 55"),"observed level2 footer reproduces31/55 using the corrected next threshold")
	await snapshot("world-observed-level2",false)
	profile.data=earned_notice_profile;app.refresh_controls()
	check(profile.data.xp==10.0 and profile.data.spice==5,"reference-only footer pose restores the actual isolated notification balance without a save")
	profile.load_profile()
	app.collect_promotions(0)
	check(app.promotions.is_empty() and int(profile.data.settings.promotion_seen)==2 and profile.data.spice==5,"acknowledged promotion stays dismissed after relaunch")
	for i in range(1100):profile.data.transactions.append({"kind":"battle-xp","score":1,"kills":1})
	var prior_count=profile.data.transactions.size()
	profile.data.transactions.append({"kind":"promotion","level":3,"spice":0,"points":1})
	profile.data.level=3
	check(profile.save_profile(),"long history archives before compacting the live profile")
	app.collect_promotions(prior_count)
	check(app.promotions.size()==1 and int(app.promotions[0].level)==3,"history compaction cannot hide a newly earned promotion behind an old array index")
	app.promotions.clear()
	app.qa_persist_progress=false
	app.sim.paused=false # The failed-save fixture paused its synthetic battle.
	app.refresh_controls()
	if DisplayServer.get_name()!="headless":
		app.qa_menu_motion=true
		app.navigate("upgrades",false)
		await get_tree().process_frame
		app.navigate("spicery")
		await get_tree().process_frame;await get_tree().process_frame
		app.menu_transition.advance(0.1)
		check(app.menu_transition.active and app.menu_transition.request.subtype=="fromRight" and is_equal_approx(app.menu_transition.age,0.1),"higher tab enters from the right on its original400ms content clock")
		check(app.ui.get_children().filter(func(n):return n.has_meta("menu_chrome")).all(func(n):return n.visible and n.z_index>app.menu_transition.z_index),"top tabs and footer remain above the moving content")
		await snapshot("tab-forward-010")
		app.menu_transition.advance(0.31)
		check(not app.menu_transition.active and app.menu_transition.previous==null and app.menu_transition.incoming==null,"completed menu transition releases both snapshots")
		check(app.ui.get_children().filter(func(n):return n.has_meta("menu_chrome")).all(func(n):return n.z_index==0),"completed transition restores ordinary modal and chrome drawing order")
		app.navigate("career")
		await get_tree().process_frame;await get_tree().process_frame
		app.menu_transition.advance(0.2)
		check(app.menu_transition.request.subtype=="fromLeft","lower tab enters from the left")
		await snapshot("tab-back-020")
		app.menu_transition.advance(0.21)
		app.navigate("world")
		await get_tree().process_frame;await get_tree().process_frame
		app.menu_transition.advance(0.2)
		check(app.menu_transition.incoming_world and app.menu_transition.incoming.get_image().get_pixel(0,0).a==0,"returning to Map moves only the outgoing native content")
		await snapshot("tab-map-020")
		app.menu_transition.advance(0.21)
		app.navigate("menu")
		await get_tree().process_frame;await get_tree().process_frame
		app.menu_transition.advance(0.1)
		check(app.menu_transition.request.type=="fade","Home uses the native content fade")
		await snapshot("tab-home-010")
		app.menu_transition.advance(0.31);app.qa_menu_motion=false
	app.navigate("career",false);app.guidance_type=0;app.refresh_controls();app.portrait_view.advance(0.5)
	app.navigate("upgrades",false)
	var headers=app.ui.get_children().filter(func(n):return n is Label and n.has_meta("original_upgrade_header"))
	check(headers.size()==1 and headers[0].text.begins_with("Use upgrade points to enhance your pirate's skills\nYou have ") and headers[0].get_theme_font_size("font_size")==20 and headers[0].position.y==91 and headers[0].get_minimum_size().y<=85,"original upgrade header retains both lines, native20pt font/frame and fits below the tabs")
	app.navigate("career",false)
	if profile.data.settings.has("guidance_seen"):profile.data.settings.guidance_seen.erase("5")
	app.offer_guidance(5,true);app.refresh_controls();app.portrait_view.advance(0.5)
	check(input.press("Dismiss guidance") and app.guidance_type==0 and app.screen=="career","promotion portrait begins closing before Tech Shop routing")
	app.portrait_view.advance(0.25)
	check(app.screen=="career","half-closed promotion portrait keeps its current menu")
	await snapshot("guidance-closing-025",false)
	app.portrait_view.advance(0.25)
	check(app.screen=="shop" and app.menu_navigation_request.current==103,"completed portrait enters original Tech Shop menu")
	await snapshot("guidance-shop-complete")
	app.navigate("career",false);app.guidance_type=0;app.refresh_controls();app.portrait_view.advance(0.5)
	app.offer_guidance(6,true);app.refresh_controls();app.portrait_view.advance(0.5)
	check(input.press("Dismiss guidance") and app.screen=="career","second promotion portrait delays Upgrades Yard routing")
	app.portrait_view.advance(0.5)
	check(app.screen=="upgrades" and app.menu_navigation_request.current==104,"completed second promotion enters original Upgrades Yard menu")
	await snapshot("guidance-upgrades-complete")
	app.navigate("menu",false);app.portrait_view.clear();app.reset_main_menu_presentation()
	await snapshot("main-menu-000")
	app.advance_main_menu_presentation(0.7)
	check(app.main_menu_view.eye_index>=0 and app.main_menu_view.eye_age<0.001,"original tablet note timer begins an eye animation after700ms")
	check(app.menu_bubbles.source_rects.size()==9 and app.menu_bubbles.pool.size()==150 and app.menu_bubbles.pool.any(func(r):return r!=null),"menu bubbles retain nine source views,150 pooled slots and actual timer emissions")
	await snapshot("main-menu-070")
	app.advance_main_menu_presentation(0.7)
	check(app.main_menu_view.eye_amount()>0 and app.main_menu_view.eye_amount()<=1,"selected fourth eye uses original scale/opacity keyframes")
	await snapshot("main-menu-140")
	app.advance_main_menu_presentation(0.625)
	check(app.main_menu_view.rotation("logoView")>0.03 and app.main_menu_view.rotation("logoWiresView")>0.029,"logo and wires retain separate authored rocking amplitudes")
	await snapshot("main-menu-202")
	app.advance_main_menu_presentation(1.975)
	check(absf(app.main_menu_view.rotation("logoView"))<0.000001,"menu logo returns to its anchor after its four-second rocking cycle")
	await snapshot("main-menu-400")
	check(app.menu_floats.items.size()==9 and app.menu_floats.pose(391).rotation!=0,"original nine floating views retain independently timed rocking")
	var play=app.ui.get_children().filter(func(n):return n.has_meta("menu_float_id") and int(n.get_meta("menu_float_id"))==391)[0]
	check(absf(play.rotation-app.menu_floats.pose(391).rotation)<0.000001 and play.pivot_offset==play.size/2,"menu control and label share the floating presentation pivot")
	app.advance_main_menu_presentation(4.0)
	check(app.get_node("/root/Content").menu_layout.entries.filter(func(e):return int(e.get("tag",0)) in range(100,109)).size()==9,"original menu NIB retains all nine lamp tags")
	await snapshot("main-menu-800")
	app.advance_main_menu_presentation(1.75)
	check(absf(app.MenuFloatView.lamp_alpha(100,app.menu_floats.age)-1.0)<0.000001 and app.MenuFloatView.lamp_alpha(108,app.menu_floats.age)<0.2,"native lamp sequence starts at eight seconds with staggered fades")
	await snapshot("main-menu-975")
	app.advance_main_menu_presentation(0.5)
	await snapshot("main-menu-1025")
	app.advance_main_menu_presentation(1.75)
	await snapshot("main-menu-1200")
	check(app.menu_motion.flies.size()==6 and app.menu_motion.notes.size()==10 and app.menu_motion.notes.all(func(n):return n==null),"native six fireflies move while disabled music emits no notes")
	profile.data.settings.music=true
	app.advance_main_menu_presentation(0.7)
	check(app.menu_motion.notes.any(func(n):return n!=null),"enabling music emits authored notes on the existing700ms clock")
	await snapshot("main-menu-notes-1270")
	var note_index=app.menu_motion.next_note
	profile.data.settings.music=false
	app.advance_main_menu_presentation(0.7)
	check(app.menu_motion.next_note==note_index,"muting music stops new notes while existing fades continue")
	await snapshot("main-menu-muted-1340")
	check(input.click_button("Play") and app.screen=="world","actual viewport press and release can activate the rocking Play control")
	if not capture_root.is_empty():
		var f=FileAccess.open(capture_root.path_join("manifest.json"),FileAccess.WRITE)
		f.store_string(JSON.stringify({"captures":captures,"verification":{"checks":checks,"failures":failures},"method":"Packaged interface actions with synthetic purchasing funds. No campaign win or original-device parity claimed."},"\t"));f.close()
	print("MENU_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures}))
	finished=true
	input.free()
	completed.emit(0 if failures.is_empty() else 1)

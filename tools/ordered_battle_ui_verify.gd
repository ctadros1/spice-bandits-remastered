extends SceneTree
var app
var failures=[]
var checks=0
var pairs=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	create_timer(45).timeout.connect(func():push_error("Ordered battle comparison exceeded45 seconds");quit(1))
	run.call_deferred()
func capture(ordered:bool) -> Image:
	app.ordered_battle_rendering=ordered;app.queue_redraw()
	await process_frame;await process_frame;RenderingServer.force_draw(true)
	return root.get_texture().get_image()
func compare(name:String) -> void:
	var reference=await capture(false)
	var ordered=await capture(true)
	var exact=reference.get_data()==ordered.get_data()
	check(exact,"exact reference/ordered full RGBA "+name)
	var folder="res://../builds/ordered-battle-r121/"
	reference.save_png(folder+name+"-reference.png");ordered.save_png(folder+name+"-ordered.png")
	pairs.append({"name":name,"exact_full_rgba":exact,"width":reference.get_width(),"height":reference.get_height()})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../builds/ordered-battle-r121"))
	app=load("res://scripts/main.gd").new();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	app.start_mission("1",true,false);app.tutorial=null;app.qa_gallery=true;app.refresh_controls();app.notice_until=0
	app.animation_delta_ms=0
	await compare("empty-training")
	app.sim.money=100000
	check(app.sim.build(Vector2i(8,6),1).is_empty(),"supplied first tower placement");check(app.sim.build(Vector2i(7,4),1).is_empty(),"supplied second tower placement")
	var enemy=app.sim.spawn_enemy(1,0,"",910,false)
	enemy.pos=app.sim.center(8,6)+Vector2(0,10);enemy.visual_pos=enemy.pos;enemy.grow_ms=400
	enemy.visual_layers=[{"state":"RunDown","alpha":1.0,"rotation":0.0,"born":0}]
	app.animation_epoch+=1
	await compare("tower-creep-overlap")
	enemy.draw_light=.3;enemy.freeze_remaining=1000
	await compare("status-after-body")
	enemy.visual_layers=[{"state":"RunDown","alpha":.4,"rotation":15.0,"born":0},{"state":"RunRight","alpha":.6,"rotation":-15.0,"born":0}]
	await compare("dual-clock-rotation-status")
	app.selected_tower=app.sim.towers[0].id
	await compare("selected-range-info")
	app.selected_tower=-1;app.build_type=1;app.show_grid=true;app.tower_drag=true;app.tower_drag_position=app.map_origin()+app.sim.center(9,6)*app.map_scale()
	await compare("placement-and-grid")
	var aircraft=app.sim.spawn_enemy(4,0,"",911,false)
	aircraft.native_air=true;aircraft.pos=app.sim.center(9,6);aircraft.visual_pos=aircraft.pos;aircraft.grow_ms=400
	await compare("air-above-placement")
	app.notice="Ordered draw notice";app.notice_until=app.ui_time_ms()+100000
	await compare("notice-above-game")
	app.notice_until=0;app.build_type=0;app.show_grid=false;app.tower_drag=false
	app.start_mission("8",true,false);app.sim.spawn_hold=true;app.sim.clock_ms=1800;app.notice_until=0
	await compare("desert-scene")
	# Return to reference must hide every child span immediately.
	await capture(false)
	check(not app.ordered_battle_canvas.visible,"reference path hides stale ordered span pool")
	var report={"checks":checks,"failures":failures,"pairs":pairs,"scope":"Native source Main reference/ordered no-hit equivalence on supplied frozen scenes. No packaged/runtime hit bridge, whole original draw registry or GPU equivalence claim."}
	var out=FileAccess.open("res://../builds/ordered-battle-r121-verification.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("ORDERED_BATTLE ",JSON.stringify(report));app.free();quit(0 if failures.is_empty() else 1)

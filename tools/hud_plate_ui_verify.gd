extends SceneTree
const Wallet=preload("res://scripts/hud_wallet_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-hud-plate-reference.json")))
	for case in reference.plates:
		var p=Wallet.plate_position(case.width,case.money_width,case.spice_width)
		check(p==Vector2(case.point[0],case.point[1]),"original clamped plate position")
	for case in reference.flashes:
		var state={"active":case.active,"age_ms":case.age_ms};Wallet.flash_advance(state,case.dt_ms)
		check(state.active==case.result.active,"original flash flag")
		check(absf(state.age_ms-case.result.age_ms)<0.000001,"original flash expiry/clock")
		var color=Wallet.flash_color(state)
		for i in range(4):check(absf(color[i]-float(case.result.color[i]))<0.000001,"original money flash color")
	var state={"active":true,"age_ms":100.0};Wallet.flash_request(state)
	check(state.age_ms==100,"another unaffordable press does not reset the active flash")
	var profile=root.get_node("Profile");profile.data=profile.fresh();profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	app.start_mission("8",true,false);app.qa_gallery=true;app.sim.money=0;app.select_build(1)
	check(app.hud_money_flash.active and app.sim.money==0,"unaffordable tray press flashes without charging")
	Wallet.flash_advance(app.hud_money_flash,100);app.sim.paused=true;app._process(.5)
	check(app.hud_money_flash.age_ms==100,"paused battle holds flash clock")
	app.sim.paused=false;app.speed=2;app._process(.1)
	check(app.hud_money_flash.age_ms==300,"battle speed scales flash clock")
	app.start_mission("1",true,false)
	check(not app.hud_money_flash.active and app.hud_money_flash.age_ms==0,"new room resets flash")
	app.queue_free();await process_frame
	var report={"checks":checks,"failures":failures,"method":"Original RenderInfoBar prefix and draw-disabled indicator flash with explicit widths/frame dt, session/text/GL and host cosf stubs. Actual tray/pause/speed/new-room integration; original font raster and full caller scheduling remain outside scope."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/hud-plate-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("HUD_PLATE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends SceneTree
const Reward=preload("res://scripts/reward_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-reward-spice-reference.json")))
	for case in reference.cases:
		var content=Vector2(case.content[0],case.content[1]);var quad=Vector2(case.quad[0],case.quad[1])
		var pose=Reward.spice(content,quad,Reward.f32(case.phase),Vector2(188,127),Reward.f32(case.alpha),Reward.f32(case.root_alpha))
		for i in range(2):
			check(pose.point[i]==Reward.f32(case.draw.point[i]),"original spice text point")
			check(pose.quad[i]==Reward.f32(case.draw.quad[i]),"original spice backing quad")
		check(pose.alpha==Reward.f32(case.draw.alpha),"original entering/completed alpha")
		check(quad==Vector2(case.quad[0],case.quad[1]) and case.quad_restored,"source quad stays restored")
		check(Reward.text_quad(content)==quad,"power-of-two backing dimensions")
	var bursts=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-reward-burst-reference.json")))
	for case in bursts.cases:
		var vector=SpiceNative.projected_random_vector(case.rand[0],case.rand[1]);var radius=Reward.burst_radius(case.rand[2])
		for i in range(2):check(vector[i]==Reward.f32(case.vector[i]),"original projected random-vector component")
		check(radius==Reward.f32(case.radius),"original0..7 random radius")
		var point=Reward.spice_burst_point(Vector2(case.content[0],case.content[1]),case.index,Vector2(188,127),vector,radius)
		for i in range(2):check(point[i]==Reward.f32(case.point[i]),"original seven-slot reward anchor")
		check(case.interval==5.0 and Reward.f32(case.clock_multiplier)==Reward.f32(1.6),"original interval/clock overrides")
	var profile=root.get_node("Profile");profile.data=profile.fresh();profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	app.start_mission("8",true,false);app.qa_gallery=true;app.sim.outcome="victory";app.result_started=0;app.elapsed_ui=0;app.refresh_controls()
	var rows=app.ui.get_children().filter(func(n):return n.has_meta("result_spice"))
	check(rows.size()==1,"one regular text object for the whole spice reward")
	if rows.size()==1:
		var row=rows[0]
		check(row.text=="Cadet! We got 3 spice!" and row.get_theme_font("font")==app.font and row.get_theme_font_size("font_size")==20,"original regular20pt row formatting")
		check(row.autowrap_mode==TextServer.AUTOWRAP_OFF and row.get_theme_color("font_shadow_color")==Color.TRANSPARENT,"single unshadowed line")
		for phase in [0.0,0.5,1.0]:
			app.result_clock.spice_phase=phase;app.result_clock.alpha=0.5;app.update_result_controls()
			var content=app.result_spice_size();var pose=Reward.spice(content,Reward.text_quad(content),phase,app.results_origin(),1,0.5)
			check(row.position==pose.point and row.scale==pose.scale and row.modulate.a==pose.alpha,"actual result controls use the original spice pose")
	app.queue_free();await process_frame
	var report={"checks":checks,"failures":failures,"method":reference.method+bursts.method+" Godot content metrics are supplied for the rendered row; explicit rand results do not establish the whole-game global RNG or old UIKit raster."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/reward-spice-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("REWARD_SPICE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

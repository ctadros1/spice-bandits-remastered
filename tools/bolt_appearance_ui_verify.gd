extends SceneTree
var Bolt
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	create_timer(30).timeout.connect(func():push_error("Bolt appearance verification timed out.");quit(1))
	run.call_deferred()
func run() -> void:
	Bolt=load("res://scripts/bolt_view.gd")
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-bolt-appearance-reference.json")))
	for case in reference.callers:
		var flags=Bolt.caller_flags(12 if case.name=="gateway" else 10,case.name=="active-defense")
		check(flags.scatter==case.scatter,"original caller endpoint-scatter argument")
		check(flags.ball==case.ball,"original caller source-ball argument")
		check(case.from==case.source and case.to==case.target,"original caller forwards source/target records")
	for case in reference.constructors:
		check(case.stored_source==case.source,"original constructor stores source rather than target")
		check(case.stored_scatter==case.scatter,"original constructor stores caller scatter flag after Construct")
		check(case.calls.size()==int(case.ball),"original constructor optional ball declaration")
		if case.ball:
			check(case.calls[0].texture=="sfx/bolt_ball3_small.png" and case.calls[0].width==64 and case.calls[0].height==64,"original preserved64px source ball")
	for case in reference.renders:
		var color=case.calls.filter(func(c):return c.has("color"))
		var quad=case.calls.filter(func(c):return c.has("quad"))
		check(quad.size()==int(case.ball and case.alive),"original source ball draw guard")
		if not quad.is_empty():
			var rect=Bolt.ball_rect(Vector2(case.source[0],case.source[1]),Vector2i(case.size[0],case.size[1]))
			for i in range(2):check(rect.position[i]==Bolt.f32(quad[0].quad[i]),"original source-centered integer-half rectangle")
			check(color[0].color==[1.0,1.0,1.0,case.alpha],"original source ball white/opacity tint")
		if case.alive:check(int(case.calls[0].blend[0])==770 and int(case.calls[0].blend[1])==1,"original source ball SRC_ALPHA,ONE pass precedes ribbons")
	for case in reference.uvs:
		var uv=Bolt.ball_uv(case.flip_h,case.flip_v)
		check(uv[0]==Vector2(case.uv[0],case.uv[2]),"original CalculateUV/SetFlip initial corner")
		check(uv[2]==Vector2(case.uv[1],case.uv[3]),"original CalculateUV/SetFlip opposite corner")
	var source=Vector2(140.25,-73.5);var target=Vector2(512.5,287.75)
	for seed_value in [0,114,123456]:
		var fixed=Bolt.sample(source,target,seed_value,false,true)
		var scattered=Bolt.sample(source,target,seed_value,true,true)
		check(fixed.points[0]==source and scattered.points[0]==source,"caller policies preserve the bolt source")
		check(fixed.points[-1].distance_to(target)<0.0002,"Tesla endpoint retains accumulated rounding")
		check(scattered.points[-1].distance_to(target)>0 and scattered.points[-1].distance_to(target)<8.001,"area endpoint uses the native projected8px scatter")
	check(root.get_node("Content").tex("assets/sfx/bolt_ball3_small.png").get_size()==Vector2(64,64),"imported ball retains natural dimensions")
	var content=root.get_node("Content")
	for filename in ["tower10_2","tower10_3","tower12_1","tower12_2","tower12_3"]:
		var parameters=content.animations["towers/"+filename].params
		var path=Bolt.texture_path(parameters,12 if filename.begins_with("tower12") else 10,false)
		check(path=="assets/"+str(parameters.custom_bolt),"authored custom beam retains its original resource-root-relative path")
		check(content.tex(path) is Texture2D,"authored colored beam resolves an actual imported texture")
	var report={"checks":checks,"failures":failures,"method":reference.method+" Constructor Construct is stubbed; its first-call scatter reads a field assigned only afterward. Fresh allocation contents, original RNG and complete caller lifecycle remain unproven."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/bolt-appearance-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOLT_APPEARANCE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

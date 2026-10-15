extends SceneTree
const Status=preload("res://scripts/creep_status_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize():
	create_timer(30).timeout.connect(func():push_error("Status source unit exceeded its bound");quit(1))
	run.call_deferred()
func run():
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-status-reference.json")))
	if not reference is Dictionary or reference.get("cases",[]).size()!=576:push_error("Missing complete original status fixture");quit(1);return
	var source_frames=0
	for c in reference.cases:
		var input=c.input
		var frames=c.calls.filter(func(call):return call.method=="frame" and int(call.blend[0])==1 and int(call.blend[1])==769)
		var enabled=Status.active(input.state,input.freeze,input.slow)
		var layers=Status.layers([{"alpha":input.alpha},{"alpha":input.secondary}])
		check(frames.size()==(layers.size() if enabled else 0),"original direct-frame guard and secondary predicate")
		for frame in frames:
			for channel in range(4):check(Status.coefficient(input.light)==Vector2(frame.rgba[channel],0).x,"original separate float32 status color, including alpha")
			source_frames+=1
		var normal=c.calls.filter(func(call):return call.method=="frame" and int(call.blend[0])==1 and int(call.blend[1])==771)
		if enabled and not normal.is_empty() and not frames.is_empty():check(c.calls.find(normal[-1])<c.calls.find(frames[0]),"both normal frames precede either screen frame")
	var content=root.get_node("Content")
	check(content.screen_textures.size()>20,"all source creep atlases have preserved premultiplied screen variants")
	var frame_pairs=0
	for key in content.animations:
		if not key.begins_with("creeps/"):continue
		var variants=[""]
		for resource in content.animations[key].resources.values():
			for variant in resource.get("variations",{}):
				if variant not in variants:variants.append(variant)
		for state in content.animations[key].states:
			for variant in variants:
				for index in [-1,0,12345]:
					var normal=content.frame(key,state,index,variant)
					var screen=content.frame(key,state,index,variant,true)
					check(not screen.is_empty(),"native screen frame exists for every creep state/variation")
					if screen.is_empty():continue
					check(normal.texture.get_size()==screen.texture.get_size() and normal.offset==screen.offset and normal.canvas_size==screen.canvas_size,"screen retains exact frame crop/rotation/flip/offset")
					check(screen==content.frame_reference(key,state,index,variant,true),"prepared/reference screen path is identical")
					frame_pairs+=1
	var app=load("res://scripts/main.gd").new();app.sim=load("res://scripts/simulation.gd").new();app.sim.freeze_until=1000
	check(app.creep_body_tint({"native_air":false,"draw_light":.3})==Color(.3,.3,.3,1),"freeze leaves the original normal body light intact")
	app.free()
	var report={"checks":checks,"failures":failures,"cases":reference.cases.size(),"status_frames":source_frames,"frame_pairs":frame_pairs,"scope":"Original status guard/RGBA/direct-frame order with supplied records and non-interpolating animator. GPU, lifecycle, additive hits and whole scene equivalence remain separate."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-status-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("CREEP_STATUS_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

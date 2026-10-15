extends SceneTree
const Transition=preload("res://scripts/transition_view.gd")
var checks=0
var failures=[]
func check(value:bool,name:String):
	checks+=1
	if not value:failures.append(name);push_error(name)
func state(view,expected:Dictionary):
	check(view.phase==int(expected.phase),"native transition phase")
	for key in ["left","circle_left","radius","opacity"]:check(absf(float(view.get(key))-float(expected[key]))<0.002,"native transition "+key)
	check(view.nodes.size()==expected.nodes.size(),"native transition node count")
	for i in range(mini(view.nodes.size(),expected.nodes.size())):
		var node=view.nodes[i];var original=expected.nodes[i]
		check(node.phase==int(original.phase) and node.visible==original.visible,"native transition node flags")
		check(node.pos.distance_to(Vector2(original.pos[0],original.pos[1]))<0.002,"native transition node position")
		for key in ["scale","left","duration","max_scale"]:check(absf(float(node[key])-float(original[key]))<0.002,"native transition node "+key)
func _initialize():run.call_deferred()
func run():
	await process_frame
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-transition-reference.json"))
	var view=Transition.new();root.add_child(view);view.set_process(false);view.set_anchors_preset(Control.PRESET_TOP_LEFT);view.size=Vector2(1024,768)
	for case in fixture.cases:
		view.phase=3;view.open(int(case.corner),0,case.random_values);state(view,case.initial)
		for frame in case.frames:view.advance(frame.dt);state(view,frame.state)
		view.close();state(view,case.close)
		for frame in case.reveal_frames:view.advance(frame.dt);state(view,frame.state)
	print("TRANSITION_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures,"original_frames":197,"method":"Original ARM transition instructions with explicit rand values; no original global RNG or framebuffer parity."}))
	quit(0 if failures.is_empty() else 1)

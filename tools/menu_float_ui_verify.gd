extends SceneTree
const View=preload("res://scripts/menu_float_view.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-menu-float-reference.json")))
	if reference==null:push_error("Original menu float fixture is missing.");quit(1);return
	for item in reference.floats:
		var spec=View.declaration(item.height,Vector2(item.position[0],item.position[1]),item.random)
		var native_path=item.animations[0].properties
		check(spec.duration==native_path.duration and native_path.Autoreverses,"original20s reversing text path")
		check(spec.path.size()==native_path.Path.points.size(),"original damping termination and closing point")
		if spec.path.size()==native_path.Path.points.size():
			for i in range(spec.path.size()):
				for axis in range(2):check(absf(spec.path[i][axis]-native_path.Path.points[i][axis])<0.00001,"original alternating float32 path")
		var rotation=item.animations[1].properties
		for i in range(4):check(absf(spec.angles[i]-rotation.Values[i])<0.00000001,"original random rotation value %d: %.12f / %.12f"%[i,spec.angles[i],rotation.Values[i]])
		check(spec.rotation_duration==rotation.duration,"original random rotation period")
		check(rotation.Autoreverses and rotation.Cumulative and rotation.TimingFunction.timing=="easeInEaseOut","original reversing cumulative rotation declaration")
	for item in reference.lamps:
		check(item.animations.size()==9,"original nine tagged lamps")
		for lamp in item.animations:
			var tag=int(lamp.target.trim_prefix("lamp-"))
			var spec=lamp.properties
			check(absf(View.lamp_begin(tag,item.media_time)-spec.BeginTime)<0.00001,"original media-time float32 plus lamp stagger")
			check(spec.Values==View.LAMP_VALUES and spec.KeyTimes==View.LAMP_TIMES,"original lamp values and mismatched key-time declaration")
			check(spec.duration==View.LAMP_DURATION and not spec.Additive and spec.TimingFunction.timing=="easeInEaseOut","original repeating nonadditive lamp fade")
	check(View.lamp_alpha(100,7.99)==0 and View.lamp_alpha(100,8.0)==0,"NIB zero-opacity lamps stay hidden until their eight-second start")
	check(absf(View.lamp_alpha(100,9.75)-1.0)<0.000001,"documented invalid key-time fallback peaks at the cycle midpoint")
	var view=View.new();view.reset([{"id":1,"rect":Rect2(10,20,130,71)}],768,114)
	var initial=view.pose(1)
	check(initial.translation==Vector2.ZERO and initial.rotation==0,"floating text starts at its authored model position")
	view.advance(1.4)
	check(view.pose(1).translation!=Vector2.ZERO and view.pose(1).rotation!=0,"independent menu clock advances both text effects")
	var report={"checks":checks,"failures":failures,"method":reference.method+" Named timing/equal-keyframe interpolation is reconstructed using Apple's documented defaults; no original compositor executes."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/menu-float-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MENU_FLOAT_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

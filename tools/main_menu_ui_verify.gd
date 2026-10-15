extends SceneTree
const View=preload("res://scripts/main_menu_view.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-menu-animation-reference.json")))
	if original==null:push_error("Original menu animation fixture is missing.");quit(1);return
	for group in [original.logo,original.chain,original.gears,original.sky]:
		for item in group.animations:
			var properties=item.properties
			if properties.keypath!="transform.rotation.z":
				var motion=View.MOTIONS[item.target].filter(func(s):return s.keypath==properties.keypath)[0]
				check(motion.to==properties.ToValue,"original component amount "+item.target)
				check(motion.duration==properties.duration,"original component duration "+item.target)
				check(motion.reverse==properties.get("Autoreverses",false),"original component reversal "+item.target)
				check(motion.timing==properties.TimingFunction.timing,"original component timing "+item.target)
				check(motion.from==properties.get("FromValue",1.0),"original component starting value "+item.target)
				continue
			var spec=View.ROTATIONS[item.target]
			check(spec.to==properties.ToValue,"original rotation amount "+item.target)
			check(spec.duration==properties.duration,"original rotation duration "+item.target)
			check(spec.reverse==properties.get("Autoreverses",false),"original autoreverse "+item.target)
			check(spec.cumulative==properties.get("Cumulative",false),"original cumulative "+item.target)
			check(spec.timing==properties.TimingFunction.timing,"original timing function "+item.target)
		for target in group.anchors:
			for axis in range(2):check(absf(View.ANCHORS[target][axis]-group.anchors[target][axis])<0.000001,"original layer anchor "+target)
	var light=original.light.animations[0].properties
	check(View.LIGHT_VALUES==light.Values,"original flicker values")
	check(View.LIGHT_TIMES==light.KeyTimes,"original flicker key times retained before framework validity rules")
	check(original.logo.light_targets==View.LIGHT_TARGETS,"original three light targets")
	check(original.logo.rocket_durations.values().all(func(v):return v==View.ROCKET_DURATION),"original four-frame rocket period")
	var view=View.new()
	for item in original.eyes:
		view.reset(1);view.eye_index=int(item.last)
		check(view.trigger_eye(int(item.random),int(item.duration_random)),"idle original eye permits a new animation")
		var record=item.record
		var expected_x=10.0+view.eye_index*20
		check(record.frames[0][0]==expected_x,"original random eye selection avoids immediate repeats")
		for animation in record.animations:
			check(animation.properties.duration==view.eye_duration,"original random2..4-second eye duration")
			check(animation.properties.Values==View.EYE_VALUES,"original eye scale/opacity values")
			check(animation.properties.KeyTimes==View.EYE_TIMES,"original eye key times")
		check(not view.trigger_eye(2,2) and original.active_eye.animations.is_empty(),"active eye blocks a second animation")
	view.reset(1)
	var logo=view.transform_for("logoView",Rect2(82,5,183,184))
	check((logo*Vector2(82,5)).distance_to(Vector2(82,78.6))<0.0001,"changed native layer anchor retains position and shifts its frame")
	view.age=2
	check(absf(view.rotation("logoView")-View.ROTATIONS.logoView.to)<0.000001,"logo rocking reaches its authored angle at2 seconds")
	view.age=4
	check(absf(view.rotation("logoView"))<0.000001,"logo rocking reverses back at4 seconds")
	for timing in ["linear","easeIn","easeInEaseOut"]:
		check(View.curve(0,timing)==0 and View.curve(1,timing)==1,"timing curve endpoints "+timing)
	check(absf(View.curve(0.5,"easeInEaseOut")-0.5)<0.000001,"symmetric native timing curve midpoint")
	check(absf(View.keyframe(View.EYE_VALUES,View.EYE_TIMES,1.0/3.0)-1.0)<0.000001,"invalid eye key times use the documented equal-spacing fallback")
	var report={"checks":checks,"failures":failures,"method":original.method+" Declaration/selection checks plus local interpolation/anchor regressions. Core Animation pixels and old iOS fallback behavior are not executed."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/main-menu-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAIN_MENU_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

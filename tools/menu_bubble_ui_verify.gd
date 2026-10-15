extends SceneTree
const View=preload("res://scripts/menu_bubble_view.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-menu-bubble-reference.json")))
	if reference==null:push_error("Original menu bubble fixture is missing.");quit(1);return
	for item in reference.cases:
		var pose=View.declaration(Vector2(item.x,item.y),item.speed,item.distance)
		var group=item.group[0].properties
		check(pose.duration==group.duration,"original bubble duration")
		check(pose.timing==group.TimingFunction.timing,"original bubble group timing")
		var path=group.Animations[0].Path.points
		for axis in range(2):
			check(absf(pose.from[axis]-path[0][axis])<0.00001,"original bubble start")
			check(absf(pose.to[axis]-path[1][axis])<0.00001,"original bubble end")
		check(pose.opacity==group.Animations[1].Values,"original bubble opacity")
		check(group.Animations[2].Values.all(func(v):return v.rgba==[1.0,1.0,1.0,1.0]),"original tiny bubble views use solid white color keyframes")
	for item in reference.creations:
		var pose=View.creation(item.width,item.height,int(item.random_x),int(item.random_y),Vector2(0,item.conversion_offset_y))
		var recorded=item.bubble[0]
		for axis in range(2):check(absf(pose.local[axis]-item.converted_inputs[0][axis])<0.00001,"original bubble local spawn point")
		check(absf(pose.point.x-recorded.x)<0.00001 and absf(pose.point.y-recorded.y)<0.00001,"explicit converted bubble spawn")
		check(pose.speed==recorded.speed and pose.distance==recorded.distance,"original bubble speed/upper-bound distance")
		check((int(item.slot)+1)%View.CAPACITY==int(item.next_slot),"original150-slot wrap")
	check(View.INTERVAL==reference.timer_interval,"original bubble timer interval")
	for item in reference.callbacks:
		var plan=View.emission_plan(int(item.chance),int(item.target_random),int(item.count_random),int(item.source_count))
		check(plan.ordinary==int(item.ordinary),"original four ordinary bubbles per timer callback")
		check(plan.extra==item.extra.size(),"original optional10..29-bubble burst")
		check(item.extra.all(func(target):return int(target)==plan.target),"original burst shares one selected source view")
	var report={"checks":checks,"failures":failures,"method":reference.method+" CGRect conversion is an explicit identity/translation stub; original UIKit presentation geometry is not executed."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/menu-bubble-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MENU_BUBBLE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

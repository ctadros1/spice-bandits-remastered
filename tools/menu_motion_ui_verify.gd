extends SceneTree
const View=preload("res://scripts/menu_motion_view.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-menu-motion-reference.json")))
	if reference==null:push_error("Original menu motion fixture is missing.");quit(1);return
	for item in reference.flies:
		var pose=View.fly_declaration(item.frame[2],item.frame[3],item.random,int(item.device))
		var native=item.animations[0].properties
		check(pose.start.distance_to(Vector2(item.centers[0][0],item.centers[0][1]))<0.0001,"original random fly center")
		check(pose.duration==native.duration and native.TimingFunction.timing=="linear","original two-second fly path clock")
		check(pose.curves.size()==native.Path.curves.size(),"original random fly path length")
		if pose.curves.size()==native.Path.curves.size():
			for i in range(pose.curves.size()):
				for j in range(3):
					for axis in range(2):check(absf(pose.curves[i][j][axis]-native.Path.curves[i][j*2+axis])<0.0001,"original float32 cubic fly control/end point")
	for item in reference.notes:
		var pose=View.note_declaration(Vector2(item.x,item.y),item.duration,item.distance,int(item.random),int(item.device))
		var path=item.animations[0].properties
		check(pose.duration==path.duration and path.RemovedOnCompletion==false,"original retained note path duration")
		for i in range(pose.path.size()):
			for axis in range(2):check(absf(pose.path[i][axis]-path.Path.points[i][axis])<0.0001,"original note alternating path")
		var opacity=item.animations[1].properties
		check(pose.alpha_duration==opacity.duration and pose.alpha==opacity.Values,"original note fade ends before its position path")
		check(item.hidden[0].hidden==false,"original note is unhidden when reused")
	for item in reference.callbacks:
		check(item.eye_calls==1,"original eye timer runs with music on or off")
		check(item.spawns.size()==(1 if item.music else 0),"original music flag gates note emission")
		check(int(item.next_index)==((int(item.index)+1)%10 if item.music else int(item.index)),"original ten-note pool advances only while music plays")
		if not item.music:continue
		var spawn=View.note_spawn(item.width,item.height,int(item.random_x),int(item.random_y))
		var native=item.spawns[0]
		check(spawn.point.distance_to(Vector2(native.x,native.y))<0.0001,"original randomized note spawn position")
		check(spawn.duration==native.duration and absf(spawn.distance-native.distance)<0.0001,"original note duration and distance")
	var view=View.new();view.reset([],Rect2(),[{"id":1}],Rect2(280,500,100,150),114)
	view.advance(0.7,false);check(view.notes.all(func(n):return n==null),"muted music emits no reconstructed notes")
	view.advance(0.7,true);check(view.notes[0]!=null and view.next_note==0,"enabled music emits and wraps the supplied note pool on the shared interval")
	var report={"checks":checks,"failures":failures,"method":reference.method+" Original path points are compared; curve flattening, keyframe interpolation and pixels remain reconstructed."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/menu-motion-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MENU_MOTION_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

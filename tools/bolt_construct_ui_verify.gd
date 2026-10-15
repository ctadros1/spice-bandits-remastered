extends SceneTree
var Bolt
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	create_timer(30).timeout.connect(func():push_error("Bolt construction verification timed out.");quit(1))
	run.call_deferred()
func run() -> void:
	# Bolt's renderer references the Content autoload. Load after registration
	# when this standalone SceneTree entry point runs outside the game folder.
	Bolt=load("res://scripts/bolt_view.gd")
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-bolt-construct-reference.json")))
	for case in reference.cases:
		var vectors=PackedVector2Array()
		for i in range(case.vectors.size()):
			var vector=SpiceNative.projected_random_vector(case.rand[i*2],case.rand[i*2+1]);vectors.append(vector)
			for j in range(2):check(vector[j]==Bolt.f32(case.vectors[i][j]),"original bolt projected-vector component")
		var points=Bolt.construct(Vector2(case.start[0],case.start[1]),Vector2(case.end[0],case.end[1]),vectors,case.scatter)
		check(points.size()==case.points.size(),"original seven-point count")
		for i in range(points.size()):
			for j in range(2):check(points[i][j]==Bolt.f32(case.points[i][j]),"original accumulated point, jitter and explicit scatter")
	var report={"checks":checks,"failures":failures,"method":reference.method+" Runtime retains a separate seeded visual stream. Caller scatter selection, refresh cadence, ball sprite and original whole-game pixels remain unproven."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/bolt-construct-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOLT_CONSTRUCT_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

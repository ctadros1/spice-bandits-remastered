extends SceneTree
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func compare(actual:Dictionary,expected:Dictionary,tolerance:float,label:String) -> void:
	check(actual.vertices.size()==expected.vertices.size(),label+" vertex count")
	check(actual.indices==expected.indices,label+" triangle order")
	check(actual.uvs==expected.uvs,label+" UV order")
	check(actual.colors==expected.colors,label+" saved vertex colors")
	for i in range(mini(actual.vertices.size(),expected.vertices.size())):
		check(actual.vertices[i].distance_to(expected.vertices[i])<=tolerance,label+" vertex")
		check(actual.bounds.grow(0.0002).has_point(actual.vertices[i]),label+" conservative native bounds")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var bolt=load("res://scripts/bolt_view.gd")
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-bolt-reference.json")))
	for case in original.cases:
		var path=PackedVector2Array()
		for value in case.points:path.append(Vector2(value[0],value[1]))
		var pass_id=int(case["pass"])
		var opacity=float(case.alpha if pass_id==1 else case.intensity*4)/255.0
		var native=bolt.ribbon(path,pass_id,opacity)
		check(native.vertices.size()==case.vertices.size(),"original ARM ribbon buffer size")
		for i in range(mini(native.vertices.size(),case.vertices.size())):
			var vertex=case.vertices[i]
			check(native.vertices[i].distance_to(Vector2(vertex.pos[0],vertex.pos[1]))<0.0001,"original ARM ribbon position")
			check(native.uvs[i]==Vector2(vertex.uv[0],vertex.uv[1]),"original ARM ribbon UV")
			var color=native.colors[i]
			for channel in range(4):check(absf(color[channel]-vertex.color[channel]/255.0)<0.000001,"original ARM ribbon color byte")
	var random=RandomNumberGenerator.new();random.seed=11484
	for size in [0,1,2,3,7,12]:
		for shape in range(8):
			var path=PackedVector2Array()
			for i in range(size):
				path.append(Vector2.ZERO if shape==0 else Vector2(i*0.05,0) if shape==1 else Vector2(-i*20,i%2*50) if shape==2 else Vector2(random.randf_range(-1024,1024),random.randf_range(-768,768)))
			for pass_id in [1,2]:
				for opacity in [0.0,0.35,0.7,1.0]:
					compare(bolt.ribbon(path,pass_id,opacity),bolt.reference_ribbon(path,pass_id,opacity),0.000001,"retained script/native regression")
	var report={"checks":checks,"failures":failures,"method":"12 original ARM FillBuffer fixture cases plus384 retained script/native cases for empty,short,reversed,stationary and seeded paths. Exact UV/color/index comparisons and1e-6 script vertex tolerance; original ARM position tolerance1e-4. No original GPU/global RNG or whole-game equivalence."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/bolt-ribbon-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOLT_RIBBON_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

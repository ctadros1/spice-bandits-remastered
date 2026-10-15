extends SceneTree
var checks=0
var failures=[]
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-water-reference.json")))
	var native=ClassDB.instantiate("SpiceNative")
	var table=native.water_table(int(original.seed))
	for i in range(original.table.permutation.size()):
		check(table.permutation[i]==int(original.table.permutation[i]),"original Perlin permutation")
		check(table.gradients[i]==float(original.table.gradients[i]),"original Perlin gradient")
	for sample in original.noise_samples:check(absf(native.water_noise(table,float(sample.x))-float(sample.noise))<0.000001,"original Perlin noise")
	for configuration in [original]+original.configurations:
		var settings={"plane":Vector2(configuration.plane[0],configuration.plane[1]),"segments":Vector2(configuration.segments[0],configuration.segments[1]),"water_uv":configuration.water_uv,"mask_uv":configuration.mask_uv,"amplitude":original.amplitude,"density":original.density,"mask_scale":original.mask_scale}
		for sample in configuration.cases:
			var mesh=native.water_vertices(table,settings,float(sample.phase))
			check(mesh.vertices.size()==int(sample.draw_count),"original water strip vertex count")
			for i in range(mini(mesh.vertices.size(),sample.vertices.size())):
				var v=sample.vertices[i]
				check(mesh.vertices[i].distance_to(Vector2(v[0],v[1]))<0.0001,"original water position")
				check(mesh.uvs[i].distance_to(Vector2(v[2],v[3]))<0.000001,"original animated water UV")
				check(mesh.mask_uvs[i].distance_to(Vector2(v[4],v[5]))<0.000001,"original water mask UV")
	var report={"checks":checks,"failures":failures,"method":"Original ARM water/Perlin comparisons with explicit texture bounds and Darwin libc rand/sin/cos stubs. No original texture-loading/compositing or global-RNG equivalence claimed."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/water-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WATER_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

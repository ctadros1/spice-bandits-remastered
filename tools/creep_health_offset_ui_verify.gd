extends SceneTree
var checks=0
var failure_count=0
var failures=[]
func _initialize() -> void:
	create_timer(60).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failure_count+=1
		if failures.size()<20:failures.append(label)
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func run() -> void:
	var path="res://../tests/fixtures/native-creep-health-offset-reference.json"
	check(FileAccess.get_sha256(path)=="4ffdadfe0596c24c76b79f881c0e93a73b288d0bad1bf7d0e39cb684589ce3db","unchanged independently repeated original fixture")
	var reference=JSON.parse_string(FileAccess.get_file_as_string(path));var app=load("res://scripts/main.gd").new();app.sim=load("res://scripts/simulation.gd").new()
	for row in reference.cases:
		var input=row.input
		var actor={"pos":Vector2(input.point[0],input.point[1]),"visual_pos":Vector2(input.point[0],input.point[1]),"def":{"traits":{"offset":input.offset}},"float_until":0,"hp":float(input.hp),"max_hp":100,"grow_ms":float(input.alpha)*400,"state":int(input.state)}
		var result=app.creep_health_layout(actor)
		var background=row.calls.filter(func(call):return call.method=="health-background")
		var fill=row.calls.filter(func(call):return call.method=="health-fill")
		check(result.is_empty()==background.is_empty(),"actual original HP/state admission")
		if result.is_empty():continue
		check(background.size()==1 and fill.size()==1,"original background/fill submissions")
		for k in 2:check(bits(result.origin[k])==bits(float(background[0].point[k])),"actual renderer uses raw animator position independently of body offset")
		var expected=fill[0].geometry_uv;var actual=[result.fill.position.x,result.fill.position.y,result.fill.size.x,result.fill.size.y,result.uv.x,result.uv.y,result.uv.z,result.uv.w]
		for k in 8:check(bits(actual[k])==bits(float(expected[k])),"actual original fill geometry/UV")
		for k in 4:check(bits(result.premultiplied[k])==bits(float(fill[0].rgba[k])),"actual original health RGBA")
	app.free()
	var suffix="postport" if "--postport" in OS.get_cmdline_user_args() else "preport"
	var report={"checks":checks,"failure_count":failure_count,"failures":failures,"original_cases":reference.cases.size(),"scope":"Actual Main health layout against original full Creep.Render with independent raw animator position/body offsets. Preserved fixed health texture dimensions and exact float32 fields. Full Fly/portal/renderer/GPU lifetimes remain separate."}
	var f=FileAccess.open("res://../builds/creep-health-offset-r169-"+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("CREEP_HEALTH_OFFSET ",JSON.stringify(report));quit(1 if failure_count else 0)

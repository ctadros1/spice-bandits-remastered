extends SceneTree
const View=preload("res://scripts/hud_wallet_view.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-hud-wallet-reference.json")))
	if reference==null:push_error("Original HUD wallet fixture is missing.");quit(1);return
	for sample in reference.cases:
		var position=View.money_position(sample.width,sample.money_width,sample.spice_width,sample.phone)
		for axis in range(2):check(absf(position[axis]-sample.money_position[axis])<0.00001,"original width-dependent HUD money position")
	for sample in reference.spice_cases:
		check(sample.spice_formats.size()==1,"one original spice format branch")
		check(View.spice_text(int(sample.spice))==sample.spice_formats[0].text,"original spice format/float32 parameter with explicit libc reference")
	for sample in reference.xp_cases:
		var pose=View.xp_pose(sample.width,sample.xp,sample.remaining,int(sample.lower),int(sample.level),sample.xp_width,sample.phone)
		var frame=sample.draws.filter(func(item):return item.kind=="image" and item.target=="0x801400")[0]
		var fill=sample.draws.filter(func(item):return item.kind=="fill")[0]
		var text=sample.draws.filter(func(item):return item.kind=="text" and item.target=="0x801500")[0]
		for axis in range(2):
			check(pose.frame.position[axis]==frame.point[axis],"original HUD XP frame position")
			check(pose.text[axis]==text.point[axis],"original width-centered HUD XP text position")
			check(pose.fill.position[axis]==fill.values[axis],"original HUD XP fill position")
			check(absf(pose.fill.size[axis]-fill.values[axis+2])<0.00001,"original HUD XP fill dimensions/minimum above level1")
	var report={"checks":checks,"failures":failures,"method":reference.method+" Source LoadTexts0xc6504 separately traces25pt money and15pt tablet spice in Kautiva Pro regular. CoreText metrics and money flash/shadow raster remain separate limits."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/hud-wallet-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("HUD_WALLET_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

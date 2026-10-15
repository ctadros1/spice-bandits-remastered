extends SceneTree
const Wave=preload("res://scripts/wave_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-wave-reference.json")))
	var checks=0;var failures=[]
	for sample in original.cases:
		var rows=Wave.rows(int(sample.current),int(sample.elapsed),5000,6,sample.particle_field_c0,60)
		checks+=1
		if rows.size()!=sample.text_draws.size():failures.append("original wave visibility count")
		for i in range(mini(rows.size(),sample.text_draws.size())):
			var expected=sample.text_draws[i]
			checks+=3
			if rows[i].number!=int(expected.object):failures.append("original wave number")
			if rows[i].x+35!=int(expected.x):failures.append("original wave position")
			if rows[i].text_y!=int(expected.y):failures.append("original wave text top")
	var colors=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-wave-indicators.json")))
	for sample in colors.cases:
		var segments=Wave.indicators(sample.creeps,float(sample.width))
		checks+=1
		if segments.size()!=sample.indicators.size():failures.append("original indicator count/order")
		for i in range(mini(segments.size(),sample.indicators.size())):
			var expected=sample.indicators[i]
			checks+=5
			for channel in range(4):
				if absf(segments[i].color[channel]-float(expected[channel]))>0.000001:failures.append("original indicator color")
			if absf(segments[i].width-float(expected[4]))>0.000001:failures.append("original indicator width")
	var report={"checks":checks,"failures":failures,"method":"80 original RenderWaves states and18 original CreateIndicators states with code-traced palette; no early-collapse or whole-callback/framebuffer equivalence."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/wave-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WAVE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

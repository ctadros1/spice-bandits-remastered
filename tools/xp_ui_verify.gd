extends SceneTree
const View=preload("res://scripts/xp_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-xp-footer-reference.json")))
	var checks=0;var failures=[]
	for case in original.cases:
		var pose=View.footer(case.xp,case.remaining,case.lower,int(case.level),case.width if case.width>0 else 82.0)
		checks+=2
		if pose.width!=View.f32(case.result.bar_width):failures.append("original footer width")
		if pose.promotion_hidden!=case.result.promotion_hidden:failures.append("original promotion visibility")
		for i in range(case.result.formats.size()):
			var request=case.result.formats[i];var value=pose.current if i==0 else pose.upper
			var expected_format="%.2fm" if value>=1000000 else "%.1fk" if value>=1000 else "%.0f"
			var expected_amount=View.f32(float(value)/(1000000.0 if value>=1000000 else 1000.0 if value>=1000 else 1.0))
			checks+=2
			if not str(request.format).contains(expected_format):failures.append("original footer format request")
			if request.amount!=expected_amount:failures.append("original footer amount")
	# Code-traced libc formats and original float32 thousand/million constants.
	# These are local formatter regressions, not execution of ARM libc.
	for case in [[8.1,"8"],[9.49,"9"],[9.5,"10"],[8.5,"8"],[99.5,"100"],[999.5,"1000"],[1000,"1.0k"],[1234.5,"1.2k"],[1000000,"1.00m"],[53286.7,"53.3k"]]:
		checks+=1
		if SpiceNative.format_xp(case[0])!=case[1]:failures.append("code-traced libc XP format")
	checks+=1
	if SpiceNative.format_xp(1234.5,false)!="1234":failures.append("unshortened result XP uses libc rounding")
	var report={"checks":checks,"failures":failures,"method":"36 bounded original MenuBottomView arithmetic/format/frame cases plus11 code-traced local libc XP/health formatter regressions. ObjC data, NSString formatting, roundf and UIKit are explicit stubs; full app/pixels and service thresholds are outside the fixture."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/xp-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("XP_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

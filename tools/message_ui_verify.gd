extends SceneTree
const View=preload("res://scripts/message_view.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-message-reference.json")))
	var checks=0;var failures=[]
	for case in original.messages:
		var size=Vector2(case.size[0],case.size[1]);var alpha=View.advance(case.alpha,case.dt,bool(case.closing))
		checks+=1
		if alpha!=case.result.alpha:failures.append("original message fade")
		var expected=[View.background(size).position,View.text_position(size,0,true),View.text_position(size,300,false)]
		for i in range(3):
			for k in range(2):
				checks+=1
				if expected[i][k]!=case.result.draws[i].position[k]:failures.append("original message quad/text position")
	for case in original.buttons:
		checks+=1
		if View.button_enabled(case.alpha)!=(not case.result.hits.is_empty()):failures.append("original message input alpha threshold")
		var pose=View.button(Vector2(case.size[0],case.size[1]),int(case.index))
		var expected=[pose.sprite.position,Vector2(pose.center_x-15,pose.text_y)]
		for i in range(2):
			for k in range(2):
				checks+=1
				if expected[i][k]!=case.result.draws[i].position[k]:failures.append("original button quad/text position")
		if not case.result.hits.is_empty():
			var hit=case.result.hits[0]
			for k in range(4):
				checks+=1
				if hit[k]!=(pose.hit.position[k] if k<2 else pose.hit.size[k-2]):failures.append("original button click bounds")
	var report={"checks":checks,"failures":failures,"method":original.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/message-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MESSAGE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

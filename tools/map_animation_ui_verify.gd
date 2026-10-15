extends SceneTree
const View=preload("res://scripts/map_animation_view.gd")
var checks=0
var failures=[]
func check(value:bool,name:String) -> void:
	checks+=1
	if not value:failures.append(name)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-map-animation-reference.json")))
	for case in original.cases:
		var state=View.initial()
		for frame in case.frames:
			var pose=View.advance(state,case.definition,float(frame.dt_ms))
			var values=[pose.position.x,pose.position.y,pose.angle]
			for i in range(3):check(values[i]==View.f32(frame.draw[i]),"original animated map position/rotation "+case.definition.name)
			check(state.phase==View.f32(frame.phase),"original keyframe phase")
			check(state.index==int(frame.index),"original keyframe segment")
			check(state.stopped==frame.stopped,"original keyframe stop")
			check(state.initialized==frame.initialized,"original keyframe initialization")
	var report={"checks":checks,"failures":failures,"method":"504 original animated map render/keyframe frames, eight authored paths and four explicit loop/ease three-frame variants. Quad rendering is stubbed; no original texture/raster equivalence."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/map-animation-verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAP_ANIMATION_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

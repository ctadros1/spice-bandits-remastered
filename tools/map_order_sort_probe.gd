extends SceneTree
const Depth=preload("res://scripts/map_depth.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var source=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-map-order-reference.json")))
	var comparisons=0;var mismatches=[]
	for case in source.sorts:
		var objects=[]
		for i in range(case.values.size()):objects.append({"id":i,"y":Depth.key(int(case.values[i][0]),case.values[i][1])})
		for pass_index in range(3):
			if not case.locked:objects.sort_custom(func(a,b):return a.y<b.y)
			var actual=objects.map(func(o):return o.id)
			var expected=case.output[pass_index].main.map(func(id):return int(id))
			comparisons+=1
			if actual!=expected:mismatches.append({"pattern":case.pattern,"size":case.size,"pass":pass_index,"expected":expected,"actual":actual})
	var report={"comparisons":comparisons,"mismatch_count":mismatches.size(),"mismatches":mismatches,"scope":"Current Godot4.7.2 sort_custom versus540 original CMap calls over supplied vectors, including locked/empty guards. Mutable input retained between calls. No whole-game registration or drawing claim."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/map-order-godot-sort-r96.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAP_ORDER_SORT_PROBE ",JSON.stringify({"comparisons":comparisons,"mismatch_count":mismatches.size()}));quit(0 if mismatches.is_empty() else 1)

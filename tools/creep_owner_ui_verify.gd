extends SceneTree
const Owner=preload("res://scripts/creep_owner_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-owner-reference.json")))
	var definitions=[{"class":"unused"},{"class":"ground"},{"class":"air"}]
	var callbacks=0
	for case in reference.cases:
		var visible=[]
		for i in range(case.missile_flags_a0.size()):
			# The original owner guard is executed by the ARM probe. Feed
			# only that recorded visible set into the phase reconstruction.
			# Current simulation suppression/lifetime is not verified here.
			if not case.missile_flags_a0[i]:visible.append({"type":int(case.resource_type),"owner":10,"label":i})
		var passes=Owner.missile_passes([{"id":10}],visible,definitions)
		for pair in [["before","before_air"],["after","ground_after"]]:
			var expected=case[pair[0]].filter(func(call):return call.method=="missile").map(func(call):return int(call.label))
			check(passes[pair[1]].map(func(m):return m.label)==expected,"original visible owner phase "+str(case.resource_type)+" "+pair[0])
		callbacks+=case.before.size()+case.after.size()
	check(reference.cases.size()==192 and callbacks==464,"all192 complete owner probes/464 callbacks consumed")
	var missiles=[{"type":2,"owner":20,"label":0},{"type":1,"owner":10,"label":1},{"type":2,"owner":10,"label":2},{"type":2,"owner":20,"label":3}]
	var ordered=Owner.missile_passes([{"id":10},{"id":20}],missiles,definitions)
	check(ordered.before_air.map(func(m):return m.label)==[2,0,3],"air missiles follow manager owner order and each owner missile insertion order")
	check(ordered.ground_after.map(func(m):return m.label)==[1],"ground missile remains in later existing pass")
	var reversed=Owner.missile_passes([{"id":20},{"id":10}],missiles,definitions)
	check(reversed.before_air.map(func(m):return m.label)==[0,3,2],"manager reversal changes owner grouping without changing per-owner order")
	var orphan=Owner.missile_passes([],missiles,definitions)
	check(orphan.before_air.size()==3 and orphan.ground_after.size()==1,"existing orphan lifetime retained pending original destruction trace")
	check(missiles.map(func(m):return m.label)==[0,1,2,3],"routing leaves simulation missile vector unchanged")
	missiles[2].label=99
	check(ordered.before_air[0].label==99,"drawing records retain live dictionary identity")
	var content=root.get_node("Content")
	var populated=0
	for type in range(content.catalog.tower_creeps.size()):
		var definition=content.catalog.tower_creeps[type]
		if not definition.has("filename"):continue
		var result=Owner.missile_passes([{"id":1}],[{"type":type,"owner":1}],content.catalog.tower_creeps)
		check(result.before_air.size()==int(definition.get("class","")=="air") and result.ground_after.size()==int(definition.get("class","")=="ground"),"authored resource phase "+str(type))
		populated+=1
	check(populated==29,"all29 populated resource classes covered")
	var report={"checks":checks,"failures":failures,"original_cases":reference.cases.size(),"callbacks":callbacks,"populated_resources":populated,"limit":"Visible owner phase only. Suppression/lifetime, ground double-after/effect interleaving, original GPU and whole-game pixels remain open."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-owner-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_OWNER_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
